from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from config.db import get_db

messages_bp = Blueprint('messages', __name__)

@messages_bp.route('/conversations', methods=['GET'])
@jwt_required()
def get_conversations():
    user_id = get_jwt_identity()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT DISTINCT
                    CASE
                        WHEN sender_id = %s THEN receiver_id
                        ELSE sender_id
                    END AS other_id
                FROM messages
                WHERE sender_id = %s OR receiver_id = %s
            """, (user_id, user_id, user_id))
            
            other_ids = [r['other_id'] for r in cursor.fetchall()]
            
            conversations = []
            for other_id in other_ids:
                cursor.execute("SELECT id, name, company FROM members WHERE id = %s", (other_id,))
                other_user = cursor.fetchone()
                
                if other_user:
                    cursor.execute("""
                        SELECT message, created_at, sender_id
                        FROM messages
                        WHERE (sender_id = %s AND receiver_id = %s)
                           OR (sender_id = %s AND receiver_id = %s)
                        ORDER BY created_at DESC LIMIT 1
                    """, (user_id, other_id, other_id, user_id))
                    last_msg = cursor.fetchone()
                    
                    initials = ''.join([n[0] for n in (other_user['name'] or 'U').split()]).upper()[:2]
                    
                    time_str = last_msg['created_at'].strftime('%b %d, %I:%M %p') if last_msg else ''
                    
                    conversations.append({
                        'id': other_user['id'],
                        'name': other_user['name'],
                        'company': other_user['company'] or 'Member',
                        'initials': initials,
                        'lastMsg': last_msg['message'] if last_msg else '',
                        'time': time_str,
                        'unread': 0
                    })
            
            return jsonify({'items': conversations, 'total': len(conversations)}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@messages_bp.route('/<int:other_id>', methods=['GET'])
@jwt_required()
def get_messages(other_id):
    user_id = get_jwt_identity()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT id, sender_id, receiver_id, message, created_at
                FROM messages
                WHERE (sender_id = %s AND receiver_id = %s)
                   OR (sender_id = %s AND receiver_id = %s)
                ORDER BY created_at ASC
            """, (user_id, other_id, other_id, user_id))
            msgs = cursor.fetchall()
            
            formatted = []
            for m in msgs:
                formatted.append({
                    'id': m['id'],
                    'from': 'me' if m['sender_id'] == user_id else 'them',
                    'text': m['message'],
                    'time': m['created_at'].strftime('%b %d, %I:%M %p')
                })
            
            return jsonify({'items': formatted, 'total': len(formatted)}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@messages_bp.route('/<int:other_id>', methods=['POST'])
@jwt_required()
def send_message(other_id):
    user_id = get_jwt_identity()
    data = request.get_json()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO messages (sender_id, receiver_id, message)
                VALUES (%s, %s, %s) RETURNING id, created_at
            """, (user_id, other_id, data.get('text')))
            new_msg = cursor.fetchone()
            conn.commit()
            
            return jsonify({
                'id': new_msg['id'],
                'from': 'me',
                'text': data.get('text'),
                'time': new_msg['created_at'].strftime('%b %d, %I:%M %p')
            }), 201
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()
