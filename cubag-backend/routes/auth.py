import os
import uuid
import random
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

from flask import Blueprint, request, jsonify, make_response
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity, verify_jwt_in_request
from werkzeug.security import generate_password_hash, check_password_hash
from flask_cors import cross_origin
from config.db import get_db
import requests as http_req

auth_bp = Blueprint('auth', __name__)

# ─── Supabase config (shared with public_materials) ──────────────────────────
SUPABASE_URL  = os.getenv('SUPABASE_URL', '')
SUPABASE_KEY  = os.getenv('SUPABASE_SERVICE_KEY', '')
PHOTO_BUCKET  = os.getenv('SUPABASE_BUCKET', 'public-materials')  # reuse same bucket

def send_verification_email(to_email, token):
    smtp_host = os.getenv('SMTP_HOST')
    smtp_port = int(os.getenv('SMTP_PORT', 587))
    smtp_user = os.getenv('SMTP_USER')
    smtp_pass = os.getenv('SMTP_PASS')
    client_url = os.getenv('CLIENT_URL', 'https://cub-production.up.railway.app')
    
    if not smtp_host or not smtp_user:
        print("[SMTP] Credentials not configured. Skipping.")
        return

    msg = MIMEMultipart()
    msg['From'] = f"CUBAG Support Team <{smtp_user}>"
    msg['To'] = to_email
    msg['Subject'] = 'Verify your CUBAG Account'

    body = f"Hello,\n\nYour CUBAG verification code is:\n\n{token}\n\nPlease enter this code in the app to complete your registration.\n\nThanks,\nCUBAG Secretariat"
    msg.attach(MIMEText(body, 'plain'))

    def _try_connect(host, port):
        if port == 465:
            s = smtplib.SMTP_SSL(host, port, timeout=15)
        else:
            s = smtplib.SMTP(host, port, timeout=15)
            s.starttls()
        s.login(smtp_user, smtp_pass)
        return s

    try:
        print(f"[SMTP] Attempting primary connection: {smtp_host}:{smtp_port}")
        server = _try_connect(smtp_host, smtp_port)
        server.send_message(msg)
        server.quit()
        print(f"[SMTP] Email sent to {to_email}")
        return True
    except Exception as e:
        print(f"[SMTP] Primary failed: {e}. Trying alternate port/IP...")
        try:
            # Try alternate common port
            alt_port = 465 if smtp_port != 465 else 587
            print(f"[SMTP] Attempting alternate port: {smtp_host}:{alt_port}")
            server = _try_connect(smtp_host, alt_port)
            server.send_message(msg)
            server.quit()
            print(f"[SMTP] Email sent via alternate port {alt_port}")
            return True
        except Exception as e2:
            print(f"[SMTP] Alternate port failed: {e2}. Trying IPv4 resolution...")
            try:
                import socket
                ipv4 = socket.getaddrinfo(smtp_host, 587, socket.AF_INET)[0][4][0]
                print(f"[SMTP] Attempting IPv4 direct: {ipv4}:587")
                server = _try_connect(ipv4, 587)
                server.send_message(msg)
                server.quit()
                print(f"[SMTP] Email sent via IPv4 fallback")
                return True
            except Exception as e3:
                print(f"[SMTP] All connection paths failed. Last error: {e3}")
                return False

@auth_bp.route('/send-otp', methods=['POST'])
def send_otp():
    data = request.get_json()
    email = data.get('email')
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
            cursor.execute("SELECT * FROM otp_codes WHERE email = %s AND code = %s", (email, token))
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
            cursor.execute("SELECT id FROM members WHERE email = %s", (data['email'],))
            if cursor.fetchone():
                return jsonify({'message': 'Email already registered'}), 409

            pw_hash = generate_password_hash(data['password'])
            cursor.execute("""
                INSERT INTO members (name, email, phone, company, license_number, agency_code,
                                     port_of_operation, member_type, password_hash, email_verified, status)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, TRUE, 'pending')
            """, (
                data['name'], data['email'], data['phone'], data['company'],
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
    email = data.get('email') or data.get('memberId')
    password = data.get('password')

    if not email or not password:
        return jsonify({'message': 'Email and password required'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT * FROM members WHERE LOWER(email) = LOWER(%s)", (email,))
            member = cursor.fetchone()

            if not member or not check_password_hash(member['password_hash'], password):
                return jsonify({'message': 'Invalid credentials'}), 401
                
            if not member.get('email_verified', True):
                return jsonify({'message': 'Please check your email to verify your account before logging in.'}), 403

            token = create_access_token(identity=str(member['id']))
            expiry = str(member['license_expiry_date']) if member.get('license_expiry_date') else None
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
                    'role': member.get('role', 'member'),
                    'profile_photo': member.get('profile_photo') or None
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
                           license_expiry_date
                    FROM members WHERE id = %s
                """, (member_id,))
            except Exception:
                conn.rollback()
                try:
                    cursor.execute("""
                        SELECT id, name, email, phone, company, license_number,
                               member_type, port_of_operation, status, profile_photo
                        FROM members WHERE id = %s
                    """, (member_id,))
                except Exception:
                    conn.rollback()
                    cursor.execute("""
                        SELECT id, name, email, phone, company, license_number,
                               member_type, port_of_operation, status
                        FROM members WHERE id = %s
                    """, (member_id,))
            member = cursor.fetchone()
            if not member:
                return jsonify({'message': 'Member not found'}), 404
            # Serialize date to string for JSON
            result = dict(member)
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

    # Upload to Supabase Storage
    if not SUPABASE_URL or not SUPABASE_KEY:
        return jsonify({'message': 'Storage not configured'}), 500

    storage_url = f"{SUPABASE_URL}/storage/v1/object/{PHOTO_BUCKET}/{safe_name}"
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": content_type,
        "x-upsert": "true",
    }
    resp = http_req.post(storage_url, data=file_bytes, headers=headers, timeout=30)
    if resp.status_code not in (200, 201):
        return jsonify({'message': f'Upload failed: {resp.text}'}), 500

    public_url = f"{SUPABASE_URL}/storage/v1/object/public/{PHOTO_BUCKET}/{safe_name}"

    # Save URL to DB
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("UPDATE members SET profile_photo = %s WHERE id = %s", (public_url, member_id))
            conn.commit()
        return jsonify({'message': 'Photo uploaded', 'photo_url': public_url}), 200
    except Exception as e:
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
        print(f"[DEBUG] JWT Verification failed: {str(e)}")
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

    @jwt_required()
    def handle_post():
        member_id = get_jwt_identity()
        data = request.get_json()
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

    return handle_post()


def send_reset_email(to_email, token):
    smtp_host = os.getenv('SMTP_HOST')
    smtp_port = int(os.getenv('SMTP_PORT', 587))
    smtp_user = os.getenv('SMTP_USER')
    smtp_pass = os.getenv('SMTP_PASS')
    client_url = os.getenv('CLIENT_URL', 'https://cub-production.up.railway.app')
    
    if not smtp_host or not smtp_user:
        print("[SMTP] Credentials not configured for reset. Skipping.")
        return

    msg = MIMEMultipart()
    msg['From'] = f"CUBAG Support Team <{smtp_user}>"
    msg['To'] = to_email
    msg['Subject'] = 'Reset your CUBAG Password'

    reset_link = f"{client_url}/reset-password?token={token}&email={to_email}"

    body = f"Hello,\n\nYou requested a password reset. Please click the link below to reset your password:\n\n{reset_link}\n\nIf you did not request this, please ignore this email.\n\nThanks,\nCUBAG Secretariat"
    msg.attach(MIMEText(body, 'plain'))

    def _try_connect(host, port):
        if port == 465:
            s = smtplib.SMTP_SSL(host, port, timeout=15)
        else:
            s = smtplib.SMTP(host, port, timeout=15)
            s.starttls()
        s.login(smtp_user, smtp_pass)
        return s

    try:
        print(f"[SMTP] Attempting primary reset connection: {smtp_host}:{smtp_port}")
        server = _try_connect(smtp_host, smtp_port)
        server.send_message(msg)
        server.quit()
        print(f"[SMTP] Password reset email sent to {to_email}")
    except Exception as e:
        print(f"[SMTP] Primary failed: {e}. Trying alternate path...")
        try:
            alt_port = 465 if smtp_port != 465 else 587
            print(f"[SMTP] Attempting alternate port: {smtp_host}:{alt_port}")
            server = _try_connect(smtp_host, alt_port)
            server.send_message(msg)
            server.quit()
            print(f"[SMTP] Reset email sent via alternate port {alt_port}")
        except Exception as e2:
            print(f"[SMTP] Alternate path failed: {e2}. Trying IPv4...")
            try:
                import socket
                ipv4 = socket.getaddrinfo(smtp_host, 587, socket.AF_INET)[0][4][0]
                print(f"[SMTP] Attempting IPv4 direct: {ipv4}:587")
                server = _try_connect(ipv4, 587)
                server.send_message(msg)
                server.quit()
                print(f"[SMTP] Reset email sent via IPv4 fallback")
            except Exception as e3:
                print(f"[SMTP] Failed all reset email attempts: {e3}")


@auth_bp.route('/forgot-password', methods=['POST'])
def forgot_password():
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


@auth_bp.route('/reset-password', methods=['POST'])
def reset_password():
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


