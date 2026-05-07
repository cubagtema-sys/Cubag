from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required
from config.db import get_db

announcements_bp = Blueprint('announcements', __name__)

@announcements_bp.route('/', methods=['GET'])
@jwt_required()
def get_announcements():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT * FROM announcements ORDER BY created_at DESC")
            data = cursor.fetchall()
        return jsonify(data), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


@announcements_bp.route('/', methods=['POST'])
@jwt_required()
def create_announcement():
    data = request.get_json()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO announcements (title, body, category, posted_by)
                VALUES (%s, %s, %s, %s)
            """, (data.get('title'), data.get('body'), data.get('category', 'General'), data.get('posted_by', 'Admin')))
            conn.commit()
        return jsonify({'message': 'Announcement posted'}), 201
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@announcements_bp.route('/admin/all', methods=['GET'])
def get_all_announcements_admin():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT * FROM announcements ORDER BY created_at DESC")
            data = cursor.fetchall()
        return jsonify(data), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()
