import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

// Maritime, Customs & Logistics feeds — curated for CUBAG members
const FEED_SOURCES = [
  { url: 'https://gcaptain.com/feed/',                        source: 'gCaptain',            color: '#f08232', icon: 'anchor' },
  { url: 'https://www.hellenicshippingnews.com/feed/',        source: 'Hellenic Shipping',   color: '#1a6b3c', icon: 'directions_boat' },
  { url: 'https://splash247.com/feed/',                       source: 'Splash247',           color: '#0066cc', icon: 'waves' },
  { url: 'https://worldmaritimenews.com/feed/',               source: 'World Maritime News', color: '#7c3aed', icon: 'public' },
  { url: 'https://www.ship-technology.com/feed/',             source: 'Ship Technology',     color: '#c0392b', icon: 'precision_manufacturing' },
  { url: 'https://www.freightwaves.com/news/feed',            source: 'FreightWaves',        color: '#003580', icon: 'local_shipping' },
]

function parseFeedXml(xml, sourceConfig) {
  try {
    const parser = new DOMParser()
    const doc = parser.parseFromString(xml, 'text/xml')
    const items = Array.from(doc.querySelectorAll('item')).slice(0, 8)
    return items.map(item => {
      const get = (tag) => item.querySelector(tag)?.textContent?.trim() || ''
      const getAttr = (tag, attr) => item.querySelector(tag)?.getAttribute(attr) || ''

      const title   = get('title')
      const link    = get('link') || getAttr('link', 'href')
      const pubDate = get('pubDate')
      const desc    = get('description')

      // Extract thumbnail: try media:thumbnail, media:content, then img in content:encoded
      let thumbnail = getAttr('thumbnail', 'url') || getAttr('content', 'url') || ''
      if (!thumbnail) {
        const content = get('encoded') || desc
        const match = content.match(/<img[^>]+src=["']([^"'> ]+)/i)
        if (match) thumbnail = match[1]
      }

      const cleanDesc = desc.replace(/<[^>]+>/g, '').trim()

      let pubTs = 0
      try { pubTs = pubDate ? new Date(pubDate).getTime() : 0 } catch {}

      return { title, link, pubDate, pubTs, description: cleanDesc, thumbnail, source: sourceConfig.source, sourceColor: sourceConfig.color }
    })
  } catch { return [] }
}

// CORS proxy chain — tries each in order until one works
const CORS_PROXIES = [
  (url) => `https://corsproxy.io/?${encodeURIComponent(url)}`,
  (url) => `https://api.allorigins.win/get?url=${encodeURIComponent(url)}&timestamp=${Date.now()}`,
  (url) => `https://api.cors.lol/?url=${encodeURIComponent(url)}`,
]

async function fetchWithProxy(rawUrl) {
  for (const buildProxy of CORS_PROXIES) {
    try {
      const proxyUrl = buildProxy(rawUrl)
      const res = await fetch(proxyUrl, { signal: AbortSignal.timeout(8000) })
      if (!res.ok) continue
      const text = await res.text()
      // allorigins wraps in JSON {contents: '...'}, others return raw XML
      try {
        const json = JSON.parse(text)
        if (json.contents) return json.contents
      } catch { /* not JSON — it's raw XML */ }
      return text
    } catch { /* try next proxy */ }
  }
  return null
}

async function fetchOneFeed(sourceConfig) {
  const xml = await fetchWithProxy(sourceConfig.url)
  if (!xml) return []
  return parseFeedXml(xml, sourceConfig)
}

export default function LiveData() {
  const [forex, setForex]               = useState({ USD: '...', EUR: '...', GBP: '...', CNY: '...' })
  const [globalNews, setGlobalNews]     = useState([])
  const [newsLoading, setNewsLoading]   = useState(true)
  const [forexLoading, setForexLoading] = useState(true)
  const [lastUpdated, setLastUpdated]   = useState(new Date().toLocaleTimeString())

  // ── Fetch Forex ──────────────────────────────────────────────────────────────
  useEffect(() => {
    async function loadForex() {
      setForexLoading(true)
      try {
        const res = await fetch('https://open.er-api.com/v6/latest/GHS')
        if (res.ok) {
          const data = await res.json()
          setForex({
            USD: (1 / data.rates['USD']).toFixed(2),
            EUR: (1 / data.rates['EUR']).toFixed(2),
            GBP: (1 / data.rates['GBP']).toFixed(2),
            CNY: (1 / data.rates['CNY']).toFixed(2),
          })
        }
      } catch {}
      setForexLoading(false)
    }
    loadForex()
    const id = setInterval(loadForex, 300000) // every 5 min
    return () => clearInterval(id)
  }, [])

  // ── Fetch News (browser-side, parallel) ──────────────────────────────────────
  useEffect(() => {
    async function loadNews() {
      setNewsLoading(true)
      try {
        // Launch all fetches in parallel
        const results = await Promise.allSettled(FEED_SOURCES.map(fetchOneFeed))
        let all = []
        results.forEach(r => { if (r.status === 'fulfilled') all = [...all, ...r.value] })
        all.sort((a, b) => (b.pubTs || 0) - (a.pubTs || 0))
        all.forEach(i => delete i.pubTs)
        setGlobalNews(all.slice(0, 30))
        setLastUpdated(new Date().toLocaleTimeString())
      } catch (e) {
        console.error('News load error', e)
      }
      setNewsLoading(false)
    }
    loadNews()
    const id = setInterval(loadNews, 600000) // every 10 min
    return () => clearInterval(id)
  }, [])

  return (
    <AppLayout title="Intelligence">
      <div style={{ maxWidth: 1000, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16, paddingBottom: 40 }}>

        {/* Header */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '1px solid var(--border-subtle)', paddingBottom: 12 }}>
          <div>
            <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: 2 }}>Intelligence Hub</h2>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.8rem', margin: 0 }}>Live monitoring of global maritime, shipping & customs news.</p>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, color: '#10b981', fontWeight: 700, fontSize: '0.65rem', textTransform: 'uppercase' }}>
              <span className="live-dot" style={{ width: 6, height: 6 }} />
              Live
            </div>
            <div style={{ color: 'var(--text-muted)', fontSize: '0.65rem', marginTop: 2 }}>{lastUpdated}</div>
          </div>
        </div>

        {/* Forex */}
        <div className="feed-card">
          <div className="card-header" style={{ padding: '10px 14px' }}>
            <span className="card-title" style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: '0.85rem' }}>
              <span className="material-symbols-outlined" style={{ color: 'var(--brand-primary)', fontSize: '1rem' }}>currency_exchange</span>
              Live Forex Rates
            </span>
          </div>
          <div className="card-body" style={{ padding: '10px 14px' }}>
            <div className="forex-grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(100px, 1fr))', gap: 8 }}>
              {Object.entries(forex).map(([currency, rate]) => (
                <div key={currency} className="forex-item" style={{ padding: '8px', borderRadius: 8, background: 'var(--bg-base)', border: '1px solid var(--border-subtle)', textAlign: 'center' }}>
                  <div style={{ fontSize: '0.65rem', fontWeight: 600, color: 'var(--text-muted)' }}>{currency}/GHS</div>
                  <div style={{ fontFamily: 'monospace', fontWeight: 800, fontSize: '1rem', margin: '2px 0' }}>
                    {forexLoading ? '...' : rate}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* News Feed */}
        <section>
          <h3 style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4, fontSize: '1.1rem', fontWeight: 800, color: 'var(--text-primary)' }}>
            <span className="material-symbols-outlined" style={{ color: '#3b82f6', fontSize: '1.4rem' }}>public</span>
            Maritime & Customs Intelligence
          </h3>
          <p style={{ fontSize: '0.7rem', color: 'var(--text-muted)', marginBottom: 12 }}>
            gCaptain · Hellenic Shipping · Splash247 · World Maritime News · Ship Technology · FreightWaves — sorted by latest
          </p>

          {newsLoading ? (
            <div style={{ padding: 40, textAlign: 'center', color: 'var(--text-muted)' }}>
              <div className="spinner" style={{ margin: '0 auto 12px' }} />
              Syncing global news feeds...
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {globalNews.map((news, i) => (
                <a key={i} href={news.link} target="_blank" rel="noreferrer" style={{ textDecoration: 'none', color: 'inherit' }}>
                  <div className="feed-card" style={{ padding: '16px', borderRadius: 14, display: 'flex', gap: 16, alignItems: 'flex-start', cursor: 'pointer', transition: 'transform 0.15s' }}
                    onMouseEnter={e => e.currentTarget.style.transform = 'translateY(-2px)'}
                    onMouseLeave={e => e.currentTarget.style.transform = 'translateY(0)'}
                  >
                    {news.thumbnail && (
                      <img src={news.thumbnail} alt="" style={{ width: 80, height: 80, objectFit: 'cover', borderRadius: 8, flexShrink: 0, background: 'var(--bg-base)' }}
                        onError={e => { e.target.style.display = 'none' }} />
                    )}
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 5, flexWrap: 'wrap' }}>
                        {news.source && (
                          <span style={{ background: (news.sourceColor || '#3b82f6') + '18', color: news.sourceColor || '#3b82f6', padding: '1px 8px', borderRadius: 20, fontSize: '0.6rem', fontWeight: 900, textTransform: 'uppercase', letterSpacing: '0.05em', border: `1px solid ${news.sourceColor || '#3b82f6'}30`, flexShrink: 0 }}>
                            {news.source}
                          </span>
                        )}
                        <span style={{ fontSize: '0.68rem', color: 'var(--text-muted)', fontWeight: 600 }}>
                          {news.pubDate ? new Date(news.pubDate).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : ''}
                        </span>
                      </div>
                      <h4 style={{ margin: '0 0 6px 0', fontSize: '0.95rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.3, display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>
                        {news.title}
                      </h4>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>
                        {news.description}
                      </div>
                    </div>
                  </div>
                </a>
              ))}
              {globalNews.length === 0 && (
                <div style={{ padding: 20, textAlign: 'center', color: 'var(--text-muted)', background: 'var(--bg-elevated)', borderRadius: 12, fontSize: '0.85rem' }}>
                  Global feed currently unavailable. Please try again later.
                </div>
              )}
            </div>
          )}
        </section>

      </div>
    </AppLayout>
  )
}
