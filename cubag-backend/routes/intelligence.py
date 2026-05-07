import os
import json
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity

intelligence_bp = Blueprint('intelligence', __name__)

DATA_FILE = os.path.join(os.path.dirname(__file__), '..', 'data', 'intelligence.json')

DEFAULT_DATA = {
    "ports": [
        {"port": "Tema Port", "status": "High (4 Days)", "color": "#ef4444"},
        {"port": "Takoradi Port", "status": "Low (1 Day)", "color": "#10b981"},
        {"port": "Lagos, Apapa", "status": "Severe (8+ Days)", "color": "#ef4444"},
        {"port": "Abidjan Port", "status": "Moderate (2 Days)", "color": "#f59e0b"}
    ],
    "bunkers": [
        {"loc": "Singapore", "price": "$630.50", "change": "-1.2%", "up": False},
        {"loc": "Rotterdam", "price": "$595.00", "change": "+0.8%", "up": True},
        {"loc": "Houston", "price": "$612.25", "change": "+0.4%", "up": True}
    ],
    "alerts": [
        {"id": 1, "title": "Red Sea Shipping Disruptions", "detail": "Major shipping lines continue to reroute vessels around the Cape of Good Hope, adding 10-14 days to transit.", "severity": "high"},
        {"id": 2, "title": "Panama Canal Transit Limits", "detail": "Water levels stabilizing; daily transit limits remain in effect causing minor delays for East Coast-bound cargo.", "severity": "medium"}
    ]
}

def load_data():
    if not os.path.exists(DATA_FILE):
        os.makedirs(os.path.dirname(DATA_FILE), exist_ok=True)
        with open(DATA_FILE, 'w') as f:
            json.dump(DEFAULT_DATA, f)
        return DEFAULT_DATA
    
    with open(DATA_FILE, 'r') as f:
        return json.load(f)

def save_data(data):
    os.makedirs(os.path.dirname(DATA_FILE), exist_ok=True)
    with open(DATA_FILE, 'w') as f:
        json.dump(data, f)

@intelligence_bp.route('/', methods=['GET'])
def get_intelligence():
    return jsonify(load_data()), 200

@intelligence_bp.route('/', methods=['POST'])
@jwt_required()
def update_intelligence():
    # In a real app, check if user is admin
    # current_user = get_jwt_identity()
    
    data = request.json
    save_data(data)
    return jsonify({"message": "Intelligence data updated successfully"}), 200
