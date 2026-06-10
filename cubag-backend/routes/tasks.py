import os
from flask import Blueprint, jsonify, request, send_from_directory, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from werkzeug.utils import secure_filename
from config.db import get_db
from routes.admin import log_admin_action
from utils import admin_required, sub_admin_required

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

            # Stringify dates
            for item in data:
                if hasattr(item.get('due_date'), 'isoformat'):
                    item['due_date'] = item['due_date'].isoformat()
                if hasattr(item.get('created_at'), 'isoformat'):
                    item['created_at'] = item['created_at'].isoformat()
                if hasattr(item.get('submitted_at'), 'isoformat'):
                    item['submitted_at'] = item['submitted_at'].isoformat()

        return jsonify({'items': data, 'total': len(data)}), 200
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
    member_id = get_jwt_identity()  # BUG-B26 fix: ownership check
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "UPDATE tasks SET done = TRUE WHERE id = %s AND member_id = %s",
                (task_id, member_id)
            )
            if cursor.rowcount == 0:
                return jsonify({'message': 'Task not found or not yours'}), 404
            conn.commit()
        return jsonify({'message': 'Task marked complete'}), 200
    except Exception as e:
        conn.rollback()
        return jsonify({'message': 'Failed to update task'}), 500
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
            # BUG-B27 fix: verify ownership before allowing submission
            cursor.execute(
                "SELECT id FROM tasks WHERE id = %s AND member_id = %s",
                (task_id, member_id)
            )
            if not cursor.fetchone():
                return jsonify({'message': 'Task not found or not assigned to you'}), 404

            # BUG-B29 fix: prevent duplicate submissions
            cursor.execute(
                "SELECT id FROM task_submissions WHERE task_id = %s AND member_id = %s",
                (task_id, member_id)
            )
            if cursor.fetchone():
                return jsonify({'message': 'You have already submitted this task'}), 409

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
            cursor.execute("UPDATE tasks SET done = TRUE WHERE id = %s AND member_id = %s", (task_id, member_id))
            conn.commit()

        return jsonify({'message': 'Submission received', 'submission_id': submission_id, 'files': saved}), 201
    except Exception as e:
        conn.rollback()
        return jsonify({'message': 'Submission failed. Please try again.'}), 500
    finally:
        conn.close()


# ─── GET /tasks/uploads/<filename> ─ Serve uploaded files (auth required) ──────
@tasks_bp.route('/uploads/<filename>', methods=['GET'])
@jwt_required()  # BUG-B28 fix: was unauthenticated
def serve_file(filename):
    member_id = get_jwt_identity()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Verify the file belongs to a submission by this member (or an admin)
            cursor.execute("SELECT role FROM members WHERE id = %s", (member_id,))
            member = cursor.fetchone()
            is_admin = member and member.get('role') in ('admin', 'sub_admin', 'super_admin')
            if not is_admin:
                # Check member owns the submission this file belongs to
                cursor.execute("""
                    SELECT tsf.id FROM task_submission_files tsf
                    JOIN task_submissions ts ON tsf.submission_id = ts.id
                    WHERE tsf.filename = %s AND ts.member_id = %s
                """, (filename, member_id))
                if not cursor.fetchone():
                    return jsonify({'message': 'Unauthorised'}), 403
    finally:
        conn.close()
    return send_from_directory(UPLOAD_FOLDER, filename)


# ─── GET /tasks/admin/all ─────────────────────────────────────────────────────
@tasks_bp.route('/admin/all', methods=['GET'])
@sub_admin_required('members')
def get_all_tasks_admin():
    try:
        page = max(1, int(request.args.get('page', 1)))
        per_page = int(request.args.get('per_page', 20))
        per_page = max(1, min(per_page, 200))
        offset = (page - 1) * per_page
        task_status = request.args.get('status', 'all').lower()

        where_clause = ""
        if task_status == 'pending':
            where_clause = "WHERE t.done = FALSE AND (s.id IS NULL OR s.admin_verified = FALSE)" # pending or submitted without submission? Wait, pending is NOT done.
            where_clause = "WHERE t.done = FALSE AND s.id IS NULL"
        elif task_status == 'submitted':
            where_clause = "WHERE t.done = TRUE AND (s.admin_verified IS NULL OR s.admin_verified = FALSE)"
        elif task_status == 'verified':
            where_clause = "WHERE s.admin_verified = TRUE"

        conn = get_db()
        with conn.cursor() as cursor:
            cursor.execute(f"""
                SELECT t.*, m.name as member_name,
                       s.id as submission_id, s.completion_note, s.admin_verified,
                       s.admin_verified_at, s.admin_notes, s.submitted_at
                FROM tasks t
                LEFT JOIN members m ON t.member_id = m.id
                LEFT JOIN task_submissions s ON t.id = s.task_id
                {where_clause}
                ORDER BY t.created_at DESC
                LIMIT %s OFFSET %s
            """, (per_page, offset))
            tasks = cursor.fetchall()

            cursor.execute(f"""
                SELECT COUNT(*) as total
                FROM tasks t
                LEFT JOIN task_submissions s ON t.id = s.task_id
                {where_clause}
            """)
            total = cursor.fetchone().get('total', 0)

            # Attach files for each submission using one bulk query
            submission_ids = [t['submission_id'] for t in tasks if t.get('submission_id')]
            files_by_submission = {}
            if submission_ids:
                placeholders = ', '.join(['%s'] * len(submission_ids))
                cursor.execute(f"""
                    SELECT id, submission_id, original_name, file_type, file_size, filename
                    FROM task_submission_files
                    WHERE submission_id IN ({placeholders})
                """, submission_ids)
                all_files = cursor.fetchall()
                for file_row in all_files:
                    sub_id = file_row['submission_id']
                    if sub_id not in files_by_submission:
                        files_by_submission[sub_id] = []
                    file_item = dict(file_row)
                    del file_item['submission_id']
                    files_by_submission[sub_id].append(file_item)

            for task in tasks:
                sub_id = task.get('submission_id')
                task['files'] = files_by_submission.get(sub_id, [])

                # Ensure dates are stringified
                for date_field in ['due_date', 'created_at', 'submitted_at', 'admin_verified_at']:
                    if hasattr(task.get(date_field), 'isoformat'):
                        task[date_field] = task[date_field].isoformat()

        return jsonify({'data': tasks, 'page': page, 'per_page': per_page, 'total': total}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        if 'conn' in locals():
            conn.close()


# ─── POST /tasks/admin/create ─────────────────────────────────────────────
@tasks_bp.route('/admin/create', methods=['POST'])
@sub_admin_required('members')
def create_task_admin():
    admin_id = get_jwt_identity()
    data = request.get_json() or {}
    member_id = data.get('member_id')
    title = (data.get('title') or '').strip()
    description = data.get('description', '')
    due_date = data.get('due_date')

    # BUG-B30 fix: validate required fields
    if not title:
        return jsonify({'message': 'Task title is required'}), 400
    if not member_id:
        return jsonify({'message': 'Member ID is required'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cursor:
            if member_id == 'all':
                # Include both active and pending members so new registrants get compliance tasks immediately
                cursor.execute("SELECT id FROM members WHERE status IN ('active', 'pending')")
                members = cursor.fetchall()
                for m in members:
                    cursor.execute("""
                        INSERT INTO tasks (member_id, title, description, due_date)
                        VALUES (%s, %s, %s, %s)
                    """, (m['id'], title, description, due_date))
                target_name = f'All active members ({len(members)})'
            else:
                cursor.execute("""
                    INSERT INTO tasks (member_id, title, description, due_date)
                    VALUES (%s, %s, %s, %s)
                """, (member_id, title, description, due_date))
                cursor.execute("SELECT name FROM members WHERE id = %s", (member_id,))
                m = cursor.fetchone()
                target_name = m['name'] if m else f'Member #{member_id}'
            conn.commit()

        # Audit log
        log_admin_action(admin_id, 'Assigned task', 'task', None, target_name, f'Task: {title}')

        return jsonify({'message': 'Task assigned successfully'}), 201
    except Exception as e:
        conn.rollback()
        return jsonify({'message': 'Failed to create task'}), 500
    finally:
        conn.close()


# ─── PATCH /tasks/admin/<id>/verify ─ Admin ticks task as verified ────────────
@tasks_bp.route('/admin/<int:submission_id>/verify', methods=['PATCH'])
@sub_admin_required('members')
def verify_task_submission(submission_id):
    admin_id = get_jwt_identity()
    data = request.get_json() or {}
    admin_notes = data.get('admin_notes', '')
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Get task and member info for audit
            cursor.execute("""
                SELECT ts.task_id, t.title, m.name as member_name
                FROM task_submissions ts
                JOIN tasks t ON ts.task_id = t.id
                LEFT JOIN members m ON ts.member_id = m.id
                WHERE ts.id = %s
            """, (submission_id,))
            info = cursor.fetchone()

            cursor.execute("""
                UPDATE task_submissions
                SET admin_verified = TRUE,
                    admin_verified_at = CURRENT_TIMESTAMP,
                    admin_notes = %s
                WHERE id = %s
            """, (admin_notes, submission_id))
            conn.commit()

        # Audit log
        if info:
            log_admin_action(admin_id, 'Verified task submission', 'task', info.get('task_id'), info.get('member_name'), f'Task: {info.get("title")}')

        return jsonify({'message': 'Task submission verified'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()
