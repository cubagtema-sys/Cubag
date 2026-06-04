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
                    cursor.execute("SELECT COALESCE(SUM(amount), 0) as total FROM payments WHERE LOWER(status) = 'paid'")
                    revenue = float(cursor.fetchone()['total'] or 0.0)

                    cursor.execute("SELECT COALESCE(SUM(amount), 0) as total FROM payments WHERE LOWER(status) = 'pending'")
                    pending_revenue = float(cursor.fetchone()['total'] or 0.0)

                    cursor.execute("SELECT COALESCE(SUM(amount), 0) as total FROM payments WHERE LOWER(status) IN ('failed', 'overdue')")
                    failed_revenue = float(cursor.fetchone()['total'] or 0.0)
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
                # Membership
                'total_members':    total_members,
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
                'suspended_members': suspended_members,
                # Financial
                'revenue':          revenue,
                'pending_revenue':  pending_revenue,
                'failed_revenue':   failed_revenue,
                # Operational
                        cursor.execute("SELECT COALESCE(SUM(amount), 0) as total FROM payments WHERE LOWER(status) IN ('failed', 'overdue')")
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


# ─── GET /admin/audit-log ─────────────────────────────────────────────────────
@admin_bp.route('/audit-log', methods=['GET'])
@admin_required
def get_audit_log():
    """Return recent admin/sub-admin actions with filtering support."""
    from utils import sub_admin_required
    @sub_admin_required('audit_log')
    def inner():
        limit       = request.args.get('limit', 50, type=int)
        offset      = request.args.get('offset', 0, type=int)
        action_type = request.args.get('action_type', '').strip()
        target_type = request.args.get('target_type', '').strip()
        date_from   = request.args.get('date_from', '').strip()
        date_to     = request.args.get('date_to', '').strip()
        actor_id    = request.args.get('actor_id', '', type=str).strip()  # filter by specific admin/sub-admin

        conn = get_db()
        try:
            with conn.cursor() as cursor:
                where_clauses = []
                params = []

                if action_type:
                    where_clauses.append("a.action ILIKE %s")
                    params.append(f'%{action_type}%')
                if target_type:
                    where_clauses.append("a.target_type = %s")
                    params.append(target_type)
                if date_from:
                    where_clauses.append("a.created_at >= %s::timestamp")
                    params.append(date_from)
                if date_to:
                    where_clauses.append("a.created_at <= %s::timestamp + interval '1 day'")
                    params.append(date_to)
                if actor_id:
                    where_clauses.append("a.admin_id = %s")
                    params.append(actor_id)

                where_sql = (' WHERE ' + ' AND '.join(where_clauses)) if where_clauses else ''

                cursor.execute(f"""
                    SELECT a.id, a.admin_id, a.action, a.target_type, a.target_id, a.target_name,
                           a.details, a.created_at,
                           m.name  AS admin_name,
                           m.email AS admin_email,
                           m.role  AS admin_role
                    FROM audit_log a
                    LEFT JOIN members m ON a.admin_id = m.id
                    {where_sql}
                    ORDER BY a.created_at DESC
                    LIMIT %s OFFSET %s
                """, params + [limit, offset])
                logs = cursor.fetchall()

                cursor.execute(f"SELECT COUNT(a.id) as count FROM audit_log a {where_sql}", params)
                total = cursor.fetchone()['count'] or 0

                # Distinct target types for filter dropdown
                cursor.execute("SELECT DISTINCT target_type FROM audit_log WHERE target_type IS NOT NULL ORDER BY target_type")
                target_types = [r['target_type'] for r in cursor.fetchall()]

                # All actors (admin + sub_admin) for the actor filter dropdown
                cursor.execute("""
                    SELECT DISTINCT m.id, m.name, m.role
                    FROM audit_log a
                    JOIN members m ON a.admin_id = m.id
                    ORDER BY m.name
                """)
                actors = cursor.fetchall()

            # Serialize dates
            for log in logs:
                for key, value in list(log.items()):
                    if hasattr(value, 'isoformat'):
                        log[key] = value.isoformat()

            return jsonify({
                'logs': logs,
                'total': total,
                'filter_options': {
                    'target_types': target_types,
                    'actors': actors,
                }
            }), 200
        except Exception as e:
            print(f"[Audit Log Fetch Error] {e}")
            return jsonify({'message': f'Internal server error: {str(e)}', 'logs': [], 'total': 0}), 500
        finally:
            conn.close()
    return inner()



# ─── GET /admin/audit-log/export — CSV export ────────────────────────────────
@admin_bp.route('/audit-log/export', methods=['GET'])
@admin_required
def export_audit_log_csv():
    """Export audit log as CSV."""
    from utils import sub_admin_required
    @sub_admin_required('audit_log')
    def inner():
        import csv
        import io

        action_type = request.args.get('action_type', '').strip()
        target_type = request.args.get('target_type', '').strip()
        date_from = request.args.get('date_from', '').strip()
        date_to = request.args.get('date_to', '').strip()

        conn = get_db()
        try:
            with conn.cursor() as cursor:
                where_clauses = []
                params = []

                if action_type:
                    where_clauses.append("a.action ILIKE %s")
                    params.append(f'%{action_type}%')
                if target_type:
                    where_clauses.append("a.target_type = %s")
                    params.append(target_type)
                if date_from:
                    where_clauses.append("a.created_at >= %s::timestamp")
                    params.append(date_from)
                if date_to:
                    where_clauses.append("a.created_at <= %s::timestamp + interval '1 day'")
                    params.append(date_to)

                where_sql = (' WHERE ' + ' AND '.join(where_clauses)) if where_clauses else ''

                cursor.execute(f"""
                    SELECT a.id, a.action, a.target_type, a.target_id, a.target_name,
                           a.details, a.created_at,
                           m.name  AS admin_name,
                           m.email AS admin_email,
                           m.role  AS admin_role
                    FROM audit_log a
                    LEFT JOIN members m ON a.admin_id = m.id
                    {where_sql}
                    ORDER BY a.created_at DESC
                """, params)
                logs = cursor.fetchall()

            output = io.StringIO()
            writer = csv.writer(output)
            writer.writerow(['ID', 'Actor', 'Role', 'Email', 'Action', 'Target Type', 'Target ID', 'Target Name', 'Details', 'Timestamp'])
            for log in logs:
                writer.writerow([
                    log.get('id', ''),
                    log.get('admin_name', ''),
                    log.get('admin_role', ''),
                    log.get('admin_email', ''),
                    log.get('action', ''),
                    log.get('target_type', ''),
                    log.get('target_id', ''),
                    log.get('target_name', ''),
                    log.get('details', ''),
                    str(log.get('created_at', '')),
                ])

            from flask import Response
            return Response(
                output.getvalue(),
                mimetype='text/csv',
                headers={'Content-Disposition': 'attachment; filename=audit_log_export.csv'}
            )
        except Exception as e:
            print(f"[Audit CSV Export Error] {e}")
            return jsonify({'message': str(e)}), 500
        finally:
            conn.close()
    return inner()


# ─── GET /admin/search?q=<query> ──────────────────────────────────────────────
@admin_bp.route('/search', methods=['GET'])
@admin_required
def admin_global_search():
    """Search across members, payments, and tickets based on caller permissions."""
    caller_id = get_jwt_identity()
    q = request.args.get('q', '').strip()
    if len(q) < 2:
        return jsonify({'results': []}), 200

    # Escape SQL wildcard characters in user input
    q_safe = q.replace('%', '\\%').replace('_', '\\_')
    pattern = f'%{q_safe}%'
    results = []
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

            # Search members
            if has_p('members'):
                cursor.execute("""
                    SELECT id, name, email, member_type, status, 'member' as result_type
                    FROM members
                    WHERE name ILIKE %s OR email ILIKE %s OR company ILIKE %s
                       OR license_number ILIKE %s
                    ORDER BY name LIMIT 10
                """, (pattern, pattern, pattern, pattern))
                results.extend(cursor.fetchall())

            # Search payments
            if has_p('payments'):
                cursor.execute("""
                    SELECT p.id, m.name as name, p.description as email,
                           CAST(p.amount AS VARCHAR) as member_type, p.status, 'payment' as result_type
                    FROM payments p
                    LEFT JOIN members m ON p.member_id = m.id
                    WHERE m.name ILIKE %s OR p.description ILIKE %s
                    ORDER BY p.created_at DESC LIMIT 10
                """, (pattern, pattern))
                results.extend(cursor.fetchall())

            # Search tickets
            if has_p('tickets'):
                try:
                    cursor.execute("""
                        SELECT t.id, t.subject as name, m.name as email,
                               t.status as member_type, t.priority as status, 'ticket' as result_type
                        FROM support_tickets t
                        LEFT JOIN members m ON t.member_id = m.id
                        WHERE t.subject ILIKE %s OR m.name ILIKE %s
                        ORDER BY t.created_at DESC LIMIT 10
                    """, (pattern, pattern))
                    results.extend(cursor.fetchall())
                except Exception:
                    pass  # support_tickets may not exist

        # Serialize dates
        for r in results:
            for key, value in list(r.items()):
                if hasattr(value, 'isoformat'):
                    r[key] = value.isoformat()

        return jsonify({'results': results}), 200
    except Exception as e:
        print(f"[Admin Search Error] {e}")
        return jsonify({'results': []}), 200
    finally:
        conn.close()
