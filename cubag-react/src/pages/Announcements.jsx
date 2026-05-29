import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

const API_URL = import.meta.env.VITE_API_URL

export default function Announcements() {
  const [alerts, setAlerts] = useState([])
  const [loading, setLoading] = useState(true)
  const [expanded, setExpanded] = useState(new Set())
  const [filter, setFilter] = useState('All')

  const token = localStorage.getItem('cubag_token')

  const fetchAlerts = async () => {
    try {
      setLoading(true)
      const res = await fetch(`${API_URL}/announcements`, {
        headers: { 'Authorization': `Bearer ${token}` }
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

  useEffect(() => {
    fetchAlerts()
  }, [])

  const toggleExpand = async (id, isRead) => {
    // Mark as read when expanding if not already read
    if (!isRead) {
      try {
        await fetch(`${API_URL}/announcements/mark-read`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`
          },
          body: JSON.stringify({ announcement_id: id })
        })
        // Update local state to reflect it's read without full re-fetch
        setAlerts(prev => prev.map(a => a.id === id ? { ...a, is_read: true } : a))
      } catch {}
    }

    setExpanded(prev => {
      const next = new Set(prev)
      next.has(id) ? next.delete(id) : next.add(id)
      return next
    })
  }

  const markAllRead = async () => {
    try {
      await fetch(`${API_URL}/announcements/mark-read`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({}) // empty body marks all as read
      })
      setAlerts(prev => prev.map(a => ({ ...a, is_read: true })))
    } catch {}
  }

  const filteredAlerts = alerts.filter(a => filter === 'All' || a.category === filter || a.type === filter)
  const unreadCount = alerts.filter(a => !a.is_read).length
  const categories = ['All', ...new Set(alerts.map(a => a.category || a.type).filter(Boolean))]

  return (
    <AppLayout title="Announcements">
      <div style={{ maxWidth: 800, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>

        {/* Page Title removed as it is now in the header */}

        {/* Category Filter - Integrated Dropdown */}
        <div style={{ marginBottom: 12 }}>
          <div style={{ position: 'relative' }}>
            <span className="material-symbols-outlined" style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--brand-primary)', fontSize: '1.1rem', zIndex: 1 }}>filter_alt</span>
            <select
              value={filter}
              onChange={(e) => setFilter(e.target.value)}
              style={{
                width: '100%', padding: '10px 12px 10px 38px', borderRadius: 10,
                border: '1.5px solid var(--border-default)', fontSize: '0.9rem', outline: 'none',
                background: 'var(--bg-card)', color: 'var(--text-primary)', fontWeight: 700,
                appearance: 'none', cursor: 'pointer', position: 'relative'
              }}
            >
              {categories.map(cat => (
                <option key={cat} value={cat}>{cat === 'All' ? 'All Updates' : cat}</option>
              ))}
            </select>
            <span className="material-symbols-outlined" style={{ position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', fontSize: '1.1rem', pointerEvents: 'none' }}>expand_more</span>
          </div>
        </div>

        <div className="feed-card">
          <div className="card-header" style={{ padding: '12px 16px', borderBottom: '1px solid var(--border-subtle)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span className="card-title" style={{ fontSize: '0.9rem', fontWeight: 800, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Latest Circulars</span>

            {unreadCount > 0 && (
              <button
                onClick={markAllRead}
                style={{
                  background: 'transparent',
                  border: 'none',
                  color: 'var(--brand-primary)',
                  fontSize: '0.72rem',
                  fontWeight: 800,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 4,
                  cursor: 'pointer',
                  textTransform: 'uppercase'
                }}
              >
                <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>done_all</span>
                Mark All Read
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
            ) : filteredAlerts.length > 0 ? (
              filteredAlerts.map((alert, i) => {
                const isExpanded = expanded.has(alert.id)
                const isRead = alert.is_read
                return (
                  <div
                    key={alert.id}
                    onClick={() => toggleExpand(alert.id, isRead)}
                    style={{
                      display: 'flex', gap: 12, alignItems: 'flex-start', padding: '16px',
                      borderBottom: i === filteredAlerts.length - 1 ? 'none' : '1px solid var(--border-subtle)',
                      transition: 'background 0.2s',
                      background: isRead ? 'transparent' : 'rgba(240,130,50,0.03)',
                      borderLeft: isRead ? 'none' : '3px solid var(--brand-primary)',
                      cursor: 'pointer'
                    }}
                  >
                    <div style={{ width: 36, height: 36, borderRadius: 10, background: 'rgba(240,130,50,0.1)', color: 'var(--brand-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                      <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>{alert.icon || 'campaign'}</span>
                    </div>

                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ marginBottom: 4 }}>
                        <h3 style={{ fontSize: '0.92rem', color: 'var(--text-primary)', margin: 0, fontWeight: isRead ? 600 : 800, lineHeight: 1.3 }}>
                          {!isRead && <span style={{ display: 'inline-block', width: 6, height: 6, borderRadius: '50%', background: 'var(--brand-primary)', marginRight: 6, verticalAlign: 'middle' }} />}
                          {alert.title}
                        </h3>
                      </div>

                      <p style={{ fontSize: '0.82rem', color: 'var(--text-secondary)', lineHeight: 1.4, marginBottom: 8 }}>
                        {alert.body}
                      </p>

                      <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                        <span style={{ fontSize: '0.65rem', fontWeight: 800, color: 'var(--brand-primary)', textTransform: 'uppercase', background: 'rgba(240,130,50,0.08)', padding: '2px 8px', borderRadius: 4 }}>
                          {alert.category || alert.type || 'GENERAL'}
                        </span>
                        <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontWeight: 500 }}>
                          • {alert.time || (alert.created_at && new Date(alert.created_at).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' }))}
                        </span>
                        <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontWeight: 500 }}>
                          • By {['System Administrator', 'Admin', '', null, undefined].includes(alert.posted_by) ? 'CUBAG Unit' : alert.posted_by}
                        </span>
                      </div>
                    </div>
                  </div>
                )
              })
            ) : (
              <div style={{ padding: '60px 20px', textAlign: 'center', color: 'var(--text-muted)' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '3rem', marginBottom: 12, display: 'block' }}>filter_list_off</span>
                <p>No circulars found in this category.</p>
              </div>
            )}
          </div>
        </div>

      </div>
    </AppLayout>
  )
}
