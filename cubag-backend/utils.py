import os
import logging
import firebase_admin
from firebase_admin import credentials, messaging
from config.db import get_db

# Module logger
logger = logging.getLogger(__name__)

def log_admin_action(admin_id, action, target_type=None, target_id=None, target_name=None, details=None):
    """Utility to record an admin action in the audit log."""
    if not admin_id:
        return

    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Ensure ids are integers
            try:
                a_id = int(admin_id)
            except (TypeError, ValueError):
                return

            t_id = None
            if target_id:
                try:
                    t_id = int(target_id)
                except (TypeError, ValueError):
                    pass

            cursor.execute("""
                INSERT INTO audit_log (admin_id, action, target_type, target_id, target_name, details)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (a_id, action, target_type, t_id, target_name, details))
        conn.commit()
    except Exception as e:
        logger.exception("[Audit Log Error] %s", e)
    finally:
        conn.close()

def log_backend_error(action, details):
    """Utility to record a backend error in the audit log without needing admin_id."""
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO audit_log (action, target_type, details)
                VALUES (%s, 'error', %s)
            """, (action, details))
        conn.commit()
    except Exception as e:
        logger.exception("[Audit Log Error logging backend error] %s", e)
    finally:
        conn.close()


def send_push_notification(fcm_token, title, body, data=None):
    """
    Sends a push notification to a specific device using FCM.
    """
    if not fcm_token:
        return False
        
    if not _init_firebase():
        return False

    try:
        # Prepare the message data (must be strings)
        string_data = {k: str(v) for k, v in (data or {}).items()}

        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=string_data,
            token=fcm_token,
        )

        response = messaging.send(message)
        logger.info("Successfully sent message: %s", response)
        return True
    except Exception as e:
        logger.exception("Error sending push notification: %s", e)
        return False

# Load service account from environment variable (JSON string) or file
# Primary env variable used across the system is FIREBASE_CREDENTIALS_JSON
service_account_json = os.getenv('FIREBASE_CREDENTIALS_JSON') or os.getenv('FIREBASE_SERVICE_ACCOUNT')

def _init_firebase():
    """Initializes the Firebase Admin SDK if not already initialized."""
    try:
        firebase_admin.get_app()
    except ValueError:
        if service_account_json:
            import json
            try:
                cred_dict = json.loads(service_account_json)
                cred = credentials.Certificate(cred_dict)
                firebase_admin.initialize_app(cred)
                logger.info("[Push] Firebase Admin initialized from ENV.")
            except Exception as e:
                logger.exception("[Push] Error parsing FIREBASE_CREDENTIALS_JSON: %s", e)
                return False
        elif os.path.exists('firebase-key.json'):
            cred = credentials.Certificate('firebase-key.json')
            firebase_admin.initialize_app(cred)
            logger.info("[Push] Firebase Admin initialized from FILE.")
        else:
            logger.warning("[Push] Firebase Credentials not found. Skipping push.")
            return False
    return True

def send_push_to_all(title, body, data=None):
    """
    Sends a push notification to all members who have an fcm_token registered.
    Uses the modern FCM V1 API via Firebase Admin SDK.
    """
    if not _init_firebase():
        return

    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT fcm_token FROM members WHERE fcm_token IS NOT NULL")
            tokens = [row['fcm_token'] for row in cursor.fetchall()]

        logger.debug("[DEBUG] Push notification triggered. Found %d tokens in DB.", len(tokens))

        if not tokens:
            return

        # Prepare the message data (must be strings)
        string_data = {k: str(v) for k, v in (data or {}).items()}

        # Multicast message allows sending to up to 500 tokens at once
        for i in range(0, len(tokens), 500):
            batch = tokens[i:i+500]
            message = messaging.MulticastMessage(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=string_data,
                tokens=batch,
            )
            try:
                response = messaging.send_multicast(message)
                logger.info("[Push] Batch sent: %s success, %s failure", response.success_count, response.failure_count)

                # Cleanup invalid tokens if any (optional but recommended)
                if response.failure_count > 0:
                    for index, resp in enumerate(response.responses):
                        if not resp.success:
                            # Token is invalid (e.g. app uninstalled) - could delete from DB here
                            pass
            except Exception as e:
                logger.exception("[Push] Error sending batch: %s", e)

    except Exception as e:
        logger.exception("[Push] Database error: %s", e)
    finally:
        conn.close()

def calculate_and_update_member_rating(member_id, cursor=None):
    from datetime import date
    should_close = False
    if cursor is None:
        conn = get_db()
        cursor = conn.cursor()
        should_close = True
    
    try:
        # Get previous rating status to compare tiers for notification triggers
        cursor.execute("SELECT compliance_score, star_rating FROM members WHERE id = %s", (member_id,))
        prev_row = cursor.fetchone()
        prev_score = prev_row['compliance_score'] if prev_row and prev_row['compliance_score'] is not None else None
        prev_stars = float(prev_row['star_rating']) if prev_row and prev_row['star_rating'] is not None else None

        cursor.execute("SELECT status, license_expiry_date, manual_review_score, created_at FROM members WHERE id = %s", (member_id,))
        member_row = cursor.fetchone()
        if not member_row:
            return {'compliance_score': 0, 'star_rating': 0.0, 'manual_review_score': 0}
            
        status = str(member_row['status'] or '').lower()
        expiry_date = member_row['license_expiry_date']
        manual_review = member_row['manual_review_score']
        created_at = member_row['created_at']
        if manual_review is None:
            manual_review = 10

        today = date.today()
        is_expired = False
        if expiry_date:
            if isinstance(expiry_date, str):
                from datetime import datetime
                try:
                    expiry_date = datetime.strptime(expiry_date, '%Y-%m-%d').date()
                except Exception as e:
                    logger.debug("Failed to parse expiry_date for member %s: %s", member_id, e)
            if isinstance(expiry_date, date):
                is_expired = expiry_date < today

        # 1. Licensing & Good Standing (40 Points)
        standing_score = 0
        if status == 'active':
            if expiry_date and not is_expired:
                standing_score = 40
            else:
                standing_score = 20 # Active but license expired (grace period)
        elif status in ('pending', 'suspended', 'inactive'):
            standing_score = 0
            
        # 2. Financial Compliance (30 Points)
        cursor.execute("""
            SELECT COUNT(*) as total_count,
                   SUM(CASE WHEN LOWER(status) = 'paid' THEN 1 ELSE 0 END) as paid_count
            FROM payments
            WHERE member_id = %s
        """, (member_id,))
        pay_stats = cursor.fetchone()
        total_invoices = pay_stats['total_count'] or 0
        paid_invoices = pay_stats['paid_count'] or 0
        
        if total_invoices == 0:
            financial_score = 30 # Innocent until proven guilty / Brand new member
        else:
            financial_score = round((paid_invoices / total_invoices) * 30)

        # 3. Event Attendance (20 Points)
        # Count total events held SINCE the member joined
        cursor.execute("SELECT COUNT(*) as count FROM events WHERE created_at >= %s", (created_at,))
        total_events = cursor.fetchone()['count'] or 0
        
        cursor.execute("SELECT COUNT(*) as count FROM event_attendance WHERE member_id = %s", (member_id,))
        attended_events = cursor.fetchone()['count'] or 0
        
        if total_events == 0:
            event_score = 20 # No events held yet
        else:
            event_score = round((min(attended_events, total_events) / total_events) * 20)

        # 4. Admin Trust Score (10 Points)
        admin_score = manual_review # directly maps 0-10

        # Total Score & Rating
        total_score = standing_score + financial_score + event_score + admin_score
        total_score = max(0, min(100, total_score))
        star_rating = round(total_score / 20.0, 2)

        # Save to database
        cursor.execute("""
            UPDATE members 
            SET compliance_score = %s, star_rating = %s, manual_review_score = %s
            WHERE id = %s
        """, (total_score, star_rating, manual_review, member_id))

        # Log history
        cursor.execute("""
            INSERT INTO member_rating_history (member_id, compliance_score, star_rating)
            VALUES (%s, %s, %s)
        """, (member_id, total_score, star_rating))

        if should_close:
            conn.commit()

        breakdown = {
            'standing': standing_score,
            'financial': financial_score,
            'events': event_score,
            'admin': admin_score
        }

        # Check for standing tier changes
        def get_tier(score):
            if score >= 90: return "Elite"
            elif score >= 70: return "Good Standing"
            elif score >= 50: return "Warning/Probation"
            else: return "Suspended/Delinquent"

        new_tier = get_tier(total_score)
        
        if prev_score is not None:
            prev_tier = get_tier(prev_score)
            if prev_tier != new_tier:
                # standing tier transition alert
                title = f"Standing Changed to {new_tier}"
                body = f"Your compliance standing has changed from {prev_tier} to {new_tier}. Compliance Score: {total_score}%."
                
                # Insert personalized notification
                cursor.execute("""
                    INSERT INTO announcements (title, body, category, posted_by, member_id)
                    VALUES (%s, %s, %s, %s, %s)
                """, (title, body, 'Compliance', 'System Alert', member_id))
                
                # FCM push
                cursor.execute("SELECT fcm_token FROM members WHERE id = %s", (member_id,))
                fcm_row = cursor.fetchone()
                fcm_token = fcm_row['fcm_token'] if fcm_row else None
                if fcm_token:
                    send_push_notification(fcm_token, title, body, data={'type': 'compliance'})
        else:
            # Welcome notice
            title = "Compliance Standing Calculated"
            body = f"Your initial compliance status is now calculated: {total_score}% ({star_rating} Stars) - {new_tier} Standing."
            cursor.execute("""
                INSERT INTO announcements (title, body, category, posted_by, member_id)
                VALUES (%s, %s, %s, %s, %s)
            """, (title, body, 'Compliance', 'System Alert', member_id))

        cursor.connection.commit()

        return {
            'compliance_score': total_score,
            'star_rating': float(star_rating),
            'manual_review_score': manual_review,
            'breakdown': breakdown
        }
    except Exception as e:
        logger.exception("Error calculating member rating: %s", e)
        try:
            cursor.connection.rollback()
        except Exception as re:
            logger.exception("Error rolling back DB after rating calc failure: %s", re)

        # Fall back to the last saved score already in the DB (fetched at top of function).
        # This means the member still sees their real previous score rather than a 0 or fake value.
        try:
            saved_score = int(prev_score) if prev_score is not None else 50
            saved_stars = float(prev_stars) if prev_stars is not None else 2.5
            saved_review = int(prev_row.get('manual_review_score') or 5) if prev_row else 5
        except Exception:
            saved_score, saved_stars, saved_review = 50, 2.5, 5

        logger.warning(
            "Returning last saved rating for member %s: score=%s stars=%s",
            member_id, saved_score, saved_stars
        )
        return {
            'compliance_score':   saved_score,
            'star_rating':        saved_stars,
            'manual_review_score': saved_review,
        }
    finally:
        if should_close:
            cursor.close()
            conn.close()

from functools import wraps
from flask import jsonify
from flask_jwt_extended import get_jwt_identity, verify_jwt_in_request

def admin_required(fn):
    @wraps(fn)
    def decorator(*args, **kwargs):
        try:
            verify_jwt_in_request()
        except Exception:
            return jsonify({'message': 'Missing or invalid authorization token'}), 401
            
        admin_id = get_jwt_identity()
        if not admin_id:
            return jsonify({'message': 'Missing or invalid authorization token'}), 401
            
        conn = get_db()
        try:
            with conn.cursor() as cursor:
                cursor.execute("SELECT role FROM members WHERE id = %s", (admin_id,))
                res = cursor.fetchone()
                if not res or res.get('role') not in ('admin', 'sub_admin', 'super_admin'):
                    return jsonify({'message': 'Admin privilege required'}), 403
                # Sub-admins pass through here — individual route decorators can
                # add further permission checks via sub_admin_required().
        except Exception as e:
            import traceback
            tb = traceback.format_exc()
            logger.exception("[Decorator admin_required Error] %s", e)
            try:
                log_backend_error('Decorator admin_required Error', f"Error: {str(e)}\nTraceback:\n{tb}")
            except Exception as log_err:
                logger.error(f"Failed to log decorator error to DB: {log_err}")
            return jsonify({'message': str(e), 'traceback': tb}), 500
        finally:
            conn.close()
        return fn(*args, **kwargs)
    return decorator


def sub_admin_required(permission: str):
    """
    Decorator that requires the caller to be either:
      - a full admin (role == 'admin' or role == 'super_admin') — always allowed, OR
      - a sub_admin with the given permission key granted.

    Supported permission keys:
      members, payments, tickets, announcements,
      schedules, events, intelligence, audit_log,
      fees, settings
    """
    def decorator_factory(fn):
        @wraps(fn)
        def decorator(*args, **kwargs):
            try:
                verify_jwt_in_request()
            except Exception:
                return jsonify({'message': 'Missing or invalid authorization token'}), 401

            caller_id = get_jwt_identity()
            if not caller_id:
                return jsonify({'message': 'Missing or invalid authorization token'}), 401

            conn = get_db()
            try:
                with conn.cursor() as cursor:
                    cursor.execute("SELECT role FROM members WHERE id = %s", (caller_id,))
                    res = cursor.fetchone()
                    if not res:
                        return jsonify({'message': 'User not found'}), 403

                    role = res.get('role')
                    if role in ('admin', 'super_admin'):
                        # Full admin — unconditional access
                        pass
                    elif role == 'sub_admin':
                        cursor.execute("""
                            SELECT 1 FROM sub_admin_permissions
                            WHERE sub_admin_id = %s AND permission_key = %s AND granted = TRUE
                        """, (caller_id, permission))
                        if not cursor.fetchone():
                            return jsonify({'message': f'Permission denied: {permission}'}), 403
                    else:
                        return jsonify({'message': 'Admin privilege required'}), 403
            except Exception as e:
                import traceback
                tb = traceback.format_exc()
                logger.exception("[Decorator sub_admin_required Error] %s", e)
                try:
                    log_backend_error('Decorator sub_admin_required Error', f"Permission: {permission}\nError: {str(e)}\nTraceback:\n{tb}")
                except Exception as log_err:
                    logger.error(f"Failed to log decorator error to DB: {log_err}")
                return jsonify({'message': str(e), 'traceback': tb}), 500
            finally:
                conn.close()
            return fn(*args, **kwargs)
        return decorator
    return decorator_factory

