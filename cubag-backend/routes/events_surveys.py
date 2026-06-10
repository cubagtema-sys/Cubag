import logging
from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from config.db import get_db
from utils import admin_required, log_admin_action, sub_admin_required
import json
from socket_instance import socketio

logger = logging.getLogger(__name__)
events_bp = Blueprint('events', __name__)
surveys_bp = Blueprint('surveys', __name__)

# ─────────────────────────────────────────────
#  EVENTS
# ─────────────────────────────────────────────

@events_bp.route('/', methods=['GET'])
@jwt_required()
def get_events():
    # B-16 fix: allow members to request past events via ?include_past=true
    include_past = request.args.get('include_past', 'false').lower() == 'true'
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            if include_past:
                cursor.execute("SELECT * FROM events ORDER BY date DESC")
            else:
                # Show events from the last 7 days onwards to ensure visibility across timezones
                # and allow members to see very recent past events.
                cursor.execute("SELECT * FROM events WHERE date >= (CURRENT_DATE - INTERVAL '7 days') ORDER BY date ASC")
            data = cursor.fetchall()

            # Ensure dates are stringified
            for ev in data:
                if hasattr(ev.get('date'), 'isoformat'):
                    ev['date'] = ev['date'].isoformat()
                if hasattr(ev.get('created_at'), 'isoformat'):
                    ev['created_at'] = ev['created_at'].isoformat()

        return jsonify({'items': data, 'total': len(data)}), 200
    finally:
        conn.close()

@events_bp.route('/', methods=['POST'])
@sub_admin_required('events')
def create_event():
    # B-17 fix: validate required fields before inserting
    admin_id = get_jwt_identity()
    data = request.get_json() or {}
    title = (data.get('title') or '').strip()
    event_date = (data.get('date') or '').strip()
    if not title:
        return jsonify({'message': 'Event title is required'}), 400
    if not event_date:
        return jsonify({'message': 'Event date is required'}), 400
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO events (title, description, date, time, location, capacity)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (title, data.get('description'), event_date,
                  data.get('time'), data.get('location'), data.get('capacity') or None))
            conn.commit()
        log_admin_action(admin_id, 'Created event', 'event', None, title, f"Date: {event_date}, Location: {data.get('location')}")
        return jsonify({'message': 'Event created'}), 201
    except Exception as e:
        conn.rollback()
        logger.error(f'[create_event] {e}')
        return jsonify({'message': 'Failed to create event'}), 500
    finally:
        conn.close()

@events_bp.route('/<int:event_id>', methods=['PUT'])
@sub_admin_required('events')
def update_event(event_id):
    admin_id = get_jwt_identity()
    data = request.get_json()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                UPDATE events SET title=%s, description=%s, date=%s, time=%s, location=%s, capacity=%s
                WHERE id=%s
            """, (data.get('title'), data.get('description'), data.get('date'),
                  data.get('time'), data.get('location'), data.get('capacity') or None, event_id))
            conn.commit()
        log_admin_action(admin_id, 'Updated event', 'event', event_id, data.get('title'), f"Date: {data.get('date')}")
        return jsonify({'message': 'Event updated'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@events_bp.route('/<int:event_id>', methods=['DELETE'])
@sub_admin_required('events')
def delete_event(event_id):
    admin_id = get_jwt_identity()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT title FROM events WHERE id = %s", (event_id,))
            event = cursor.fetchone()
            cursor.execute("DELETE FROM events WHERE id = %s", (event_id,))
            conn.commit()
        title = event['title'] if event else f'#{event_id}'
        log_admin_action(admin_id, 'Deleted event', 'event', event_id, title)
        return jsonify({'message': 'Event deleted'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@events_bp.route('/admin/all', methods=['GET'])
@sub_admin_required('events')
def get_all_events_admin():
    try:
        page = max(1, int(request.args.get('page', 1)))
        per_page = int(request.args.get('per_page', 20))
        per_page = max(1, min(per_page, 200))
        offset = (page - 1) * per_page
        event_status = request.args.get('status', 'all').lower()

        where_clause = ""
        if event_status == 'upcoming':
            where_clause = "WHERE date >= CURRENT_DATE"
        elif event_status == 'history':
            where_clause = "WHERE date < CURRENT_DATE"

        conn = get_db()
        with conn.cursor() as cursor:
            cursor.execute(f"SELECT * FROM events {where_clause} ORDER BY date DESC LIMIT %s OFFSET %s", (per_page, offset))
            data = cursor.fetchall()
            cursor.execute(f"SELECT COUNT(*) as total FROM events {where_clause}")
            total = cursor.fetchone().get('total', 0)

            # Ensure dates are stringified
            for ev in data:
                if hasattr(ev.get('date'), 'isoformat'):
                    ev['date'] = ev['date'].isoformat()
                if hasattr(ev.get('created_at'), 'isoformat'):
                    ev['created_at'] = ev['created_at'].isoformat()

        return jsonify({'data': data, 'page': page, 'per_page': per_page, 'total': total}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


@events_bp.route('/<int:event_id>/check-in', methods=['POST'])
@sub_admin_required('events')
def check_in_member(event_id):
    admin_id = get_jwt_identity()
    data = request.get_json() or {}
    member_id = data.get('member_id')
    if not member_id:
        return jsonify({'message': 'Member ID is required'}), 400
    
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # Verify event exists
            cursor.execute("SELECT title FROM events WHERE id = %s", (event_id,))
            event = cursor.fetchone()
            if not event:
                return jsonify({'message': 'Event not found'}), 404
            
            # Duplicate check
            cursor.execute("SELECT checked_in_at FROM event_attendance WHERE event_id = %s AND member_id = %s", (event_id, member_id))
            if cursor.fetchone():
                cursor.execute("SELECT name, company, profile_photo, license_number FROM members WHERE id = %s", (member_id,))
                member = cursor.fetchone()
                return jsonify({
                    'message': 'Error: This QR code has already been scanned for this event!',
                    'member': member
                }), 400

            # Insert into event_attendance
            cursor.execute("""
                INSERT INTO event_attendance (event_id, member_id)
                VALUES (%s, %s)
            """, (event_id, member_id))
            
            # Fetch member details to return to scanner for visual verification
            cursor.execute("""
                SELECT name, company, profile_photo, license_number
                FROM members WHERE id = %s
            """, (member_id,))
            member = cursor.fetchone()

            conn.commit()
            
            log_admin_action(admin_id, 'Checked in member', 'event', event_id, event['title'], f"Member ID: {member_id}")
            
        return jsonify({
            'message': f'Member #{member_id} checked in successfully',
            'member': member
        }), 200
    except Exception as e:
        conn.rollback()
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@events_bp.route('/<int:event_id>/attendees', methods=['GET'])
@sub_admin_required('events')
def get_attendees(event_id):
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # We want all members to know who attended and who didn't.
            cursor.execute("""
                SELECT m.id, m.name, m.email, m.company, m.member_type, ea.checked_in_at
                FROM members m
                LEFT JOIN event_attendance ea ON m.id = ea.member_id AND ea.event_id = %s
                ORDER BY ea.checked_in_at DESC NULLS LAST, m.name ASC
            """, (event_id,))
            data = cursor.fetchall()
            for row in data:
                if hasattr(row.get('checked_in_at'), 'isoformat'):
                    row['checked_in_at'] = row['checked_in_at'].isoformat()
        return jsonify({'attendees': data}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()


# ─────────────────────────────────────────────
#  SURVEYS
# ─────────────────────────────────────────────

@surveys_bp.route('/', methods=['GET'])
@jwt_required()
def get_surveys():
    member_id = get_jwt_identity()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT s.*, 
                       (CASE WHEN sr.survey_id IS NOT NULL THEN TRUE ELSE FALSE END) as has_responded
                FROM surveys s
                LEFT JOIN survey_responses sr ON s.id = sr.survey_id AND sr.member_id = %s
                ORDER BY s.created_at DESC
            """, (member_id,))
            data = cursor.fetchall()

            # Parse options JSON string into object and ensure date serialization
            for s in data:
                if isinstance(s.get('options'), str):
                    try:
                        s['options'] = json.loads(s['options'])
                    except:
                        s['options'] = []

                if hasattr(s.get('created_at'), 'isoformat'):
                    s['created_at'] = s['created_at'].isoformat()
                if hasattr(s.get('deadline'), 'isoformat'):
                    s['deadline'] = s['deadline'].isoformat()

        return jsonify({'items': data, 'total': len(data)}), 200
    finally:
        conn.close()

@surveys_bp.route('/', methods=['POST'])
@sub_admin_required('events')
def create_survey():
    admin_id = get_jwt_identity()
    data = request.get_json()
    conn = get_db()
    try:
        import json as json_lib
        options_json = json_lib.dumps(data.get('options', []))
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO surveys (title, description, type, deadline, options, cover_image, active)
                VALUES (%s, %s, %s, %s, %s, %s, TRUE)
            """, (data.get('title'), data.get('description'), data.get('type', 'survey'),
                  data.get('deadline') or None, options_json, data.get('cover_image')))
            conn.commit()
        log_admin_action(admin_id, 'Created survey', 'survey', None, data.get('title'), f"Type: {data.get('type', 'survey')}")
        return jsonify({'message': 'Survey created'}), 201
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@surveys_bp.route('/<int:survey_id>', methods=['DELETE'])
@sub_admin_required('events')
def delete_survey(survey_id):
    admin_id = get_jwt_identity()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT title FROM surveys WHERE id = %s", (survey_id,))
            survey = cursor.fetchone()
            cursor.execute("DELETE FROM survey_responses WHERE survey_id = %s", (survey_id,))
            cursor.execute("DELETE FROM surveys WHERE id = %s", (survey_id,))
            conn.commit()
        title = survey['title'] if survey else f'#{survey_id}'
        log_admin_action(admin_id, 'Deleted survey', 'survey', survey_id, title)
        return jsonify({'message': 'Survey deleted'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@surveys_bp.route('/<int:survey_id>/toggle-active', methods=['PUT'])
@sub_admin_required('events')
def toggle_survey_active(survey_id):
    """Toggle the active status of a survey (close or reopen)."""
    admin_id = get_jwt_identity()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT title, active FROM surveys WHERE id = %s", (survey_id,))
            survey = cursor.fetchone()
            if not survey:
                return jsonify({'message': 'Survey not found'}), 404
            new_active = not survey['active']
            cursor.execute("UPDATE surveys SET active = %s WHERE id = %s", (new_active, survey_id))
            conn.commit()
        action = 'Reopened survey' if new_active else 'Closed survey'
        log_admin_action(admin_id, action, 'survey', survey_id, survey['title'])
        # Emit real-time update to admin room
        try:
            socketio.emit('survey_update', {'survey_id': survey_id, 'active': new_active}, room='admin_dashboard')
        except Exception as se:
            logger.warning(f'Socket emit failed: {se}')
        return jsonify({'message': action, 'active': new_active}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@surveys_bp.route('/admin/all', methods=['GET'])
@sub_admin_required('events')
def get_all_surveys_admin():
    try:
        page = max(1, int(request.args.get('page', 1)))
        per_page = int(request.args.get('per_page', 20))
        per_page = max(1, min(per_page, 200))
        offset = (page - 1) * per_page
        survey_status = request.args.get('status', 'all').lower()

        where_clause = ""
        if survey_status == 'active':
            where_clause = "WHERE active = TRUE AND (deadline IS NULL OR deadline >= CURRENT_DATE)"
        elif survey_status == 'history':
            where_clause = "WHERE active = FALSE OR (deadline IS NOT NULL AND deadline < CURRENT_DATE)"

        conn = get_db()
        with conn.cursor() as cursor:
            cursor.execute(f"SELECT * FROM surveys {where_clause} ORDER BY created_at DESC LIMIT %s OFFSET %s", (per_page, offset))
            data = cursor.fetchall()
            cursor.execute(f"SELECT COUNT(*) as total FROM surveys {where_clause}")
            total = cursor.fetchone().get('total', 0)

            # Parse options JSON string into object and ensure date serialization
            for s in data:
                if isinstance(s.get('options'), str):
                    try:
                        s['options'] = json.loads(s['options'])
                    except:
                        s['options'] = []

                if hasattr(s.get('created_at'), 'isoformat'):
                    s['created_at'] = s['created_at'].isoformat()
                if hasattr(s.get('deadline'), 'isoformat'):
                    s['deadline'] = s['deadline'].isoformat()

        return jsonify({'data': data, 'page': page, 'per_page': per_page, 'total': total}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@surveys_bp.route('/<int:survey_id>/participation', methods=['GET'])
@sub_admin_required('events')
def get_survey_participation(survey_id):
    """Returns lists of members who have and haven't responded to a survey."""
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # All active members
            cursor.execute("""
                SELECT id, name, email, company, member_type
                FROM members WHERE status = 'active' ORDER BY name ASC
            """)
            all_members = cursor.fetchall()

            # Members who responded
            cursor.execute("""
                SELECT member_id, submitted_at, answers
                FROM survey_responses WHERE survey_id = %s
            """, (survey_id,))
            responses = cursor.fetchall()
            responded_ids = {r['member_id']: r for r in responses}

        responded = []
        not_responded = []
        import json
        
        tallies = {}
        total_stars = 0
        star_count = 0

        for m in all_members:
            if m['id'] in responded_ids:
                r_data = responded_ids[m['id']]
                ans = {}
                try:
                    if isinstance(r_data['answers'], dict):
                        ans = r_data['answers']
                    elif r_data['answers']:
                        ans = json.loads(r_data['answers'])
                except Exception as e:
                    import logging as _logging
                    _logging.getLogger(__name__).debug("Malformed survey answer for member %s: %s", m['id'], e)
                
                vote = ans.get('vote')
                if vote is not None:
                    try:
                        # Try to parse as integer for star ratings
                        vote_int = int(vote)
                        total_stars += vote_int
                        star_count += 1
                    except ValueError:
                        tallies[vote] = tallies.get(vote, 0) + 1

                responded.append({**m, 'submitted_at': str(r_data['submitted_at']), 'vote': vote})
            else:
                not_responded.append(m)

        return jsonify({
            'responded': responded,
            'not_responded': not_responded,
            'total': len(all_members),
            'response_rate': round(len(responded) / len(all_members) * 100) if all_members else 0,
            'tallies': tallies,
            'average_stars': round(total_stars / star_count, 1) if star_count > 0 else 0
        }), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@surveys_bp.route('/<int:survey_id>/respond', methods=['POST'])
@jwt_required()
def submit_response(survey_id):
    member_id = get_jwt_identity()
    conn = get_db()
    try:
        import json as json_lib
        data = request.get_json()
        with conn.cursor() as cursor:
            cursor.execute("SELECT active, deadline FROM surveys WHERE id = %s", (survey_id,))
            survey = cursor.fetchone()
            
            if not survey:
                return jsonify({'message': 'Survey not found'}), 404
                
            if not survey['active']:
                return jsonify({'message': 'This survey is no longer active'}), 400
                
            if survey['deadline']:
                from datetime import date
                if survey['deadline'] < date.today():
                    return jsonify({'message': 'The deadline for this survey has passed'}), 400
                    
            # Upsert — one response per member per survey
            cursor.execute("""
                INSERT INTO survey_responses (survey_id, member_id, answers)
                VALUES (%s, %s, %s)
                ON CONFLICT (survey_id, member_id) 
                DO UPDATE SET answers = EXCLUDED.answers, submitted_at = CURRENT_TIMESTAMP
            """, (survey_id, member_id, json.dumps(data.get('answers', {}))))
            conn.commit()

        # Emit real-time update to admin room
        try:
            socketio.emit('survey_update', {'survey_id': survey_id}, room='admin_dashboard')
        except Exception as se:
            logger.warning(f'Socket emit failed: {se}')

        return jsonify({'message': 'Response submitted'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()
