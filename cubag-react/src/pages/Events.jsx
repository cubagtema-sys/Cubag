import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

const API_URL = import.meta.env.VITE_API_URL

export default function Events() {
  const [events, setEvents] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function fetchEvents() {
      try {
        setLoading(true)
        const res = await fetch(`${API_URL}/events`, {
          headers: { 'Authorization': `Bearer ${localStorage.getItem('cubag_token')}` }
        })
        if (res.ok) {
          const data = await res.json()
          if (Array.isArray(data)) setEvents(data)
        }
      } catch (e) {
        console.error("Events load error", e)
      } finally {
        setLoading(false)
      }
    }
    fetchEvents()
  }, [])

  return (
    <AppLayout title="Events & Workshops">
      <div style={{ maxWidth: 900, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>
        
        {/* Page Title removed as it is now in the header */}

        {loading ? (
          <div style={{ minHeight: '300px', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', background: 'var(--bg-card)', borderRadius: 16, border: '1px solid var(--border-subtle)' }}>
            <div className="spinner" style={{ marginBottom: 12 }}></div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600 }}>SYNCING EVENTS</div>
          </div>
        ) : events.length === 0 ? (
          <div className="feed-card" style={{ padding: '60px 20px', textAlign: 'center' }}>
            <span className="material-symbols-outlined" style={{ fontSize: '3rem', color: 'var(--text-muted)', marginBottom: 16 }}>calendar_month</span>
            <h3 style={{ color: 'var(--text-primary)', marginBottom: 8, fontSize: '1.1rem' }}>No Upcoming Events</h3>
            <p style={{ color: 'var(--text-secondary)', fontSize: '0.85rem', maxWidth: 300, margin: '0 auto' }}>Check back later for meetings and seminars.</p>
          </div>
        ) : (
          <div style={{ display: 'grid', gap: 16 }}>
            {events.map(event => (
              <div key={event.id} className="feed-card" style={{ display: 'flex', flexDirection: 'row', overflow: 'hidden', minHeight: 100 }}>
                <div style={{ width: '80px', background: 'var(--gradient-brand)', color: '#fff', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '12px', flexShrink: 0 }}>
                  <div style={{ fontSize: '0.65rem', fontWeight: 700, textTransform: 'uppercase' }}>{new Date(event.date).toLocaleString('default', { month: 'short' })}</div>
                  <div style={{ fontSize: '1.5rem', fontWeight: 900 }}>{new Date(event.date).getDate()}</div>
                </div>
                <div className="card-body" style={{ flex: 1, padding: '16px' }}>
                  <h3 style={{ color: 'var(--text-primary)', marginBottom: 4, fontSize: '1rem', fontWeight: 700 }}>{event.title}</h3>
                  <p style={{ fontSize: '0.8rem', color: 'var(--text-secondary)', marginBottom: 10, display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>{event.description}</p>
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: 12, fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                      <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>schedule</span> {event.time}
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                      <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>location_on</span> {event.location}
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}

      </div>
    </AppLayout>
  )
}
