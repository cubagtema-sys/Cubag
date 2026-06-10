import os
import uuid
import requests
import hashlib
import hmac
import resend
import logging
from flask import Blueprint, jsonify, request
from flask_cors import cross_origin
from flask_jwt_extended import jwt_required, get_jwt_identity
from config.db import get_db
from socket_instance import socketio
from utils import admin_required, sub_admin_required, log_backend_error, log_admin_action

payments_bp = Blueprint('payments', __name__)
logger = logging.getLogger(__name__)

# ─── WhitsunPay Configuration ─────────────────────────────────────────────────
WHITSUNPAY_BASE_URL = os.getenv('WHITSUNPAY_BASE_URL', 'https://api.whitsun.io').rstrip('/')
WHITSUNPAY_CLIENT_ID = os.getenv('WHITSUNPAY_CLIENT_ID', '') or os.getenv('x-client-id', '')
WHITSUNPAY_API_KEY = os.getenv('WHITSUNPAY_API_KEY', '') or os.getenv('x-api-key', '')
WHITSUNPAY_WEBHOOK_SECRET = os.getenv('WHITSUNPAY_WEBHOOK_SECRET', '')
WHITSUNPAY_CALLBACK_URL = os.getenv('WHITSUNPAY_CALLBACK_URL', '') or os.getenv('x-callback-url', '')

# Full versioned API base — e.g. https://api.whitsun.io/api/v1
_WP_API = f'{WHITSUNPAY_BASE_URL}/api/v1'


def _whitsunpay_headers():
    """Build headers for WhitsunPay API requests (Enhanced to bypass Cloudflare)."""
    return {
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'en-US,en;q=0.9',
        'x-client-id': WHITSUNPAY_CLIENT_ID,
        'x-api-key': WHITSUNPAY_API_KEY,
        'x-callback-url': WHITSUNPAY_CALLBACK_URL,
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
        'Referer': 'https://developer.whitsun.dev/',
        'Origin': 'https://developer.whitsun.dev',
        'Sec-Ch-Ua': '"Not(A:Brand";v="24", "Chromium";v="122"',
        'Sec-Ch-Ua-Mobile': '?0',
        'Sec-Ch-Ua-Platform': '"Windows"',
    }

@payments_bp.route('/test-gateway', methods=['GET'])
def test_gateway_connectivity():
    """Public debug route to test if the backend can reach WhitsunPay."""
    tests = [
        "https://developer.whitsun.dev/api/v1/health",
        "https://api.whitsun.dev/api/v1/health",
        "https://api.whitsun.io/api/v1/health",
        "https://api.whitsunsystems.com/api/v1/health",
        "https://api.swagpaygh.com/api/v1/health",
        "https://swagpay.whitsun.dev/api/v1/health"
    ]
    results = []

    headers = _whitsunpay_headers()
    if 'x-callback-url' in headers: del headers['x-callback-url']

    for url in tests:
        try:
            r = requests.get(url, headers=headers, timeout=5)
            results.append({
                'url': url,
                'status': r.status_code,
                'blocked': 'Just a moment' in r.text or r.status_code == 403,
                'preview': r.text[:100].strip()
            })
        except Exception as e:
            results.append({'url': url, 'error': str(e)})

    return jsonify({
        'results': results,
        'recommendation': 'WhitsunPay API host is likely blocked by Cloudflare on Render. Contact WhitsunPay support to whitelist Render outgoing IPs.'
    }), 200


# ─── POST /payments — Initiate charge (MoMo or Bank) ──────────────────────────
@payments_bp.route('/', methods=['POST'])
@jwt_required()
def create_payment():
    member_id = get_jwt_identity()
    data = request.get_json()
    if not data:
        return jsonify({'message': 'Request body is required'}), 400

    logger.info(f"[Payments] New request from member {member_id}: {data}")

    amount      = data.get('amount')
    description = data.get('description')
    payment_ref = data.get('payment_ref', '')
    method      = data.get('method', 'momo')
    network     = data.get('network', 'MTN')
    phone       = data.get('phone', '')

    if not amount or not description:
        return jsonify({'message': 'Amount and description are required'}), 400

    if method == 'momo' and not phone:
        return jsonify({'message': 'Phone number is required for Mobile Money payments'}), 400

    # Validate amount is a positive number
    try:
        amount = float(amount)
        if amount <= 0:
            return jsonify({'message': 'Amount must be greater than zero'}), 400
    except (TypeError, ValueError):
        return jsonify({'message': 'Amount must be a valid number'}), 400

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
            if 'Renewal' in description or 'License' in description:
                cursor.execute(
                    "UPDATE members SET status = 'pending' WHERE id = %s",
                    (member_id,)
                )

            conn.commit()

        # ── 2. Handle MoMo via WhitsunPay ──
        if method == 'momo' and WHITSUNPAY_CLIENT_ID and WHITSUNPAY_API_KEY:
            network_map = {'MTN': 'mtn', 'Vodafone': 'vodafone', 'AirtelTigo': 'airteltigo'}

            # WhitsunPay requires international format without +: 233XXXXXXXXX
            clean_phone = ''.join(filter(str.isdigit, phone))
            if clean_phone.startswith('0') and len(clean_phone) == 10:
                clean_phone = '233' + clean_phone[1:]
            elif len(clean_phone) == 9:
                clean_phone = '233' + clean_phone

            tx_ref = f"CUBAG-{payment_id}-{uuid.uuid4().hex[:8]}"

            payload = {
                'transactionReference': tx_ref,
                'description': description,
                'amount': round(float(amount), 2),
                'debitParty': {
                    'msisdn': clean_phone,
                    'provider': network_map.get(network, 'mtn')
                }
            }
            try:
                target_url = f'{_WP_API}/payments'
                headers = _whitsunpay_headers()
                logger.info(f"[WhitsunPay Debug] Calling API: {target_url}")
                logger.info(f"[WhitsunPay Debug] Headers: { {k: (v if k != 'x-api-key' else '***') for k, v in headers.items()} }")
                logger.info(f"[WhitsunPay Debug] Payload: {payload}")

                wp_res = requests.post(
                    target_url,
                    json=payload,
                    headers=headers,
                    timeout=30
                )

                logger.info(f"[WhitsunPay Debug] Status Code: {wp_res.status_code}")

                # Try to parse JSON, but catch cases where it's not JSON
                wp_data = {}
                try:
                    wp_data = wp_res.json()
                except Exception:
                    wp_data = {'raw_response': wp_res.text[:1000]} # Increase visibility of raw response
                    logger.warning(f"[WhitsunPay Debug] Failed to parse JSON response: {wp_res.text[:500]}")

                logger.info(f"[WhitsunPay Debug] Response Body: {wp_data}")

                if wp_res.status_code >= 400:
                    logger.error(f"[WhitsunPay Debug] Error response ({wp_res.status_code}): {wp_data}")
                    with conn.cursor() as cursor:
                        cursor.execute("UPDATE payments SET status = 'failed' WHERE id = %s", (payment_id,))
                        conn.commit()

                    # Return detailed error to help diagnose
                    return jsonify({
                        'payment_id': payment_id,
                        'message': wp_data.get('message', 'WhitsunPay payment initiation failed'),
                        'error': True,
                        'status_code': wp_res.status_code,
                        'details': wp_data
                    }), 400

                # ── 3. Store WhitsunPay transaction reference ──
                with conn.cursor() as cursor:
                    cursor.execute(
                        "UPDATE payments SET payment_ref = %s WHERE id = %s",
                        (tx_ref, payment_id)
                    )
                    if 'Renewal' in description or 'License' in description:
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

    # ── Local Database Check First ──
    # If the webhook already received the terminal state callback and updated the DB,
    # resolve immediately to avoid gateway polling failures.
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT status FROM payments WHERE id = %s", (payment_id,))
            p = cursor.fetchone()
            if p:
                status = str(p['status']).lower()
                if status == 'paid':
                    return jsonify({'message': 'Payment confirmed! 🎉', 'status': 'success'}), 200
                elif status in ('failed', 'declined', 'cancelled', 'reversed'):
                    return jsonify({'message': 'Payment failed or declined', 'status': 'failed'}), 200
    except Exception as e:
        logger.error(f"[verify_payment_code DB check] {e}")
    finally:
        conn.close()

    try:
        target_url = f'{_WP_API}/{tx_ref}/status'
        logger.info(f"[WhitsunPay] Checking status at {target_url}")
        wp_res = requests.get(
            target_url,
            headers=_whitsunpay_headers(),
            timeout=15
        )
        # Handle Cloudflare or non-JSON errors
        try:
            wp_data = wp_res.json()
        except Exception:
            logger.error(f"[WhitsunPay] Non-JSON response in verify: {wp_res.text[:300]}")
            return jsonify({'message': 'WhitsunPay returned an invalid response. Cloudflare may be blocking the request.', 'error': True}), 502

        logger.info(f"[WhitsunPay Verify Status] Status Code: {wp_res.status_code}, Body: {wp_data}")
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
                "SELECT id, member_id, status FROM payments WHERE payment_ref = %s",
                (reference,)
            )
            row = cursor.fetchone()
            if not row:
                return jsonify({'message': 'Payment reference not found', 'status': 'error'}), 404
            if str(row['member_id']) != str(member_id):
                return jsonify({'message': 'Unauthorised', 'status': 'error'}), 403
            payment_id = row['id']
            
            # If already marked as paid locally via webhook, resolve immediately
            if str(row['status']).lower() == 'paid':
                return jsonify({'message': 'Payment verified and updated!', 'status': 'success'}), 200
    finally:
        conn.close()

    try:
        target_url = f'{_WP_API}/{reference}/status'
        logger.info(f"[WhitsunPay] Manual check at {target_url}")
        wp_res = requests.get(
            target_url,
            headers=_whitsunpay_headers(),
            timeout=15
        )
        try:
            wp_data = wp_res.json()
        except Exception:
            logger.error(f"[WhitsunPay] Non-JSON response in manual verify: {wp_res.text[:300]}")
            return jsonify({'message': 'WhitsunPay returned an invalid response.', 'status': 'error'}), 200

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
            cursor.execute("SELECT status, member_id, description, amount FROM payments WHERE id = %s", (payment_id,))
            p = cursor.fetchone()
            if not p or str(p['status']).lower() == 'paid': return

            member_id = p['member_id']
            description = p['description']

            cursor.execute(
                "UPDATE payments SET status = 'paid', paid_at = NOW() WHERE id = %s",
                (payment_id,)
            )

            # ── Handle License Issuance & Expiry ──
            license_issued = False
            expiry_date_str = None
            if 'Renewal' in description or 'License' in description:
                import datetime
                now = datetime.datetime.now()
                expiry_date = now + datetime.timedelta(days=365)
                expiry_date_str = expiry_date.strftime("%d %b %Y")

                # Fetch current license info
                cursor.execute("SELECT license_number FROM members WHERE id = %s", (member_id,))
                member_row = cursor.fetchone()

                license_number = member_row['license_number'] if member_row else None
                if not license_number or str(license_number).lower() in ('pending', 'none', 'n/a', ''):
                    year = now.year
                    license_number = f"CUBAG-LIC-{year}-{member_id:04d}"

                cursor.execute("""
                    UPDATE members
                    SET status = 'active',
                        license_number = %s,
                        license_expiry_date = %s
                    WHERE id = %s
                """, (license_number, expiry_date.date(), member_id))

                # Log to history
                cursor.execute("""
                    INSERT INTO license_history (member_id, license_number, start_date, expiry_date, duration_label)
                    VALUES (%s, %s, %s, %s, %s)
                """, (member_id, license_number, now.date(), expiry_date.date(), '1 Year'))
                license_issued = True
            else:
                # Regular payment, just ensure they are active if they were pending
                cursor.execute("UPDATE members SET status = 'active' WHERE id = %s AND status = 'pending'", (member_id,))

            conn.commit()

            # Fetch for receipt email
            cursor.execute("""
                SELECT m.email, m.name, p.amount, p.description
                FROM payments p JOIN members m ON p.member_id = m.id
                WHERE p.id = %s
            """, (payment_id,))
            row = cursor.fetchone()
            if row:
                custom_msg = ""
                if license_issued:
                    custom_msg = f"<p>Your membership license has been issued/renewed and is valid until <strong>{expiry_date_str}</strong>.</p>"
                _send_receipt_email(row['email'], row['name'], row['amount'], row['description'], payment_id, custom_msg)
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


def _send_receipt_email(to_email, member_name, amount, description, payment_id, custom_msg=""):
    resend.api_key = os.getenv('RESEND_API_KEY')
    if not resend.api_key:
        logger.error('[Resend] RESEND_API_KEY not configured — receipt email not sent.')
        return

    sender_email = os.getenv('SMTP_USER', 'support@winningedgeinvestment.com')

    html = f"""
    <div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;padding:32px;border:1px solid #eee;border-radius:12px">
      <h2 style="color:#f08232">CUBAG</h2>
      <p>Hi <strong>{member_name}</strong>,</p>
      <p>Your payment has been confirmed. Here is your receipt:</p>
      {custom_msg}
      <table style="width:100%;border-collapse:collapse">
        <tr><td style="padding:10px 0;border-bottom:1px solid #eee;color:#888">Description</td><td style="text-align:right;font-weight:700">{description}</td></tr>
        <tr><td style="padding:10px 0;border-bottom:1px solid #eee;color:#888">Amount</td><td style="text-align:right;font-weight:900;color:#f08232;font-size:1.2em">GH₵ {float(amount):.2f}</td></tr>
        <tr><td style="padding:10px 0;border-bottom:1px solid #eee;color:#888">TX ID</td><td style="text-align:right">{payment_id}</td></tr>
        <tr><td style="padding:10px 0;color:#888">Status</td><td style="text-align:right"><span style="background:#d1fae5;color:#10b981;padding:2px 10px;border-radius:20px;font-size:0.8em;font-weight:800">PAID</span></td></tr>
      </table>
      <p style="margin-top:24px;color:#888;font-size:0.85em">Thank you for your payment. This is an automated receipt from CUBAG.</p>
    </div>
    """

    try:
        params = {
            "from": f"CUBAG Support <{sender_email}>",
            "to": [to_email],
            "subject": f'CUBAG Payment Receipt — GH₵ {float(amount):.2f}',
            "html": html,
        }
        resend.Emails.send(params)
        logger.info(f'[Resend] Receipt sent to {to_email} for payment {payment_id}')
    except Exception as e:
        logger.warning(f'[Resend] Failed to send receipt to {to_email}: {e}')


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
        page = int(request.args.get('page', 1))
        limit = int(request.args.get('limit', 20))
        offset = (page - 1) * limit
        search = request.args.get('search', '').lower()
        status = request.args.get('status', 'all').lower()

        where_clauses = []
        params = []
        if search:
            where_clauses.append("(LOWER(m.name) LIKE %s OR LOWER(p.description) LIKE %s)")
            params.extend([f"%{search}%", f"%{search}%"])
        if status != 'all':
            where_clauses.append("LOWER(p.status) = %s")
            params.append(status)

        where_sql = ""
        if where_clauses:
            where_sql = "WHERE " + " AND ".join(where_clauses)

        with conn.cursor() as cursor:
            # Get total count with filters
            count_query = f"""
                SELECT COUNT(*) as total 
                FROM payments p
                LEFT JOIN members m ON p.member_id = m.id
                {where_sql}
            """
            cursor.execute(count_query, tuple(params))
            total = cursor.fetchone()['total']

            # Get paginated data
            data_query = f"""
                SELECT p.id as tx_id, p.amount, p.description, p.status,
                       p.payment_ref, p.created_at, m.name as member_name
                FROM payments p
                LEFT JOIN members m ON p.member_id = m.id
                {where_sql}
                ORDER BY p.created_at DESC
                LIMIT %s OFFSET %s
            """
            cursor.execute(data_query, tuple(params) + (limit, offset))
            payments = cursor.fetchall()

            # Manually serialize dates and decimals
            for p in payments:
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
            'data': payments,
            'total': total,
            'page': page,
            'limit': limit,
            'kpis': {
                'revenue': float(revenue['revenue'] or 0),
                'pending': float(pending['pending'] or 0),
                'failed':  float(failed['failed']  or 0),
            }
        }), 200
    except Exception as e:
        import traceback
        tb = traceback.format_exc()
        logger.exception("[Admin Payments Error] %s", e)
        try:
            log_backend_error('Admin Payments Error', f"Error: {str(e)}\nTraceback:\n{tb}")
        except Exception as log_err:
            logger.error(f"Failed to log error to DB: {log_err}")
        return jsonify({'message': str(e), 'traceback': tb}), 500
    finally:
        conn.close()


# ─── POST /payments/admin/mark-paid/<id> ─────────────────────────────────────
@payments_bp.route('/admin/mark-paid/<int:payment_id>', methods=['POST'])
@sub_admin_required('payments')
def admin_mark_paid(payment_id):
    admin_id = get_jwt_identity()
    try:
        conn = get_db()
        with conn.cursor() as cursor:
            # Get data for audit log
            cursor.execute("""
                SELECT p.member_id, p.amount, m.name
                FROM payments p LEFT JOIN members m ON p.member_id = m.id
                WHERE p.id = %s
            """, (payment_id,))
            row = cursor.fetchone()
        conn.close()

        # Use unified helper
        _mark_payment_as_paid(payment_id)

        if row:
            # Real-time WebSocket emission
            socketio.emit('payment_approved', {'member_id': row['member_id'], 'payment_id': payment_id})
            # Audit log
            log_admin_action(admin_id, 'Marked payment as paid', 'payment', payment_id, row.get('name'), f'Amount: {row.get("amount")}')

        return jsonify({'message': 'Payment marked as paid'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500


# ─── POST /payments/admin/approve-license/<id> ───────────────────────────────
@payments_bp.route('/admin/approve-license/<int:payment_id>', methods=['POST'])
@sub_admin_required('payments')
def admin_approve_license(payment_id):
    try:
        # Use unified helper
        _mark_payment_as_paid(payment_id)
        return jsonify({'message': 'License approved and payment confirmed'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
