import os
import json
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required
from config.db import get_db

intelligence_bp = Blueprint('intelligence', __name__)

DEFAULT_DATA = {
    "ports": [
        {"port": "Tema Port",     "status": "High (4 Days)",    "color": "#ef4444"},
        {"port": "Takoradi Port", "status": "Low (1 Day)",      "color": "#10b981"},
        {"port": "Lagos, Apapa",  "status": "Severe (8+ Days)", "color": "#ef4444"},
        {"port": "Abidjan Port",  "status": "Moderate (2 Days)","color": "#f59e0b"}
    ],
    "bunkers": [
        {"loc": "Singapore", "price": "$630.50", "change": "-1.2%", "up": False},
        {"loc": "Rotterdam", "price": "$595.00", "change": "+0.8%", "up": True},
        {"loc": "Houston",   "price": "$612.25", "change": "+0.4%", "up": True}
    ],
    "alerts": [
        {"id": 1, "title": "Red Sea Shipping Disruptions",
         "detail": "Major shipping lines continue to reroute vessels around the Cape of Good Hope, adding 10-14 days to transit.",
         "severity": "high"},
        {"id": 2, "title": "Panama Canal Transit Limits",
         "detail": "Water levels stabilizing; daily transit limits remain in effect causing minor delays for East Coast-bound cargo.",
         "severity": "medium"}
    ]
}

SETTING_KEY = 'intelligence_data'


def load_data():
    """Load from DB settings table, fall back to defaults."""
    try:
        conn = get_db()
        try:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT value FROM settings WHERE key = %s",
                    (SETTING_KEY,)
                )
                row = cursor.fetchone()
            if row:
                return json.loads(row['value'])
        finally:
            conn.close()
    except Exception as e:
        print(f"[intelligence] DB load failed: {e}")
    return DEFAULT_DATA


def save_data(data):
    """Upsert intelligence data into DB settings table."""
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO settings (key, value)
                VALUES (%s, %s)
                ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value
            """, (SETTING_KEY, json.dumps(data)))
            conn.commit()
    finally:
        conn.close()


@intelligence_bp.route('/', methods=['GET'])
def get_intelligence():
    return jsonify(load_data()), 200


@intelligence_bp.route('/', methods=['POST'])
@jwt_required()
def update_intelligence():
    data = request.json
    save_data(data)
    return jsonify({"message": "Intelligence data updated successfully"}), 200
