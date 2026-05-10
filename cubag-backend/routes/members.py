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
                       port_of_operation, license_number, status, created_at, payment_ref, fcm_token
                FROM members
                ORDER BY created_at DESC
            """)
            members = cursor.fetchall()
        return jsonify(members), 200
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
