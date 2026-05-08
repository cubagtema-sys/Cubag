import os
import uuid
from flask import Blueprint, request, jsonify, send_from_directory
from flask_jwt_extended import jwt_required
from werkzeug.utils import secure_filename
from config.db import get_db

public_materials_bp = Blueprint('public_materials', __name__)

UPLOAD_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'uploads', 'materials')
ALLOWED_EXTENSIONS = {'pdf', 'doc', 'docx', 'xls', 'xlsx', 'png', 'jpg', 'jpeg', 'webp'}
MAX_SIZE_MB = 30

os.makedirs(UPLOAD_DIR, exist_ok=True)


def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


# ─── GET /public — Publicly accessible material list ──────────────────────────
@public_materials_bp.route('/public', methods=['GET'])
def get_public_materials():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT id, title, category, file_type, file_url, created_at
                FROM public_materials
                ORDER BY created_at DESC
            """)
            data = cursor.fetchall()
        return jsonify(data), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


# ─── POST / — Upload new material (admin only) ────────────────────────────────
@public_materials_bp.route('/', methods=['POST'])
@jwt_required()
def upload_material():
    if 'material' not in request.files:
        return jsonify({'message': 'No file provided'}), 400

    file = request.files['material']
    title = request.form.get('title', '').strip()
    category = request.form.get('category', 'Other').strip()

    if not file or not file.filename:
        return jsonify({'message': 'No file selected'}), 400

    if not allowed_file(file.filename):
        return jsonify({'message': 'File type not allowed'}), 400

    # Size check
    file.seek(0, 2)
    size_mb = file.tell() / (1024 * 1024)
    file.seek(0)
    if size_mb > MAX_SIZE_MB:
        return jsonify({'message': f'File too large. Max {MAX_SIZE_MB}MB.'}), 413

    ext = file.filename.rsplit('.', 1)[1].lower()
    safe_name = f"{uuid.uuid4().hex}.{ext}"
    file.save(os.path.join(UPLOAD_DIR, safe_name))

    file_url = f"/api/public-materials/files/{safe_name}"

    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO public_materials (title, category, file_type, file_url)
                VALUES (%s, %s, %s, %s)
                RETURNING id
            """, (title, category, ext, file_url))
            conn.commit()
        return jsonify({'message': 'Material published successfully'}), 201
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


# ─── GET /files/<filename> — Serve file download ──────────────────────────────
@public_materials_bp.route('/files/<filename>', methods=['GET'])
def serve_material(filename):
    """Public endpoint to serve uploaded materials for download."""
    return send_from_directory(UPLOAD_DIR, filename, as_attachment=True)


# ─── DELETE /<id> — Remove material (admin only) ─────────────────────────────
@public_materials_bp.route('/<int:material_id>', methods=['DELETE'])
@jwt_required()
def delete_material(material_id):
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT file_url FROM public_materials WHERE id = %s", (material_id,))
            row = cursor.fetchone()
            if not row:
                return jsonify({'message': 'Not found'}), 404

            # Delete the physical file
            if row['file_url']:
                fname = row['file_url'].split('/')[-1]
                fpath = os.path.join(UPLOAD_DIR, fname)
                if os.path.exists(fpath):
                    os.remove(fpath)

            cursor.execute("DELETE FROM public_materials WHERE id = %s", (material_id,))
            conn.commit()
        return jsonify({'message': 'Material removed'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()
