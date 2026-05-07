from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from config.db import get_db

tasks_bp = Blueprint('tasks', __name__)

@tasks_bp.route('/', methods=['GET'])
@jwt_required()
def get_tasks():
    member_id = get_jwt_identity()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT * FROM tasks WHERE member_id = %s ORDER BY due_date ASC", (member_id,))
            data = cursor.fetchall()
        return jsonify(data), 200
    finally:
        conn.close()


@tasks_bp.route('/summary', methods=['GET'])
@jwt_required()
def tasks_summary():
    member_id = get_jwt_identity()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT COUNT(*) as pending FROM tasks WHERE member_id = %s AND done = FALSE", (member_id,))
            result = cursor.fetchone()
        return jsonify({'pending': result['pending']}), 200
    finally:
        conn.close()


@tasks_bp.route('/<int:task_id>/complete', methods=['PATCH'])
@jwt_required()
def complete_task(task_id):
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("UPDATE tasks SET done = TRUE WHERE id = %s", (task_id,))
            conn.commit()
        return jsonify({'message': 'Task marked complete'}), 200
    finally:
        conn.close()

@tasks_bp.route('/admin/all', methods=['GET'])
def get_all_tasks_admin():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT t.*, m.name as member_name 
                FROM tasks t 
                LEFT JOIN members m ON t.member_id = m.id
                ORDER BY t.created_at DESC
            """)
            data = cursor.fetchall()
        return jsonify(data), 200
    finally:
        conn.close()

@tasks_bp.route('/admin/create', methods=['POST'])
def create_task_admin():
    data = request.get_json()
    member_id = data.get('member_id')
    title = data.get('title')
    description = data.get('description')
    due_date = data.get('due_date')
    
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            if member_id == 'all':
                cursor.execute("SELECT id FROM members WHERE status = 'active'")
                members = cursor.fetchall()
                for m in members:
                    cursor.execute("""
                        INSERT INTO tasks (member_id, title, description, due_date)
                        VALUES (%s, %s, %s, %s)
                    """, (m['id'], title, description, due_date))
            else:
                cursor.execute("""
                    INSERT INTO tasks (member_id, title, description, due_date)
                    VALUES (%s, %s, %s, %s)
                """, (member_id, title, description, due_date))
            conn.commit()
        return jsonify({'message': 'Task assigned successfully'}), 201
    finally:
        conn.close()

