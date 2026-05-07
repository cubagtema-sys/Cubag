import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

const API_URL = import.meta.env.VITE_API_URL
const EMPTY_FORM = { title: '', description: '', date: '', time: '', location: '', capacity: '' }

export default function AdminEvents() {
  const [events, setEvents] = useState([])
  const [loading, setLoading] = useState(true)
  const [tab, setTab] = useState('upcoming') // 'upcoming' | 'history' | 'create'
  const [submitting, setSubmitting] = useState(false)
  const [form, setForm] = useState(EMPTY_FORM)
  const [editingEvent, setEditingEvent] = useState(null) // null = no modal
  const [editForm, setEditForm] = useState(EMPTY_FORM)

  const token = localStorage.getItem('cubag_token')

  const fetchEvents = async () => {
    setLoading(true)
    try {
      const res = await fetch(`${API_URL}/events`, {
        headers: { Authorization: `Bearer ${token}` }
      })
      const data = await res.json()
      setEvents(Array.isArray(data) ? data : [])
    } catch {
      setEvents([])
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchEvents() }, [])

  const handleCreate = async (e) => {
    e.preventDefault()
    setSubmitting(true)
    try {
      await fetch(`${API_URL}/events`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify(form)
      })
      setForm(EMPTY_FORM)
      setTab('upcoming')
      fetchEvents()
    } catch {
    } finally {
      setSubmitting(false)
    }
  }

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this event?')) return
    try {
      await fetch(`${API_URL}/events/${id}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` }
      })
      fetchEvents()
    } catch {}
  }

  const openEdit = (ev) => {
    setEditingEvent(ev)
    setEditForm({
      title: ev.title || '',
      description: ev.description || '',
      date: ev.date || '',
      time: ev.time || '',
      location: ev.location || '',
      capacity: ev.capacity || ''
    })
  }

  const handleEdit = async (e) => {
    e.preventDefault()
    setSubmitting(true)
    try {
      await fetch(`${API_URL}/events/${editingEvent.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify(editForm)
      })
      setEditingEvent(null)
      fetchEvents()
    } catch {
    } finally {
      setSubmitting(false)
    }
  }

  const today = new Date()
  today.setHours(0, 0, 0, 0)
  const upcomingEvents = events.filter(e => new Date(e.date) >= today)
  const pastEvents = events.filter(e => new Date(e.date) < today)

  const TABS = [
    { id: 'upcoming', label: `Upcoming (${upcomingEvents.length})`, icon: 'event_available' },
    { id: 'history',  label: `History (${pastEvents.length})`,       icon: 'history' },
    { id: 'create',   label: 'New Event',                            icon: 'add_circle' },
  ]

  const EventCard = ({ ev, isPast }) => (
    <div style={{
      display: 'flex', alignItems: 'flex-start', gap: 16, padding: '16px',
      background: 'var(--bg-base)', borderRadius: 12, border: '1px solid var(--border-subtle)',
      flexWrap: 'wrap', opacity: isPast ? 0.8 : 1
    }}>
      {/* Date badge */}
      <div style={{ width: 52, height: 52, borderRadius: 12, background: isPast ? 'var(--bg-surface)' : 'rgba(240,130,50,0.1)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        <span style={{ fontSize: '0.62rem', fontWeight: 800, color: isPast ? 'var(--text-muted)' : 'var(--brand-primary)', textTransform: 'uppercase' }}>
          {new Date(ev.date).toLocaleString('en', { month: 'short' })}
        </span>
        <span style={{ fontSize: '1.3rem', fontWeight: 800, color: isPast ? 'var(--text-muted)' : 'var(--brand-primary)', lineHeight: 1 }}>
          {new Date(ev.date).getDate()}
        </span>
      </div>

      {/* Info */}
      <div style={{ flex: 1, minWidth: 160 }}>
        <div style={{ fontWeight: 700, color: 'var(--text-primary)', marginBottom: 4 }}>{ev.title}</div>
        <div style={{ fontSize: '0.82rem', color: 'var(--text-muted)', display: 'flex', flexWrap: 'wrap', gap: '6px 14px' }}>
          <span><span className="material-symbols-outlined" style={{ fontSize: '0.9rem', verticalAlign: 'middle' }}>schedule</span> {ev.time || 'TBD'}</span>
          <span><span className="material-symbols-outlined" style={{ fontSize: '0.9rem', verticalAlign: 'middle' }}>location_on</span> {ev.location}</span>
          {ev.capacity && <span><span className="material-symbols-outlined" style={{ fontSize: '0.9rem', verticalAlign: 'middle' }}>group</span> {ev.capacity}</span>}
        </div>
        {ev.description && <div style={{ fontSize: '0.83rem', color: 'var(--text-secondary)', marginTop: 6 }}>{ev.description}</div>}
      </div>

      {/* Actions */}
      <div style={{ display: 'flex', gap: 8, flexShrink: 0, alignSelf: 'flex-start', flexWrap: 'wrap' }}>
        <button className="btn btn-sm btn-outline" onClick={() => openEdit(ev)}
          style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
          <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>edit</span> Edit
        </button>
        <button className="btn btn-sm btn-danger" onClick={() => handleDelete(ev.id)}
          style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
          <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>delete</span> Delete
        </button>
      </div>
    </div>
  )

  const EventForm = ({ formData, setFormData, onSubmit, submitLabel }) => (
    <form onSubmit={onSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      <div className="form-group">
        <label>Event Title</label>
        <input required value={formData.title} onChange={e => setFormData({ ...formData, title: e.target.value })}
          placeholder="e.g. Annual General Meeting" />
      </div>
      <div className="form-group">
        <label>Location / Venue</label>
        <input required value={formData.location} onChange={e => setFormData({ ...formData, location: e.target.value })}
          placeholder="e.g. CUBAG Secretariat, Tema" />
      </div>
      <div className="form-group">
        <label>Date</label>
        <input required type="date" value={formData.date} onChange={e => setFormData({ ...formData, date: e.target.value })} />
      </div>
      <div className="form-group">
        <label>Time</label>
        <input required type="time" value={formData.time} onChange={e => setFormData({ ...formData, time: e.target.value })} />
      </div>
      <div className="form-group">
        <label>Capacity <span style={{ fontWeight: 400, color: 'var(--text-muted)', fontSize: '0.8rem' }}>(optional)</span></label>
        <input type="number" min="1" value={formData.capacity}
          onChange={e => setFormData({ ...formData, capacity: e.target.value })}
          placeholder="Leave blank for unlimited" />
      </div>
      <div className="form-group">
        <label>Description</label>
        <textarea rows="3" value={formData.description}
          onChange={e => setFormData({ ...formData, description: e.target.value })}
          placeholder="Brief description of the event..."
          style={{ resize: 'vertical', borderRadius: 'var(--radius-md)', border: '1.5px solid var(--border-default)', padding: '10px 14px', fontFamily: 'inherit', fontSize: '0.9rem', width: '100%', boxSizing: 'border-box' }}
        />
      </div>
      <button type="submit" className="btn btn-primary" disabled={submitting} style={{ width: '100%' }}>
        {submitting ? 'Saving...' : submitLabel}
      </button>
    </form>
  )

  return (
    <AppLayout title="Events & Workshops">
      <div style={{ maxWidth: 860, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 24 }}>

        {/* Header */}
        <div>
          <h2 style={{ margin: 0, fontSize: '1.4rem' }}>Events & Workshops</h2>
          <p style={{ margin: '4px 0 0', color: 'var(--text-muted)', fontSize: '0.88rem' }}>
            Create and manage CUBAG events, training workshops, and board meetings.
          </p>
        </div>

        {/* Tab Bar */}
        <div style={{ display: 'flex', gap: 4, background: 'var(--bg-surface)', borderRadius: 12, padding: 4, flexWrap: 'wrap' }}>
          {TABS.map(t => (
            <button key={t.id} onClick={() => setTab(t.id)} style={{
              flex: 1, minWidth: 100, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
              padding: '10px 14px', borderRadius: 9, border: 'none', cursor: 'pointer',
              fontWeight: 700, fontSize: '0.85rem',
              background: tab === t.id ? (t.id === 'create' ? 'var(--brand-primary)' : '#fff') : 'transparent',
              color: tab === t.id ? (t.id === 'create' ? '#fff' : 'var(--brand-primary)') : 'var(--text-secondary)',
              boxShadow: tab === t.id && t.id !== 'create' ? '0 2px 8px rgba(0,0,0,0.08)' : 'none',
              transition: 'all 0.2s'
            }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>{t.icon}</span>
              {t.label}
            </button>
          ))}
        </div>

        {/* Create Tab */}
        {tab === 'create' && (
          <div className="card">
            <h3 style={{ marginBottom: 20 }}>Create New Event</h3>
            <EventForm formData={form} setFormData={setForm} onSubmit={handleCreate} submitLabel="Create Event" />
          </div>
        )}

        {/* Upcoming Tab */}
        {tab === 'upcoming' && (
          <div className="card">
            <h3 style={{ marginBottom: 16 }}>Upcoming Events</h3>
            {loading ? (
              <div style={{ textAlign: 'center', padding: 40, color: 'var(--text-muted)' }}>Loading...</div>
            ) : upcomingEvents.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '40px 20px' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '3rem', color: 'var(--text-muted)', display: 'block', marginBottom: 12 }}>event_available</span>
                <p style={{ color: 'var(--text-muted)', marginBottom: 16 }}>No upcoming events.</p>
                <button className="btn btn-primary" onClick={() => setTab('create')}>Create an Event</button>
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                {upcomingEvents.map(ev => <EventCard key={ev.id} ev={ev} isPast={false} />)}
              </div>
            )}
          </div>
        )}

        {/* History Tab */}
        {tab === 'history' && (
          <div className="card">
            <h3 style={{ marginBottom: 16 }}>Event History</h3>
            {loading ? (
              <div style={{ textAlign: 'center', padding: 40, color: 'var(--text-muted)' }}>Loading...</div>
            ) : pastEvents.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '40px 20px' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '3rem', color: 'var(--text-muted)', display: 'block', marginBottom: 12 }}>history</span>
                <p style={{ color: 'var(--text-muted)' }}>No past events yet.</p>
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                {pastEvents.map(ev => <EventCard key={ev.id} ev={ev} isPast={true} />)}
              </div>
            )}
          </div>
        )}

      </div>

      {/* Edit Modal */}
      {editingEvent && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', zIndex: 9999, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16 }}>
          <div style={{ background: 'var(--bg-surface)', borderRadius: 16, padding: 28, width: '100%', maxWidth: 520, maxHeight: '90vh', overflowY: 'auto', boxShadow: '0 20px 60px rgba(0,0,0,0.3)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
              <h3 style={{ margin: 0 }}>Edit Event</h3>
              <button onClick={() => setEditingEvent(null)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '1.5rem' }}>close</span>
              </button>
            </div>
            <EventForm formData={editForm} setFormData={setEditForm} onSubmit={handleEdit} submitLabel="Save Changes" />
          </div>
        </div>
      )}

    </AppLayout>
  )
}
