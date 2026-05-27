from flask_socketio import SocketIO

# We'll initialize it without the app first
socketio = SocketIO(cors_allowed_origins="*", async_mode='eventlet')
