import requests
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required
from config.db import get_db
import xml.etree.ElementTree as ET
import re

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

FEED_SOURCES = [
    {'url': 'http://feeds.bbci.co.uk/news/world/rss.xml',    'source': 'BBC News'},
    {'url': 'https://www.aljazeera.com/xml/rss/all.xml',     'source': 'Al Jazeera'},
    {'url': 'https://feeds.skynews.com/feeds/rss/world.xml', 'source': 'Sky News'},
    {'url': 'https://gcaptain.com/feed/',                    'source': 'gCaptain Maritime'},
    {'url': 'https://www.theafricareport.com/feed/',         'source': 'The Africa Report'},
    {'url': 'https://rssfeeds.usatoday.com/usatoday-NewsTopStories', 'source': 'USA Today'},
]

HEADERS = {'User-Agent': 'Mozilla/5.0 (compatible; CUBAGNewsBot/1.0)'}

def _parse_feed(source_config):
    """Fetch and parse one RSS feed, returning a list of article dicts."""
    results = []
    try:
        res = requests.get(source_config['url'], headers=HEADERS, timeout=5, verify=False)
        if not res.ok:
            return results
        root = ET.fromstring(res.content)
        for item in root.findall('./channel/item')[:8]:
            title_el     = item.find('title')
            link_el      = item.find('link')
            pubdate_el   = item.find('pubDate')
            desc_el      = item.find('description')
            content_el   = item.find('{http://purl.org/rss/1.0/modules/content/}encoded')
            media_el     = item.find('{http://search.yahoo.com/mrss/}thumbnail')
            media_cont   = item.find('{http://search.yahoo.com/mrss/}content')

            t_str    = (title_el.text   or '').strip()  if title_el   is not None else ''
            l_str    = (link_el.text    or '').strip()  if link_el    is not None else ''
            d_str    = (pubdate_el.text or '').strip()  if pubdate_el is not None else ''
            desc_str = (desc_el.text    or '').strip()  if desc_el    is not None else ''
            c_str    = (content_el.text or desc_str)    if content_el is not None else desc_str

            # Try to find a thumbnail image
            thumbnail = ''
            if media_el is not None and media_el.get('url'):
                thumbnail = media_el.get('url')
            elif media_cont is not None and media_cont.get('url'):
                thumbnail = media_cont.get('url')
            elif c_str:
                img_match = re.search(r'<img[^>]+src=["\']([^"\'> ]+)', c_str)
                if img_match:
                    thumbnail = img_match.group(1)

            clean_desc = re.sub(r'<[^>]+>', '', desc_str).strip()

            # Parse pubDate for sorting (fall back to epoch 0 if unparsable)
            try:
                from email.utils import parsedate_to_datetime
                pub_ts = parsedate_to_datetime(d_str).timestamp() if d_str else 0
            except Exception:
                pub_ts = 0

            results.append({
                'title':       t_str,
                'link':        l_str,
                'pubDate':     d_str,
                'pub_ts':      pub_ts,
                'description': clean_desc,
                'thumbnail':   thumbnail,
                'source':      source_config['source'],
            })
    except Exception as e:
        print(f"Feed error [{source_config['source']}]: {e}")
    return results


import threading
import time as _time

# ─── In-memory news cache ─────────────────────────────────────────────────────
_news_cache = []
_cache_lock = threading.Lock()
_cache_populated = threading.Event()

def _refresh_cache():
    """Fetch all feeds and update the in-memory cache."""
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    all_items = []
    for s in FEED_SOURCES:
        try:
            all_items.extend(_parse_feed(s))
        except Exception as e:
            print(f"[NewsCache] Feed error [{s['source']}]: {e}")
    all_items.sort(key=lambda x: x.get('pub_ts', 0), reverse=True)
    for item in all_items:
        item.pop('pub_ts', None)
    with _cache_lock:
        global _news_cache
        _news_cache = all_items[:30]
    _cache_populated.set()
    print(f"[NewsCache] Refreshed — {len(_news_cache)} articles cached.")

def _cache_worker():
    """Background daemon that refreshes the cache every 10 minutes."""
    while True:
        try:
            _refresh_cache()
        except Exception as e:
            print(f"[NewsCache] Worker error: {e}")
        _time.sleep(600)  # 10 minutes

def start_news_worker():
    """Start the background worker thread."""
    worker = threading.Thread(target=_cache_worker, daemon=True, name='news-cache-worker')
    worker.start()
    print("[NewsCache] Background worker started.")

@news_bp.route('/global', methods=['GET'])
def get_global_news():
    """Return cached news — refreshed every 10 min by background thread."""
    # Wait up to 20s for first load on cold start
    _cache_populated.wait(timeout=20)
    with _cache_lock:
        return jsonify(_news_cache), 200

