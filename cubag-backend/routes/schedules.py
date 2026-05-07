from flask import Blueprint, jsonify, request
from config.db import get_db

schedules_bp = Blueprint('schedules', __name__)

@schedules_bp.route('/', methods=['GET'])
def get_schedules():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT * FROM schedules ORDER BY created_at DESC")
            data = cursor.fetchall()
        return jsonify(data), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@schedules_bp.route('/', methods=['POST'])
def create_schedule():
    data = request.get_json()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO schedules (type, container, vessel, cargo, date, port, status)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            """, (
                data.get('type'), data.get('container'), data.get('vessel'),
                data.get('cargo'), data.get('date'), data.get('port'), data.get('status', 'Scheduled')
            ))
            conn.commit()
        return jsonify({'message': 'Schedule added successfully'}), 201
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()
