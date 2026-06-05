import os
import uuid
import random
import logging
import resend

from flask import Blueprint, request, jsonify, make_response
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity, verify_jwt_in_request
from werkzeug.security import generate_password_hash, check_password_hash
from flask_cors import cross_origin
from config.db import get_db
import requests as http_req

auth_bp = Blueprint('auth', __name__)
logger = logging.getLogger(__name__)

# ─── Supabase config ──────────────────────────────────────────────────────────
SUPABASE_URL  = os.getenv('SUPABASE_URL', '')
SUPABASE_KEY  = os.getenv('SUPABASE_SERVICE_KEY', '')
PHOTO_BUCKET  = os.getenv('SUPABASE_BUCKET', 'uploads')

def send_verification_email(to_email, token):
    resend.api_key = os.getenv('RESEND_API_KEY')
    
    if not resend.api_key:
        print("[Resend] API key not configured. Skipping.")
        return

    body = f"Hello,\n\nYour CUBAG verification code is:\n\n{token}\n\nPlease enter this code in the app to complete your registration.\n\nThanks,\nCUBAG Secretariat"

    params = {
        "from": "CUBAG Support <onboarding@resend.dev>",
        "to": [to_email],
        "subject": "Verify your CUBAG Account",
        "text": body,
    }

    try:
        email_response = resend.Emails.send(params)
        print(f"[Resend] Email sent to {to_email}")
        return True
    except Exception as e:
        print(f"[Resend] Failed to send email: {e}")
        return False

@auth_bp.route('/send-otp', methods=['POST'])
def send_otp():
    data = request.get_json()
    email = (data.get('email') or '').strip().lower()
    if not email:
        return jsonify({'message': 'Email is required'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Check if email is already registered
            cursor.execute("SELECT id FROM members WHERE email = %s", (email,))
            if cursor.fetchone():
                return jsonify({'message': 'Email already registered'}), 409
            
            token = str(random.randint(100000, 999999))
            
            # Upsert into otp_codes
            cursor.execute("""
                INSERT INTO otp_codes (email, code) VALUES (%s, %s)
                ON CONFLICT (email) DO UPDATE SET code = EXCLUDED.code, created_at = CURRENT_TIMESTAMP
            """, (email, token))
            conn.commit()
            
            import threading
            threading.Thread(target=send_verification_email, args=(email, token), daemon=True).start()
            return jsonify({'message': 'OTP sent to email.'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@auth_bp.route('/verify-email', methods=['POST'])
def verify_email():
    data = request.get_json()
    email = data.get('email')
    token = data.get('token')
    if not email or not token:
        return jsonify({'message': 'Email and Token are required'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Check code is valid AND was created within the last 15 minutes
            cursor.execute("""
                SELECT * FROM otp_codes
                WHERE email = %s AND code = %s
                  AND created_at > NOW() - INTERVAL '15 minutes'
            """, (email, token))
            if not cursor.fetchone():
                return jsonify({'message': 'Invalid or expired verification code'}), 400

            # Delete the OTP code so it can't be reused
            cursor.execute("DELETE FROM otp_codes WHERE email = %s", (email,))
            conn.commit()
            return jsonify({'message': 'Email verified successfully.'}), 200
    finally:
        conn.close()

@auth_bp.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    # licenseNumber and agencyCode are now OPTIONAL
    required = ['name', 'email', 'phone', 'company', 'memberType', 'password']
    for field in required:
        if not data.get(field):
            return jsonify({'message': f'{field} is required'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cursor:
            email = (data.get('email') or '').strip().lower()
            cursor.execute("SELECT id FROM members WHERE email = %s", (email,))
            if cursor.fetchone():
                return jsonify({'message': 'Email already registered'}), 409

            pw_hash = generate_password_hash(data['password'])
            cursor.execute("""
                INSERT INTO members (name, email, phone, company, license_number, agency_code,
                                     port_of_operation, member_type, password_hash, email_verified, status)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, TRUE, 'pending')
            """, (
                data['name'], email, data['phone'], data['company'],
                data.get('licenseNumber'), data.get('agencyCode'),
                data.get('portOfOperation', 'Tema Port'), data['memberType'], pw_hash
            ))
            conn.commit()
            return jsonify({'message': 'Registration successful. You can now log in.'}), 201
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    identifier = (data.get('email') or data.get('identifier') or data.get('memberId') or '').strip()
    password = data.get('password')

    if not identifier or not password:
        return jsonify({'message': 'Email or phone number and password are required'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Detect if input looks like a phone number (digits, spaces, dashes, +)
            import re
            is_phone = bool(re.match(r'^[\d\s\+\-\(\)]+$', identifier))

            if is_phone:
                # Normalize: strip all non-digit chars for flexible matching
                digits_only = re.sub(r'\D', '', identifier)
                cursor.execute(
                    "SELECT * FROM members WHERE regexp_replace(phone, '[^0-9]', '', 'g') = %s",
                    (digits_only,)
                )
            else:
                cursor.execute("SELECT * FROM members WHERE LOWER(email) = LOWER(%s)", (identifier,))
            member = cursor.fetchone()

            if not member or not check_password_hash(member['password_hash'], password):
                return jsonify({'message': 'Invalid credentials'}), 401

            if not member.get('email_verified', True):
                return jsonify({'message': 'Please check your email to verify your account before logging in.'}), 403

            from utils import calculate_and_update_member_rating
            rating_data = calculate_and_update_member_rating(member['id'], cursor)

            # Generate JWT with identity and role
            role = member.get('role', 'member')
            token = create_access_token(
                identity=str(member['id']),
                additional_claims={'role': role}
            )

            # Expiry date serialization
            expiry = str(member['license_expiry_date']) if member.get('license_expiry_date') else None

            # Audit log for admin & sub_admin logins
            role = member.get('role', 'member')
            if role in ('admin', 'sub_admin'):
                from utils import log_admin_action
                log_admin_action(
                    member['id'],
                    f'{"Admin" if role == "admin" else "Sub-Admin"} Login',
                    role, member['id'], member['name'],
                    f'IP: {request.remote_addr}'
                )

            return jsonify({
                'token': token,
                'user': {
                    'id': member['id'],
                    'name': member['name'],
                    'email': member['email'],
                    'company': member['company'],
                    'memberType': member['member_type'],
                    'licenseNumber': member['license_number'],
                    'licenseExpiryDate': expiry,
                    'portOfOperation': member['port_of_operation'],
                    'status': member['status'],
                    'role': role,
                    'profile_photo': member.get('profile_photo') or None,
                    'compliance_score': rating_data['compliance_score'],
                    'star_rating': rating_data['star_rating'],
                    'manual_review_score': rating_data['manual_review_score'],
                    'breakdown': rating_data.get('breakdown', {})
                }
            }), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


@auth_bp.route('/me', methods=['GET'])
@jwt_required()
def me():
    member_id = get_jwt_identity()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            try:
                cursor.execute("""
                    SELECT id, name, email, phone, company, license_number,
                           member_type, port_of_operation, status, profile_photo,
                           license_expiry_date, role, compliance_score, star_rating, manual_review_score
                    FROM members WHERE id = %s
                """, (member_id,))
            except Exception:
                conn.rollback()
                try:
                    cursor.execute("""
                        SELECT id, name, email, phone, company, license_number,
                               member_type, port_of_operation, status, profile_photo, role
                        FROM members WHERE id = %s
                    """, (member_id,))
                except Exception:
                    conn.rollback()
                    cursor.execute("""
                        SELECT id, name, email, phone, company, license_number,
                               member_type, port_of_operation, status, role
                        FROM members WHERE id = %s
                    """, (member_id,))
            member = cursor.fetchone()
            if not member:
                return jsonify({'message': 'Member not found'}), 404
                
            from utils import calculate_and_update_member_rating
            rating_data = calculate_and_update_member_rating(member_id, cursor)

            # Fetch rating history
            cursor.execute("""
                SELECT compliance_score, star_rating, recorded_at
                FROM member_rating_history
                WHERE member_id = %s
                ORDER BY recorded_at ASC
            """, (member_id,))
            history_rows = cursor.fetchall()
            history = []
            for h in history_rows:
                history.append({
                    'compliance_score': h['compliance_score'],
                    'star_rating': float(h['star_rating']),
                    'recorded_at': str(h['recorded_at'])
                })

            # Return fresh data
            result = dict(member)
            result['compliance_score'] = rating_data['compliance_score']
            result['star_rating'] = rating_data['star_rating']
            result['manual_review_score'] = rating_data['manual_review_score']
            result['breakdown'] = rating_data.get('breakdown', {})
            result['rating_history'] = history
            if result.get('license_expiry_date'):
                result['license_expiry_date'] = str(result['license_expiry_date'])
            return jsonify(result), 200
    finally:
        conn.close()


@auth_bp.route('/upload-photo', methods=['POST'])
@jwt_required()
def upload_photo():
    """Upload profile photo to Supabase Storage and save URL in DB."""
    member_id = get_jwt_identity()

    if 'photo' not in request.files:
        return jsonify({'message': 'No photo provided'}), 400

    file = request.files['photo']
    if not file or not file.filename:
        return jsonify({'message': 'No file selected'}), 400

    ext = file.filename.rsplit('.', 1)[-1].lower()
    if ext not in ('jpg', 'jpeg', 'png', 'webp'):
        return jsonify({'message': 'Only JPG, PNG, or WebP allowed'}), 400

    # Size check (max 5MB)
    file.seek(0, 2)
    if file.tell() > 5 * 1024 * 1024:
        return jsonify({'message': 'Photo too large. Max 5MB.'}), 413
    file.seek(0)

    safe_name = f"profile_{member_id}_{uuid.uuid4().hex[:8]}.{ext}"
    file_bytes = file.read()
    content_type = file.content_type or 'image/jpeg'

    # Read Supabase config at request time (not module load time)
    supabase_url = os.getenv('SUPABASE_URL', '')
    supabase_key = os.getenv('SUPABASE_SERVICE_KEY', '')
    photo_bucket = os.getenv('SUPABASE_BUCKET', 'uploads')

    if not supabase_url or not supabase_key:
        logger.error("[upload-photo] SUPABASE_URL or SUPABASE_SERVICE_KEY not set")
        return jsonify({'message': 'Storage not configured. Set SUPABASE_URL and SUPABASE_SERVICE_KEY.'}), 500

    storage_url = f"{supabase_url}/storage/v1/object/{photo_bucket}/{safe_name}"
    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
        "Content-Type": content_type,
        "x-upsert": "true",
    }

    try:
        resp = http_req.post(storage_url, data=file_bytes, headers=headers, timeout=30)
        if resp.status_code not in (200, 201):
            logger.error(f"[upload-photo] Supabase upload failed: {resp.status_code} - {resp.text}")
            return jsonify({'message': f'Upload failed: {resp.text}'}), 500
    except Exception as e:
        logger.error(f"[upload-photo] Request to Supabase failed: {e}")
        return jsonify({'message': 'Failed to connect to storage service'}), 500

    public_url = f"{supabase_url}/storage/v1/object/public/{photo_bucket}/{safe_name}"

    # Save URL to DB
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("UPDATE members SET profile_photo = %s WHERE id = %s", (public_url, member_id))
            conn.commit()
        return jsonify({'message': 'Photo uploaded', 'photo_url': public_url}), 200
    except Exception as e:
        logger.error(f"[upload-photo] DB update failed: {e}")
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


@auth_bp.route('/change-password', methods=['POST', 'OPTIONS'])
@cross_origin(supports_credentials=True)
def change_password():
    print(f"[DEBUG] Change Password request: {request.method}")
    if request.method == 'OPTIONS':
        res = make_response('', 200)
        res.headers["Access-Control-Allow-Origin"] = request.headers.get("Origin", "*")
        res.headers["Access-Control-Allow-Methods"] = "POST, OPTIONS"
        res.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type"
        res.headers["Access-Control-Allow-Credentials"] = "true"
        return res

    try:
        # Manually verify JWT so it doesn't block the preflight
        verify_jwt_in_request()
        member_id = get_jwt_identity()
    except Exception as e:
        logger.debug(f"[change-password] JWT verification failed: {str(e)}")
        return jsonify({'message': 'Authentication required'}), 401

    data = request.get_json()
    current_password = data.get('current_password')
    new_password = data.get('new_password')

    if not current_password or not new_password:
        return jsonify({'message': 'Current and new passwords are required'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT password_hash FROM members WHERE id = %s", (member_id,))
            member = cursor.fetchone()
            if not member or not check_password_hash(member['password_hash'], current_password):
                return jsonify({'message': 'Incorrect current password'}), 401

            hashed_pw = generate_password_hash(new_password)
            cursor.execute("UPDATE members SET password_hash = %s WHERE id = %s", (hashed_pw, member_id))
            conn.commit()
            return jsonify({'message': 'Password changed successfully'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


@auth_bp.route('/update-fcm-token', methods=['POST', 'OPTIONS'])
def update_fcm_token():
    if request.method == 'OPTIONS':
        return jsonify({'ok': True}), 200

    # Properly verify JWT on the route function (inner-function decorator pattern doesn't work)
    try:
        verify_jwt_in_request()
        member_id = get_jwt_identity()
    except Exception:
        return jsonify({'message': 'Authentication required'}), 401

    data = request.get_json() or {}
    token = data.get('token')

    if not token:
        return jsonify({'message': 'Token is required'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("UPDATE members SET fcm_token = %s WHERE id = %s", (token, member_id))
            conn.commit()
        return jsonify({'message': 'FCM token updated'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


def send_reset_email(to_email, token):
    resend.api_key = os.getenv('RESEND_API_KEY')
    client_url = os.getenv('CLIENT_URL', 'https://cub-production.up.railway.app')
    
    if not resend.api_key:
        print("[Resend] API key not configured for reset. Skipping.")
        return

    reset_link = f"{client_url}/reset-password?token={token}&email={to_email}"
    body = f"Hello,\n\nYou requested a password reset. Please click the link below to reset your password:\n\n{reset_link}\n\nIf you did not request this, please ignore this email.\n\nThanks,\nCUBAG Secretariat"

    params = {
        "from": "CUBAG Support <onboarding@resend.dev>",
        "to": [to_email],
        "subject": "Reset your CUBAG Password",
        "text": body,
    }

    try:
        email_response = resend.Emails.send(params)
        print(f"[Resend] Password reset email sent to {to_email}")
        return True
    except Exception as e:
        print(f"[Resend] Failed to send reset email: {e}")
        return False


@auth_bp.route('/forgot-password', methods=['POST', 'OPTIONS'])
def forgot_password():
    if request.method == 'OPTIONS':
        return jsonify({'ok': True}), 200

    data = request.get_json()
    email = data.get('email')
    if not email:
        return jsonify({'message': 'Email is required'}), 400
        
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id, email FROM members WHERE LOWER(email) = LOWER(%s)", (email,))
            user = cursor.fetchone()
            if user:
                actual_email = user['email']
                token = str(uuid.uuid4())
                # Delete ALL otp entries for this email (PK constraint = one row per email)
                cursor.execute("DELETE FROM otp_codes WHERE LOWER(email) = LOWER(%s)", (actual_email,))
                # Insert the password reset token
                cursor.execute(
                    "INSERT INTO otp_codes (email, code, type) VALUES (%s, %s, 'password_reset')",
                    (actual_email, token)
                )
                conn.commit()
                # Send synchronously with 10s timeout (threads unreliable with gevent)
                try:
                    send_reset_email(actual_email, token)
                except Exception as mail_err:
                    print(f"[SMTP] Non-fatal: {mail_err}")
                
        return jsonify({'message': 'If an account exists, a reset link has been sent.'}), 200
    except Exception as e:
        print(f"[forgot-password] Error: {e}")
        return jsonify({'message': str(e)}), 500
    finally:

        conn.close()


@auth_bp.route('/reset-password', methods=['POST', 'OPTIONS'])
def reset_password():
    if request.method == 'OPTIONS':
        return jsonify({'ok': True}), 200

    data = request.get_json()
    email = data.get('email')
    token = data.get('code')
    new_password = data.get('new_password')
    
    if not email or not token or not new_password:
        return jsonify({'message': 'Email, code, and new password are required'}), 400
        
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT * FROM otp_codes WHERE LOWER(email) = LOWER(%s) AND code = %s AND type = 'password_reset'", (email, token))
            otp_record = cursor.fetchone()
            
            if not otp_record:
                return jsonify({'message': 'Invalid or expired reset code'}), 400
                
            actual_email = otp_record['email']
            hashed_pw = generate_password_hash(new_password)
            cursor.execute("UPDATE members SET password_hash = %s WHERE LOWER(email) = LOWER(%s)", (hashed_pw, actual_email))
            cursor.execute("DELETE FROM otp_codes WHERE LOWER(email) = LOWER(%s) AND type = 'password_reset'", (actual_email,))
            conn.commit()
            
            return jsonify({'message': 'Password has been reset successfully. You can now log in.'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


