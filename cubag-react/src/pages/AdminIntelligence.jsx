import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

const API_URL = import.meta.env.VITE_API_URL

export default function AdminIntelligence() {
  const [globalNews, setGlobalNews] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetch(`${API_URL}/news/global`)
      .then(res => res.json())
      .then(d => {
        setGlobalNews(d)
        setLoading(false)
      })
      .catch(() => setLoading(false))
  }, [])

  return (
    <AppLayout title="Intelligence">
      <div style={{ maxWidth: 800, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16, paddingBottom: 60 }}>
        
        {/* Page Title */}
        <div style={{ marginBottom: 4 }}>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Intelligence Control</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Global news integration is active.</p>
        </div>

        <div style={{ padding: '16px 20px', background: 'var(--bg-elevated)', borderRadius: 12, border: '1px solid rgba(16,185,129,0.3)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, color: '#10b981', marginBottom: 6 }}>
            <span className="material-symbols-outlined">auto_awesome</span>
            <h2 style={{ margin: 0, fontSize: '1.1rem', fontWeight: 800 }}>Fully Automated</h2>
          </div>
          <p style={{ margin: 0, color: 'var(--text-secondary)', fontSize: '0.9rem', lineHeight: 1.5 }}>
            The Intelligence Hub is now directly connected to global maritime and logistics news networks. 
            <strong> Manual updates are no longer required.</strong> The system automatically pulls live data 24/7 for all members.
          </p>
        </div>

        <h3 style={{ fontSize: '1rem', fontWeight: 800, marginTop: 10, display: 'flex', alignItems: 'center', gap: 6 }}>
          <span className="material-symbols-outlined" style={{ color: '#3b82f6' }}>public</span>
          Live Global Feed Preview
        </h3>

        {loading ? (
          <div style={{ padding: 40, textAlign: 'center', color: 'var(--text-muted)' }}>
            <div className="spinner" style={{ margin: '0 auto 12px' }} />
            Syncing global intelligence...
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {globalNews.slice(0, 10).map((news, i) => (
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
        )}
      </div>
    </AppLayout>
  )
}
