from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from config.db import get_db

tickets_bp = Blueprint('tickets', __name__)

@tickets_bp.route('/', methods=['GET'])
@jwt_required()
def get_user_tickets():
    member_id = get_jwt_identity()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT id, subject, message, status, created_at, updated_at
                FROM support_tickets
                WHERE member_id = %s
                ORDER BY updated_at DESC
            """, (member_id,))
            tickets = cursor.fetchall()
            
            # Get replies for each ticket
            for t in tickets:
                cursor.execute("""
                    SELECT author, message, created_at
                    FROM ticket_replies
                    WHERE ticket_id = %s
                    ORDER BY created_at ASC
                """, (t['id'],))
                replies = cursor.fetchall()
                t['replies'] = [{
                    'author': r['author'],
                    'message': r['message'],
                    'date': r['created_at'].strftime('%Y-%m-%d %H:%M')
                } for r in replies]
                
                t['date'] = t['created_at'].strftime('%Y-%m-%d')
                t['lastUpdate'] = t['updated_at'].strftime('%Y-%m-%d %H:%M')
                
            return jsonify(tickets), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@tickets_bp.route('/', methods=['POST'])
@jwt_required()
def create_ticket():
    member_id = get_jwt_identity()
    data = request.get_json()
    conn = get_db()
    try:
        # Generate random ticket ID TKT-XXXX
        import random
        ticket_id = f"TKT-{random.randint(1000, 9999)}"
        
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO support_tickets (id, member_id, subject, message)
                VALUES (%s, %s, %s, %s)
            """, (ticket_id, member_id, data.get('subject'), data.get('message')))
            conn.commit()
            
        return jsonify({'id': ticket_id, 'message': 'Ticket created'}), 201
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

# --- ADMIN ENDPOINTS ---

@tickets_bp.route('/admin/all', methods=['GET'])
def get_all_tickets_admin():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT t.id, t.subject, t.message, t.status, t.created_at, t.updated_at, m.name as member_name
                FROM support_tickets t
                JOIN members m ON t.member_id = m.id
                WHERE t.deleted_at IS NULL
                ORDER BY t.updated_at DESC
            """)
            tickets = cursor.fetchall()
            
            for t in tickets:
                cursor.execute("""
                    SELECT author, message, created_at
                    FROM ticket_replies
                    WHERE ticket_id = %s
                    ORDER BY created_at ASC
                """, (t['id'],))
                replies = cursor.fetchall()
                t['replies'] = [{
                    'author': r['author'],
                    'message': r['message'],
                    'date': r['created_at'].strftime('%Y-%m-%d %H:%M')
                } for r in replies]
                
                t['date'] = t['created_at'].strftime('%Y-%m-%d')
                t['lastUpdate'] = t['updated_at'].strftime('%Y-%m-%d %H:%M')
                # member_name is already in the row from the JOIN — no need to concat into subject
                
            return jsonify(tickets), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@tickets_bp.route('/admin/<ticket_id>/status', methods=['PUT'])
def update_ticket_status(ticket_id):
    data = request.get_json()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                UPDATE support_tickets 
                SET status = %s, updated_at = CURRENT_TIMESTAMP
                WHERE id = %s
            """, (data.get('status'), ticket_id))
            conn.commit()
        return jsonify({'message': 'Status updated'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@tickets_bp.route('/admin/<ticket_id>/reply', methods=['POST'])
def add_ticket_reply(ticket_id):
    data = request.get_json()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO ticket_replies (ticket_id, author, message)
                VALUES (%s, 'Admin', %s)
            """, (ticket_id, data.get('message')))
            
            cursor.execute("""
                UPDATE support_tickets
                SET updated_at = CURRENT_TIMESTAMP
                WHERE id = %s
            """, (ticket_id,))
            conn.commit()
        return jsonify({'message': 'Reply added'}), 201
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

# ─── DELETE /tickets/admin/<id> — Soft delete (keeps data in DB) ──────────────
@tickets_bp.route('/admin/<ticket_id>', methods=['DELETE'])
def soft_delete_ticket(ticket_id):
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                UPDATE support_tickets
                SET deleted_at = CURRENT_TIMESTAMP
                WHERE id = %s
            """, (ticket_id,))
            conn.commit()
        return jsonify({'message': 'Ticket archived'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()
