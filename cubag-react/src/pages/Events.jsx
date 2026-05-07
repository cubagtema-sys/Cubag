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
      <div style={{ maxWidth: 900, margin: '0 auto' }}>
        
        {loading ? (
          <div style={{ minHeight: '300px', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', background: 'var(--bg-card)', borderRadius: 'var(--radius-xl)' }}>
            <div className="spinner" style={{ marginBottom: 16 }}></div>
            <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', fontWeight: 600 }}>SYNCING EVENTS</div>
          </div>
        ) : events.length === 0 ? (
          <div className="feed-card" style={{ padding: '60px 20px', textAlign: 'center' }}>
            <span className="material-symbols-outlined" style={{ fontSize: '4rem', color: 'var(--text-muted)', marginBottom: 20 }}>calendar_month</span>
            <h3 style={{ color: 'var(--text-primary)', marginBottom: 12 }}>No Upcoming Events</h3>
            <p style={{ color: 'var(--text-secondary)', maxWidth: 400, margin: '0 auto' }}>Check back later for association meetings, workshops, and industry seminars.</p>
          </div>
        ) : (
          <div style={{ display: 'grid', gap: 20 }}>
            {events.map(event => (
              <div key={event.id} className="feed-card" style={{ display: 'flex', overflow: 'hidden' }}>
                <div style={{ width: '120px', background: 'var(--gradient-brand)', color: '#fff', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '20px' }}>
                  <div style={{ fontSize: '0.8rem', fontWeight: 600, textTransform: 'uppercase' }}>{new Date(event.date).toLocaleString('default', { month: 'short' })}</div>
                  <div style={{ fontSize: '2rem', fontWeight: 800 }}>{new Date(event.date).getDate()}</div>
                </div>
                <div className="card-body" style={{ flex: 1, padding: '24px' }}>
                  <h3 style={{ color: 'var(--text-primary)', marginBottom: 8 }}>{event.title}</h3>
                  <p style={{ fontSize: '0.9rem', color: 'var(--text-secondary)', marginBottom: 16 }}>{event.description}</p>
                  <div style={{ display: 'flex', gap: 20, fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                      <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>schedule</span> {event.time}
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                      <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>location_on</span> {event.location}
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
