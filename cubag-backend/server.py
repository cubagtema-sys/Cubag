import eventlet
eventlet.monkey_patch()

import os
import json
import logging
import sys
import time
from flask import g
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
from flask_jwt_extended import JWTManager, get_jwt_identity, verify_jwt_in_request
from dotenv import load_dotenv
from datetime import timedelta
import firebase_admin
from firebase_admin import credentials
from utils import log_admin_action

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

logger.info("Starting CUBAG Production Backend...")
logger.info(f"Python {sys.version}")
logger.info(f"PORT env = {os.getenv('PORT', 'NOT SET')}")
logger.info(f"DB_HOST env = {'SET' if os.getenv('DB_HOST') or os.getenv('DATABASE_URL') else 'NOT SET'}")
logger.info(f"SECRET_KEY env = {'SET' if os.getenv('SECRET_KEY') else 'NOT SET'}")
logger.info(f"JWT_SECRET_KEY env = {'SET' if os.getenv('JWT_SECRET_KEY') else 'NOT SET'}")

from config.db import get_db, init_db
from routes.auth import auth_bp
from routes.members import members_bp
from routes.announcements import announcements_bp
from routes.tasks import tasks_bp
from routes.payments import payments_bp
from routes.events_surveys import events_bp, surveys_bp
from routes.sub_admins import sub_admins_bp

# Load environment variables
load_dotenv()

# ── Resolve static file path (Flutter web build or fallback) ─────────────────
STATIC_DIR = os.path.join(os.path.dirname(__file__), 'static')
if not os.path.isdir(STATIC_DIR):
    STATIC_DIR = os.path.join(os.path.dirname(__file__), 'dist')

# Create Flask app
app = Flask(__name__, static_folder=STATIC_DIR, static_url_path='')
app.url_map.strict_slashes = False

# Initialize Firebase Admin
try:
    firebase_json_env = os.getenv('FIREBASE_CREDENTIALS_JSON') or os.getenv('FIREBASE_SERVICE_ACCOUNT')
    cred_path = os.getenv('FIREBASE_CREDENTIALS', 'firebase-key.json')  # Updated to match project file
    
    if firebase_json_env:
        try:
            cred_dict = json.loads(firebase_json_env)
            cred = credentials.Certificate(cred_dict)
            firebase_admin.initialize_app(cred)
            logger.info("Firebase Admin initialized from ENV.")
        except Exception as e:
            logger.error(f"Error initializing Firebase from ENV: {e}")
    elif os.path.exists(cred_path):
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        logger.info(f"Firebase Admin initialized from FILE: {cred_path}")
    else:
        logger.warning("Firebase credentials not found. Push notifications will be disabled.")
except Exception as e:
    logger.error(f"Failed to initialize Firebase Admin: {e}")

# Config
# SECURITY: In production, app will fail to start if these secrets are not provided.
_DEFAULT_SECRET = 'cubag-secret-placeholder-insecure'
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', _DEFAULT_SECRET)
app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY', _DEFAULT_SECRET)
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(seconds=int(os.getenv('JWT_ACCESS_TOKEN_EXPIRES', 604800)))

# PRODUCTION GUARD: Ensure we are not using default secrets in non-debug mode
IS_DEBUG = os.getenv('FLASK_DEBUG', 'false').lower() == 'true'
if not IS_DEBUG:
    if app.config['SECRET_KEY'] == _DEFAULT_SECRET or app.config['JWT_SECRET_KEY'] == _DEFAULT_SECRET:
        logger.critical("[SECURITY] PRODUCTION FAILURE: SECRET_KEY or JWT_SECRET_KEY is missing or insecure! Set these env vars before deploying.")
        logger.critical("[SECURITY] Set SECRET_KEY and JWT_SECRET_KEY in your Railway environment variables.")
        # Log all env var names (not values) for debugging
        logger.critical(f"[SECURITY] Available env vars: {list(os.environ.keys())}")
        # Fail fast in production to avoid running with insecure defaults
        sys.exit(1)

# Extensions — restrict CORS to explicitly allowed origins
_RAW_ORIGINS = os.getenv(
    'CORS_ALLOWED_ORIGINS',
    'https://cubag-backend.onrender.com,https://cubag-production.up.railway.app,http://localhost:8080,http://127.0.0.1:8080'
)
# Mobile apps (Android/iOS APK/IPA) send requests with no Origin header (null origin).
# We must include "*" OR handle the null case to allow native apps to reach the API.
_CORS_ORIGINS = [o.strip() for o in _RAW_ORIGINS.split(',') if o.strip()]

CORS(
    app,
    origins="*",          # Allow ALL origins — mobile APKs send null/no Origin
    supports_credentials=False,   # Must be False when origins="*"
    allow_headers=["Authorization", "Content-Type", "Accept"],
    methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
)
JWTManager(app)

def _is_admin_api_path(path):
    return path.startswith('/api/admin') or (
        path.startswith('/api/') and '/admin/' in path
    )

@app.before_request
def require_admin_role_for_admin_api():
    if request.method == 'OPTIONS':
        return None

    # 1. Automatic Admin Activity Logging
    if request.path.startswith('/api/admin/') and request.method in ('POST', 'PUT', 'DELETE'):
        try:
            verify_jwt_in_request()
            admin_id = get_jwt_identity()
            if admin_id:
                action_desc = f"{request.method} {request.path.replace('/api/admin/', '')}"
                # ── Scrub sensitive fields before logging ─────────────────────
                import json as _json
                _SENSITIVE = {'password', 'password_hash', 'current_password',
                              'new_password', 'token', 'secret', 'api_key', 'key'}
                try:
                    _body = _json.loads(request.get_data(as_text=True) or '{}')
                    if isinstance(_body, dict):
                        _body = {k: ('***' if k.lower() in _SENSITIVE else v)
                                 for k, v in _body.items()}
                    _payload_log = _json.dumps(_body)[:300]
                except Exception:
                    _payload_log = '[unreadable body]'
                log_admin_action(admin_id, 'Admin Action', 'system', None, action_desc,
                                 f"Payload: {_payload_log}")
        except Exception as e:
            logger.exception("Failed to log admin action: %s", e)

    # 2. Access Control for Admin Routes
    if not _is_admin_api_path(request.path):
        return None

    try:
        from flask_jwt_extended import get_jwt
        verify_jwt_in_request()
        claims = get_jwt()
        role = claims.get('role')

        if role not in ('admin', 'sub_admin'):
            return jsonify({'message': 'Admin access required'}), 403

    except Exception:
        return jsonify({'message': 'Missing or invalid authorization token'}), 401

    return None


@app.before_request
def enforce_account_status():
    """
    CROSS-04: Check live member status on every authenticated API call.
    This makes account suspension/deactivation take effect immediately
    without needing a JWT blocklist or Redis — the DB is the source of truth.
    Skips: OPTIONS preflight, public auth endpoints, static files.
    """
    if request.method == 'OPTIONS':
        return None

    # Only check protected API routes (skip auth, public, static)
    _OPEN_PREFIXES = ('/api/auth/', '/static/', '/#')
    if any(request.path.startswith(p) for p in _OPEN_PREFIXES):
        return None
    if not request.path.startswith('/api/'):
        return None

    try:
        verify_jwt_in_request(optional=True)
        member_id = get_jwt_identity()
        if not member_id:
            return None  # unauthenticated request — let route handle it

        conn = get_db()
        try:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT status FROM members WHERE id = %s",
                    (member_id,)
                )
                row = cursor.fetchone()
        finally:
            conn.close()

        if not row:
            return None  # member deleted — JWT will naturally fail on next call

        status = str(row.get('status') or '').lower()
        if status == 'suspended':
            return jsonify({
                'message': 'Your account has been suspended. Please contact the CUBAG Secretariat.'
            }), 403
        if status == 'inactive':
            return jsonify({
                'message': 'Your account is inactive. Please contact the CUBAG Secretariat.'
            }), 403

    except Exception:
        pass  # Don't block requests if the status check itself fails

    return None



@app.before_request
def _start_request_timer():
    try:
        g._start_time = time.time()
    except Exception:
        pass


@app.after_request
def _log_request_time(response):
    try:
        start = getattr(g, '_start_time', None)
        if start:
            duration = time.time() - start
            logger.info("%s %s completed in %.3fs", request.method, request.path, duration)
            response.headers['X-Response-Time'] = f"{duration:.3f}s"
    except Exception:
        pass
    return response

# Initialize SocketIO
from socket_instance import socketio
socketio.init_app(app)

# Initialize Background Workers (Beta)
try:
    logger.info("[Init] Starting background workers...")
    from ais_stream import ais_manager
    ais_manager.start()
    logger.info("[Init] AIS manager started.")

    from routes.news import start_news_worker
    start_news_worker()
    logger.info("[Init] News worker started.")

    from jobs import start_scheduler
    start_scheduler()

    @socketio.on('track_vessel')
    def handle_track_vessel(data):
        mmsi = data.get('mmsi')
        logger.info(f"[AIS] Search request for MMSI: {mmsi}")
        if mmsi:
            ais_manager.add_track(mmsi)
    logger.info("[Init] All background workers started successfully.")
except Exception as e:
    logger.error(f"[Init] Failed to start background workers: {e}", exc_info=True)

# Register blueprints
app.register_blueprint(auth_bp,          url_prefix='/api/auth')
app.register_blueprint(members_bp,       url_prefix='/api/members')
app.register_blueprint(announcements_bp, url_prefix='/api/announcements')
app.register_blueprint(tasks_bp,         url_prefix='/api/tasks')
app.register_blueprint(payments_bp,      url_prefix='/api/payments')
app.register_blueprint(events_bp,        url_prefix='/api/events')
app.register_blueprint(surveys_bp,       url_prefix='/api/surveys')

from routes.admin import admin_bp
from routes.schedules import schedules_bp
from routes.messages import messages_bp
from routes.tickets import tickets_bp
from routes.settings import settings_bp
from routes.intelligence import intelligence_bp
from routes.uploads import uploads_bp
from routes.news import news_bp
from routes.compliance_settings import compliance_settings_bp

app.register_blueprint(admin_bp,         url_prefix='/api/admin')
app.register_blueprint(schedules_bp,     url_prefix='/api/schedules')
app.register_blueprint(messages_bp,      url_prefix='/api/messages')
app.register_blueprint(tickets_bp,       url_prefix='/api/tickets')
app.register_blueprint(settings_bp,      url_prefix='/api/settings')
app.register_blueprint(intelligence_bp,  url_prefix='/api/intelligence')
app.register_blueprint(uploads_bp,          url_prefix='/api/uploads')
app.register_blueprint(news_bp,             url_prefix='/api/news')
app.register_blueprint(sub_admins_bp,       url_prefix='/api/sub-admins')
app.register_blueprint(compliance_settings_bp, url_prefix='/api/compliance-settings')

@app.route('/api/ping', methods=['GET'])
def ping():
    return 'pong', 200

@app.route('/api/health', methods=['GET'])
def health():
    return {'status': 'CUBAG API is running'}, 200

@app.route('/api/vessels', methods=['GET'])
def get_vessels():
    try:
        from ais_stream import ais_manager
        with ais_manager.lock:
            vessels = list(ais_manager.active_vessels.values())
        # B-31 fix: wrap in 'items' for consistent Flutter data service parsing
        return jsonify({'items': vessels, 'total': len(vessels)}), 200
    except Exception as e:
        logger.error(f"Error in /api/vessels: {e}")
        return jsonify({'items': [], 'total': 0}), 200


@app.route('/api/vessels/registry', methods=['GET'])
def get_vessel_registry():
    """
    Known vessel registry for Gulf of Guinea shipping lanes.
    Used by Flutter for autocomplete suggestions when the live AIS stream
    doesn't yet have a vessel. Centralised here so it can be updated without
    a new app release.
    """
    registry = [
        {'name': 'Maersk Charleston',   'mmsi': '563297800', 'imo': '9454199', 'flag': 'Singapore',       'type': 'Container Ship',             'length': '266', 'width': '37', 'callsign': '9V8129', 'departure_port': 'Tema, Ghana', 'atd': '2026-06-08 14:00 UTC', 'destination': 'Lome, Togo', 'eta': '2026-06-10 08:00 UTC'},
        {'name': 'Maersk Cubango',       'mmsi': '477174700', 'imo': '9513361', 'flag': 'Hong Kong',        'type': 'Container Ship',             'length': '254', 'width': '32', 'callsign': 'VRJZ8', 'departure_port': 'Takoradi, Ghana', 'atd': '2026-06-09 06:30 UTC', 'destination': 'Tema, Ghana', 'eta': '2026-06-09 20:00 UTC'},
        {'name': 'Maersk Tema',          'mmsi': '477353900', 'imo': '9624275', 'flag': 'Hong Kong',        'type': 'Container Ship',             'length': '255', 'width': '37', 'callsign': 'VRNX6', 'departure_port': 'Tema, Ghana', 'atd': '2026-06-07 10:00 UTC', 'destination': 'Abidjan, Ivory Coast', 'eta': '2026-06-11 12:00 UTC'},
        {'name': 'MSC Johannesburg V',   'mmsi': '636024423', 'imo': '9308637', 'flag': 'Liberia',          'type': 'Container Ship',             'length': '275', 'width': '40', 'callsign': 'A8IF9', 'departure_port': 'Durban, South Africa', 'atd': '2026-06-02 08:00 UTC', 'destination': 'Tema, Ghana', 'eta': '2026-06-12 18:00 UTC'},
        {'name': 'MSC Assunta III',      'mmsi': '636023923', 'imo': '9211028', 'flag': 'Liberia',          'type': 'Container Ship',             'length': '259', 'width': '32', 'callsign': 'A8GX6', 'departure_port': 'Pointe Noire, Congo', 'atd': '2026-06-05 16:00 UTC', 'destination': 'Tema, Ghana', 'eta': '2026-06-10 14:00 UTC'},
        {'name': 'MSC Aniello',          'mmsi': '372741000', 'imo': '9203928', 'flag': 'Panama',           'type': 'Container Ship',             'length': '259', 'width': '32', 'callsign': '3FYQ9', 'departure_port': 'Lagos, Nigeria', 'atd': '2026-06-08 12:00 UTC', 'destination': 'Tema, Ghana', 'eta': '2026-06-09 16:00 UTC'},
        {'name': 'MSC Pamela',           'mmsi': '636022359', 'imo': '9290531', 'flag': 'Liberia',          'type': 'Container Ship',             'length': '337', 'width': '46', 'callsign': 'A8HR2', 'departure_port': 'Tema, Ghana', 'atd': '2026-06-09 08:00 UTC', 'destination': 'Algeciras, Spain', 'eta': '2026-06-16 10:00 UTC'},
        {'name': 'One Presence',         'mmsi': '563290200', 'imo': '9347504', 'flag': 'Singapore',        'type': 'Container Ship',             'length': '300', 'width': '40', 'callsign': '9V7182', 'departure_port': 'Singapore, Singapore', 'atd': '2026-05-20 00:00 UTC', 'destination': 'Tema, Ghana', 'eta': '2026-06-15 06:00 UTC'},
        {'name': 'Grande Argentina',     'mmsi': '215949000', 'imo': '9220976', 'flag': 'Malta',            'type': 'Ro-Ro/Cargo',                'length': '214', 'width': '32', 'callsign': '9HNM6', 'departure_port': 'Antwerp, Belgium', 'atd': '2026-05-28 14:00 UTC', 'destination': 'Tema, Ghana', 'eta': '2026-06-14 08:00 UTC'},
        {'name': 'Grande Tema',          'mmsi': '247343700', 'imo': '9672105', 'flag': 'Italy',            'type': 'Ro-Ro/Cargo',                'length': '236', 'width': '36', 'callsign': 'IBDR', 'departure_port': 'Tema, Ghana', 'atd': '2026-06-09 12:00 UTC', 'destination': 'Lagos, Nigeria', 'eta': '2026-06-10 18:00 UTC'},
        {'name': 'Grande Dakar',         'mmsi': '247341900', 'imo': '9680724', 'flag': 'Italy',            'type': 'Ro-Ro/Container Carrier',    'length': '236', 'width': '36', 'callsign': 'IBDK', 'departure_port': 'Dakar, Senegal', 'atd': '2026-06-06 10:00 UTC', 'destination': 'Tema, Ghana', 'eta': '2026-06-11 06:00 UTC'},
        {'name': 'African Wind',         'mmsi': '305537000', 'imo': '9372107', 'flag': 'Antigua Barbuda',  'type': 'General Cargo',              'length': '132', 'width': '16', 'callsign': 'V2CG9', 'departure_port': 'Tema, Ghana', 'atd': '2026-06-08 18:00 UTC', 'destination': 'Takoradi, Ghana', 'eta': '2026-06-09 08:00 UTC'},
        {'name': 'Oslo Trader',          'mmsi': '636014459', 'imo': '9239082', 'flag': 'Liberia',          'type': 'Container Ship',             'length': '200', 'width': '30', 'callsign': 'A8HF8', 'departure_port': 'Abidjan, Ivory Coast', 'atd': '2026-06-09 04:00 UTC', 'destination': 'Tema, Ghana', 'eta': '2026-06-10 10:00 UTC'},
    ]
    return jsonify(registry), 200


@app.route('/api/analytics/telemetry', methods=['POST'])
def telemetry():
    try:
        # Just ack the telemetry for now to prevent 405 errors
        return jsonify({"status": "ok"}), 200
    except Exception as e:
        logger.error(f"Error in telemetry: {e}")
        return jsonify({"status": "error"}), 500

@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def serve_spa(path):
    # Check if the requested path is a real file (like an image or JS)
    if app.static_folder:
        full_path = os.path.join(app.static_folder, path)
        if path and os.path.isfile(full_path):
            return send_from_directory(app.static_folder, path)

        # Otherwise, always serve index.html to let Flutter web router handle the URL
        index_path = os.path.join(app.static_folder, 'index.html')
        if os.path.isfile(index_path):
            return send_from_directory(app.static_folder, 'index.html')

    # Fallback if no static files exist
    return jsonify({'status': 'CUBAG API is running', 'message': 'No frontend build found. Use /api/health for API status.'}), 200

# Initialize DB
try:
    logger.info("[Init] Initializing database...")
    init_db()
    logger.info("[Init] Database initialized successfully.")
except Exception as e:
    logger.error(f"DB init failed (non-fatal): {e}", exc_info=True)

logger.info("[Init] CUBAG Backend fully loaded and ready to accept requests.")

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5001))
    logger.info(f"Running on port {port}")
    socketio.run(app, host='0.0.0.0', port=port, debug=False)
