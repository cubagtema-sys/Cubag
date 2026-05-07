from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required
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
@jwt_required()
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

# ─── PATCH /schedules/<id> — Update status ────────────────────────────────────
@schedules_bp.route('/<int:schedule_id>', methods=['PATCH'])
@jwt_required()
def update_schedule_status(schedule_id):
    data = request.get_json()
    new_status = data.get('status')
    if not new_status:
        return jsonify({'message': 'status is required'}), 400
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "UPDATE schedules SET status = %s WHERE id = %s",
                (new_status, schedule_id)
            )
            conn.commit()
        return jsonify({'message': 'Status updated'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

# ─── DELETE /schedules/<id> ───────────────────────────────────────────────────
@schedules_bp.route('/<int:schedule_id>', methods=['DELETE'])
@jwt_required()
def delete_schedule(schedule_id):
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("DELETE FROM schedules WHERE id = %s", (schedule_id,))
            conn.commit()
        return jsonify({'message': 'Schedule deleted'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()
