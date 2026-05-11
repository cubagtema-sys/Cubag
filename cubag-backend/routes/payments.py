import os
import requests
import hashlib
import hmac
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from flask import Blueprint, jsonify, request
from flask_cors import cross_origin
from flask_jwt_extended import jwt_required, get_jwt_identity
from config.db import get_db
from socket_instance import socketio

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
    payment_ref = data.get('payment_ref', '') # Internal ref from client
    method      = data.get('method', 'momo')   # 'momo' | 'bank'
    network     = data.get('network', 'MTN')   # MTN | Vodafone | AirtelTigo
    phone       = data.get('phone', '')

    if not amount or not description:
        return jsonify({'message': 'Amount and description are required'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT email, name FROM members WHERE id = %s", (member_id,))
            member = cursor.fetchone()
            if not member:
                return jsonify({'message': 'Member not found'}), 404

            # ── Duplicate Prevention Logic ──
            # If they are paying for "License Renewal" or "Association Dues",
            # check if they already have a 'pending' transaction for that exact thing.
            # If so, we'll "re-use" that record ID rather than making a duplicate.
            cursor.execute("""
                SELECT id FROM payments
                WHERE member_id = %s AND description = %s AND status = 'pending'
                LIMIT 1
            """, (member_id, description))
            existing_pending = cursor.fetchone()

            if existing_pending:
                payment_id = existing_pending['id']
                # Update the existing record with the new payment_ref and amount just in case
                cursor.execute("""
                    UPDATE payments SET amount = %s, payment_ref = %s
                    WHERE id = %s
                """, (amount, payment_ref, payment_id))
            else:
                # Initialize New Record
                cursor.execute("""
                    INSERT INTO payments (member_id, amount, description, status, payment_ref)
                    VALUES (%s, %s, %s, 'pending', %s)
                    RETURNING id
                """, (member_id, amount, description, payment_ref))
                payment_id = cursor.fetchone()['id']

            # If it's a license renewal, ensure member status is 'pending' while waiting for pay
            if 'Renewal' in description:
                cursor.execute(
                    "UPDATE members SET status = 'pending' WHERE id = %s",
                    (member_id,)
                )

            conn.commit()

        # ── 2. Handle MoMo via Paystack ──
        if method == 'momo' and PAYSTACK_SECRET and 'REPLACE' not in PAYSTACK_SECRET:
            network_map = {'MTN': 'mtn', 'Vodafone': 'vod', 'AirtelTigo': 'atl'}

            # Ensure phone is in local 10-digit format for Paystack GHS
            # (Remove +233 if it was somehow added, but usually frontend sends 0...)
            clean_phone = phone.strip().replace(' ', '')
            if clean_phone.startswith('+233'):
                clean_phone = '0' + clean_phone[4:]

            payload = {
                'email': member['email'],
                'amount': int(float(amount) * 100),  # pesewas
                'currency': 'GHS',
                'mobile_money': {
                    'phone': clean_phone,
                    'provider': network_map.get(network, 'mtn')
                },
                'metadata': {
                    'payment_id': payment_id,
                    'member_id': member_id,
                    'description': description
                }
            }
            print(f"[DEBUG] Initiating Paystack Charge. Phone: {clean_phone}, Provider: {network_map.get(network)}")
            try:
                ps_res = requests.post(
                    'https://api.paystack.co/charge',
                    json=payload,
                    headers=_paystack_headers(),
                    timeout=15
                )
                ps_data = ps_res.json()
                print(f"[DEBUG] Paystack Charge Response: {ps_data}")

                if not ps_data.get('status'):
                    with conn.cursor() as cursor:
                        cursor.execute("UPDATE payments SET status = 'failed' WHERE id = %s", (payment_id,))
                        conn.commit()
                    return jsonify({
                        'payment_id': payment_id,
                        'message': ps_data.get('message', 'Paystack initialization failed'),
                        'error': True,
                        'details': ps_data
                    }), 400

                ps_payload = ps_data.get('data', {})
                paystack_ref = ps_payload.get('reference')
                ps_status = ps_payload.get('status')

                # ── 3. Update Record with Paystack Reference Immediately ──
                with conn.cursor() as cursor:
                    cursor.execute(
                        "UPDATE payments SET payment_ref = %s WHERE id = %s",
                        (paystack_ref, payment_id)
                    )
                    # If it's a license renewal, link it to the member profile too
                    if 'Renewal' in description:
                        cursor.execute(
                            "UPDATE members SET payment_ref = %s WHERE id = %s",
                            (paystack_ref, member_id)
                        )
                    conn.commit()

                return jsonify({
                    'payment_id': payment_id,
                    'paystack_ref': paystack_ref,
                    'status': ps_status,
                    'message': 'Payment request sent successfully. Please check your phone.',
                    'display_text': 'Please check your phone for the MoMo prompt.' if ps_status in ('send_otp', 'pay_offline', 'pending') else 'Authorization required'
                }), 200

            except Exception as e:
                with conn.cursor() as cursor:
                    cursor.execute("UPDATE payments SET status = 'failed' WHERE id = %s", (payment_id,))
                    conn.commit()
                return jsonify({
                    'payment_id': payment_id,
                    'status': 'failed',
                    'message': 'Payment record created, but MoMo prompt failed to send.',
                    'error': str(e)
                }), 400

        # ── 4. Handle Bank Transfer ──
        return jsonify({
            'payment_id': payment_id,
            'status': 'pending',
            'message': 'Bank transfer record saved. Awaiting verification.'
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


# ─── POST /payments/verify-code — Submit OTP to Paystack ─────────────────────
@payments_bp.route('/verify-code', methods=['POST', 'OPTIONS'])
@jwt_required()
def verify_payment_code():
    if request.method == 'OPTIONS':
        return jsonify({'ok': True}), 200

    data = request.get_json() or {}
    payment_id  = data.get('payment_id')
    otp         = str(data.get('code', '')).strip()
    paystack_ref = str(data.get('paystack_ref', '')).strip()

    print(f"[DEBUG] verify-code called. payment_id: {payment_id}, otp: {otp}, ref: {paystack_ref}")

    if not paystack_ref or not otp:
        return jsonify({'message': 'Paystack reference and OTP code are required', 'error': True}), 400

    try:
        # 1. Submit OTP to Paystack
        payload = {'otp': otp, 'reference': paystack_ref}
        print(f"[DEBUG] Submitting to Paystack: {payload}")

        ps_res = requests.post(
            'https://api.paystack.co/charge/submit_otp',
            json=payload,
            headers=_paystack_headers(),
            timeout=15
        )
        ps_data = ps_res.json()
        print(f"[DEBUG] Paystack submit_otp response: {ps_data}")

        if not ps_data.get('status'):
            msg = ps_data.get('message', 'OTP verification failed')
            if not msg and ps_data.get('data'):
                msg = ps_data.get('data', {}).get('message')
            return jsonify({'message': msg or 'Paystack rejected the code', 'error': True}), 400

        # 2. Check the final status from the response
        ps_payload = ps_data.get('data', {})
        ps_status = ps_payload.get('status')

        if ps_status == 'success':
            _mark_payment_as_paid(payment_id or ps_payload.get('metadata', {}).get('payment_id'))
            return jsonify({'message': 'Payment confirmed! 🎉', 'status': 'success'}), 200

        return jsonify({
            'message': ps_data.get('message', 'Payment processing'),
            'status': ps_status
        }), 200

    except Exception as e:
        print(f"[ERROR] verify_payment_code: {str(e)}")
        return jsonify({'message': str(e)}), 500


# ─── GET /payments/verify/<reference> — Poll Paystack for status ─────────────
@payments_bp.route('/verify/<string:reference>', methods=['GET', 'OPTIONS'])
@cross_origin()
def verify_payment_manually(reference):
    if request.method == 'OPTIONS':
        return jsonify({'ok': True}), 200

    try:
        # Paystack uses /transaction/verify for all charge references
        ps_res = requests.get(
            f'https://api.paystack.co/transaction/verify/{reference}',
            headers=_paystack_headers(),
            timeout=15
        )
        ps_data = ps_res.json()

        if not ps_data.get('status'):
            # Transaction may not be finalized yet — return pending, not 404
            return jsonify({'message': 'Transaction pending', 'status': 'pending'}), 200

        ps_payload = ps_data.get('data', {})
        ps_status = ps_payload.get('status', 'pending')

        if ps_status == 'success':
            payment_id = ps_payload.get('metadata', {}).get('payment_id')
            _mark_payment_as_paid(payment_id)
            return jsonify({'message': 'Payment verified', 'status': 'success'}), 200
        elif ps_status in ('failed', 'abandoned', 'reversed', 'declined', 'cancelled', 'canceled'):
            payment_id = ps_payload.get('metadata', {}).get('payment_id')
            if payment_id:
                _mark_payment_as_failed(payment_id)
            return jsonify({'message': 'Payment failed or declined', 'status': 'failed'}), 200

        return jsonify({'message': 'Payment processing', 'status': ps_status}), 200
    except Exception as e:
        print(f'[ERROR] verify_payment_manually: {e}')
        # Return pending instead of 500 so frontend doesn't break
        return jsonify({'message': 'Checking...', 'status': 'pending'}), 200


def _mark_payment_as_failed(payment_id):
    if not payment_id: return
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT status FROM payments WHERE id = %s", (payment_id,))
            p = cursor.fetchone()
            if p and p['status'] == 'pending':
                cursor.execute(
                    "UPDATE payments SET status = 'failed' WHERE id = %s",
                    (payment_id,)
                )
                conn.commit()
    finally:
        conn.close()

def _mark_payment_as_paid(payment_id):
    if not payment_id: return
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Check if already paid to avoid double processing
            cursor.execute("SELECT status FROM payments WHERE id = %s", (payment_id,))
            p = cursor.fetchone()
            if p and p['status'] == 'paid': return

            cursor.execute(
                "UPDATE payments SET status = 'paid', paid_at = NOW() WHERE id = %s",
                (payment_id,)
            )
            # If it was a license renewal, activate the member
            cursor.execute("""
                UPDATE members m
                SET status = 'active'
                FROM payments p
                WHERE p.id = %s AND p.member_id = m.id AND p.description ILIKE '%%Renewal%%'
            """, (payment_id,))

            conn.commit()

            # Fetch for receipt email
            cursor.execute("""
                SELECT m.email, m.name, p.amount, p.description
                FROM payments p JOIN members m ON p.member_id = m.id
                WHERE p.id = %s
            """, (payment_id,))
            row = cursor.fetchone()
            if row:
                _send_receipt_email(row['email'], row['name'], row['amount'], row['description'], payment_id)
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
        ps_payload = event.get('data', {})
        payment_id = ps_payload.get('metadata', {}).get('payment_id')
        if payment_id:
            _mark_payment_as_paid(payment_id)
    elif event.get('event') in ('charge.failed', 'charge.abandoned', 'charge.reversed'):
        ps_payload = event.get('data', {})
        payment_id = ps_payload.get('metadata', {}).get('payment_id')
        if payment_id:
            _mark_payment_as_failed(payment_id)

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
            # Get Totals
            cursor.execute("""
                SELECT 
                    SUM(CASE WHEN status='paid' THEN amount ELSE 0 END) as total_paid,
                    SUM(CASE WHEN status='pending' THEN amount ELSE 0 END) as total_pending
                FROM payments WHERE member_id = %s
            """, (member_id,))
            totals = cursor.fetchone()

            # Get breakdown of pending items
            cursor.execute("""
                SELECT description, amount, created_at
                FROM payments
                WHERE member_id = %s AND status = 'pending'
                ORDER BY created_at DESC
            """, (member_id,))
            items = cursor.fetchall()

        return jsonify({
            'total_paid': float(totals['total_paid'] or 0),
            'total_pending': float(totals['total_pending'] or 0),
            'items': items
        }), 200
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
            # Get the member_id from the payment
            cursor.execute("SELECT member_id FROM payments WHERE id = %s", (payment_id,))
            row = cursor.fetchone()
            if row:
                # Mark payment as paid
                cursor.execute(
                    "UPDATE payments SET status = 'paid', paid_at = NOW() WHERE id = %s",
                    (payment_id,)
                )
                # Approve the member's license/activate account
                cursor.execute(
                    "UPDATE members SET status = 'active' WHERE id = %s",
                    (row['member_id'],)
                )
                conn.commit()
                # Real-time WebSocket emission
                socketio.emit('payment_approved', {'member_id': row['member_id'], 'payment_id': payment_id})
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
