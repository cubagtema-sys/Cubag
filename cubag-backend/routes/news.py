import requests
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required
from config.db import get_db

news_bp = Blueprint('news', __name__)

@news_bp.route('/blog', methods=['GET'])
def get_blogs():
    try:
        conn = get_db()
        with conn.cursor() as cursor:
            cursor.execute("SELECT * FROM news_blog ORDER BY created_at DESC")
            posts = cursor.fetchall()
        return jsonify(posts), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if 'conn' in locals():
            conn.close()

@news_bp.route('/blog', methods=['POST'])
@jwt_required()
def create_blog():
    data = request.json
    try:
        conn = get_db()
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO news_blog (title, category, content, image_url, author)
                VALUES (%s, %s, %s, %s, %s) RETURNING id
            """, (
                data.get('title'),
                data.get('category', 'General'),
                data.get('content'),
                data.get('image_url', ''),
                data.get('author', 'CUBAG Admin')
            ))
            new_id = cursor.fetchone()['id']
        conn.commit()
        return jsonify({'message': 'Blog post created', 'id': new_id}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if 'conn' in locals():
            conn.close()

@news_bp.route('/blog/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_blog(id):
    try:
        conn = get_db()
        with conn.cursor() as cursor:
            cursor.execute("DELETE FROM news_blog WHERE id = %s", (id,))
        conn.commit()
        return jsonify({'message': 'Blog post deleted'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        if 'conn' in locals():
            conn.close()

@news_bp.route('/global', methods=['GET'])
def get_global_news():
    # Fetch automated RSS feed using rss2json API (free public logistics news)
    # Using Splash247 as a reliable source of maritime/logistics news
    rss_url = "https://splash247.com/feed/"
    api_url = f"https://api.rss2json.com/v1/api.json?rss_url={rss_url}"
    try:
        response = requests.get(api_url, timeout=10)
        if response.ok:
            data = response.json()
            return jsonify(data.get('items', [])), 200
        else:
            return jsonify([]), 500
    except Exception as e:
        return jsonify([]), 500
