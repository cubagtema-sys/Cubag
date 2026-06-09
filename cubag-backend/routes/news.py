import requests
import logging
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required
from config.db import get_db
import xml.etree.ElementTree as ET
import re
import threading
import time as _time
from utils import admin_required, sub_admin_required

# Configure logging
logger = logging.getLogger(__name__)

news_bp = Blueprint('news', __name__)

@news_bp.route('/blog', methods=['GET'])
def get_blogs():
    try:
        # Pagination parameters
        try:
            page = max(1, int(request.args.get('page', 1)))
        except Exception:
            page = 1
        try:
            per_page = int(request.args.get('per_page', 20))
        except Exception:
            per_page = 20
        per_page = max(1, min(per_page, 100))
        offset = (page - 1) * per_page

        conn = get_db()
        with conn.cursor() as cursor:
            cursor.execute("SELECT * FROM news_blog ORDER BY created_at DESC LIMIT %s OFFSET %s", (per_page, offset))
            posts = cursor.fetchall()

            # Optional: return pagination metadata
            cursor.execute("SELECT COUNT(*) as total FROM news_blog")
            total = cursor.fetchone().get('total', 0)

        return jsonify({
            'items': posts,
            'page': page,
            'per_page': per_page,
            'total': total
        }), 200
    except Exception as e:
        logger.exception("Error in get_blogs: %s", e)
        return jsonify({'error': str(e)}), 500
    finally:
        if 'conn' in locals():
            conn.close()

@news_bp.route('/blog', methods=['POST'])
@sub_admin_required('announcements')
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
@sub_admin_required('announcements')
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
    { 'url': 'https://gcaptain.com/feed/',                  'source': 'gCaptain',            'color': '#f08232' },
    { 'url': 'https://www.hellenicshippingnews.com/feed/',  'source': 'Hellenic Shipping',   'color': '#1a6b3c' },
    { 'url': 'https://splash247.com/feed/',                 'source': 'Splash247',           'color': '#0066cc' },
    { 'url': 'https://www.ship-technology.com/feed/',       'source': 'Ship Technology',     'color': '#c0392b' },
    { 'url': 'https://www.freightwaves.com/news/feed',      'source': 'FreightWaves',        'color': '#003580' },
]

HEADERS = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}

def _parse_feed(source_config):
    """Fetch and parse one RSS feed, returning a list of article dicts."""
    results = []
    try:
        # Increase timeout slightly and handle errors more gracefully
        # Enforce TLS verification; do not disable certificate checks
        res = requests.get(source_config['url'], headers=HEADERS, timeout=12, verify=True)
        if not res.ok:
            logger.warning(f"Feed server returned {res.status_code} for {source_config['source']}")
            return results

        # Clean up XML string to prevent encoding errors
        content = res.content.decode('utf-8', errors='replace')
        # Some feeds have leading whitespace
        content = content.strip()

        root = ET.fromstring(content)
        for item in root.findall('./channel/item')[:10]:
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

            # Parse pubDate for sorting
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
                'sourceColor': source_config.get('color', '#3b82f6'),
            })
    except Exception as e:
        logger.error(f"Feed error [{source_config['source']}]: {e}")
    return results

# ─── In-memory news cache ─────────────────────────────────────────────────────
_news_cache = []
_cache_lock = threading.Lock()
_cache_populated = threading.Event()

# Fallback articles if all feeds fail
_MOCK_ARTICLES = [
    {
        'title': 'CUBAG Digital Platform Optimization Complete',
        'link': 'https://cubag.org',
        'pubDate': 'Wed, 03 Jun 2026 08:00:00 GMT',
        'description': 'The Secretariat is pleased to announce the successful migration of our enterprise platform to Flutter, providing enhanced performance and mobile support for all members.',
        'thumbnail': '',
        'source': 'CUBAG Official',
        'sourceColor': '#f08232',
    },
    {
        'title': 'West Africa Maritime Traffic Overview',
        'link': 'https://cubag.org',
        'pubDate': 'Wed, 03 Jun 2026 07:30:00 GMT',
        'description': 'Maritime activity in the Gulf of Guinea remains steady. Member firms are advised to monitor live vessel movements via the CUBAG Intelligence Hub.',
        'thumbnail': '',
        'source': 'Logistics Hub',
        'sourceColor': '#1a6b3c',
    }
]

def _refresh_cache():
    """Fetch all feeds and update the in-memory cache."""
    logger.info("[NewsCache] Refreshing feeds...")
    all_items = []

    # Try fetching from real sources
    for s in FEED_SOURCES:
        try:
            feed_items = _parse_feed(s)
            if feed_items:
                all_items.extend(feed_items)
                logger.info(f"[NewsCache] Fetched {len(feed_items)} items from {s['source']}")
        except Exception as e:
            logger.error(f"[NewsCache] Feed error [{s['source']}]: {e}")

    # Sort by timestamp
    all_items.sort(key=lambda x: x.get('pub_ts', 0), reverse=True)

    # Remove timestamp field before caching
    for item in all_items:
        item.pop('pub_ts', None)

    with _cache_lock:
        global _news_cache
        if all_items:
            _news_cache = all_items[:40]
            logger.info(f"[NewsCache] Refreshed with {len(_news_cache)} real articles.")
        else:
            # Fallback to mock data if all feeds failed
            _news_cache = _MOCK_ARTICLES
            logger.warning("[NewsCache] All feeds failed. Using mock fallback data.")

    _cache_populated.set()

def _cache_worker():
    """Background daemon that refreshes the cache every 15 minutes."""
    while True:
        try:
            _refresh_cache()
        except Exception as e:
            logger.error(f"[NewsCache] Worker error: {e}")
        _time.sleep(900)  # 15 minutes

def start_news_worker():
    """Start the background worker thread."""
    worker = threading.Thread(target=_cache_worker, daemon=True, name='news-cache-worker')
    worker.start()
    logger.info("[NewsCache] Background worker started.")

@news_bp.route('/global', methods=['GET'])
def get_global_news():
    """Return cached news — refreshed by background thread."""
    # Don't block — if cache isn't ready yet, return mock articles immediately.
    # The client can refresh after a few seconds to get real data.
    if not _cache_populated.is_set():
        logger.info("[NewsCache] Cache not ready yet, returning mock fallback.")
        return jsonify(_MOCK_ARTICLES), 200

    with _cache_lock:
        articles = list(_news_cache)

    if not articles:
        return jsonify(_MOCK_ARTICLES), 200
    return jsonify(articles), 200

@news_bp.route('/refresh', methods=['POST'])
@sub_admin_required('announcements')
def trigger_refresh():
    """Admin endpoint to manually trigger a news refresh."""
    threading.Thread(target=_refresh_cache, daemon=True).start()
    return jsonify({'message': 'Refresh triggered in background'}), 200
