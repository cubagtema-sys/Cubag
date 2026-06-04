from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from config.db import get_db
from utils import admin_required, log_admin_action, sub_admin_required

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
        with conn.cursor() as cursor:
            # Generate a unique ticket ID
            import random
            attempts = 0
            while True:
                # 6 digits for better collision avoidance
                ticket_id = f"TKT-{random.randint(100000, 999999)}"
                cursor.execute("SELECT 1 FROM support_tickets WHERE id = %s", (ticket_id,))
                if not cursor.fetchone():
                    break
                attempts += 1
                if attempts > 50:
                    import uuid
                    ticket_id = f"TKT-{uuid.uuid4().hex[:8].upper()}"
                    break

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
@sub_admin_required('tickets')
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
@sub_admin_required('tickets')
def update_ticket_status(ticket_id):
    admin_id = get_jwt_identity()
    data = request.get_json()
    new_status = data.get('status', '')
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Fetch ticket subject for audit context
            cursor.execute("SELECT subject, member_id FROM support_tickets WHERE id = %s", (ticket_id,))
            ticket = cursor.fetchone()
            cursor.execute("""
                UPDATE support_tickets 
                SET status = %s, updated_at = CURRENT_TIMESTAMP
                WHERE id = %s
            """, (new_status, ticket_id))
            conn.commit()
        subject = ticket['subject'] if ticket else ticket_id
        log_admin_action(admin_id, f'Updated ticket status to {new_status}', 'ticket', None, subject, f'Ticket: {ticket_id} → {new_status}')
        return jsonify({'message': 'Status updated'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@tickets_bp.route('/admin/<ticket_id>/reply', methods=['POST'])
@sub_admin_required('tickets')
def add_ticket_reply(ticket_id):
    admin_id = get_jwt_identity()
    data = request.get_json()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT subject FROM support_tickets WHERE id = %s", (ticket_id,))
            ticket = cursor.fetchone()
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
        subject = ticket['subject'] if ticket else ticket_id
        log_admin_action(admin_id, 'Replied to ticket', 'ticket', None, subject, f'Ticket: {ticket_id}')
        return jsonify({'message': 'Reply added'}), 201
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

# ─── DELETE /tickets/admin/<id> — Soft delete (keeps data in DB) ──────────────
@tickets_bp.route('/admin/<ticket_id>', methods=['DELETE'])
@sub_admin_required('tickets')
def soft_delete_ticket(ticket_id):
    admin_id = get_jwt_identity()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT subject FROM support_tickets WHERE id = %s", (ticket_id,))
            ticket = cursor.fetchone()
            cursor.execute("""
                UPDATE support_tickets
                SET deleted_at = CURRENT_TIMESTAMP
                WHERE id = %s
            """, (ticket_id,))
            conn.commit()
        subject = ticket['subject'] if ticket else ticket_id
        log_admin_action(admin_id, 'Archived ticket', 'ticket', None, subject, f'Ticket: {ticket_id}')
        return jsonify({'message': 'Ticket archived'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()
