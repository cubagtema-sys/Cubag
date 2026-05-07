from flask import Blueprint, jsonify
from config.db import get_db

admin_bp = Blueprint('admin', __name__)

@admin_bp.route('/dashboard', methods=['GET'])
def get_dashboard_stats():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Total members
            cursor.execute("SELECT COUNT(id) as count FROM members")
            total_members = cursor.fetchone()['count'] or 0

            # Revenue
            cursor.execute("SELECT SUM(amount) as total FROM payments WHERE status = 'paid'")
            revenue = cursor.fetchone()['total'] or 0

            # Pending Renewals (using tasks or pending members for now)
            cursor.execute("SELECT COUNT(id) as count FROM members WHERE status = 'pending'")
            pending_renewals = cursor.fetchone()['count'] or 0

            # Active surveys
            cursor.execute("SELECT COUNT(id) as count FROM surveys WHERE active = TRUE")
            active_surveys = cursor.fetchone()['count'] or 0

            # Recent members table
            cursor.execute("""
                SELECT id, name, company, member_type, status 
                FROM members 
                ORDER BY created_at DESC LIMIT 5
            """)
            recent_members = cursor.fetchall()

        return jsonify({
            'kpis': {
                'total_members': total_members,
                'revenue': float(revenue),
                'pending_renewals': pending_renewals,
                'active_surveys': active_surveys
            },
            'recent_members': recent_members
        }), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()
