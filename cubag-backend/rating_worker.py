import time
import logging
import threading
from config.db import get_db
from utils import calculate_and_update_member_rating

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def run_rating_update_cycle():
    """Runs a full pass over all members to update their compliance ratings."""
    logger.info("[Rating Worker] Starting full compliance update cycle...")
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id FROM members WHERE role != 'admin' AND status = 'active'")
            member_ids = [row['id'] for row in cursor.fetchall()]

            logger.info(f"[Rating Worker] Found {len(member_ids)} active members to process.")

            for mid in member_ids:
                try:
                    calculate_and_update_member_rating(mid, cursor)
                    # We commit after each member to avoid long-running transaction locks
                    conn.commit()
                except Exception as e:
                    logger.error(f"[Rating Worker] Failed to update member {mid}: {e}")
                    conn.rollback()

    except Exception as e:
        logger.error(f"[Rating Worker] Critical cycle error: {e}")
    finally:
        conn.close()
    logger.info("[Rating Worker] Update cycle complete.")

def start_rating_worker(interval_seconds=86400):
    """
    Starts the rating background thread.
    Default interval: 86400s (24 hours).
    """
    def _worker_loop():
        # Delay start slightly to allow main server to boot
        time.sleep(10)
        while True:
            run_rating_update_cycle()
            logger.info(f"[Rating Worker] Sleeping for {interval_seconds}s...")
            time.sleep(interval_seconds)

    thread = threading.Thread(target=_worker_loop, daemon=True)
    thread.start()
    logger.info("[Rating Worker] Background thread started.")
