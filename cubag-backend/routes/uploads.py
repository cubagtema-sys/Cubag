import os
import uuid
import requests
from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required

uploads_bp = Blueprint('uploads', __name__)

# ─── Supabase Configuration ──────────────────────────────────────────────────
SUPABASE_URL    = os.getenv('SUPABASE_URL', '').strip().strip('\'"')
SUPABASE_KEY    = os.getenv('SUPABASE_SERVICE_KEY', '').strip().strip('\'"')
SUPABASE_BUCKET = os.getenv('SUPABASE_BUCKET', 'uploads').strip().strip('\'"')

ALLOWED = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'avif'}
MAX_SIZE_MB = 10

def allowed(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED

@uploads_bp.route('/image', methods=['POST'])
@jwt_required()
def upload_image():
    """
    Uploads an image to Supabase Storage and returns the public URL.
    This ensures images are permanent in production (Railway).
    """
    file = request.files.get('image')
    if not file or not file.filename:
        return jsonify({'message': 'No file provided'}), 400

    if not allowed(file.filename):
        return jsonify({'message': 'File type not allowed. Use PNG, JPG, JPEG, GIF, WEBP or AVIF.'}), 400

    # Size check
    file.seek(0, 2)
    size_mb = file.tell() / (1024 * 1024)
    file.seek(0)
    if size_mb > MAX_SIZE_MB:
        return jsonify({'message': f'File too large. Max {MAX_SIZE_MB}MB.'}), 413

    if not SUPABASE_URL or not SUPABASE_KEY:
        return jsonify({'message': 'Cloud storage not configured.'}), 500

    ext = file.filename.rsplit('.', 1)[1].lower()
    safe_name = f"survey_{uuid.uuid4().hex}.{ext}"
    file_bytes = file.read()
    content_type = file.content_type or 'image/jpeg'

    # Upload to Supabase Storage
    storage_url = f"{SUPABASE_URL}/storage/v1/object/{SUPABASE_BUCKET}/{safe_name}"
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": content_type,
        "x-upsert": "true",
    }

    try:
        resp = requests.post(storage_url, data=file_bytes, headers=headers, timeout=30)
        if resp.status_code not in (200, 201):
            return jsonify({'message': f'Cloud upload failed: {resp.text}'}), 500

        public_url = f"{SUPABASE_URL}/storage/v1/object/public/{SUPABASE_BUCKET}/{safe_name}"
        return jsonify({'url': public_url}), 201

    except Exception as e:
        return jsonify({'message': str(e)}), 500


@uploads_bp.route('/debug-supabase', methods=['POST'])
@jwt_required()
def debug_supabase():
    """
    Returns lengths and masked versions of the loaded Supabase credentials
    to diagnose JWS/JWT authorization issues on production.
    """
    url_val = SUPABASE_URL or ''
    key_val = SUPABASE_KEY or ''
    bucket_val = SUPABASE_BUCKET or ''
    
    masked_url = url_val[:12] + "..." + url_val[-5:] if len(url_val) > 17 else url_val
    masked_key = key_val[:10] + "..." + key_val[-10:] if len(key_val) > 20 else key_val
    
    return jsonify({
        'url_length': len(url_val),
        'url_masked': masked_url,
        'key_length': len(key_val),
        'key_masked': masked_key,
        'bucket_name': bucket_val,
        'url_has_quotes': '"' in url_val or "'" in url_val,
        'key_has_quotes': '"' in key_val or "'" in key_val,
    }), 200


@uploads_bp.route('/images/<filename>', methods=['GET'])
def serve_image(filename):
    """Legacy endpoint for local images - redirects to Supabase or returns 404"""
    return jsonify({'message': 'Local storage is disabled in production. Please re-upload your image.'}), 404
