import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'
import ConfirmModal from '../components/ConfirmModal'
import useAutoRefresh from '../hooks/useAutoRefresh'

const API_URL = import.meta.env.VITE_API_URL
const EMPTY_FORM = { title: '', description: '', date: '', time: '', location: '', capacity: '' }

const EventCard = ({ ev, isPast, onEdit, onDelete }) => (
  <div style={{
    display: 'flex', alignItems: 'flex-start', gap: 12, padding: '14px 16px',
    background: 'var(--bg-base)', borderRadius: 12, border: '1px solid var(--border-subtle)',
    opacity: isPast ? 0.8 : 1, position: 'relative'
  }}>
    {/* Date badge */}
    <div style={{ width: 44, height: 44, borderRadius: 10, background: isPast ? 'var(--bg-surface)' : 'rgba(240,130,50,0.1)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
      <span style={{ fontSize: '0.55rem', fontWeight: 800, color: isPast ? 'var(--text-muted)' : 'var(--brand-primary)', textTransform: 'uppercase' }}>
        {new Date(ev.date).toLocaleString('en', { month: 'short', timeZone: 'UTC' })}
      </span>
      <span style={{ fontSize: '1.1rem', fontWeight: 900, color: isPast ? 'var(--text-muted)' : 'var(--brand-primary)', lineHeight: 1 }}>
        {new Date(ev.date).getUTCDate()}
      </span>
    </div>

    {/* Info */}
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ fontWeight: 800, color: 'var(--text-primary)', fontSize: '0.95rem', marginBottom: 2, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{ev.title}</div>
      <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', display: 'flex', flexWrap: 'wrap', gap: '4px 10px' }}>
        <span><span className="material-symbols-outlined" style={{ fontSize: '0.85rem', verticalAlign: 'middle' }}>schedule</span> {ev.time || 'TBD'}</span>
        <span><span className="material-symbols-outlined" style={{ fontSize: '0.85rem', verticalAlign: 'middle' }}>location_on</span> {ev.location}</span>
      </div>

      {/* Actions row inside card for mobile friendliness */}
      <div style={{ display: 'flex', gap: 6, marginTop: 10 }}>
        <button className="btn btn-sm btn-ghost" onClick={() => onEdit(ev)} style={{ flex: 1, height: 32, fontSize: '0.7rem', padding: 0 }}>Edit</button>
        <button className="btn btn-sm btn-danger" onClick={() => onDelete(ev.id)} style={{ flex: 1, height: 32, fontSize: '0.7rem', padding: 0, opacity: 0.9 }}>Delete</button>
      </div>
    </div>
  </div>
)

const EventForm = ({ formData, setFormData, onSubmit, submitLabel, submitting }) => (
  <form onSubmit={onSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
    <div className="form-group">
      <label style={{ fontSize: '0.8rem', fontWeight: 700, marginBottom: 4 }}>Event Title</label>
      <input required value={formData.title} onChange={e => setFormData({ ...formData, title: e.target.value })}
        placeholder="e.g. Annual Meeting" style={{ padding: '10px 12px', fontSize: '0.9rem', width: '100%', boxSizing: 'border-box' }} />
    </div>
    <div className="form-group">
      <label style={{ fontSize: '0.8rem', fontWeight: 700, marginBottom: 4 }}>Venue</label>
      <input required value={formData.location} onChange={e => setFormData({ ...formData, location: e.target.value })}
        placeholder="e.g. Tema Secretariat" style={{ padding: '10px 12px', fontSize: '0.9rem', width: '100%', boxSizing: 'border-box' }} />
    </div>
    <div className="form-group">
      <label style={{ fontSize: '0.8rem', fontWeight: 700, marginBottom: 4 }}>Date</label>
      <input required type="date" value={formData.date} onChange={e => setFormData({ ...formData, date: e.target.value })} style={{ padding: '10px 12px', fontSize: '0.9rem', width: '100%', maxWidth: '220px', minHeight: '44px', boxSizing: 'border-box' }} />
    </div>
    <div className="form-group">
      <label style={{ fontSize: '0.8rem', fontWeight: 700, marginBottom: 4 }}>Time</label>
      <input required type="time" value={formData.time} onChange={e => setFormData({ ...formData, time: e.target.value })} style={{ padding: '10px 12px', fontSize: '0.9rem', width: '100%', maxWidth: '220px', minHeight: '44px', boxSizing: 'border-box' }} />
    </div>
    <div className="form-group">
      <label style={{ fontSize: '0.8rem', fontWeight: 700, marginBottom: 4 }}>Description</label>
      <textarea rows="3" value={formData.description}
        onChange={e => setFormData({ ...formData, description: e.target.value })}
        placeholder="Details..."
        style={{ resize: 'none', borderRadius: 8, border: '1.5px solid var(--border-default)', padding: '10px 12px', fontFamily: 'inherit', fontSize: '0.9rem', width: '100%', boxSizing: 'border-box' }}
      />
    </div>
    <button type="submit" className="btn btn-primary btn-lg" disabled={submitting} style={{ width: '100%', height: 48, fontSize: '0.95rem' }}>
      {submitting ? 'Saving...' : submitLabel}
    </button>
  </form>
)

export default function AdminEvents() {
  const [events, setEvents] = useState([])
  const [loading, setLoading] = useState(true)
  const [tab, setTab] = useState('upcoming') // 'upcoming' | 'history' | 'create'
  const [submitting, setSubmitting] = useState(false)
  const [form, setForm] = useState(EMPTY_FORM)
  const [editingEvent, setEditingEvent] = useState(null)
  const [editForm, setEditForm] = useState(EMPTY_FORM)
  const [pendingDelete, setPendingDelete] = useState(null)

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

  useAutoRefresh(fetchEvents, 30000)

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
    try {
      await fetch(`${API_URL}/events/${id}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` }
      })
      fetchEvents()
    } catch {}
    finally { setPendingDelete(null) }
  }

  const openEdit = (ev) => {
    setEditingEvent(ev)
    let safeDate = ''
    if (ev.date) safeDate = new Date(ev.date).toISOString().split('T')[0]
    setEditForm({
      title: ev.title || '',
      description: ev.description || '',
      date: safeDate,
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

  const todayObj = new Date()
  const todayStr = `${todayObj.getFullYear()}-${String(todayObj.getMonth() + 1).padStart(2, '0')}-${String(todayObj.getDate()).padStart(2, '0')}`

  const upcomingEvents = events.filter(e => e.date && new Date(e.date).toISOString().split('T')[0] >= todayStr)
  const pastEvents = events.filter(e => e.date && new Date(e.date).toISOString().split('T')[0] < todayStr)

  const TABS = [
    { id: 'upcoming', label: `Upcoming`, icon: 'event_available' },
    { id: 'history',  label: `History`,  icon: 'history' },
    { id: 'create',   label: 'New Event', icon: 'add_circle' },
  ]

  return (
    <AppLayout title="Events Management">
      <div style={{ maxWidth: 860, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>

        {/* Page Title removed as it is now in the header */}

        {/* Tab Bar */}
        <div style={{ display: 'flex', gap: 4, background: 'var(--bg-surface)', borderRadius: 10, padding: 3, flexWrap: 'wrap' }}>
          {TABS.map(t => (
            <button key={t.id} onClick={() => setTab(t.id)} style={{
              flex: 1, minWidth: 90, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
              padding: '8px 10px', borderRadius: 8, border: 'none', cursor: 'pointer',
              fontWeight: 700, fontSize: '0.75rem',
              background: tab === t.id ? (t.id === 'create' ? 'var(--brand-primary)' : 'var(--bg-base)') : 'transparent',
              color: tab === t.id ? (t.id === 'create' ? '#fff' : 'var(--brand-primary)') : 'var(--text-secondary)',
              boxShadow: tab === t.id && t.id !== 'create' ? 'var(--shadow-sm)' : 'none',
              transition: 'all 0.2s'
            }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>{t.icon}</span>
              {t.label}
            </button>
          ))}
        </div>

        {/* Create Tab */}
        {tab === 'create' && (
          <div className="feed-card" style={{ padding: '20px 16px', borderRadius: 12 }}>
            <h3 style={{ marginBottom: 16, fontSize: '1.1rem' }}>New Event</h3>
            <EventForm formData={form} setFormData={setForm} onSubmit={handleCreate} submitLabel="Publish Event" submitting={submitting} />
          </div>
        )}

        {/* List Tabs */}
        {(tab === 'upcoming' || tab === 'history') && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {loading ? (
              <div style={{ textAlign: 'center', padding: 40, color: 'var(--text-muted)', fontSize: '0.8rem' }}>Loading events...</div>
            ) : (tab === 'upcoming' ? upcomingEvents : pastEvents).length === 0 ? (
              <div className="card" style={{ textAlign: 'center', padding: '48px 20px', borderRadius: 12 }}>
                <span className="material-symbols-outlined" style={{ fontSize: '3rem', color: 'var(--text-muted)', display: 'block', marginBottom: 12 }}>calendar_month</span>
                <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>No events found here.</p>
              </div>
            ) : (
              (tab === 'upcoming' ? upcomingEvents : pastEvents).map(ev => <EventCard key={ev.id} ev={ev} isPast={tab === 'history'} onEdit={openEdit} onDelete={(id) => setPendingDelete(id)} />)
            )}
          </div>
        )}

      </div>

      {/* Edit Modal */}
      {editingEvent && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', zIndex: 9999, display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }}>
          <div style={{ background: 'var(--bg-surface)', borderRadius: '16px 16px 0 0', padding: '24px 20px 32px', width: '100%', maxWidth: 520, maxHeight: '90vh', overflowY: 'auto', boxShadow: '0 -8px 40px rgba(0,0,0,0.3)', animation: 'fadeInUp 0.25s ease' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
              <h3 style={{ margin: 0, fontSize: '1.1rem' }}>Edit Event</h3>
              <button onClick={() => setEditingEvent(null)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '1.5rem' }}>close</span>
              </button>
            </div>
            <EventForm formData={editForm} setFormData={setEditForm} onSubmit={handleEdit} submitLabel="Save Changes" submitting={submitting} />
          </div>
        </div>
      )}

      <ConfirmModal
        open={!!pendingDelete}
        message="Delete this event? This cannot be undone."
        onConfirm={() => handleDelete(pendingDelete)}
        onCancel={() => setPendingDelete(null)}
      />
    </AppLayout>
  )
}
