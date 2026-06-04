from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from config.db import get_db
from utils import admin_required, log_admin_action

admin_bp = Blueprint('admin', __name__)


@admin_bp.route('/dashboard', methods=['GET'])
@admin_required
def get_dashboard_stats():
    caller_id = get_jwt_identity()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Determine permissions
            cursor.execute("SELECT role FROM members WHERE id = %s", (caller_id,))
            user = cursor.fetchone()
            is_full_admin = user['role'] == 'admin'

            perms = []
            if not is_full_admin:
                cursor.execute("SELECT permission_key FROM sub_admin_permissions WHERE sub_admin_id = %s AND granted = TRUE", (caller_id,))
                perms = [r['permission_key'] for r in cursor.fetchall()]

            def has_p(p): return is_full_admin or p in perms

            # Initialize metrics with default values
            total_members = 0
            active_members = 0
            pending_members = 0
            suspended_members = 0
            status_counts = {}
            type_counts = {}
            revenue = 0.0
            pending_revenue = 0.0
            failed_revenue = 0.0
            open_tickets = 0
            announcements_count = 0
            schedules_count = 0
            recent_members = []

            # ── Membership KPIs ──────────────────────────────────────────
            if has_p('members'):
                try:
                    cursor.execute("""
                        SELECT
                            COUNT(id) as total,
                            COUNT(id) FILTER (WHERE LOWER(status) = 'active') as active,
                            COUNT(id) FILTER (WHERE LOWER(status) = 'pending') as pending,
                            COUNT(id) FILTER (WHERE LOWER(status) = 'suspended') as suspended
                        FROM members
                    """)
                    row = cursor.fetchone()
                    total_members = int(row['total'] or 0)
                    active_members = int(row['active'] or 0)
                    pending_members = int(row['pending'] or 0)
                    suspended_members = int(row['suspended'] or 0)

                    # Member breakdown by status
                    cursor.execute("""
                        SELECT LOWER(TRIM(COALESCE(status, 'inactive'))) AS status, COUNT(id) as count
                        FROM members
                        GROUP BY LOWER(TRIM(COALESCE(status, 'inactive')))
                    """)
                    status_rows = cursor.fetchall()
                    status_counts = {'active': 0, 'pending': 0, 'suspended': 0, 'inactive': 0}
                    for r in status_rows:
                        status_key = str(r['status'] or 'inactive').strip().lower()
                        status_counts[status_key] = status_counts.get(status_key, 0) + int(r['count'])

                    # Member breakdown by type
                    cursor.execute("""
                        SELECT TRIM(COALESCE(member_type, 'Unknown')) AS member_type, COUNT(id) as count
                        FROM members
                        GROUP BY TRIM(COALESCE(member_type, 'Unknown'))
                    """)
                    type_rows = cursor.fetchall()
                    type_counts = {
                        'Corporate Agency': 0,
                        'Individual Broker': 0,
                        'Freight Forwarder': 0,
                        'Shipping Line': 0,
                    }
                    for r in type_rows:
                        member_type = str(r['member_type'] or 'Unknown').strip()
                        type_counts[member_type] = type_counts.get(member_type, 0) + int(r['count'])
                except Exception as e:
                    print(f"[Admin Dashboard] Membership queries failed: {e}")

            # ── Financial KPIs ───────────────────────────────────────────
            if has_p('payments'):
                try:
                    cursor.execute("""
                        SELECT
                            COALESCE(SUM(amount) FILTER (WHERE LOWER(status) = 'paid'), 0) as paid,
                            COALESCE(SUM(amount) FILTER (WHERE LOWER(status) = 'pending'), 0) as pending,
                            COALESCE(SUM(amount) FILTER (WHERE LOWER(status) IN ('failed', 'overdue')), 0) as failed
                        FROM payments
                    """)
                    row = cursor.fetchone()
                    revenue = float(row['paid'] or 0.0)
                    pending_revenue = float(row['pending'] or 0.0)
                    failed_revenue = float(row['failed'] or 0.0)
                except Exception as e:
                    print(f"[Admin Dashboard] Financial queries failed: {e}")

            # ── Operational KPIs ─────────────────────────────────────────
            if has_p('tickets'):
                try:
                    cursor.execute("SELECT COUNT(id) as count FROM support_tickets WHERE LOWER(status) != 'closed' AND deleted_at IS NULL")
                    open_tickets = int(cursor.fetchone()['count'] or 0)
                except Exception as e:
                    print(f"[Admin Dashboard] support_tickets query failed: {e}")

            if has_p('announcements'):
                try:
                    cursor.execute("SELECT COUNT(id) as count FROM announcements WHERE deleted_at IS NULL")
                    announcements_count = int(cursor.fetchone()['count'] or 0)
                except Exception as e:
                    print(f"[Admin Dashboard] announcements query failed: {e}")

            if has_p('schedules'):
                try:
                    cursor.execute("SELECT COUNT(id) as count FROM schedules")
                    schedules_count = int(cursor.fetchone()['count'] or 0)
                except Exception as e:
                    print(f"[Admin Dashboard] schedules query failed: {e}")

            # ── Recent members ───────────────────────────────────────────
            if has_p('members'):
                try:
                    cursor.execute("""
                        SELECT id, name, company, member_type, status, created_at
                        FROM members
                        ORDER BY created_at DESC LIMIT 5
                    """)
                    recent_members = cursor.fetchall()
                    for m in recent_members:
                        for key, value in list(m.items()):
                            if hasattr(value, 'isoformat'):
                                m[key] = value.isoformat()
                            elif hasattr(value, 'strftime'):
                                m[key] = str(value)
                except Exception as e:
                    print(f"[Admin Dashboard] Recent members query failed: {e}")

        return jsonify({
            'kpis': {
                'total_members':    total_members,
                'active_members':   active_members,
                'pending_members':  pending_members,
                'suspended_members': suspended_members,
                'revenue':          revenue,
                'pending_revenue':  pending_revenue,
                'failed_revenue':   failed_revenue,
                'open_tickets':     open_tickets,
                'announcements':    announcements_count,
                'schedules':        schedules_count,
            },
            'status_counts': status_counts,
            'type_counts':   type_counts,
            'recent_members': recent_members
        }), 200
    except Exception as e:
        import traceback
        print(f"[Admin Dashboard Critical Error] {e}")
        print(traceback.format_exc())
        return jsonify({
            'message': f"Critical dashboard error: {str(e)}",
            'error_details': str(e)
        }), 500
    finally:
        conn.close()


@admin_bp.route('/audit-log', methods=['GET'])
@admin_required
def get_audit_log():
    caller_id = get_jwt_identity()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Check permission
            cursor.execute("SELECT role FROM members WHERE id = %s", (caller_id,))
            user = cursor.fetchone()
            if user['role'] != 'admin':
                cursor.execute("SELECT 1 FROM sub_admin_permissions WHERE sub_admin_id = %s AND permission_key = 'audit_log' AND granted = TRUE", (caller_id,))
                if not cursor.fetchone():
                    return jsonify({'message': 'Permission denied'}), 403

            limit = request.args.get('limit', 50, type=int)
            cursor.execute("""
                SELECT a.*, m.name as admin_name
                FROM audit_log a
                LEFT JOIN members m ON a.admin_id = m.id
                ORDER BY a.created_at DESC
                LIMIT %s
            """, (limit,))
            logs = cursor.fetchall()
            for l in logs:
                if hasattr(l.get('created_at'), 'isoformat'):
                    l['created_at'] = l['created_at'].isoformat()
            return jsonify(logs), 200
    finally:
        conn.close()
