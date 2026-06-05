import os
import uuid
import requests
import hashlib
import hmac
import smtplib
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from flask import Blueprint, jsonify, request
from flask_cors import cross_origin
from flask_jwt_extended import jwt_required, get_jwt_identity
from config.db import get_db
from socket_instance import socketio
from routes.admin import log_admin_action
from utils import admin_required, sub_admin_required

payments_bp = Blueprint('payments', __name__)
logger = logging.getLogger(__name__)

# ─── WhitsunPay Configuration ─────────────────────────────────────────────────
WHITSUNPAY_BASE_URL = os.getenv('WHITSUNPAY_BASE_URL', 'https://developer.whitsun.dev').rstrip('/')
WHITSUNPAY_CLIENT_ID = os.getenv('WHITSUNPAY_CLIENT_ID', '')
WHITSUNPAY_API_KEY = os.getenv('WHITSUNPAY_API_KEY', '')
WHITSUNPAY_WEBHOOK_SECRET = os.getenv('WHITSUNPAY_WEBHOOK_SECRET', '')
WHITSUNPAY_CALLBACK_URL = os.getenv('WHITSUNPAY_CALLBACK_URL', '')

# Full versioned API base — e.g. https://developer.whitsun.dev/api/v1
_WP_API = f'{WHITSUNPAY_BASE_URL}/api/v1'


def _whitsunpay_headers():
    """Build headers for WhitsunPay API requests (per official docs)."""
    return {
        'Content-Type': 'application/json',
        'x-client-id': WHITSUNPAY_CLIENT_ID,
        'x-api-key': WHITSUNPAY_API_KEY,
        'x-callback-url': WHITSUNPAY_CALLBACK_URL,  # Required per docs
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
                WHERE member_id = %s AND description = %s AND LOWER(status) = 'pending'
                LIMIT 1
            """, (member_id, description))
            existing_pending = cursor.fetchone()

            if existing_pending:
                payment_id = existing_pending['id']
                # Update the existing record with the new payment_ref and amount
                # We also refresh created_at so it shows up as "recent" in the history
                cursor.execute("""
                    UPDATE payments SET amount = %s, payment_ref = %s, created_at = NOW()
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

        # ── 2. Handle MoMo via WhitsunPay ──
        if method == 'momo' and WHITSUNPAY_CLIENT_ID and WHITSUNPAY_API_KEY:
            network_map = {'MTN': 'mtn', 'Vodafone': 'vodafone', 'AirtelTigo': 'airteltigo'}

            # WhitsunPay requires international format without +: 233XXXXXXXXX
            clean_phone = phone.strip().replace(' ', '').replace('-', '')
            if clean_phone.startswith('+'):
                clean_phone = clean_phone[1:]
            elif clean_phone.startswith('0'):
                clean_phone = '233' + clean_phone[1:]

            tx_ref = f"CUBAG-{payment_id}-{uuid.uuid4().hex[:8]}"

            payload = {
                'transactionReference': tx_ref,
                'description': description,
                'amount': float(amount),
                'debitParty': {
                    'msisdn': clean_phone,
                    'provider': network_map.get(network, 'mtn')
                }
            }
            try:
                wp_res = requests.post(
                    f'{_WP_API}/charge',
                    json=payload,
                    headers=_whitsunpay_headers(),
                    timeout=30
                )
                # Parse response body immediately so it's always available
                wp_data = {}
                try:
                    wp_data = wp_res.json()
                except Exception:
                    pass

                if wp_res.status_code >= 400:
                    with conn.cursor() as cursor:
                        cursor.execute("UPDATE payments SET status = 'failed' WHERE id = %s", (payment_id,))
                        conn.commit()
                    return jsonify({
                        'payment_id': payment_id,
                        'message': wp_data.get('message', 'WhitsunPay payment initiation failed'),
                        'error': True,
                        'details': wp_data
                    }), 400

                # ── 3. Store WhitsunPay transaction reference ──
                with conn.cursor() as cursor:
                    cursor.execute(
                        "UPDATE payments SET payment_ref = %s WHERE id = %s",
                        (tx_ref, payment_id)
                    )
                    if 'Renewal' in description:
                        cursor.execute(
                            "UPDATE members SET payment_ref = %s WHERE id = %s",
                            (tx_ref, member_id)
                        )
                    conn.commit()

                return jsonify({
                    'payment_id': payment_id,
                    'whitsun_ref': tx_ref,
                    'transaction_ref': tx_ref,
                    'status': 'pending',
                    'message': 'Payment request sent successfully. Please check your phone.',
                    'display_text': 'Please check your phone for the MoMo prompt and enter your PIN to approve.'
                }), 200

            except Exception as e:
                logger.error(f"[WhitsunPay] Request failed: {str(e)}")
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


# ─── POST /payments/verify-code — Check status via WhitsunPay ────────────────
@payments_bp.route('/verify-code', methods=['POST', 'OPTIONS'])
@jwt_required()
def verify_payment_code():
    """WhitsunPay handles MoMo PIN approval on-device (no OTP submission).
    This endpoint now checks the transaction status via WhitsunPay instead."""
    if request.method == 'OPTIONS':
        return jsonify({'ok': True}), 200

    data = request.get_json() or {}
    payment_id = data.get('payment_id')
    tx_ref = str(data.get('whitsun_ref', data.get('transaction_ref', ''))).strip()

    if not tx_ref:
        return jsonify({'message': 'Transaction reference is required', 'error': True}), 400

    try:
        wp_res = requests.get(
            f'{_WP_API}/{tx_ref}/status',
            headers=_whitsunpay_headers(),
            timeout=15
        )
        wp_data = wp_res.json()
        wp_status = str(wp_data.get('status', '')).lower()

        if wp_status in ('successful', 'success', 'completed'):
            _mark_payment_as_paid(payment_id)
            return jsonify({'message': 'Payment confirmed! 🎉', 'status': 'success'}), 200
        elif wp_status in ('failed', 'declined', 'reversed', 'cancelled'):
            _mark_payment_as_failed(payment_id)
            return jsonify({'message': f'Payment {wp_status}', 'status': 'failed'}), 200

        return jsonify({
            'message': 'Payment is still processing. Please approve the MoMo prompt on your phone.',
            'status': wp_status or 'pending'
        }), 200

    except Exception as e:
        logger.error(f"[verify_payment_code] {str(e)}")
        return jsonify({'message': str(e)}), 500


# ─── GET /payments/verify/<reference> — Poll WhitsunPay for status (auth required) ────
@payments_bp.route('/verify/<string:reference>', methods=['GET', 'OPTIONS'])
@cross_origin()
@jwt_required()  # ✔ SECURITY: must be authenticated to trigger payment verification
def verify_payment_manually(reference):
    if request.method == 'OPTIONS':
        return jsonify({'ok': True}), 200

    member_id = get_jwt_identity()

    if not reference or reference.lower() in ('n/a', 'pending', 'null', 'undefined'):
        return jsonify({'message': 'Invalid reference code', 'status': 'error'}), 200

    # Ownership check: verify this reference belongs to the calling member
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT id, member_id FROM payments WHERE payment_ref = %s",
                (reference,)
            )
            row = cursor.fetchone()
            if not row:
                return jsonify({'message': 'Payment reference not found', 'status': 'error'}), 404
            if str(row['member_id']) != str(member_id):
                return jsonify({'message': 'Unauthorised', 'status': 'error'}), 403
            payment_id = row['id']
    finally:
        conn.close()

    try:
        wp_res = requests.get(
            f'{_WP_API}/{reference}/status',
            headers=_whitsunpay_headers(),
            timeout=15
        )
        wp_data = wp_res.json()
        wp_status = str(wp_data.get('status', 'pending')).lower()

        if wp_status in ('successful', 'success', 'completed'):
            _mark_payment_as_paid(payment_id)
            return jsonify({'message': 'Payment verified and updated!', 'status': 'success'}), 200

        elif wp_status in ('failed', 'abandoned', 'reversed', 'declined', 'cancelled'):
            return jsonify({'message': f'Payment {wp_status}', 'status': 'failed'}), 200

        return jsonify({'message': f'Transaction state: {wp_status.replace("_", " ")}', 'status': wp_status}), 200
    except Exception as e:
        logger.error(f'[verify_payment_manually] {e}')
        return jsonify({'message': 'Verification service temporarily unavailable', 'status': 'pending'}), 200


def _mark_payment_as_failed(payment_id):
    if not payment_id: return
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT status FROM payments WHERE id = %s", (payment_id,))
            p = cursor.fetchone()
            if p and str(p['status']).lower() == 'pending':
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
            if p and str(p['status']).lower() == 'paid': return

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


# ─── PUT|POST /payments/webhook — WhitsunPay callback on terminal state ───────
@payments_bp.route('/webhook', methods=['PUT', 'POST'])
def whitsunpay_webhook():
    sig  = request.headers.get('X-Whitsun-Signature', '')
    body = request.get_data()

    # Reject all webhook calls when no secret is configured — prevents unauthenticated pay-marking
    if not WHITSUNPAY_WEBHOOK_SECRET:
        logger.warning('[Webhook] WHITSUNPAY_WEBHOOK_SECRET not set — rejecting webhook call')
        return jsonify({'message': 'Webhook not configured on server'}), 503

    # Verify HMAC-SHA256 signature
    expected = 'sha256=' + hmac.new(
        WHITSUNPAY_WEBHOOK_SECRET.encode(), body, hashlib.sha256
    ).hexdigest()
    if not hmac.compare_digest(sig, expected):
        return jsonify({'message': 'Invalid signature'}), 401

    event     = request.get_json() or {}
    tx_ref    = event.get('transactionReference', '')
    wp_status = str(event.get('status', '')).lower()

    if tx_ref:
        conn = get_db()
        try:
            with conn.cursor() as cursor:
                cursor.execute("SELECT id FROM payments WHERE payment_ref = %s", (tx_ref,))
                row = cursor.fetchone()
                if row:
                    if wp_status in ('successful', 'success', 'completed'):
                        _mark_payment_as_paid(row['id'])
                        # Trigger rating update for this member immediately after successful payment
                        try:
                            with conn.cursor() as cursor2:
                                cursor2.execute("SELECT member_id FROM payments WHERE id = %s", (row['id'],))
                                m_row = cursor2.fetchone()
                                if m_row:
                                    m_id = m_row['member_id']
                                    from utils import calculate_and_update_member_rating
                                    calculate_and_update_member_rating(m_id, cursor2)
                                    conn.commit()
                        except Exception as e:
                            logger.error(f"[Webhook Rating Update] {e}")
                    elif wp_status in ('failed', 'declined', 'reversed', 'cancelled'):
                        _mark_payment_as_failed(row['id'])
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
        logger.warning(f'[Email] Failed to send receipt to {to_email}: {e}')


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
                    SUM(CASE WHEN LOWER(status)='paid' THEN amount ELSE 0 END) as total_paid,
                    SUM(CASE WHEN LOWER(status)='pending' THEN amount ELSE 0 END) as total_pending
                FROM payments WHERE member_id = %s
            """, (member_id,))
            totals = cursor.fetchone()

            # Get breakdown of pending items
            cursor.execute("""
                SELECT description, amount, created_at
                FROM payments
                WHERE member_id = %s AND LOWER(status) = 'pending'
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
@sub_admin_required('payments')
def get_all_payments_admin():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT p.id as tx_id, p.amount, p.description, p.status,
                       p.payment_ref, p.created_at, m.name as member_name
                FROM payments p
                LEFT JOIN members m ON p.member_id = m.id
                ORDER BY p.created_at DESC
            """)
            payments = cursor.fetchall()

            # Manually serialize dates and decimals
            for p in payments:
                # Add a 'date' alias for components expecting it (like Dashboard charts)
                if 'created_at' in p and p['created_at']:
                    p['date'] = p['created_at'].isoformat() if hasattr(p['created_at'], 'isoformat') else str(p['created_at'])

                for key, value in list(p.items()):
                    if hasattr(value, 'isoformat'):
                        p[key] = value.isoformat()
                    elif hasattr(value, 'strftime'):
                        p[key] = str(value)
                    elif hasattr(value, 'to_eng_string'): # Decimal
                        p[key] = float(value)
                    elif key == 'amount' and value is not None:
                        p[key] = float(value)

            cursor.execute("SELECT COALESCE(SUM(amount), 0) as revenue FROM payments WHERE LOWER(status) = 'paid'")
            revenue = cursor.fetchone()

            cursor.execute("SELECT COALESCE(SUM(amount), 0) as pending FROM payments WHERE LOWER(status) = 'pending'")
            pending = cursor.fetchone()

            cursor.execute("SELECT COALESCE(SUM(amount), 0) as failed FROM payments WHERE LOWER(status) IN ('failed', 'overdue')")
            failed = cursor.fetchone()

        return jsonify({
            'transactions': payments,
            'kpis': {
                'revenue': float(revenue['revenue'] or 0),
                'pending': float(pending['pending'] or 0),
                'failed':  float(failed['failed']  or 0),
            }
        }), 200
    except Exception as e:
        logger.exception("[Admin Payments Error] %s", e)
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


# ─── POST /payments/admin/mark-paid/<id> ─────────────────────────────────────
@payments_bp.route('/admin/mark-paid/<int:payment_id>', methods=['POST'])
@sub_admin_required('payments')
def admin_mark_paid(payment_id):
    admin_id = get_jwt_identity()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Get the member_id from the payment
            cursor.execute("SELECT member_id, amount FROM payments WHERE id = %s", (payment_id,))
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
                # Audit log
                cursor.execute("SELECT name FROM members WHERE id = %s", (row['member_id'],))
                member = cursor.fetchone()
                log_admin_action(admin_id, 'Marked payment as paid', 'payment', payment_id, member['name'] if member else None, f'Amount: {row["amount"]}')
        return jsonify({'message': 'Payment marked as paid'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


# ─── POST /payments/admin/approve-license/<id> ───────────────────────────────
@payments_bp.route('/admin/approve-license/<int:payment_id>', methods=['POST'])
@sub_admin_required('payments')
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
