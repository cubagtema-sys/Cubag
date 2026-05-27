from flask import Blueprint, jsonify
from config.db import get_db

admin_bp = Blueprint('admin', __name__)

@admin_bp.route('/dashboard', methods=['GET'])
@jwt_required()
def get_dashboard_stats():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Total members
            cursor.execute("SELECT COUNT(id) as count FROM members")
            total_members = cursor.fetchone()['count'] or 0

            # Active members
            cursor.execute("SELECT COUNT(id) as count FROM members WHERE status = 'active'")
            active_members = cursor.fetchone()['count'] or 0

            # Revenue
            cursor.execute("SELECT SUM(amount) as total FROM payments WHERE status = 'paid'")
            revenue = cursor.fetchone()['total'] or 0

            # Pending members
            cursor.execute("SELECT COUNT(id) as count FROM members WHERE status = 'pending'")
            pending_members = cursor.fetchone()['count'] or 0

            # Open tickets
            cursor.execute("SELECT COUNT(id) as count FROM support_tickets WHERE status != 'closed' AND deleted_at IS NULL")
            open_tickets = cursor.fetchone()['count'] or 0

            # Recent members
            cursor.execute("""
                SELECT id, name, company, member_type, status, created_at
                FROM members 
                ORDER BY created_at DESC LIMIT 5
            """)
            recent_members = cursor.fetchall()
            for m in recent_members:
                if m.get('created_at') and not isinstance(m['created_at'], str):
                    try:
                        m['created_at'] = m['created_at'].isoformat()
                    except:
                        m['created_at'] = str(m['created_at'])

        return jsonify({
            'kpis': {
                'total_members': total_members,
                'active_members': active_members,
                'revenue': float(revenue or 0),
                'pending_members': pending_members,
                'open_tickets': open_tickets
            },
            'recent_members': recent_members
        }), 200
    except Exception as e:
        print(f"[Admin Dashboard Error] {e}")
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()
