import os
import uuid
import requests as http_req
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required
from config.db import get_db

public_materials_bp = Blueprint('public_materials', __name__)

ALLOWED_EXTENSIONS = {'pdf', 'doc', 'docx', 'xls', 'xlsx', 'png', 'jpg', 'jpeg', 'webp'}
MAX_SIZE_MB = 30

# ─── Supabase Storage config ──────────────────────────────────────────────────
SUPABASE_URL     = os.getenv('SUPABASE_URL', '')          # https://<ref>.supabase.co
SUPABASE_KEY     = os.getenv('SUPABASE_SERVICE_KEY', '')  # service_role key
STORAGE_BUCKET   = os.getenv('SUPABASE_BUCKET', 'public-materials')


def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


def upload_to_supabase(file_bytes, filename, content_type):
    """
    Upload bytes to Supabase Storage.
    Returns the public URL on success, raises on failure.
    """
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise RuntimeError("SUPABASE_URL / SUPABASE_SERVICE_KEY not configured")

    storage_url = f"{SUPABASE_URL}/storage/v1/object/{STORAGE_BUCKET}/{filename}"
    headers = {
        "apikey":        SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type":  content_type,
        "x-upsert":      "true",
    }
    resp = http_req.post(storage_url, data=file_bytes, headers=headers, timeout=30)
    if resp.status_code not in (200, 201):
        raise RuntimeError(f"Supabase upload failed: {resp.status_code} {resp.text}")

    # Build public URL
    public_url = f"{SUPABASE_URL}/storage/v1/object/public/{STORAGE_BUCKET}/{filename}"
    return public_url


def delete_from_supabase(filename):
    """Delete a file from Supabase Storage. Silently ignores errors."""
    if not SUPABASE_URL or not SUPABASE_KEY:
        return
    try:
        storage_url = f"{SUPABASE_URL}/storage/v1/object/{STORAGE_BUCKET}/{filename}"
        headers = {
            "apikey":        SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}",
        }
        http_req.delete(storage_url, headers=headers, timeout=10)
    except Exception as e:
        print(f"[public_materials] delete_from_supabase error: {e}")


# ─── GET /public — Publicly accessible material list ─────────────────────────
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


# ─── POST / — Upload new material (admin only) ───────────────────────────────
@public_materials_bp.route('/', methods=['POST'])
@jwt_required()
def upload_material():
    if 'material' not in request.files:
        return jsonify({'message': 'No file provided'}), 400

    file      = request.files['material']
    title     = request.form.get('title', '').strip()
    category  = request.form.get('category', 'Other').strip()

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

    ext          = file.filename.rsplit('.', 1)[1].lower()
    safe_name    = f"{uuid.uuid4().hex}.{ext}"
    file_bytes   = file.read()
    content_type = file.content_type or 'application/octet-stream'

    try:
        public_url = upload_to_supabase(file_bytes, safe_name, content_type)
    except Exception as e:
        return jsonify({'message': f'Storage error: {str(e)}'}), 500

    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO public_materials (title, category, file_type, file_url)
                VALUES (%s, %s, %s, %s)
                RETURNING id
            """, (title, category, ext, public_url))
            conn.commit()
        return jsonify({'message': 'Material published successfully'}), 201
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


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

            # Try to remove from Supabase Storage too
            file_url = row['file_url'] or ''
            if file_url:
                fname = file_url.split('/')[-1]
                delete_from_supabase(fname)

            cursor.execute("DELETE FROM public_materials WHERE id = %s", (material_id,))
            conn.commit()
        return jsonify({'message': 'Material removed'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()
