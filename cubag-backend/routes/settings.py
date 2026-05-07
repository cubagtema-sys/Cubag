from flask import Blueprint, jsonify, request
from config.db import get_db
import json

settings_bp = Blueprint('settings', __name__)

@settings_bp.route('/<key>', methods=['GET'])
def get_setting(key):
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT config_value FROM platform_settings WHERE config_key = %s", (key,))
            result = cursor.fetchone()
            if result:
                return jsonify(result['config_value']), 200
            else:
                return jsonify({}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@settings_bp.route('/<key>', methods=['POST'])
def update_setting(key):
    data = request.get_json()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Upsert
            cursor.execute("""
                INSERT INTO platform_settings (config_key, config_value)
                VALUES (%s, %s)
                ON CONFLICT (config_key) 
                DO UPDATE SET config_value = EXCLUDED.config_value, updated_at = CURRENT_TIMESTAMP
            """, (key, json.dumps(data)))
            conn.commit()
            return jsonify({'message': 'Settings updated'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()
