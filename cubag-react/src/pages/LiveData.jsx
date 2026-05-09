import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

const API_URL = import.meta.env.VITE_API_URL

export default function LiveData() {
  const [forex, setForex] = useState({ USD: '...', EUR: '...', GBP: '...', CNY: '...' })
  const [loading, setLoading] = useState(true)
  const [lastUpdated, setLastUpdated] = useState(new Date().toLocaleTimeString())
  
  // Real-time feeds from Backend
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

        // 2. Global Logistics News (RSS Feed via backend)
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
              Live monitoring of global markets & logistics news.
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

        {loading ? (
          <div style={{ padding: 40, textAlign: 'center', color: 'var(--text-muted)' }}>
            <div className="spinner" style={{ margin: '0 auto 12px' }} />
            Syncing global feeds...
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
            
            {/* Forex Widget */}
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
                      <div style={{ fontFamily: 'monospace', fontWeight: 800, fontSize: '1rem', margin: '2px 0' }}>{rate}</div>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            {/* Global Logistics Feed */}
            <section>
              <h3 style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 12, fontSize: '1.1rem', fontWeight: 800, color: 'var(--text-primary)' }}>
                <span className="material-symbols-outlined" style={{ color: '#3b82f6', fontSize: '1.4rem' }}>public</span>
                Worldwide Shipping News
              </h3>
              
              <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                {globalNews.slice(0, 15).map((news, i) => (
                  <a key={i} href={news.link} target="_blank" rel="noreferrer" style={{ textDecoration: 'none', color: 'inherit' }}>
                    <div className="feed-card" style={{ padding: '16px', borderRadius: 14, display: 'flex', gap: 16, alignItems: 'flex-start', cursor: 'pointer', transition: 'transform 0.2s' }}>
                      {news.thumbnail && (
                        <img src={news.thumbnail} alt="" style={{ width: 80, height: 80, objectFit: 'cover', borderRadius: 8, flexShrink: 0, background: 'var(--bg-base)' }} />
                      )}
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ fontSize: '0.7rem', color: '#3b82f6', fontWeight: 800, marginBottom: 4 }}>
                          LIVE FEED • {new Date(news.pubDate).toLocaleDateString()}
                        </div>
                        <h4 style={{ margin: '0 0 6px 0', fontSize: '0.95rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.3, display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>
                          {news.title}
                        </h4>
                        <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>
                          {news.description.replace(/<[^>]+>/g, '')}
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
