import logging
from flask import Blueprint, jsonify, request
from config.db import get_db
from utils import admin_required

logger = logging.getLogger(__name__)
compliance_settings_bp = Blueprint('compliance_settings', __name__)

@compliance_settings_bp.route('/', methods=['GET'])
@admin_required
def get_settings():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT * FROM compliance_settings LIMIT 1")
            settings = cursor.fetchone()
            if not settings:
                settings = {
                    'payment_punctual': 25, 'payment_history': 15,
                    'license_active': 15, 'license_inactive': 5,
                    'task_completion': 15, 'survey_completion': 10,
                    'agm_active': 10, 'agm_inactive': 5
                }
        return jsonify(settings), 200
    except Exception as e:
        logger.exception("Error fetching compliance settings: %s", e)
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@compliance_settings_bp.route('/', methods=['PUT'])
@admin_required
def update_settings():
    data = request.get_json() or {}
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Check if exists
            cursor.execute("SELECT COUNT(*) FROM compliance_settings")
            count = cursor.fetchone()['count']
            if count == 0:
                cursor.execute("INSERT INTO compliance_settings DEFAULT VALUES")
            
            cursor.execute("""
                UPDATE compliance_settings SET 
                    payment_punctual = %s,
                    payment_history = %s,
                    license_active = %s,
                    license_inactive = %s,
                    task_completion = %s,
                    survey_completion = %s,
                    agm_active = %s,
                    agm_inactive = %s,
                    updated_at = CURRENT_TIMESTAMP
            """, (
                int(data.get('payment_punctual', 25)),
                int(data.get('payment_history', 15)),
                int(data.get('license_active', 15)),
                int(data.get('license_inactive', 5)),
                int(data.get('task_completion', 15)),
                int(data.get('survey_completion', 10)),
                int(data.get('agm_active', 10)),
                int(data.get('agm_inactive', 5))
            ))
            conn.commit()
            
            # Recalculate for all members
            cursor.execute("SELECT id FROM members WHERE status IN ('active', 'pending')")
            members = cursor.fetchall()
            
        # Re-fetch cursor to prevent holding lock during recalculation
        from utils import calculate_and_update_member_rating
        for m in members:
            calculate_and_update_member_rating(m['id'])
            
        return jsonify({'message': 'Settings updated and all member scores recalculated.'}), 200
    except Exception as e:
        logger.exception("Error updating compliance settings: %s", e)
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()
