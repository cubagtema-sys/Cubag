import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

const API_URL = import.meta.env.VITE_API_URL

export default function Announcements() {
  const [alerts, setAlerts] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function fetchAlerts() {
      try {
        setLoading(true)
        const res = await fetch(`${API_URL}/announcements`, {
          headers: { 'Authorization': `Bearer ${localStorage.getItem('cubag_token')}` }
        })
        if (res.ok) {
          const data = await res.json()
          setAlerts(data)
        }
      } catch (e) {
        console.error("Announcements load error", e)
      } finally {
        setLoading(false)
      }
    }
    fetchAlerts()
  }, [])
  return (
    <AppLayout title="Announcements">
      <div style={{ maxWidth: 800, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 24 }}>
        
        <div className="feed-card">
          <div className="card-header" style={{ padding: '20px 24px' }}>
            <span className="card-title" style={{ fontSize: '1.1rem' }}>Association Circulars</span>
          </div>
          <div className="card-body" style={{ padding: 0 }}>
            {loading ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 0 }}>
                {[1, 2, 3].map(i => (
                  <div key={i} style={{ padding: '24px', borderBottom: '1px solid var(--border-subtle)' }}>
                    <div style={{ display: 'flex', gap: 16 }}>
                      <div className="skeleton" style={{ width: 44, height: 44, borderRadius: 12 }}></div>
                      <div style={{ flex: 1 }}>
                        <div className="skeleton skeleton-text" style={{ width: '40%' }}></div>
                        <div className="skeleton skeleton-text"></div>
                        <div className="skeleton skeleton-text short"></div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            ) : alerts.length > 0 ? (
              alerts.map((alert, i) => (
                <div key={alert.id} style={{ display: 'flex', gap: 16, alignItems: 'flex-start', padding: '24px', borderBottom: i === alerts.length - 1 ? 'none' : '1px solid var(--border-subtle)', transition: 'background 0.2s', cursor: 'pointer' }} onMouseOver={e => e.currentTarget.style.background = 'var(--bg-card)'} onMouseOut={e => e.currentTarget.style.background = 'transparent'}>
                  
                  <div style={{ width: 48, height: 48, borderRadius: 12, background: 'rgba(240,130,50,0.1)', color: 'var(--brand-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                    <span className="material-symbols-outlined">{alert.icon || 'campaign'}</span>
                  </div>
                  
                  <div style={{ flex: 1 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 6 }}>
                      <h3 style={{ fontSize: '1.05rem', color: 'var(--text-primary)', margin: 0 }}>{alert.title}</h3>
                      <span className={`badge badge-${alert.color || 'info'}`} style={{ flexShrink: 0, marginLeft: 12 }}>{alert.type}</span>
                    </div>
                    <p style={{ fontSize: '0.9rem', color: 'var(--text-secondary)', lineHeight: 1.6, marginBottom: 12 }}>{alert.body}</p>
                    
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                      <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>{alert.time}</div>
                      <button className="btn btn-ghost btn-sm" style={{ padding: '4px 12px' }}>Read full <span className="material-symbols-outlined" style={{ fontSize: '1rem', marginLeft: 4 }}>arrow_forward</span></button>
                    </div>
                  </div>
                </div>
              ))
            ) : (
              <div style={{ padding: '60px 20px', textAlign: 'center', color: 'var(--text-muted)' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '3rem', marginBottom: 12 }}>notifications_off</span>
                <p>No new announcements at this time.</p>
              </div>
            )}
          </div>
        </div>

      </div>
    </AppLayout>
  )
}
