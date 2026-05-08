import os
from flask import Flask
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from dotenv import load_dotenv
from datetime import timedelta

from config.db import init_db
from routes.auth import auth_bp
from routes.members import members_bp
from routes.announcements import announcements_bp
from routes.tasks import tasks_bp
from routes.payments import payments_bp
from routes.events_surveys import events_bp, surveys_bp

# Load environment variables
load_dotenv()

# Create Flask app
app = Flask(__name__)
app.url_map.strict_slashes = False

# Config
app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'cubag-secret')
app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY', 'cubag-jwt-secret')
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(seconds=int(os.getenv('JWT_ACCESS_TOKEN_EXPIRES', 604800)))

# Extensions
CORS(app, origins=[os.getenv('CLIENT_URL', 'http://localhost:5173'), 'http://localhost:5174', 'capacitor://localhost', 'http://localhost', 'https://localhost'])
JWTManager(app)

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
app.register_blueprint(uploads_bp,          url_prefix='/api/uploads')
app.register_blueprint(public_materials_bp, url_prefix='/api/public-materials')

@app.route('/api/health', methods=['GET'])
def health():
    return {'status': 'CUBAG API is running'}, 200

# Run DB migrations on startup (works with both gunicorn and direct python)
init_db()

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5001))
    print(f"[*] CUBAG Flask API running on http://localhost:{port}")
    app.run(host='0.0.0.0', port=port, debug=True)
