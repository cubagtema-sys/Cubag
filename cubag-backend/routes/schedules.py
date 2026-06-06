from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from config.db import get_db
from routes.admin import log_admin_action
from utils import admin_required, sub_admin_required

schedules_bp = Blueprint('schedules', __name__)

@schedules_bp.route('/', methods=['GET'])
def get_schedules():
    schedule_type = request.args.get('type')
    return _fetch_schedules(schedule_type)

@schedules_bp.route('/<string:schedule_type>', methods=['GET'])
def get_schedules_by_path(schedule_type):
    return _fetch_schedules(schedule_type)

def _fetch_schedules(schedule_type):
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            if schedule_type:
                # Use LOWER to ensure case-insensitive matching between saved data and request
                cursor.execute("SELECT * FROM schedules WHERE LOWER(type) = LOWER(%s) ORDER BY created_at DESC", (schedule_type,))
            else:
                cursor.execute("SELECT * FROM schedules ORDER BY created_at DESC")
            data = cursor.fetchall()
        return jsonify(data), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@schedules_bp.route('/', methods=['POST'])
@sub_admin_required('schedules')
def create_schedule():
    admin_id = get_jwt_identity()
    data = request.get_json()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO schedules (type, container, vessel, cargo, date, port, status, origin, destination, progress)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                data.get('type'), data.get('container'), data.get('vessel'),
                data.get('cargo'), data.get('date'), data.get('port'),
                data.get('status', 'Scheduled'),
                data.get('origin'),       # vessel movement: departure port
                data.get('destination'),  # vessel movement: arrival port
                data.get('progress', 0)   # 0–100 percent along route
            ))
            conn.commit()

        # Audit log
        log_admin_action(admin_id, 'Created schedule', 'schedule', None, data.get('vessel') or data.get('container'), f'Type: {data.get("type")}, Port: {data.get("port")}')

        return jsonify({'message': 'Schedule added successfully'}), 201
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

# ─── PATCH /schedules/<id> — Update status ────────────────────────────────────
@schedules_bp.route('/<int:schedule_id>', methods=['PATCH'])
@sub_admin_required('schedules')
def update_schedule_status(schedule_id):
    admin_id = get_jwt_identity()
    data = request.get_json()
    new_status = data.get('status')
    if not new_status:
        return jsonify({'message': 'status is required'}), 400
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT vessel, container FROM schedules WHERE id = %s", (schedule_id,))
            sched = cursor.fetchone()

            cursor.execute(
                "UPDATE schedules SET status = %s WHERE id = %s",
                (new_status, schedule_id)
            )
            conn.commit()

        # Audit log
        label = sched.get('vessel') or sched.get('container') or f'#{schedule_id}' if sched else f'#{schedule_id}'
        log_admin_action(admin_id, 'Updated schedule status', 'schedule', schedule_id, label, f'Status → {new_status}')

        return jsonify({'message': 'Status updated'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

# ─── DELETE /schedules/<id> ───────────────────────────────────────────────
@schedules_bp.route('/<int:schedule_id>', methods=['DELETE'])
@sub_admin_required('schedules')
def delete_schedule(schedule_id):
    admin_id = get_jwt_identity()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT vessel, container FROM schedules WHERE id = %s", (schedule_id,))
            sched = cursor.fetchone()

            cursor.execute("DELETE FROM schedules WHERE id = %s", (schedule_id,))
            conn.commit()

        # Audit log
        label = sched.get('vessel') or sched.get('container') or f'#{schedule_id}' if sched else f'#{schedule_id}'
        log_admin_action(admin_id, 'Deleted schedule', 'schedule', schedule_id, label)

        return jsonify({'message': 'Schedule deleted'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()
