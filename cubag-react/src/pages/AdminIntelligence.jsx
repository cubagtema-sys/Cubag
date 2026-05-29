import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

// Reuse the same curated maritime feed sources
const FEED_SOURCES = [
  { url: 'https://gcaptain.com/feed/',                  source: 'gCaptain',            color: '#f08232' },
  { url: 'https://www.hellenicshippingnews.com/feed/',  source: 'Hellenic Shipping',   color: '#1a6b3c' },
  { url: 'https://splash247.com/feed/',                 source: 'Splash247',           color: '#0066cc' },
  { url: 'https://worldmaritimenews.com/feed/',         source: 'World Maritime News', color: '#7c3aed' },
  { url: 'https://www.ship-technology.com/feed/',       source: 'Ship Technology',     color: '#c0392b' },
  { url: 'https://www.freightwaves.com/news/feed',      source: 'FreightWaves',        color: '#003580' },
]

function parseFeedXml(xml, sourceConfig) {
  try {
    const parser = new DOMParser()
    const doc = parser.parseFromString(xml, 'text/xml')
    return Array.from(doc.querySelectorAll('item')).slice(0, 5).map(item => {
      const get = (tag) => item.querySelector(tag)?.textContent?.trim() || ''
      const getAttr = (tag, attr) => item.querySelector(tag)?.getAttribute(attr) || ''
      const title   = get('title')
      const link    = get('link') || getAttr('link', 'href')
      const pubDate = get('pubDate')
      let thumbnail = getAttr('thumbnail', 'url') || getAttr('content', 'url') || ''
      if (!thumbnail) {
        const c = get('encoded') || get('description')
        const m = c.match(/<img[^>]+src=["']([^"'> ]+)/i)
        if (m) thumbnail = m[1]
      }
      let pubTs = 0; try { pubTs = pubDate ? new Date(pubDate).getTime() : 0 } catch {}
      return { title, link, pubDate, pubTs, thumbnail, source: sourceConfig.source, sourceColor: sourceConfig.color }
    })
  } catch { return [] }
}

const CORS_PROXIES = [
  (url) => `https://corsproxy.io/?${encodeURIComponent(url)}`,
  (url) => `https://api.allorigins.win/get?url=${encodeURIComponent(url)}&timestamp=${Date.now()}`,
  (url) => `https://api.cors.lol/?url=${encodeURIComponent(url)}`,
]

async function fetchWithProxy(rawUrl) {
  for (const buildProxy of CORS_PROXIES) {
    try {
      const res = await fetch(buildProxy(rawUrl), { signal: AbortSignal.timeout(8000) })
      if (!res.ok) continue
      const text = await res.text()
      try { const j = JSON.parse(text); if (j.contents) return j.contents } catch {}
      return text
    } catch {}
  }
  return null
}

async function fetchOneFeed(s) {
  const xml = await fetchWithProxy(s.url)
  if (!xml) return []
  return parseFeedXml(xml, s)
}

export default function AdminIntelligence() {
  const [globalNews, setGlobalNews] = useState([])
  const [loading, setLoading]       = useState(true)
  const [lastUpdated, setLastUpdated] = useState('')

  useEffect(() => {
    async function load() {
      setLoading(true)
      const results = await Promise.allSettled(FEED_SOURCES.map(fetchOneFeed))
      let all = []
      results.forEach(r => { if (r.status === 'fulfilled') all = [...all, ...r.value] })
      all.sort((a, b) => (b.pubTs || 0) - (a.pubTs || 0))
      all.forEach(i => delete i.pubTs)
      setGlobalNews(all.slice(0, 12))
      setLastUpdated(new Date().toLocaleTimeString())
      setLoading(false)
    }
    load()
  }, [])

  return (
    <AppLayout title="Intelligence Hub">
      <div style={{ maxWidth: 800, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16, paddingBottom: 60 }}>

        {/* Page Title removed as it is now in the header */}

        {/* Status Banner */}
        <div style={{ padding: '16px 20px', background: 'var(--bg-elevated)', borderRadius: 12, border: '1px solid rgba(16,185,129,0.3)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, color: '#10b981', marginBottom: 6 }}>
            <span className="material-symbols-outlined">anchor</span>
            <h2 style={{ margin: 0, fontSize: '1.1rem', fontWeight: 800 }}>Maritime Intelligence Active</h2>
          </div>
          <p style={{ margin: 0, color: 'var(--text-secondary)', fontSize: '0.9rem', lineHeight: 1.5 }}>
            The Intelligence Hub is directly connected to <strong>6 maritime and customs news networks</strong> — 
            gCaptain, Hellenic Shipping News, Splash247, World Maritime News, Ship Technology, and FreightWaves.
            Live data is pulled 24/7 for all CUBAG members.
          </p>
          <div style={{ marginTop: 10, display: 'flex', gap: 6, flexWrap: 'wrap' }}>
            {FEED_SOURCES.map(s => (
              <span key={s.source} style={{ fontSize: '0.6rem', fontWeight: 800, padding: '2px 8px', borderRadius: 20, background: s.color + '18', color: s.color, border: `1px solid ${s.color}30`, textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                {s.source}
              </span>
            ))}
          </div>
        </div>

        {/* Feed Preview */}
        <h3 style={{ fontSize: '1rem', fontWeight: 800, marginTop: 4, display: 'flex', alignItems: 'center', gap: 6 }}>
          <span className="material-symbols-outlined" style={{ color: '#3b82f6' }}>directions_boat</span>
          Live Maritime Feed Preview
          {lastUpdated && <span style={{ fontSize: '0.65rem', fontWeight: 600, color: 'var(--text-muted)', marginLeft: 4 }}>• updated {lastUpdated}</span>}
        </h3>

        {loading ? (
          <div style={{ padding: 40, textAlign: 'center', color: 'var(--text-muted)' }}>
            <div className="spinner" style={{ margin: '0 auto 12px' }} />
            Syncing maritime intelligence feeds...
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {globalNews.map((news, i) => (
              <a key={i} href={news.link} target="_blank" rel="noreferrer" style={{ textDecoration: 'none', color: 'inherit' }}>
                <div className="feed-card" style={{ padding: '14px 16px', borderRadius: 12, display: 'flex', gap: 12, alignItems: 'flex-start', cursor: 'pointer', transition: 'transform 0.15s' }}
                  onMouseEnter={e => e.currentTarget.style.transform = 'translateY(-2px)'}
                  onMouseLeave={e => e.currentTarget.style.transform = 'translateY(0)'}
                >
                  {news.thumbnail && (
                    <img src={news.thumbnail} alt="" style={{ width: 64, height: 64, objectFit: 'cover', borderRadius: 8, flexShrink: 0 }}
                      onError={e => { e.target.style.display = 'none' }} />
                  )}
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 5, flexWrap: 'wrap' }}>
                      <span style={{ background: (news.sourceColor || '#3b82f6') + '18', color: news.sourceColor || '#3b82f6', padding: '1px 8px', borderRadius: 20, fontSize: '0.58rem', fontWeight: 900, textTransform: 'uppercase', letterSpacing: '0.05em', border: `1px solid ${news.sourceColor || '#3b82f6'}30`, flexShrink: 0 }}>
                        {news.source}
                      </span>
                      <span style={{ fontSize: '0.67rem', color: 'var(--text-muted)', fontWeight: 600 }}>
                        {news.pubDate ? new Date(news.pubDate).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : ''}
                      </span>
                    </div>
                    <h4 style={{ margin: '0 0 4px 0', fontSize: '0.9rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.3, display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>
                      {news.title}
                    </h4>
                    <span style={{ fontSize: '0.7rem', color: '#3b82f6', fontWeight: 700 }}>Read full article ↗</span>
                  </div>
                </div>
              </a>
            ))}
            {globalNews.length === 0 && (
              <div style={{ padding: 20, textAlign: 'center', color: 'var(--text-muted)', background: 'var(--bg-elevated)', borderRadius: 12 }}>
                Maritime feed currently unavailable.
              </div>
            )}
          </div>
        )}

      </div>
    </AppLayout>
  )
}
