from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from config.db import get_db

events_bp = Blueprint('events', __name__)
surveys_bp = Blueprint('surveys', __name__)

# ─────────────────────────────────────────────
#  EVENTS
# ─────────────────────────────────────────────

@events_bp.route('/', methods=['GET'])
@jwt_required()
def get_events():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT * FROM events WHERE date >= CURRENT_DATE ORDER BY date ASC")
            data = cursor.fetchall()
        return jsonify(data), 200
    finally:
        conn.close()

@events_bp.route('/', methods=['POST'])
@jwt_required()
def create_event():
    data = request.get_json()
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO events (title, description, date, time, location, capacity)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (data.get('title'), data.get('description'), data.get('date'),
                  data.get('time'), data.get('location'), data.get('capacity') or None))
            conn.commit()
        return jsonify({'message': 'Event created'}), 201
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@events_bp.route('/<int:event_id>', methods=['PUT'])
@jwt_required()
def update_event(event_id):
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
        return jsonify({'message': 'Event updated'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@events_bp.route('/<int:event_id>', methods=['DELETE'])
@jwt_required()
def delete_event(event_id):
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("DELETE FROM events WHERE id = %s", (event_id,))
            conn.commit()
        return jsonify({'message': 'Event deleted'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@events_bp.route('/admin/all', methods=['GET'])
@jwt_required()
def get_all_events_admin():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT * FROM events ORDER BY date DESC")
            data = cursor.fetchall()
        return jsonify(data), 200
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
        return jsonify(data), 200
    finally:
        conn.close()

@surveys_bp.route('/', methods=['POST'])
@jwt_required()
def create_survey():
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
        return jsonify({'message': 'Survey created'}), 201
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@surveys_bp.route('/<int:survey_id>', methods=['DELETE'])
@jwt_required()
def delete_survey(survey_id):
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("DELETE FROM survey_responses WHERE survey_id = %s", (survey_id,))
            cursor.execute("DELETE FROM surveys WHERE id = %s", (survey_id,))
            conn.commit()
        return jsonify({'message': 'Survey deleted'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@surveys_bp.route('/admin/all', methods=['GET'])
@jwt_required()
def get_all_surveys_admin():
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT * FROM surveys ORDER BY created_at DESC")
            data = cursor.fetchall()
        return jsonify(data), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()

@surveys_bp.route('/<int:survey_id>/participation', methods=['GET'])
@jwt_required()
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
                    ans = json.loads(r_data['answers']) if r_data['answers'] else {}
                except:
                    pass
                
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
            """, (survey_id, member_id, json_lib.dumps(data.get('answers', {}))))
            conn.commit()
        return jsonify({'message': 'Response submitted'}), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500
    finally:
        conn.close()
