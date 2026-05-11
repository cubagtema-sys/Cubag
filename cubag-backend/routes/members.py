from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from config.db import get_db

members_bp = Blueprint('members', __name__)

@members_bp.route('/', methods=['GET'])
@jwt_required()
def get_members():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT id, name, email, phone, company, member_type,
                       port_of_operation, license_number, status
                FROM members WHERE status = 'active'
                ORDER BY name ASC
            """)
            members = cursor.fetchall()
        return jsonify(members), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@members_bp.route('/admin/all', methods=['GET'])
@jwt_required()
def get_all_members_admin():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT id, name, email, phone, company, member_type,
                       port_of_operation, license_number, status, created_at,
                       payment_ref, fcm_token, license_expiry_date
                FROM members
                ORDER BY created_at DESC
            """)
            members = cursor.fetchall()
            result = []
            for m in members:
                d = dict(m)
                if d.get('license_expiry_date'):
                    d['license_expiry_date'] = str(d['license_expiry_date'])
                result.append(d)
        return jsonify(result), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@members_bp.route('/renew', methods=['POST'])
@jwt_required()
def submit_renewal():
    member_id = get_jwt_identity()
    data = request.get_json()
    payment_ref = data.get('payment_ref', 'MOMO-PAYMENT')
    
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
            member.get('status') in ('active', 'pending', 'suspended')
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
def update_member_status(member_id):
    data = request.get_json()
    new_status = data.get('status')
    if not new_status:
        return jsonify({'message': 'Status is required'}), 400
        
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            new_license = None
            if new_status == 'active':
                cursor.execute("SELECT license_number FROM members WHERE id = %s", (member_id,))
                member = cursor.fetchone()
                if member and (not member['license_number'] or member['license_number'].lower() == 'pending'):
                    import datetime
                    year = datetime.datetime.now().year
                    new_license = f"CUBAG-LIC-{year}-{member_id:04d}"
                    cursor.execute("UPDATE members SET status = %s, license_number = %s WHERE id = %s", (new_status, new_license, member_id))
                else:
                    cursor.execute("UPDATE members SET status = %s WHERE id = %s", (new_status, member_id))
            else:
                cursor.execute("UPDATE members SET status = %s WHERE id = %s", (new_status, member_id))
        conn.commit()
        
        response_data = {'message': f'Member {member_id} status updated to {new_status}'}
        if new_license:
            response_data['license_number'] = new_license
            
        return jsonify(response_data), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


@members_bp.route('/admin/set-expiry/<int:member_id>', methods=['PUT'])
def set_license_expiry(member_id):
    """Admin: archive old license period then set new expiry date."""
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
            # ── 1. Ensure columns & history table exist ───────────────────────
            cursor.execute(
                "ALTER TABLE members ADD COLUMN IF NOT EXISTS license_expiry_date DATE"
            )
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS license_history (
                    id             SERIAL PRIMARY KEY,
                    member_id      INTEGER NOT NULL,
                    license_number VARCHAR(100),
                    start_date     DATE,
                    expiry_date    DATE,
                    duration_label VARCHAR(50),
                    archived_at    TIMESTAMP DEFAULT NOW()
                )
            """)

            # ── 2. Read the current (outgoing) license period ─────────────────
            cursor.execute("""
                SELECT license_number, license_expiry_date
                FROM members WHERE id = %s
            """, (member_id,))
            current = cursor.fetchone()

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
def get_public_directory():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT id, company as name, member_type as type, port_of_operation as location, 
                       phone, email, '4.8' as rating 
                FROM members WHERE status = 'active' AND company IS NOT NULL
            """)
            companies = cursor.fetchall()
            
            # If the database is empty during dev, provide fallback mock data
            if not companies:
                return jsonify([
                    { 'id': 1, 'name': 'Tema Logistics Agency', 'type': 'Corporate Agency', 'location': 'Tema Port', 'phone': '+233 50 123 4567', 'email': 'contact@temalogistics.com.gh', 'rating': '4.8' },
                    { 'id': 2, 'name': 'Accra Freight Forwarders', 'type': 'Corporate Agency', 'location': 'KIA, Accra', 'phone': '+233 24 987 6543', 'email': 'info@accrafreight.com', 'rating': '4.9' },
                ]), 200

        return jsonify(companies), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


@members_bp.route('/<int:member_id>', methods=['GET'])
@jwt_required()
def get_member(member_id):
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id, name, email, phone, company, member_type, port_of_operation FROM members WHERE id = %s", (member_id,))
            member = cursor.fetchone()
        if not member:
            return jsonify({'message': 'Member not found'}), 404
        return jsonify(member), 200
    finally:
        conn.close()
