import logging
import time
from datetime import date, timedelta
from apscheduler.schedulers.background import BackgroundScheduler
from config.db import get_db
from utils import send_push_notification, calculate_and_update_member_rating

logger = logging.getLogger(__name__)

def check_expired_licenses():
    logger.info("[Jobs] Running expired license check...")
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            today = date.today()
            warning_date = today + timedelta(days=7)

            # Find active members whose license expires in exactly 7 days
            cursor.execute("""
                SELECT id, name, fcm_token, license_expiry_date 
                FROM members 
                WHERE status = 'active' AND license_expiry_date = %s
            """, (warning_date,))
            warning_members = cursor.fetchall()

            for m in warning_members:
                if m['fcm_token']:
                    title = "License Expiring Soon"
                    body = f"Hello {m['name']}, your license will expire on {m['license_expiry_date']}. Please renew to avoid suspension."
                    send_push_notification(m['fcm_token'], title, body, data={'type': 'license_warning'})
                
                # Send announcement
                cursor.execute("""
                    INSERT INTO announcements (title, body, category, posted_by, member_id)
                    VALUES (%s, %s, %s, %s, %s)
                """, ("License Expiring Soon", f"Please renew by {m['license_expiry_date']}", 'Compliance', 'System Alert', m['id']))

            # Find active members whose license has already expired
            cursor.execute("""
                SELECT id, name, fcm_token 
                FROM members 
                WHERE status = 'active' AND license_expiry_date < %s
            """, (today,))
            expired_members = cursor.fetchall()

            for m in expired_members:
                # Update status to suspended
                cursor.execute("UPDATE members SET status = 'suspended' WHERE id = %s", (m['id'],))
                
                if m['fcm_token']:
                    title = "License Expired - Account Suspended"
                    body = f"Hello {m['name']}, your license has expired and your account is now suspended. Please renew immediately."
                    send_push_notification(m['fcm_token'], title, body, data={'type': 'license_expired'})
                
                cursor.execute("""
                    INSERT INTO announcements (title, body, category, posted_by, member_id)
                    VALUES (%s, %s, %s, %s, %s)
                """, ("License Expired", "Account suspended due to license expiration.", 'Compliance', 'System Alert', m['id']))

            conn.commit()

            if expired_members:
                logger.info(f"[Jobs] Suspended {len(expired_members)} members due to expired licenses.")

    except Exception as e:
        logger.exception(f"[Jobs] Error in check_expired_licenses: {e}")
        conn.rollback()
    finally:
        conn.close()


def run_rating_update_cycle():
    logger.info("[Jobs] Starting full compliance update cycle...")
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id FROM members WHERE role NOT IN ('admin', 'super_admin') AND status = 'active'")
            member_ids = [row['id'] for row in cursor.fetchall()]

            for mid in member_ids:
                try:
                    calculate_and_update_member_rating(mid, cursor)
                    conn.commit()
                except Exception as e:
                    logger.error(f"[Jobs] Failed to update member {mid}: {e}")
                    conn.rollback()
    except Exception as e:
        logger.error(f"[Jobs] Critical cycle error: {e}")
    finally:
        conn.close()

def start_scheduler():
    scheduler = BackgroundScheduler(daemon=True)
    
    # Check licenses daily at 12:00 PM
    scheduler.add_job(check_expired_licenses, 'cron', hour=12, minute=0)
    
    # Update ratings daily at 2:00 AM
    scheduler.add_job(run_rating_update_cycle, 'cron', hour=2, minute=0)
    
    scheduler.start()
    logger.info("[Jobs] APScheduler started.")
