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

const NEWS_PER_PAGE = 10

export default function LiveData() {
  const [forex, setForex]               = useState({ USD: '...', EUR: '...', GBP: '...', CNY: '...' })
  const [globalNews, setGlobalNews]     = useState([])
  const [newsLoading, setNewsLoading]   = useState(true)
  const [forexLoading, setForexLoading] = useState(true)
  const [lastUpdated, setLastUpdated]   = useState(new Date().toLocaleTimeString())
  const [newsPage, setNewsPage]         = useState(1)

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
        setGlobalNews(all)          // store ALL items — pagination slices them
        setNewsPage(1)              // reset to page 1 on each refresh
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
    <AppLayout title="Intelligence Hub">
      <div style={{ maxWidth: 1000, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16, paddingBottom: 40 }}>

        {/* Header removed as it is now in the header */}
        <div style={{ display: 'flex', justifyContent: 'flex-end', alignItems: 'flex-start', paddingBottom: 4 }}>
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
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 4 }}>
            <h3 style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: '1.1rem', fontWeight: 800, color: 'var(--text-primary)', margin: 0 }}>
              <span className="material-symbols-outlined" style={{ color: '#3b82f6', fontSize: '1.4rem' }}>directions_boat</span>
              Maritime &amp; Customs Intelligence
            </h3>
            {!newsLoading && globalNews.length > 0 && (
              <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontWeight: 600 }}>
                {globalNews.length} articles
              </span>
            )}
          </div>
          <p style={{ fontSize: '0.7rem', color: 'var(--text-muted)', marginBottom: 12 }}>
            gCaptain · Hellenic Shipping · Splash247 · World Maritime News · Ship Technology · FreightWaves — sorted by latest
          </p>

          {newsLoading ? (
            <div style={{ padding: 40, textAlign: 'center', color: 'var(--text-muted)' }}>
              <div className="spinner" style={{ margin: '0 auto 12px' }} />
              Syncing maritime news feeds...
            </div>
          ) : (() => {
            const totalPages = Math.max(1, Math.ceil(globalNews.length / NEWS_PER_PAGE))
            const pageItems  = globalNews.slice((newsPage - 1) * NEWS_PER_PAGE, newsPage * NEWS_PER_PAGE)

            const goTo = (n) => {
              setNewsPage(n)
              window.scrollTo({ top: 0, behavior: 'smooth' })
            }

            return (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                {pageItems.map((news, i) => (
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

                {/* ── Pagination ── */}
                {totalPages > 1 && (
                  <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 6, padding: '16px 0 8px' }}>
                    <button
                      onClick={() => goTo(Math.max(1, newsPage - 1))}
                      disabled={newsPage === 1}
                      style={{ padding: '7px 16px', borderRadius: 8, border: '1px solid var(--border-subtle)', background: 'var(--bg-card)', color: newsPage === 1 ? 'var(--text-muted)' : 'var(--text-primary)', cursor: newsPage === 1 ? 'default' : 'pointer', fontWeight: 700, fontSize: '0.8rem', opacity: newsPage === 1 ? 0.45 : 1 }}
                    >← Prev</button>

                    {Array.from({ length: totalPages }, (_, i) => i + 1)
                      .filter(n => n === 1 || n === totalPages || Math.abs(n - newsPage) <= 1)
                      .reduce((acc, n, idx, arr) => {
                        if (idx > 0 && n - arr[idx - 1] > 1) acc.push('…')
                        acc.push(n)
                        return acc
                      }, [])
                      .map((n, idx) =>
                        n === '…'
                          ? <span key={`e${idx}`} style={{ padding: '0 4px', color: 'var(--text-muted)', fontSize: '0.8rem' }}>…</span>
                          : <button key={n} onClick={() => goTo(n)} style={{ width: 36, height: 36, borderRadius: 8, border: 'none', background: newsPage === n ? 'var(--brand-primary)' : 'var(--bg-card)', color: newsPage === n ? '#fff' : 'var(--text-secondary)', fontWeight: 800, fontSize: '0.82rem', cursor: 'pointer' }}>{n}</button>
                      )
                    }

                    <button
                      onClick={() => goTo(Math.min(totalPages, newsPage + 1))}
                      disabled={newsPage === totalPages}
                      style={{ padding: '7px 16px', borderRadius: 8, border: '1px solid var(--border-subtle)', background: 'var(--bg-card)', color: newsPage === totalPages ? 'var(--text-muted)' : 'var(--text-primary)', cursor: newsPage === totalPages ? 'default' : 'pointer', fontWeight: 700, fontSize: '0.8rem', opacity: newsPage === totalPages ? 0.45 : 1 }}
                    >Next →</button>
                  </div>
                )}

              </div>
            )
          })()}
        </section>

      </div>
    </AppLayout>
  )
}
