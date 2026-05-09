import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

const API_URL = import.meta.env.VITE_API_URL

export default function LiveData() {
  const [forex, setForex] = useState({ USD: '...', EUR: '...', GBP: '...', CNY: '...' })
  const [loading, setLoading] = useState(true)
  const [lastUpdated, setLastUpdated] = useState(new Date().toLocaleTimeString())
  const [activeTab, setActiveTab] = useState('data')
  
  // Real-time feeds from Backend
  const [intelligence, setIntelligence] = useState({ ports: [], bunkers: [], alerts: [] })
  const [blogs, setBlogs] = useState([])
  const [globalNews, setGlobalNews] = useState([])

  useEffect(() => {
    async function loadData() {
      try {
        setLoading(true)
        // 1. Real-time Forex (Actual API)
        const forexRes = await fetch('https://open.er-api.com/v6/latest/GHS')
        if (forexRes.ok) {
          const data = await forexRes.json()
          setForex({
            USD: (1 / data.rates['USD']).toFixed(2),
            EUR: (1 / data.rates['EUR']).toFixed(2),
            GBP: (1 / data.rates['GBP']).toFixed(2),
            CNY: (1 / data.rates['CNY']).toFixed(2),
          })
        }

        // 2. Intelligence Hub (From CUBAG Admin)
        const intelRes = await fetch(`${API_URL}/intelligence`)
        if (intelRes.ok) setIntelligence(await intelRes.json())

        // 3. Official CUBAG Blogs
        const blogRes = await fetch(`${API_URL}/news/blog`)
        if (blogRes.ok) setBlogs(await blogRes.json())

        // 4. Global Logistics News (RSS Feed via backend)
        const globalRes = await fetch(`${API_URL}/news/global`)
        if (globalRes.ok) setGlobalNews(await globalRes.json())
        
        setLastUpdated(new Date().toLocaleTimeString())
      } catch (e) {
        console.error("Live Data load error", e)
      } finally {
        setLoading(false)
      }
    }

    loadData()
    const interval = setInterval(loadData, 60000) // Refresh every minute
    return () => clearInterval(interval)
  }, [])

  return (
    <AppLayout title="Intelligence">
      <div style={{ maxWidth: 1000, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16, paddingBottom: 40 }}>
        
        {/* Header summary */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '1px solid var(--border-subtle)', paddingBottom: 12 }}>
          <div>
            <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: 2 }}>Intelligence Hub</h2>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.8rem', margin: 0 }}>
              Live monitoring of global markets, logistics & news.
            </p>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, color: '#10b981', fontWeight: 700, fontSize: '0.65rem', textTransform: 'uppercase' }}>
              <span className="live-dot" style={{ width: 6, height: 6 }}></span>
              Live
            </div>
            <div style={{ color: 'var(--text-muted)', fontSize: '0.65rem', marginTop: 2 }}>{lastUpdated.split(' ')[0]}</div>
          </div>
        </div>

        {/* Tab Switcher */}
        <div style={{ display: 'flex', gap: 0, background: 'var(--bg-base)', borderRadius: 12, padding: 4, border: '1.5px solid var(--border-subtle)' }}>
          {[
            { id: 'data', label: 'Markets & Data', icon: 'analytics' },
            { id: 'news', label: 'News & Blog', icon: 'newspaper' }
          ].map(t => (
            <button
              key={t.id}
              onClick={() => setActiveTab(t.id)}
              style={{
                flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
                padding: '10px 12px', borderRadius: 10, border: 'none', cursor: 'pointer',
                fontSize: '0.8rem', fontWeight: activeTab === t.id ? 800 : 600,
                background: activeTab === t.id ? 'var(--brand-primary)' : 'transparent',
                color: activeTab === t.id ? '#fff' : 'var(--text-muted)',
                transition: 'all 0.2s ease',
                boxShadow: activeTab === t.id ? '0 2px 8px rgba(240,130,50,0.3)' : 'none'
              }}
            >
              <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>{t.icon}</span>
              {t.label}
            </button>
          ))}
        </div>

        {loading ? (
          <div style={{ padding: 40, textAlign: 'center', color: 'var(--text-muted)' }}>
            <div className="spinner" style={{ margin: '0 auto 12px' }} />
            Syncing intelligence feeds...
          </div>
        ) : activeTab === 'data' ? (
          /* ── MARKETS & DATA TAB ── */
          <div className="dashboard-grid" style={{ gridTemplateColumns: '1fr', gap: 16 }}>
            {/* Forex Widget */}
            <div className="feed-card">
              <div className="card-header" style={{ padding: '10px 14px' }}>
                <span className="card-title" style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: '0.85rem' }}>
                  <span className="material-symbols-outlined" style={{ color: 'var(--brand-primary)', fontSize: '1rem' }}>currency_exchange</span>
                  Forex Rates
                </span>
              </div>
              <div className="card-body" style={{ padding: '10px 14px' }}>
                <div className="forex-grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(100px, 1fr))', gap: 8 }}>
                  {Object.entries(forex).map(([currency, rate]) => (
                    <div key={currency} className="forex-item" style={{ padding: '8px', borderRadius: 8, background: 'var(--bg-base)', border: '1px solid var(--border-subtle)', textAlign: 'center' }}>
                      <div style={{ fontSize: '0.65rem', fontWeight: 600, color: 'var(--text-muted)' }}>{currency}/GHS</div>
                      <div style={{ fontFamily: 'monospace', fontWeight: 800, fontSize: '1rem', margin: '2px 0' }}>{rate}</div>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            {/* Port Congestion Index */}
            <div className="feed-card">
              <div className="card-header" style={{ padding: '10px 14px' }}>
                <span className="card-title" style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: '0.85rem' }}>
                  <span className="material-symbols-outlined" style={{ color: '#f59e0b', fontSize: '1rem' }}>directions_boat</span>
                  Port Congestion
                </span>
              </div>
              <div className="card-body" style={{ padding: '10px 14px', gap: 8 }}>
                {intelligence.ports.map(p => (
                  <div key={p.port} style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: 8, borderBottom: '1px solid var(--border-subtle)' }}>
                    <span style={{ color: 'var(--text-secondary)', fontWeight: 600, fontSize: '0.8rem' }}>{p.port}</span>
                    <span style={{ color: p.color, fontWeight: 800, fontSize: '0.8rem' }}>{p.status}</span>
                  </div>
                ))}
                {intelligence.ports.length === 0 && <p style={{ textAlign: 'center', color: 'var(--text-muted)', fontSize: '0.8rem' }}>No port data.</p>}
              </div>
            </div>

            {/* Alerts Feed */}
            <div className="feed-card">
              <div className="card-header" style={{ padding: '10px 14px' }}>
                <span className="card-title" style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: '0.85rem' }}>
                  <span className="material-symbols-outlined" style={{ color: '#ef4444', fontSize: '1rem' }}>warning</span>
                  Supply Chain Alerts
                </span>
              </div>
              <div className="card-body" style={{ padding: '10px 14px', gap: 10 }}>
                {intelligence.alerts.map(alert => (
                  <div key={alert.id} style={{ background: 'var(--bg-base)', padding: 12, borderRadius: 10, borderLeft: `3px solid ${alert.severity === 'high' ? '#ef4444' : (alert.severity === 'medium' ? '#f59e0b' : '#3b82f6')}` }}>
                    <div style={{ fontWeight: 700, color: 'var(--text-primary)', marginBottom: 2, fontSize: '0.85rem' }}>{alert.title}</div>
                    <p style={{ margin: 0, color: 'var(--text-secondary)', fontSize: '0.75rem', lineHeight: 1.4 }}>{alert.detail}</p>
                  </div>
                ))}
                {intelligence.alerts.length === 0 && <p style={{ textAlign: 'center', color: 'var(--text-muted)', fontSize: '0.8rem' }}>No active alerts.</p>}
              </div>
            </div>
          </div>
        ) : (
          /* ── NEWS & BLOG TAB ── */
          <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
            
            {/* CUBAG Official Blog */}
            <section>
              <h3 style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 12, fontSize: '1.1rem', fontWeight: 800, color: 'var(--text-primary)' }}>
                <span className="material-symbols-outlined" style={{ color: 'var(--brand-primary)', fontSize: '1.4rem' }}>campaign</span>
                Official CUBAG News
              </h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                {blogs.map(b => (
                  <div key={b.id} className="feed-card" style={{ padding: '16px', borderRadius: 14 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                      <span style={{ fontSize: '0.65rem', fontWeight: 800, color: '#fff', background: 'var(--brand-primary)', padding: '2px 8px', borderRadius: 20, textTransform: 'uppercase' }}>
                        {b.category}
                      </span>
                      <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{new Date(b.created_at).toLocaleDateString()}</span>
                    </div>
                    {b.image_url && <img src={b.image_url} alt="Blog" style={{ width: '100%', height: 180, objectFit: 'cover', borderRadius: 8, marginBottom: 12 }} />}
                    <h4 style={{ margin: '0 0 6px 0', fontSize: '1.1rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.3 }}>{b.title}</h4>
                    <p style={{ margin: 0, fontSize: '0.85rem', color: 'var(--text-secondary)', lineHeight: 1.5, whiteSpace: 'pre-wrap' }}>
                      {b.content}
                    </p>
                    <div style={{ marginTop: 12, paddingTop: 10, borderTop: '1px solid var(--border-subtle)', fontSize: '0.7rem', color: 'var(--text-muted)' }}>
                      Author: <strong>{b.author}</strong>
                    </div>
                  </div>
                ))}
                {blogs.length === 0 && (
                  <div style={{ padding: 20, textAlign: 'center', color: 'var(--text-muted)', background: 'var(--bg-elevated)', borderRadius: 12 }}>
                    No official announcements yet.
                  </div>
                )}
              </div>
            </section>

            {/* Global Logistics Feed */}
            <section>
              <h3 style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 12, fontSize: '1.1rem', fontWeight: 800, color: 'var(--text-primary)' }}>
                <span className="material-symbols-outlined" style={{ color: '#3b82f6', fontSize: '1.4rem' }}>public</span>
                Global Shipping Intelligence
              </h3>
              <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: -6, marginBottom: 12 }}>Automated live feed from global maritime and logistics news sources.</p>
              
              <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                {globalNews.slice(0, 8).map((news, i) => (
                  <a key={i} href={news.link} target="_blank" rel="noreferrer" style={{ textDecoration: 'none', color: 'inherit' }}>
                    <div className="feed-card" style={{ padding: '16px', borderRadius: 14, display: 'flex', gap: 16, alignItems: 'flex-start', cursor: 'pointer', transition: 'transform 0.2s' }}>
                      {news.thumbnail && (
                        <img src={news.thumbnail} alt="" style={{ width: 80, height: 80, objectFit: 'cover', borderRadius: 8, flexShrink: 0, background: 'var(--bg-base)' }} />
                      )}
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ fontSize: '0.7rem', color: '#3b82f6', fontWeight: 800, marginBottom: 4 }}>
                          LIVE NEWS • {new Date(news.pubDate).toLocaleDateString()}
                        </div>
                        <h4 style={{ margin: '0 0 6px 0', fontSize: '0.95rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.3, display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>
                          {news.title}
                        </h4>
                        <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                          Read full article ↗
                        </div>
                      </div>
                    </div>
                  </a>
                ))}
                {globalNews.length === 0 && (
                  <div style={{ padding: 20, textAlign: 'center', color: 'var(--text-muted)', background: 'var(--bg-elevated)', borderRadius: 12 }}>
                    Global feed currently unavailable.
                  </div>
                )}
              </div>
            </section>

          </div>
        )}

      </div>
    </AppLayout>
  )
}
