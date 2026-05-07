import os
import requests
import hashlib
import hmac
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from config.db import get_db

payments_bp = Blueprint('payments', __name__)

PAYSTACK_SECRET = os.getenv('PAYSTACK_SECRET_KEY', '')
PAYSTACK_WEBHOOK_SECRET = os.getenv('PAYSTACK_WEBHOOK_SECRET', '')


def _paystack_headers():
    return {
        'Authorization': f'Bearer {PAYSTACK_SECRET}',
        'Content-Type': 'application/json'
    }


# ─── POST /payments — Initiate charge (MoMo or Bank) ──────────────────────────
@payments_bp.route('/', methods=['POST'])
@jwt_required()
def create_payment():
    member_id = get_jwt_identity()
    data = request.get_json()
    amount      = data.get('amount')
    description = data.get('description')
    payment_ref = data.get('payment_ref', '')
    method      = data.get('method', 'momo')   # 'momo' | 'bank'
    network     = data.get('network', 'MTN')   # MTN | Vodafone | AirtelTigo
    phone       = data.get('phone', '')

    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT email, name FROM members WHERE id = %s", (member_id,))
            member = cursor.fetchone()
            if not member:
                return jsonify({'message': 'Member not found'}), 404

            full_desc = f"{description} (Ref: {payment_ref})" if payment_ref else description

            cursor.execute("""
                INSERT INTO payments (member_id, amount, description, status, payment_ref)
                VALUES (%s, %s, %s, 'pending', %s)
                RETURNING id
            """, (member_id, amount, full_desc, payment_ref))
            payment_id = cursor.fetchone()['id']

            if description and 'Renewal' in description:
                cursor.execute(
                    "UPDATE members SET status = 'pending', payment_ref = %s WHERE id = %s",
                    (payment_ref, member_id)
                )
            conn.commit()

        # ── MoMo via Paystack ───────────────────────────────────────────────
        if method == 'momo' and PAYSTACK_SECRET and 'REPLACE' not in PAYSTACK_SECRET:
            network_map = {'MTN': 'mtn', 'Vodafone': 'vod', 'AirtelTigo': 'atl'}
            payload = {
                'email': member['email'],
                'amount': int(float(amount) * 100),  # pesewas
                'currency': 'GHS',
                'mobile_money': {
                    'phone': phone,
                    'provider': network_map.get(network, 'mtn')
                },
                'metadata': {
                    'payment_id': payment_id,
                    'member_id': member_id,
                    'description': description
                }
            }
            try:
                ps_res = requests.post(
                    'https://api.paystack.co/charge',
                    json=payload,
                    headers=_paystack_headers(),
                    timeout=15
                )
                ps_data = ps_res.json()
                ps_status = ps_data.get('data', {}).get('status', '')

                return jsonify({
                    'payment_id': payment_id,
                    'paystack_ref': ps_data.get('data', {}).get('reference'),
                    'status': 'pending',
                    'message': 'Prompt sent! Approve the payment on your phone.' if ps_status in ('send_otp', 'pay_offline', 'pending') else ps_data.get('message', 'Prompt sent')
                }), 200
            except Exception as e:
                # Paystack call failed but payment is saved — return gracefully
                return jsonify({'payment_id': payment_id, 'status': 'pending', 'message': 'Payment recorded. MoMo prompt could not be sent.'}), 200

        # ── Bank transfer ───────────────────────────────────────────────────
        return jsonify({
            'payment_id': payment_id,
            'status': 'pending',
            'message': 'Bank transfer recorded successfully.'
        }), 201

    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


# ─── GET /payments/status/<id> — Poll payment status ──────────────────────────
@payments_bp.route('/status/<int:payment_id>', methods=['GET'])
@jwt_required()
def poll_payment_status(payment_id):
    member_id = get_jwt_identity()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT id, status, amount, description, created_at FROM payments WHERE id = %s AND member_id = %s",
                (payment_id, member_id)
            )
            payment = cursor.fetchone()
        if not payment:
            return jsonify({'message': 'Not found'}), 404
        return jsonify(payment), 200
    finally:
        conn.close()


# ─── POST /payments/webhook — Paystack fires this when payment completes ───────
@payments_bp.route('/webhook', methods=['POST'])
def paystack_webhook():
    sig = request.headers.get('X-Paystack-Signature', '')
    body = request.get_data()

    if PAYSTACK_WEBHOOK_SECRET and 'your_webhook' not in PAYSTACK_WEBHOOK_SECRET:
        expected = hmac.new(
            PAYSTACK_WEBHOOK_SECRET.encode(), body, hashlib.sha512
        ).hexdigest()
        if not hmac.compare_digest(sig, expected):
            return jsonify({'message': 'Invalid signature'}), 400

    event = request.get_json()

    if event.get('event') == 'charge.success':
        meta = event.get('data', {}).get('metadata', {})
        payment_id = meta.get('payment_id')

        if payment_id:
            conn = get_db()
            try:
                with conn.cursor() as cursor:
                    cursor.execute(
                        "UPDATE payments SET status = 'paid', paid_at = NOW() WHERE id = %s",
                        (payment_id,)
                    )
                    conn.commit()

                    # Fetch member email and payment details for receipt
                    cursor.execute("""
                        SELECT m.email, m.name, p.amount, p.description, p.created_at
                        FROM payments p JOIN members m ON p.member_id = m.id
                        WHERE p.id = %s
                    """, (payment_id,))
                    row = cursor.fetchone()

                if row:
                    _send_receipt_email(
                        to_email=row['email'],
                        member_name=row['name'],
                        amount=row['amount'],
                        description=row['description'],
                        payment_id=payment_id
                    )
            finally:
                conn.close()

    return jsonify({'message': 'ok'}), 200


def _send_receipt_email(to_email, member_name, amount, description, payment_id):
    smtp_host   = os.getenv('SMTP_HOST', '')
    smtp_port   = int(os.getenv('SMTP_PORT', 465))
    smtp_user   = os.getenv('SMTP_USER', '')
    smtp_pass   = os.getenv('SMTP_PASS', '')
    if not smtp_host or not smtp_user:
        return  # SMTP not configured — skip silently

    msg = MIMEMultipart('alternative')
    msg['Subject'] = f'CUBAG Payment Receipt — GH₵ {float(amount):.2f}'
    msg['From']    = smtp_user
    msg['To']      = to_email

    html = f"""
    <div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;padding:32px;border:1px solid #eee;border-radius:12px">
      <h2 style="color:#f08232">CUBAG</h2>
      <p>Hi <strong>{member_name}</strong>,</p>
      <p>Your payment has been confirmed. Here is your receipt:</p>
      <table style="width:100%;border-collapse:collapse">
        <tr><td style="padding:10px 0;border-bottom:1px solid #eee;color:#888">Description</td><td style="text-align:right;font-weight:700">{description}</td></tr>
        <tr><td style="padding:10px 0;border-bottom:1px solid #eee;color:#888">Amount</td><td style="text-align:right;font-weight:900;color:#f08232;font-size:1.2em">GH₵ {float(amount):.2f}</td></tr>
        <tr><td style="padding:10px 0;border-bottom:1px solid #eee;color:#888">TX ID</td><td style="text-align:right">{payment_id}</td></tr>
        <tr><td style="padding:10px 0;color:#888">Status</td><td style="text-align:right"><span style="background:#d1fae5;color:#10b981;padding:2px 10px;border-radius:20px;font-size:0.8em;font-weight:800">PAID</span></td></tr>
      </table>
      <p style="margin-top:24px;color:#888;font-size:0.85em">Thank you for your payment. This is an automated receipt from CUBAG.</p>
    </div>
    """
    msg.attach(MIMEText(html, 'html'))

    try:
        with smtplib.SMTP_SSL(smtp_host, smtp_port) as server:
            server.login(smtp_user, smtp_pass)
            server.sendmail(smtp_user, to_email, msg.as_string())
    except Exception as e:
        print(f'[Email] Failed to send receipt to {to_email}: {e}')


# ─── GET /payments/ — Member payment history ──────────────────────────────────
@payments_bp.route('/', methods=['GET'])
@jwt_required()
def get_payments():
    member_id = get_jwt_identity()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT * FROM payments WHERE member_id = %s ORDER BY created_at DESC", (member_id,))
            data = cursor.fetchall()
        return jsonify(data), 200
    finally:
        conn.close()


# ─── GET /payments/summary ────────────────────────────────────────────────────
@payments_bp.route('/summary', methods=['GET'])
@jwt_required()
def payments_summary():
    member_id = get_jwt_identity()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT 
                    SUM(CASE WHEN status='paid' THEN amount ELSE 0 END) as total_paid,
                    SUM(CASE WHEN status='pending' THEN amount ELSE 0 END) as total_pending,
                    SUM(CASE WHEN status='overdue' THEN amount ELSE 0 END) as total_overdue
                FROM payments WHERE member_id = %s
            """, (member_id,))
            data = cursor.fetchone()
        return jsonify(data), 200
    finally:
        conn.close()


# ─── GET /payments/admin/all ──────────────────────────────────────────────────
@payments_bp.route('/admin/all', methods=['GET'])
@jwt_required()
def get_all_payments_admin():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT p.id as tx_id, p.amount, p.description, p.status,
                       p.created_at as date, m.name as member_name
                FROM payments p
                LEFT JOIN members m ON p.member_id = m.id
                ORDER BY p.created_at DESC
            """)
            payments = cursor.fetchall()

            cursor.execute("SELECT COALESCE(SUM(amount), 0) as revenue FROM payments WHERE status = 'paid'")
            revenue = cursor.fetchone()

            cursor.execute("SELECT COALESCE(SUM(amount), 0) as pending FROM payments WHERE status = 'pending'")
            pending = cursor.fetchone()

            cursor.execute("SELECT COUNT(id) as failed FROM payments WHERE status = 'overdue'")
            failed = cursor.fetchone()

        return jsonify({
            'transactions': payments,
            'kpis': {
                'revenue': revenue['revenue'] or 0,
                'pending': pending['pending'] or 0,
                'failed': failed['failed'] or 0
            }
        }), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


# ─── POST /payments/admin/mark-paid/<id> ─────────────────────────────────────
@payments_bp.route('/admin/mark-paid/<int:payment_id>', methods=['POST'])
@jwt_required()
def admin_mark_paid(payment_id):
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "UPDATE payments SET status = 'paid', paid_at = NOW() WHERE id = %s",
                (payment_id,)
            )
            conn.commit()
        return jsonify({'message': 'Payment marked as paid'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


# ─── POST /payments/admin/approve-license/<id> ───────────────────────────────
@payments_bp.route('/admin/approve-license/<int:payment_id>', methods=['POST'])
@jwt_required()
def admin_approve_license(payment_id):
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Get the member_id from the payment
            cursor.execute("SELECT member_id FROM payments WHERE id = %s", (payment_id,))
            row = cursor.fetchone()
            if not row:
                return jsonify({'message': 'Payment not found'}), 404

            member_id = row['member_id']

            # Mark payment as paid
            cursor.execute(
                "UPDATE payments SET status = 'paid', paid_at = NOW() WHERE id = %s",
                (payment_id,)
            )
            # Approve the member's license
            cursor.execute(
                "UPDATE members SET status = 'active' WHERE id = %s",
                (member_id,)
            )
            conn.commit()
        return jsonify({'message': 'License approved and payment confirmed'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()
