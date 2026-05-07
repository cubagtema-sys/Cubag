import os
from flask import Blueprint, jsonify, request, send_from_directory, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from werkzeug.utils import secure_filename
from config.db import get_db

tasks_bp = Blueprint('tasks', __name__)

UPLOAD_FOLDER = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'uploads', 'task_submissions')
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'mp4', 'mov', 'avi', 'txt'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

os.makedirs(UPLOAD_FOLDER, exist_ok=True)


# ─── GET /tasks ───────────────────────────────────────────────────────────────
@tasks_bp.route('/', methods=['GET'])
@jwt_required()
def get_tasks():
    member_id = get_jwt_identity()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT t.*, 
                       s.id as submission_id,
                       s.admin_verified,
                       s.submitted_at,
                       s.completion_note
                FROM tasks t
                LEFT JOIN task_submissions s ON t.id = s.task_id AND s.member_id = %s
                WHERE t.member_id = %s
                ORDER BY t.due_date ASC
            """, (member_id, member_id))
            data = cursor.fetchall()
        return jsonify(data), 200
    finally:
        conn.close()


# ─── GET /tasks/summary ───────────────────────────────────────────────────────
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


# ─── PATCH /tasks/<id>/complete ───────────────────────────────────────────────
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


# ─── POST /tasks/<id>/submit ─ User submits completion evidence ───────────────
@tasks_bp.route('/<int:task_id>/submit', methods=['POST'])
@jwt_required()
def submit_task(task_id):
    member_id = get_jwt_identity()
    note = request.form.get('note', '')
    files = request.files.getlist('files')

    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Create submission record
            cursor.execute("""
                INSERT INTO task_submissions (task_id, member_id, completion_note)
                VALUES (%s, %s, %s)
                RETURNING id
            """, (task_id, member_id, note))
            submission_id = cursor.fetchone()['id']

            # Save uploaded files
            saved = []
            for f in files:
                if f and f.filename and allowed_file(f.filename):
                    safe_name = f"{submission_id}_{secure_filename(f.filename)}"
                    path = os.path.join(UPLOAD_FOLDER, safe_name)
                    f.save(path)
                    file_size = os.path.getsize(path)
                    cursor.execute("""
                        INSERT INTO task_submission_files (submission_id, filename, original_name, file_type, file_size)
                        VALUES (%s, %s, %s, %s, %s)
                    """, (submission_id, safe_name, f.filename, f.content_type, file_size))
                    saved.append(f.filename)

            # Mark task as submitted (done = TRUE pending admin verify)
            cursor.execute("UPDATE tasks SET done = TRUE WHERE id = %s", (task_id,))
            conn.commit()

        return jsonify({'message': 'Submission received', 'submission_id': submission_id, 'files': saved}), 201
    except Exception as e:
        conn.rollback()
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


# ─── GET /tasks/uploads/<filename> ─ Serve uploaded files ────────────────────
@tasks_bp.route('/uploads/<filename>', methods=['GET'])
def serve_file(filename):
    return send_from_directory(UPLOAD_FOLDER, filename)


# ─── GET /tasks/admin/all ─────────────────────────────────────────────────────
@tasks_bp.route('/admin/all', methods=['GET'])
def get_all_tasks_admin():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT t.*, m.name as member_name,
                       s.id as submission_id, s.completion_note, s.admin_verified,
                       s.admin_verified_at, s.admin_notes, s.submitted_at
                FROM tasks t
                LEFT JOIN members m ON t.member_id = m.id
                LEFT JOIN task_submissions s ON t.id = s.task_id
                ORDER BY t.created_at DESC
            """)
            tasks = cursor.fetchall()

            # Attach files for each submission
            for task in tasks:
                if task.get('submission_id'):
                    cursor.execute("""
                        SELECT id, original_name, file_type, file_size, filename
                        FROM task_submission_files
                        WHERE submission_id = %s
                    """, (task['submission_id'],))
                    task['files'] = cursor.fetchall()
                else:
                    task['files'] = []

        return jsonify(tasks), 200
    finally:
        conn.close()


# ─── POST /tasks/admin/create ─────────────────────────────────────────────────
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


# ─── PATCH /tasks/admin/<id>/verify ─ Admin ticks task as verified ────────────
@tasks_bp.route('/admin/<int:submission_id>/verify', methods=['PATCH'])
def verify_task_submission(submission_id):
    data = request.get_json() or {}
    admin_notes = data.get('admin_notes', '')
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                UPDATE task_submissions
                SET admin_verified = TRUE,
                    admin_verified_at = CURRENT_TIMESTAMP,
                    admin_notes = %s
                WHERE id = %s
            """, (admin_notes, submission_id))
            conn.commit()
        return jsonify({'message': 'Task submission verified'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()
