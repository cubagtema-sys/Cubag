import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

const API_URL = import.meta.env.VITE_API_URL
const READ_KEY = 'cubag_read_announcements'

function getReadIds() {
  try { return new Set(JSON.parse(localStorage.getItem(READ_KEY) || '[]')) }
  catch { return new Set() }
}

function markRead(id) {
  const ids = getReadIds()
  ids.add(id)
  localStorage.setItem(READ_KEY, JSON.stringify([...ids]))
}

export default function Announcements() {
  const [alerts, setAlerts] = useState([])
  const [loading, setLoading] = useState(true)
  const [expanded, setExpanded] = useState(new Set())
  const [readIds, setReadIds] = useState(getReadIds())

  useEffect(() => {
    async function fetchAlerts() {
      try {
        setLoading(true)
        const res = await fetch(`${API_URL}/announcements`, {
          headers: { 'Authorization': `Bearer ${localStorage.getItem('cubag_token')}` }
        })
        if (res.ok) {
          const data = await res.json()
          setAlerts(Array.isArray(data) ? data : [])
        }
      } catch (e) {
        console.error('Announcements load error', e)
      } finally {
        setLoading(false)
      }
    }
    fetchAlerts()
  }, [])

  const toggleExpand = (id) => {
    // Mark as read when expanding
    if (!expanded.has(id)) {
      markRead(id)
      setReadIds(getReadIds())
    }
    setExpanded(prev => {
      const next = new Set(prev)
      next.has(id) ? next.delete(id) : next.add(id)
      return next
    })
  }

  const unreadCount = alerts.filter(a => !readIds.has(a.id)).length

  return (
    <AppLayout title="Announcements">
      <div style={{ maxWidth: 800, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 24 }}>

        <div className="feed-card">
          <div className="card-header" style={{ padding: '20px 24px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <span className="card-title" style={{ fontSize: '1.1rem' }}>Association Circulars</span>
              {unreadCount > 0 && (
                <span style={{ background: 'var(--brand-primary)', color: '#fff', borderRadius: 20, padding: '2px 10px', fontSize: '0.75rem', fontWeight: 800 }}>
                  {unreadCount} unread
                </span>
              )}
            </div>
            {unreadCount > 0 && (
              <button
                className="btn btn-ghost btn-sm"
                style={{ fontSize: '0.8rem' }}
                onClick={() => {
                  alerts.forEach(a => markRead(a.id))
                  setReadIds(getReadIds())
                }}
              >
                Mark all read
              </button>
            )}
          </div>

          <div className="card-body" style={{ padding: 0 }}>
            {loading ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 0 }}>
                {[1, 2, 3].map(i => (
                  <div key={i} style={{ padding: '24px', borderBottom: '1px solid var(--border-subtle)' }}>
                    <div style={{ display: 'flex', gap: 16 }}>
                      <div className="skeleton" style={{ width: 44, height: 44, borderRadius: 12 }} />
                      <div style={{ flex: 1 }}>
                        <div className="skeleton skeleton-text" style={{ width: '40%' }} />
                        <div className="skeleton skeleton-text" />
                        <div className="skeleton skeleton-text short" />
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            ) : alerts.length > 0 ? (
              alerts.map((alert, i) => {
                const isExpanded = expanded.has(alert.id)
                const isRead = readIds.has(alert.id)
                return (
                  <div
                    key={alert.id}
                    style={{
                      display: 'flex', gap: 16, alignItems: 'flex-start', padding: '24px',
                      borderBottom: i === alerts.length - 1 ? 'none' : '1px solid var(--border-subtle)',
                      transition: 'background 0.2s',
                      background: isRead ? 'transparent' : 'rgba(240,130,50,0.03)',
                      borderLeft: isRead ? 'none' : '3px solid var(--brand-primary)'
                    }}
                  >
                    <div style={{ width: 48, height: 48, borderRadius: 12, background: 'rgba(240,130,50,0.1)', color: 'var(--brand-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                      <span className="material-symbols-outlined">{alert.icon || 'campaign'}</span>
                    </div>

                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 6 }}>
                        <h3 style={{ fontSize: '1.05rem', color: 'var(--text-primary)', margin: 0, fontWeight: isRead ? 600 : 800 }}>
                          {!isRead && <span style={{ display: 'inline-block', width: 8, height: 8, borderRadius: '50%', background: 'var(--brand-primary)', marginRight: 8, verticalAlign: 'middle' }} />}
                          {alert.title}
                        </h3>
                        <span className={`badge badge-${alert.color || 'info'}`} style={{ flexShrink: 0, marginLeft: 12 }}>{alert.category || alert.type}</span>
                      </div>

                      <p style={{ fontSize: '0.9rem', color: 'var(--text-secondary)', lineHeight: 1.6, marginBottom: 12 }}>
                        {alert.body}
                      </p>

                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                        <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                          <span style={{ marginRight: 8 }}>By {alert.posted_by || 'CUBAG Unit'} ·</span>
                          {alert.time || (alert.created_at && new Date(alert.created_at).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' }))}
                        </div>
                      </div>
                    </div>
                  </div>
                )
              })
            ) : (
              <div style={{ padding: '60px 20px', textAlign: 'center', color: 'var(--text-muted)' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '3rem', marginBottom: 12, display: 'block' }}>notifications_off</span>
                <p>No new announcements at this time.</p>
              </div>
            )}
          </div>
        </div>

      </div>
    </AppLayout>
  )
}
