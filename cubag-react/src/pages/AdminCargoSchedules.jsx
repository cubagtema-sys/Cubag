import { useState, useEffect, Fragment } from 'react'
import AppLayout from '../components/AppLayout'
import useAutoRefresh from '../hooks/useAutoRefresh'
import ConfirmModal from '../components/ConfirmModal'

const API_URL = import.meta.env.VITE_API_URL
const STATUSES = ['Scheduled', 'In Progress', 'Completed', 'Cancelled']

const statusStyle = {
  'Scheduled':  { bg: 'rgba(59,130,246,0.12)',  color: '#3b82f6' },
  'In Progress':{ bg: 'rgba(245,158,11,0.12)',  color: '#f59e0b' },
  'Completed':  { bg: 'rgba(16,185,129,0.12)',  color: '#10b981' },
  'Cancelled':  { bg: 'rgba(239,68,68,0.12)',   color: '#ef4444' },
}

export default function AdminCargoSchedules() {
  const [loading, setLoading] = useState(false)
  const [success, setSuccess] = useState(false)
  const [schedules, setSchedules] = useState([])
  const [activeTab, setActiveTab] = useState('upload')
  const [savingId, setSavingId] = useState(null)
  const [deletingId, setDeletingId] = useState(null)

  const [formData, setFormData] = useState({
    type: 'vanning', container: '', vessel: '', cargo: '', date: '', port: '', status: 'Scheduled',
    origin: '', destination: '', progress: 0
  })

  const authHeader = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${localStorage.getItem('cubag_token')}`
  }

  const fetchSchedules = async () => {
    try {
      const res = await fetch(`${API_URL}/schedules`)
      if (res.ok) setSchedules(await res.json())
    } catch (e) { console.error(e) }
  }

  useAutoRefresh(fetchSchedules, 20000)

  const handleChange = (e) => {
    const val = e.target.type === 'range' ? parseInt(e.target.value, 10) : e.target.value
    setFormData({ ...formData, [e.target.name]: val })
  }

  const handleUpload = async (e) => {
    e.preventDefault()
    setLoading(true)
    setSuccess(false)
    try {
      const res = await fetch(`${API_URL}/schedules`, {
        method: 'POST',
        headers: authHeader,
        body: JSON.stringify(formData)
      })
      if (res.ok) {
        setSuccess(true)
        setFormData({ type: 'vanning', container: '', vessel: '', cargo: '', date: '', port: '', status: 'Scheduled', origin: '', destination: '', progress: 0 })
        fetchSchedules()
        setTimeout(() => setSuccess(false), 3000)
      }
    } catch (e) { console.error(e) }
    finally { setLoading(false) }
  }

  const handleStatusChange = async (id, newStatus) => {
    setSavingId(id)
    setSchedules(prev => prev.map(s => s.id === id ? { ...s, status: newStatus } : s))
    try {
      await fetch(`${API_URL}/schedules/${id}`, {
        method: 'PATCH',
        headers: authHeader,
        body: JSON.stringify({ status: newStatus })
      })
    } catch (e) {
      console.error(e)
      fetchSchedules()
    } finally {
      setSavingId(null)
    }
  }

  const [pendingDelete, setPendingDelete] = useState(null)

  const handleDelete = async (id) => {
    setDeletingId(id)
    try {
      const res = await fetch(`${API_URL}/schedules/${id}`, {
        method: 'DELETE',
        headers: authHeader
      })
      if (res.ok) setSchedules(prev => prev.filter(s => s.id !== id))
    } catch (e) { console.error(e) }
    finally { setDeletingId(null); setPendingDelete(null); }
  }

  return (
    <Fragment>
    <AppLayout title="Cargo">
      <div style={{ maxWidth: 1000, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>

        {/* Page Title for Content */}
        <div style={{ marginBottom: 4 }}>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Logistics Management</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Publish live vessel and container schedules.</p>
        </div>

        <div style={{ display: 'flex', gap: 6, background: 'var(--bg-surface)', borderRadius: 10, padding: 3, flexWrap: 'wrap' }}>
          {[
            { id: 'upload', label: 'New Entry', icon: 'publish' },
            { id: 'history', label: 'History', icon: 'history', badge: schedules.length }
          ].map(t => (
            <button key={t.id} onClick={() => setActiveTab(t.id)} style={{
              flex: 1, minWidth: 110, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
              padding: '8px 12px', borderRadius: 8, border: 'none', cursor: 'pointer',
              fontWeight: 700, fontSize: '0.8rem',
              background: activeTab === t.id ? 'var(--brand-primary)' : 'transparent',
              color: activeTab === t.id ? '#fff' : 'var(--text-secondary)',
              transition: 'all 0.2s'
            }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>{t.icon}</span>
              {t.label}
              {t.badge > 0 && <span style={{ marginLeft: 4, background: 'rgba(255,255,255,0.2)', borderRadius: 12, padding: '1px 6px', fontSize: '0.65rem' }}>{t.badge}</span>}
            </button>
          ))}
        </div>

        {activeTab === 'upload' ? (
          <div className="feed-card" style={{ maxWidth: 700, margin: '0 auto', width: '100%', borderRadius: 12 }}>
            <div className="card-header" style={{ padding: '12px 16px' }}><span className="card-title">Compose Entry</span></div>
            <div className="card-body" style={{ padding: '16px' }}>
              {success && (
                <div style={{ padding: '10px 14px', background: '#10b981', color: '#fff', borderRadius: 8, marginBottom: 16, fontSize: '0.85rem', fontWeight: 600 }}>
                  Published successfully!
                </div>
              )}

              <form onSubmit={handleUpload} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700, marginBottom: 4 }}>Type</label>
                  <select name="type" value={formData.type} onChange={handleChange} style={{ width: '100%', padding: 10, border: '1.5px solid var(--border-default)', borderRadius: 8, background: 'var(--bg-base)', fontSize: '0.9rem' }}>
                    <option value="vanning">Vanning (Loading)</option>
                    <option value="devanning">Devanning (Unloading)</option>
                    <option value="movement">Vessel Movement</option>
                  </select>
                </div>

                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700, marginBottom: 4 }}>Container ID</label>
                  <input required type="text" name="container" placeholder="MSCU..." value={formData.container} onChange={handleChange} style={{ width: '100%', padding: 10, border: '1.5px solid var(--border-default)', borderRadius: 8, background: 'var(--bg-base)', fontSize: '0.9rem' }} />
                </div>

                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700, marginBottom: 4 }}>Vessel Name</label>
                  <input required type="text" name="vessel" placeholder="Vessel..." value={formData.vessel} onChange={handleChange} style={{ width: '100%', padding: 10, border: '1.5px solid var(--border-default)', borderRadius: 8, background: 'var(--bg-base)', fontSize: '0.9rem' }} />
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                  <div className="form-group">
                    <label style={{ fontSize: '0.8rem', fontWeight: 700, marginBottom: 4 }}>Date</label>
                    <input required type="text" name="date" placeholder="10 May" value={formData.date} onChange={handleChange} style={{ width: '100%', padding: 10, border: '1.5px solid var(--border-default)', borderRadius: 8, background: 'var(--bg-base)', fontSize: '0.9rem' }} />
                  </div>
                  <div className="form-group">
                    <label style={{ fontSize: '0.8rem', fontWeight: 700, marginBottom: 4 }}>Port</label>
                    <input required type="text" name="port" placeholder="Tema" value={formData.port} onChange={handleChange} style={{ width: '100%', padding: 10, border: '1.5px solid var(--border-default)', borderRadius: 8, background: 'var(--bg-base)', fontSize: '0.9rem' }} />
                  </div>
                </div>

                {formData.type === 'movement' && (
                  <div style={{ padding: 12, background: 'rgba(59,130,246,0.05)', borderRadius: 10, border: '1px solid rgba(59,130,246,0.1)' }}>
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
                      <div className="form-group">
                        <label style={{ fontSize: '0.75rem', fontWeight: 700 }}>Origin</label>
                        <input type="text" name="origin" value={formData.origin} onChange={handleChange} style={{ width: '100%', padding: 8, border: '1.5px solid var(--border-default)', borderRadius: 6, fontSize: '0.85rem' }} />
                      </div>
                      <div className="form-group">
                        <label style={{ fontSize: '0.75rem', fontWeight: 700 }}>Destination</label>
                        <input type="text" name="destination" value={formData.destination} onChange={handleChange} style={{ width: '100%', padding: 8, border: '1.5px solid var(--border-default)', borderRadius: 6, fontSize: '0.85rem' }} />
                      </div>
                    </div>
                  </div>
                )}

                <button type="submit" className="btn btn-primary btn-lg" style={{ width: '100%', height: 48, fontSize: '0.95rem' }} disabled={loading}>
                  {loading ? 'Publishing...' : 'Upload to Portal'}
                </button>
              </form>
            </div>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {schedules.map((s) => {
              const ss = statusStyle[s.status] || statusStyle['Scheduled']
              return (
                <div key={s.id} className="feed-card" style={{ padding: '12px 16px', borderRadius: 12, display: 'flex', flexDirection: 'column', gap: 10, opacity: deletingId === s.id ? 0.4 : 1 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                    <div style={{ minWidth: 0 }}>
                      <div style={{ display: 'flex', gap: 6, alignItems: 'center', marginBottom: 2 }}>
                        <span style={{ fontSize: '0.65rem', fontWeight: 800, color: 'var(--brand-primary)', textTransform: 'uppercase' }}>{s.type}</span>
                        <span style={{ color: 'var(--text-muted)' }}>•</span>
                        <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{s.date}</span>
                      </div>
                      <div style={{ fontWeight: 800, fontSize: '0.95rem', color: 'var(--text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{s.vessel}</div>
                      <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)', fontFamily: 'monospace' }}>{s.container}</div>
                    </div>
                    <div style={{ position: 'relative' }}>
                      <select
                        value={s.status}
                        onChange={e => handleStatusChange(s.id, e.target.value)}
                        disabled={savingId === s.id}
                        style={{
                          appearance: 'none', background: ss.bg, color: ss.color, border: 'none',
                          borderRadius: 20, padding: '4px 24px 4px 10px', fontSize: '0.65rem', fontWeight: 800, textTransform: 'uppercase'
                        }}
                      >
                        {STATUSES.map(st => <option key={st} value={st}>{st}</option>)}
                      </select>
                      <span className="material-symbols-outlined" style={{ position: 'absolute', right: 4, top: '50%', transform: 'translateY(-50%)', fontSize: '0.9rem', color: ss.color, pointerEvents: 'none' }}>expand_more</span>
                    </div>
                  </div>

                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', paddingTop: 8, borderTop: '1px solid var(--border-subtle)' }}>
                    <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{s.port}</span>
                    <button onClick={() => setPendingDelete(s.id)} style={{ background: 'none', border: 'none', color: '#ef4444', padding: 4, display: 'flex' }}>
                      <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>delete</span>
                    </button>
                  </div>
                </div>
              )
            })}
            {schedules.length === 0 && (
              <div className="card" style={{ padding: 40, textAlign: 'center' }}>
                <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>No history found.</p>
              </div>
            )}
          </div>
        )}
      </div>
    </AppLayout>
    <ConfirmModal
      open={!!pendingDelete}
      message="Delete this schedule? This cannot be undone."
      onConfirm={() => handleDelete(pendingDelete)}
      onCancel={() => setPendingDelete(null)}
    />
    </Fragment>
  )
}
