import os
from flask import Flask, send_from_directory
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from dotenv import load_dotenv
from datetime import timedelta
import firebase_admin
from firebase_admin import credentials

from config.db import init_db
from routes.auth import auth_bp
from routes.members import members_bp
from routes.announcements import announcements_bp
from routes.tasks import tasks_bp
from routes.payments import payments_bp
from routes.events_surveys import events_bp, surveys_bp

# Load environment variables
load_dotenv()

# ── Resolve React build path ─────────────────────────────────────────────────
STATIC_DIR = os.path.join(os.path.dirname(__file__), '..', 'cubag-react', 'dist')
# Fallback: if deployed with build output right next to the backend
if not os.path.isdir(STATIC_DIR):
    STATIC_DIR = os.path.join(os.path.dirname(__file__), 'static')
if not os.path.isdir(STATIC_DIR):
    STATIC_DIR = os.path.join(os.path.dirname(__file__), 'dist')

# Create Flask app — serve React build as static files
app = Flask(__name__, static_folder=STATIC_DIR, static_url_path='')
app.url_map.strict_slashes = False

import json

# Initialize Firebase Admin
try:
    firebase_json_env = os.getenv('FIREBASE_CREDENTIALS_JSON')
    cred_path = os.getenv('FIREBASE_CREDENTIALS', 'planning-with-ai-a2368-firebase-adminsdk-fbsvc-3f0078de77.json')
    
    if firebase_json_env:
        # Load directly from environment variable string (for Railway deployment)
        cred_dict = json.loads(firebase_json_env)
        cred = credentials.Certificate(cred_dict)
        firebase_admin.initialize_app(cred)
        print("Firebase Admin initialized successfully from ENV.")
    elif os.path.exists(cred_path):
        # Load from file (for local development)
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        print("Firebase Admin initialized successfully from FILE.")
    else:
        print(f"Firebase credentials not found. Push notifications will not work.")
except Exception as e:
    print(f"Failed to initialize Firebase Admin: {e}")

# Config
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'cubag-secret')
app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY', 'cubag-jwt-secret')
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(seconds=int(os.getenv('JWT_ACCESS_TOKEN_EXPIRES', 604800)))

# Extensions
CORS(app, origins=[os.getenv('CLIENT_URL', 'https://cub-production.up.railway.app'), 'https://cub-production.up.railway.app', 'http://localhost:5173', 'http://localhost:5174', 'capacitor://localhost', 'http://localhost', 'https://localhost'])
JWTManager(app)

# Initialize SocketIO
from socket_instance import socketio
socketio.init_app(app)

# Register blueprints (all under /api)
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

app.register_blueprint(admin_bp,         url_prefix='/api/admin')
app.register_blueprint(schedules_bp,     url_prefix='/api/schedules')
app.register_blueprint(messages_bp,      url_prefix='/api/messages')
app.register_blueprint(tickets_bp,       url_prefix='/api/tickets')
app.register_blueprint(settings_bp,      url_prefix='/api/settings')
app.register_blueprint(intelligence_bp,  url_prefix='/api/intelligence')

from routes.uploads import uploads_bp
from routes.public_materials import public_materials_bp
from routes.news import news_bp
app.register_blueprint(uploads_bp,          url_prefix='/api/uploads')
app.register_blueprint(public_materials_bp, url_prefix='/api/public-materials')
app.register_blueprint(news_bp,             url_prefix='/api/news')

@app.route('/api/health', methods=['GET'])
def health():
    return {'status': 'CUBAG API is running'}, 200


# ── SPA catch-all: serve React's index.html for any non-API route ─────────
@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def serve_spa(path):
    # If the path matches an actual file in the build (JS, CSS, images), serve it
    full_path = os.path.join(app.static_folder, path)
    if path and os.path.isfile(full_path):
        return send_from_directory(app.static_folder, path)
    # Otherwise serve index.html so React Router handles the route
    index_path = os.path.join(app.static_folder, 'index.html')
    if os.path.isfile(index_path):
        return send_from_directory(app.static_folder, 'index.html')
    # No build found — return API info
    return {'message': 'CUBAG API is running. Frontend build not found at this location.'}, 200


# Run DB migrations on startup (works with both gunicorn and direct python)
try:
    init_db()
except Exception as e:
    print(f"[CRITICAL] Failed to initialize database: {e}")

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5001))
    print(f"[*] CUBAG Flask API running on http://0.0.0.0:{port}")
    # Use socketio.run instead of app.run for real-time support
    socketio.run(app, host='0.0.0.0', port=port, debug=True, allow_unsafe_werkzeug=True)

