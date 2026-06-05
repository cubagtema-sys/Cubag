from flask import Blueprint, jsonify, request
import logging
from flask_jwt_extended import jwt_required, get_jwt_identity
from config.db import get_db
from routes.admin import log_admin_action
from utils import admin_required, sub_admin_required

members_bp = Blueprint('members', __name__)
logger = logging.getLogger(__name__)

@members_bp.route('/', methods=['GET'])
@jwt_required()
def get_members():
    """Returns a safe public list — no PII (email/phone/license) for other members."""
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT id, name, company, member_type,
                       port_of_operation, star_rating
                FROM members WHERE LOWER(status) = 'active'
                ORDER BY name ASC
            """)
            members = cursor.fetchall()
        return jsonify(members), 200
    except Exception as e:
        return jsonify({'message': 'Unable to fetch members'}), 500
    finally:
        conn.close()

@members_bp.route('/admin/all', methods=['GET'])
@sub_admin_required('members')
def get_all_members_admin():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Use a LATERAL join to efficiently fetch the latest renewal payment reference for each member
            cursor.execute("""
                SELECT m.id, m.name, m.email, m.phone, m.company, m.member_type,
                       m.port_of_operation, m.license_number, m.status, m.created_at,
                       COALESCE(m.payment_ref, p.payment_ref) as payment_ref,
                       m.fcm_token, m.license_expiry_date,
                       m.compliance_score, m.star_rating, m.manual_review_score
                FROM members m
                LEFT JOIN LATERAL (
                    SELECT payment_ref
                    FROM payments
                    WHERE member_id = m.id AND description ILIKE '%License Renewal%'
                    ORDER BY created_at DESC
                    LIMIT 1
                ) p ON TRUE
                ORDER BY m.created_at DESC
            """)
            members = cursor.fetchall()

            result = []
            for m in members:
                d = dict(m)
                # Defensive serialization
                for key, value in list(d.items()):
                    if hasattr(value, 'isoformat'):
                        d[key] = value.isoformat()
                    elif hasattr(value, 'strftime'):
                        d[key] = str(value)
                    elif value is None:
                        d[key] = None
                    elif not isinstance(value, (str, int, float, bool, list, dict)):
                        d[key] = str(value)
                result.append(d)
        return jsonify(result), 200
    except Exception as e:
        logger.exception("[Admin Members Error] %s", e)
        return jsonify({'message': f"Server error fetching members: {str(e)}"}), 500
    finally:
        conn.close()

@members_bp.route('/renew', methods=['POST'])
@jwt_required()
def submit_renewal():
    member_id = get_jwt_identity()
    data = request.get_json() or {}
    payment_ref = (data.get('payment_ref') or '').strip()

    if not payment_ref:
        return jsonify({'message': 'A valid payment reference is required to submit renewal'}), 400

    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("UPDATE members SET status = 'pending', payment_ref = %s WHERE id = %s", (payment_ref, member_id))
            conn.commit()
        return jsonify({'message': 'Renewal submitted'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@members_bp.route('/license-history', methods=['GET'])
@jwt_required()
def get_license_history():
    member_id = get_jwt_identity()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT id, name, email, company, license_number, member_type,
                       port_of_operation, status, payment_ref, created_at
                FROM members WHERE id = %s
            """, (member_id,))
            member = cursor.fetchone()
            if not member:
                return jsonify({'message': 'Member not found'}), 404

        # Always build a history entry from the member's current record.
        # A record is considered "submitted" if payment_ref is set OR status is active/pending.
        history = []
        has_activity = (
            member.get('payment_ref') or
            str(member.get('status')).lower() in ('active', 'pending', 'suspended')
        )
        if has_activity:
            history.append({
                'id': member['id'],
                'payment_ref': member.get('payment_ref') or 'N/A',
                'status': member['status'],
                'license_number': member.get('license_number'),
                'member_type': member.get('member_type'),
                'company': member.get('company'),
                'name': member.get('name'),
                'email': member.get('email'),
                'port_of_operation': member.get('port_of_operation'),
                'submitted_at': str(member['created_at']) if member.get('created_at') else '',
                'approved': member['status'] == 'active',
            })

        return jsonify({'member': member, 'history': history}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@members_bp.route('/admin/status/<int:member_id>', methods=['PUT'])
@sub_admin_required('members')
def update_member_status(member_id):
    admin_id = get_jwt_identity()
    data = request.get_json()
    new_status = data.get('status')
    if not new_status:
        return jsonify({'message': 'Status is required'}), 400
        
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Get member name for audit log
            cursor.execute("SELECT name, license_number FROM members WHERE id = %s", (member_id,))
            member = cursor.fetchone()
            member_name = member['name'] if member else f'Member #{member_id}'

            new_license = None
            norm_status = str(new_status).lower()
            if norm_status == 'active':
                if member and (not member['license_number'] or str(member['license_number']).lower() == 'pending'):
                    import datetime
                    year = datetime.datetime.now().year
                    new_license = f"CUBAG-LIC-{year}-{member_id:04d}"
                    cursor.execute("UPDATE members SET status = %s, license_number = %s WHERE id = %s", (new_status, new_license, member_id))
                else:
                    cursor.execute("UPDATE members SET status = %s WHERE id = %s", (new_status, member_id))
            else:
                cursor.execute("UPDATE members SET status = %s WHERE id = %s", (new_status, member_id))
        conn.commit()

        # Log admin action
        action_label = {'active': 'Activated', 'suspended': 'Suspended', 'inactive': 'Deactivated', 'pending': 'Set to Pending'}.get(new_status, f'Changed to {new_status}')
        log_admin_action(admin_id, f'{action_label} member', 'member', member_id, member_name, f'Status → {new_status}')
        
        response_data = {'message': f'Member {member_id} status updated to {new_status}'}
        if new_license:
            response_data['license_number'] = new_license
            
        return jsonify(response_data), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


@members_bp.route('/admin/set-expiry/<int:member_id>', methods=['PUT'])
@sub_admin_required('members')
def set_license_expiry(member_id):
    """Admin: archive old license period then set new expiry date."""
    admin_id = get_jwt_identity()
    data          = request.get_json()
    expiry_date   = data.get('license_expiry_date')   # 'YYYY-MM-DD'
    duration_label = data.get('duration_label', '')   # e.g. '1 Year'
    start_date    = data.get('start_date', '')         # defaults to today server-side

    if not expiry_date:
        return jsonify({'message': 'license_expiry_date is required (YYYY-MM-DD)'}), 400

    from datetime import date
    today = date.today().isoformat()
    effective_start = start_date or today

    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # ── 2. Read the current (outgoing) license period ─────────────────
            cursor.execute("""
                SELECT name, license_number, license_expiry_date
                FROM members WHERE id = %s
            """, (member_id,))
            current = cursor.fetchone()
            member_name = current['name'] if current else f'Member #{member_id}'

            # ── 3. Archive it only if there was a previous expiry set ─────────
            if current and current.get('license_expiry_date'):
                cursor.execute("""
                    INSERT INTO license_history
                        (member_id, license_number, start_date, expiry_date, duration_label)
                    SELECT %s, license_number,
                           COALESCE(
                               (SELECT MAX(expiry_date) FROM license_history WHERE member_id = %s),
                               created_at::date
                           ),
                           %s, 'Previous Period'
                    FROM members WHERE id = %s
                """, (member_id, member_id, str(current['license_expiry_date']), member_id))

            # ── 4. Set new expiry and log the new period ──────────────────────
            cursor.execute(
                "UPDATE members SET license_expiry_date = %s WHERE id = %s",
                (expiry_date, member_id)
            )
            cursor.execute("""
                INSERT INTO license_history
                    (member_id, license_number, start_date, expiry_date, duration_label)
                SELECT %s, license_number, %s, %s, %s
                FROM members WHERE id = %s
            """, (member_id, effective_start, expiry_date, duration_label or 'Custom', member_id))

        conn.commit()

        # Audit log
        log_admin_action(admin_id, 'Updated license expiry', 'member', member_id, member_name, f'Expiry → {expiry_date} ({duration_label or "Custom"})')

        return jsonify({
            'message': 'License period updated and history archived.',
            'license_expiry_date': expiry_date,
            'start_date': effective_start
        }), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


@members_bp.route('/admin/license-history/<int:member_id>', methods=['GET'])
@sub_admin_required('members')
def get_member_license_history(member_id):
    """Admin: fetch the full license period history for a member."""
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Return empty list gracefully if table doesn't exist yet
            try:
                cursor.execute("""
                    SELECT lh.id, lh.license_number, lh.start_date, lh.expiry_date,
                           lh.duration_label, lh.archived_at
                    FROM license_history lh
                    WHERE lh.member_id = %s
                    ORDER BY lh.archived_at DESC
                """, (member_id,))
                rows = cursor.fetchall()
                result = []
                for r in rows:
                    d = dict(r)
                    for field in ('start_date', 'expiry_date', 'archived_at'):
                        if d.get(field):
                            d[field] = str(d[field])
                    result.append(d)
                return jsonify(result), 200
            except Exception:
                conn.rollback()
                return jsonify([]), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


@members_bp.route('/my-license-history', methods=['GET'])
@jwt_required()
def get_my_license_history():
    """Member: fetch their own license period history."""
    member_id = get_jwt_identity()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            try:
                cursor.execute("""
                    SELECT id, license_number, start_date, expiry_date,
                           duration_label, archived_at
                    FROM license_history
                    WHERE member_id = %s
                    ORDER BY archived_at DESC
                """, (member_id,))
                rows = cursor.fetchall()
                result = []
                for r in rows:
                    d = dict(r)
                    for field in ('start_date', 'expiry_date', 'archived_at'):
                        if d.get(field):
                            d[field] = str(d[field])
                    result.append(d)
                return jsonify(result), 200
            except Exception:
                conn.rollback()
                return jsonify([]), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


@members_bp.route('/public-directory', methods=['GET'])
@jwt_required()  # Require login — phone/email are not exposed
def get_public_directory():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT id, company as name, member_type as type,
                       port_of_operation as location, star_rating as rating
                FROM members WHERE LOWER(status) = 'active' AND company IS NOT NULL
            """)
            companies = cursor.fetchall()
        return jsonify(companies), 200
    except Exception as e:
        return jsonify({'message': 'Unable to fetch directory'}), 500
    finally:
        conn.close()


@members_bp.route('/<int:member_id>', methods=['GET'])
@jwt_required()
def get_member(member_id):
    caller_id = get_jwt_identity()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Check caller's role
            cursor.execute("SELECT role FROM members WHERE id = %s", (caller_id,))
            caller = cursor.fetchone()
            is_admin = caller and caller.get('role') in ('admin', 'sub_admin')
            is_owner = str(caller_id) == str(member_id)

            if is_owner or is_admin:
                # Full profile for self or admins
                cursor.execute("""
                    SELECT id, name, email, phone, company, member_type, port_of_operation,
                           status, compliance_score, star_rating, manual_review_score,
                           license_number, profile_photo
                    FROM members WHERE id = %s
                """, (member_id,))
            else:
                # Other members see only safe public fields — no PII
                cursor.execute("""
                    SELECT id, name, company, member_type, port_of_operation,
                           status, star_rating
                    FROM members WHERE id = %s AND LOWER(status) = 'active'
                """, (member_id,))

            member = cursor.fetchone()
            if not member:
                return jsonify({'message': 'Member not found'}), 404

            if is_owner or is_admin:
                from utils import calculate_and_update_member_rating
                rating_data = calculate_and_update_member_rating(member_id, cursor)
                cursor.execute("""
                    SELECT compliance_score, star_rating, recorded_at
                    FROM member_rating_history WHERE member_id = %s
                    ORDER BY recorded_at ASC
                """, (member_id,))
                history = [
                    {'compliance_score': h['compliance_score'],
                     'star_rating': float(h['star_rating']),
                     'recorded_at': str(h['recorded_at'])}
                    for h in cursor.fetchall()
                ]
                result = dict(member)
                result['compliance_score']    = rating_data['compliance_score']
                result['star_rating']          = rating_data['star_rating']
                result['manual_review_score']  = rating_data['manual_review_score']
                result['breakdown']            = rating_data.get('breakdown', {})
                result['rating_history']       = history
                return jsonify(result), 200

            return jsonify(dict(member)), 200
    finally:
        conn.close()

@members_bp.route('/verify/<int:member_id>', methods=['GET'])
def verify_member_public(member_id):
    """Publicly verify a member's credentials by their ID."""
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT name, company, member_type, port_of_operation,
                       status, profile_photo, license_number,
                       compliance_score, star_rating
                FROM members WHERE id = %s
            """, (member_id,))
            member = cursor.fetchone()
        if not member:
            return jsonify({'message': 'Invalid member ID'}), 404
        return jsonify(dict(member)), 200
    finally:
        conn.close()

@members_bp.route('/admin/set-review-score/<int:member_id>', methods=['PUT'])
@sub_admin_required('members')
def set_manual_review_score(member_id):
    admin_id = get_jwt_identity()
    data = request.get_json()
    score = data.get('manual_review_score')
    if score is None or not (0 <= int(score) <= 10):
        return jsonify({'message': 'manual_review_score must be between 0 and 10'}), 400
        
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Get member name for audit
            cursor.execute("SELECT name FROM members WHERE id = %s", (member_id,))
            member = cursor.fetchone()
            member_name = member['name'] if member else f'Member #{member_id}'

            cursor.execute("UPDATE members SET manual_review_score = %s WHERE id = %s", (int(score), member_id))
            conn.commit()
            
            # Recalculate
            from utils import calculate_and_update_member_rating
            rating_data = calculate_and_update_member_rating(member_id, cursor)

        # Audit log
        log_admin_action(admin_id, 'Updated review score', 'member', member_id, member_name, f'Manual review score → {score}/10')
            
        return jsonify({
            'message': 'Manual review score updated successfully.',
            'compliance_score': rating_data['compliance_score'],
            'star_rating': rating_data['star_rating']
        }), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()
