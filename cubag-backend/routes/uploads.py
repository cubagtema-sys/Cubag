import os
import uuid
from flask import Blueprint, jsonify, request, send_from_directory
from flask_jwt_extended import jwt_required
from werkzeug.utils import secure_filename

uploads_bp = Blueprint('uploads', __name__)

UPLOAD_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'uploads', 'images')
ALLOWED = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'avif'}
MAX_SIZE_MB = 5

os.makedirs(UPLOAD_DIR, exist_ok=True)


def allowed(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED


@uploads_bp.route('/image', methods=['POST'])
@jwt_required()
def upload_image():
    """
    Accepts a multipart/form-data file upload under the key 'image'.
    Returns { url: '/api/uploads/images/<filename>' }
    """
    file = request.files.get('image')
    if not file or not file.filename:
        return jsonify({'message': 'No file provided'}), 400

    if not allowed(file.filename):
        return jsonify({'message': 'File type not allowed. Use PNG, JPG, JPEG, GIF, WEBP or AVIF.'}), 400

    # Check file size before saving
    file.seek(0, 2)          # Seek to end
    size_mb = file.tell() / (1024 * 1024)
    file.seek(0)             # Reset
    if size_mb > MAX_SIZE_MB:
        return jsonify({'message': f'File too large. Max {MAX_SIZE_MB}MB.'}), 413

    ext = file.filename.rsplit('.', 1)[1].lower()
    safe_name = f"{uuid.uuid4().hex}.{ext}"
    file.save(os.path.join(UPLOAD_DIR, safe_name))

    return jsonify({'url': f'/api/uploads/images/{safe_name}'}), 201


@uploads_bp.route('/images/<filename>', methods=['GET'])
def serve_image(filename):
    """Public endpoint to serve uploaded images."""
    return send_from_directory(UPLOAD_DIR, filename)
