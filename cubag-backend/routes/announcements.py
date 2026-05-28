from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from config.db import get_db
from utils import send_push_to_all

announcements_bp = Blueprint('announcements', __name__)

# ─── GET / — Members: only non-deleted announcements ──────────────────────────
@announcements_bp.route('/', methods=['GET'])
@jwt_required()
def get_announcements():
    user_id = get_jwt_identity()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT a.*,
                       (ar.member_id IS NOT NULL) AS is_read
                FROM announcements a
                LEFT JOIN announcement_reads ar ON a.id = ar.announcement_id AND ar.member_id = %s
                WHERE a.deleted_at IS NULL
                ORDER BY a.created_at DESC
            """, (user_id,))
            data = cursor.fetchall()
        return jsonify(data), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

# ─── POST /mark-read — Mark specific or all announcements as read ────────────
@announcements_bp.route('/mark-read', methods=['POST'])
@jwt_required()
def mark_read():
    user_id = get_jwt_identity()
    data = request.get_json()
    ann_id = data.get('announcement_id') # single ID or None for "all"

    conn = get_db()
    try:
        with conn.cursor() as cursor:
            if ann_id:
                cursor.execute("""
                    INSERT INTO announcement_reads (member_id, announcement_id)
                    VALUES (%s, %s)
                    ON CONFLICT DO NOTHING
                """, (user_id, ann_id))
            else:
                # Mark all as read
                cursor.execute("""
                    INSERT INTO announcement_reads (member_id, announcement_id)
                    SELECT %s, id FROM announcements WHERE deleted_at IS NULL
                    ON CONFLICT DO NOTHING
                """, (user_id,))
            conn.commit()
        return jsonify({'message': 'Marked as read'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

# ─── POST / — Create new announcement ─────────────────────────────────────────
@announcements_bp.route('/', methods=['POST'])
@jwt_required()
def create_announcement():
    data = request.get_json()
    title = data.get('title')
    body = data.get('body')
    category = data.get('category', 'General')

    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO announcements (title, body, category, posted_by)
                VALUES (%s, %s, %s, %s)
            """, (
                title,
                body,
                category,
                data.get('posted_by', 'CUBAG Unit')
            ))
            conn.commit()

        # Trigger Push Notification
        send_push_to_all(
            title=f"New Announcement: {title}",
            body=body[:100] + ("..." if len(body) > 100 else ""),
            data={'type': 'announcement', 'category': category}
        )

        return jsonify({'message': 'Announcement posted'}), 201
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


# ─── GET /admin/all — Admin: all announcements (including soft-deleted) ────────
@announcements_bp.route('/admin/all', methods=['GET'])
@jwt_required()
def get_all_announcements_admin():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT *, deleted_at IS NOT NULL AS is_deleted
                FROM announcements
                ORDER BY created_at DESC
            """)
            data = cursor.fetchall()
        return jsonify(data), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


# ─── DELETE /<id> — Soft-delete: set deleted_at timestamp ─────────────────────
@announcements_bp.route('/<int:ann_id>', methods=['DELETE'])
@jwt_required()
def soft_delete_announcement(ann_id):
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Ensure the announcement exists
            cursor.execute("SELECT id FROM announcements WHERE id = %s", (ann_id,))
            if not cursor.fetchone():
                return jsonify({'message': 'Announcement not found'}), 404

            # Soft-delete — keep the record, just mark the timestamp
            cursor.execute(
                "UPDATE announcements SET deleted_at = NOW() WHERE id = %s",
                (ann_id,)
            )
            conn.commit()
        return jsonify({'message': 'Announcement archived (soft-deleted)'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


# ─── PATCH /<id>/restore — Restore a soft-deleted announcement ────────────────
@announcements_bp.route('/<int:ann_id>/restore', methods=['PATCH'])
@jwt_required()
def restore_announcement(ann_id):
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "UPDATE announcements SET deleted_at = NULL WHERE id = %s",
                (ann_id,)
            )
            conn.commit()
        return jsonify({'message': 'Announcement restored'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()
