import { useState, useEffect } from 'react'
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

  // ── Inline status update ─────────────────────────────────────────────────────
  const handleStatusChange = async (id, newStatus) => {
    setSavingId(id)
    // Optimistic update
    setSchedules(prev => prev.map(s => s.id === id ? { ...s, status: newStatus } : s))
    try {
      await fetch(`${API_URL}/schedules/${id}`, {
        method: 'PATCH',
        headers: authHeader,
        body: JSON.stringify({ status: newStatus })
      })
    } catch (e) {
      console.error(e)
      fetchSchedules() // revert on error
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
    finally { setDeletingId(null) }
  }

  return (
    <AppLayout title="Cargo Management" hideSearch>
      <div style={{ maxWidth: 1000, margin: '0 auto', padding: '24px 16px', display: 'flex', flexDirection: 'column', gap: 24 }}>
        <div>
          <h2 style={{ fontSize: '1.5rem', marginBottom: 8, display: 'flex', alignItems: 'center', gap: 8 }}>
            <span className="material-symbols-outlined" style={{ color: 'var(--brand-primary)' }}>local_shipping</span>
            Manage Logistics Data
          </h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '0.95rem' }}>Publish live vessel and vanning schedules or view uploaded history.</p>
        </div>

        <div style={{ display: 'flex', gap: '16px', marginBottom: '24px' }}>
          <button className={`btn ${activeTab === 'upload' ? 'btn-primary' : 'btn-outline'}`} onClick={() => setActiveTab('upload')}>Upload Schedule</button>
          <button className={`btn ${activeTab === 'history' ? 'btn-primary' : 'btn-outline'}`} onClick={() => setActiveTab('history')}>
            Upload History
            {schedules.length > 0 && <span style={{ marginLeft: 8, background: 'rgba(255,255,255,0.25)', borderRadius: 12, padding: '1px 8px', fontSize: '0.8rem', fontWeight: 800 }}>{schedules.length}</span>}
          </button>
        </div>

        {activeTab === 'upload' ? (
          <div className="card" style={{ maxWidth: 700, margin: '0 auto' }}>
            <h2 style={{ fontSize: '1.4rem', marginBottom: 8, display: 'flex', alignItems: 'center', gap: 8 }}>
              <span className="material-symbols-outlined" style={{ color: 'var(--brand-primary)' }}>publish</span>
              Upload Cargo & Vessel Data
            </h2>
            <p style={{ color: 'var(--text-secondary)', fontSize: '0.95rem', marginBottom: 24 }}>Publish new vanning, devanning, or vessel movement schedules to the member portal.</p>

            {success && (
              <div style={{ padding: 12, background: 'rgba(16,185,129,0.1)', color: 'var(--brand-success)', borderRadius: 8, marginBottom: 24, border: '1px solid rgba(16,185,129,0.2)', display: 'flex', alignItems: 'center', gap: 8 }}>
                <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>check_circle</span>
                Schedule data published successfully!
              </div>
            )}

            <form onSubmit={handleUpload}>
              <div className="form-group" style={{ marginBottom: 16 }}>
                <label style={{ fontSize: '0.8rem', fontWeight: 700 }}>Schedule Type</label>
                <select name="type" value={formData.type} onChange={handleChange} style={{ width: '100%', padding: 12, border: '2px solid var(--border-subtle)', borderRadius: 8, background: 'var(--bg-elevated)', color: 'var(--text-primary)' }}>
                  <option value="vanning">Vanning (Loading)</option>
                  <option value="devanning">Devanning (Unloading)</option>
                  <option value="movement">Vessel Movement</option>
                </select>
              </div>

              <div className="form-row" style={{ marginBottom: 16 }}>
                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700 }}>Container Number</label>
                  <input required type="text" name="container" placeholder="e.g. MSCU1234567" value={formData.container} onChange={handleChange} style={{ width: '100%', padding: 12, border: '2px solid var(--border-subtle)', borderRadius: 8, background: 'var(--bg-elevated)', color: 'var(--text-primary)' }} />
                </div>
                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700 }}>Vessel Name</label>
                  <input required type="text" name="vessel" placeholder="e.g. Maersk Atlantic" value={formData.vessel} onChange={handleChange} style={{ width: '100%', padding: 12, border: '2px solid var(--border-subtle)', borderRadius: 8, background: 'var(--bg-elevated)', color: 'var(--text-primary)' }} />
                </div>
              </div>

              <div className="form-row" style={{ marginBottom: 16 }}>
                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700 }}>Cargo Type</label>
                  <input required type="text" name="cargo" placeholder="e.g. Electronics" value={formData.cargo} onChange={handleChange} style={{ width: '100%', padding: 12, border: '2px solid var(--border-subtle)', borderRadius: 8, background: 'var(--bg-elevated)', color: 'var(--text-primary)' }} />
                </div>
                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700 }}>Date / Time</label>
                  <input required type="text" name="date" placeholder="e.g. 10 May 2026" value={formData.date} onChange={handleChange} style={{ width: '100%', padding: 12, border: '2px solid var(--border-subtle)', borderRadius: 8, background: 'var(--bg-elevated)', color: 'var(--text-primary)' }} />
                </div>
              </div>

              {/* ── Movement-only fields ──────────────────────────────────── */}
              {formData.type === 'movement' && (
                <>
                  <div style={{ padding: '12px 16px', background: 'rgba(59,130,246,0.06)', border: '1px solid rgba(59,130,246,0.15)', borderRadius: 10, marginBottom: 16 }}>
                    <div style={{ fontSize: '0.8rem', fontWeight: 700, color: '#3b82f6', marginBottom: 12, display: 'flex', alignItems: 'center', gap: 6 }}>
                      <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>directions_boat</span>
                      Vessel Route Details
                    </div>
                    <div className="form-row" style={{ marginBottom: 12 }}>
                      <div className="form-group">
                        <label style={{ fontSize: '0.8rem', fontWeight: 700 }}>Origin Port (Departure)</label>
                        <input type="text" name="origin" placeholder="e.g. Port of Hamburg" value={formData.origin} onChange={handleChange}
                          style={{ width: '100%', padding: 12, border: '2px solid var(--border-subtle)', borderRadius: 8, background: 'var(--bg-elevated)', color: 'var(--text-primary)' }} />
                      </div>
                      <div className="form-group">
                        <label style={{ fontSize: '0.8rem', fontWeight: 700 }}>Destination Port (Arrival)</label>
                        <input type="text" name="destination" placeholder="e.g. Tema Port, Ghana" value={formData.destination} onChange={handleChange}
                          style={{ width: '100%', padding: 12, border: '2px solid var(--border-subtle)', borderRadius: 8, background: 'var(--bg-elevated)', color: 'var(--text-primary)' }} />
                      </div>
                    </div>
                    <div className="form-group">
                      <label style={{ fontSize: '0.8rem', fontWeight: 700, display: 'flex', justifyContent: 'space-between' }}>
                        <span>Current Route Progress</span>
                        <span style={{ color: 'var(--brand-primary)' }}>Automatic</span>
                      </label>
                      <div style={{ padding: '12px 16px', background: 'var(--bg-base)', borderRadius: 8, border: '1px solid var(--border-subtle)', fontSize: '0.85rem', color: 'var(--text-secondary)', display: 'flex', alignItems: 'center', gap: 10 }}>
                        <span className="material-symbols-outlined" style={{ fontSize: '1.3rem', color: 'var(--brand-primary)' }}>auto_mode</span>
                        <span>Route progress will automatically update based on the shipment's <strong>Status</strong>.</span>
                      </div>
                      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: 12 }}>
                        <span>🚢 {formData.origin || 'Origin'}</span>
                        <span>{formData.destination || 'Destination'} ⚓</span>
                      </div>
                    </div>
                  </div>
                </>
              )}

              <div className="form-row" style={{ marginBottom: 32 }}>
                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700 }}>Port / Location</label>
                  <input required type="text" name="port" placeholder="e.g. Tema Port" value={formData.port} onChange={handleChange} style={{ width: '100%', padding: 12, border: '2px solid var(--border-subtle)', borderRadius: 8, background: 'var(--bg-elevated)', color: 'var(--text-primary)' }} />
                </div>
                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700 }}>Initial Status</label>
                  <select name="status" value={formData.status} onChange={handleChange} style={{ width: '100%', padding: 12, border: '2px solid var(--border-subtle)', borderRadius: 8, background: 'var(--bg-elevated)', color: 'var(--text-primary)' }}>
                    {STATUSES.map(s => <option key={s} value={s}>{s}</option>)}
                  </select>
                </div>
              </div>

              <button type="submit" className="btn btn-primary btn-lg" style={{ width: '100%', height: 54 }} disabled={loading}>
                {loading ? 'Publishing...' : 'Upload Data to Portal'}
              </button>
            </form>
          </div>
        ) : (
          <div className="card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
              <h3 style={{ margin: 0 }}>Uploaded Schedules History</h3>
              <span style={{ fontSize: '0.82rem', color: 'var(--text-muted)' }}>Click status to update · Trash to delete</span>
            </div>
            <div className="responsive-table-wrapper">
              <table className="responsive-table" style={{ width: '100%', textAlign: 'left', borderCollapse: 'collapse' }}>
                <thead>
                  <tr style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Type</th>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Vessel / Container</th>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Port & Date</th>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Status</th>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem', textAlign: 'right' }}>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {schedules.map((s) => {
                    const ss = statusStyle[s.status] || statusStyle['Scheduled']
                    return (
                      <tr key={s.id} style={{ borderBottom: '1px solid var(--border-subtle)', opacity: deletingId === s.id ? 0.4 : 1, transition: 'opacity 0.2s' }}>
                        <td data-label="Type" style={{ padding: '14px 12px', fontSize: '0.9rem', fontWeight: 600, textTransform: 'capitalize' }}>
                          {s.type}
                          <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 400 }}>{s.cargo}</div>
                        </td>
                        <td data-label="Vessel / Container" style={{ padding: '14px 12px', fontSize: '0.9rem' }}>
                          <div style={{ fontWeight: 600 }}>{s.vessel}</div>
                          <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)', fontFamily: 'monospace' }}>{s.container}</div>
                        </td>
                        <td data-label="Port & Date" style={{ padding: '14px 12px', fontSize: '0.9rem', color: 'var(--text-secondary)' }}>
                          <div>{s.port}</div>
                          <div style={{ fontSize: '0.8rem' }}>{s.date}</div>
                        </td>
                        <td data-label="Status" style={{ padding: '14px 12px' }}>
                          {/* ── Inline status dropdown ── */}
                          <div style={{ position: 'relative', display: 'inline-block' }}>
                            <select
                              value={s.status}
                              onChange={e => handleStatusChange(s.id, e.target.value)}
                              disabled={savingId === s.id}
                              style={{
                                appearance: 'none',
                                WebkitAppearance: 'none',
                                background: ss.bg,
                                color: ss.color,
                                border: `1.5px solid ${ss.color}40`,
                                borderRadius: 20,
                                padding: '5px 28px 5px 12px',
                                fontSize: '0.75rem',
                                fontWeight: 800,
                                cursor: 'pointer',
                                outline: 'none',
                                transition: 'all 0.2s',
                                minWidth: 110
                              }}
                            >
                              {STATUSES.map(st => <option key={st} value={st}>{st}</option>)}
                            </select>
                            <span className="material-symbols-outlined" style={{ position: 'absolute', right: 6, top: '50%', transform: 'translateY(-50%)', fontSize: '0.9rem', color: ss.color, pointerEvents: 'none' }}>
                              {savingId === s.id ? 'sync' : 'expand_more'}
                            </span>
                          </div>
                        </td>
                        <td style={{ padding: '14px 12px', textAlign: 'right' }}>
                          <button
                            onClick={() => setPendingDelete(s.id)}
                            disabled={deletingId === s.id}
                            title="Delete schedule"
                            style={{ background: 'rgba(239,68,68,0.08)', border: 'none', borderRadius: 8, padding: '6px 10px', cursor: 'pointer', color: '#ef4444', display: 'inline-flex', alignItems: 'center', transition: 'background 0.2s' }}
                            onMouseOver={e => e.currentTarget.style.background = 'rgba(239,68,68,0.18)'}
                            onMouseOut={e => e.currentTarget.style.background = 'rgba(239,68,68,0.08)'}
                          >
                            <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>delete</span>
                          </button>
                        </td>
                      </tr>
                    )
                  })}
                  {schedules.length === 0 && (
                    <tr>
                      <td colSpan="5" style={{ padding: '48px', textAlign: 'center', color: 'var(--text-muted)' }}>
                        <span className="material-symbols-outlined" style={{ fontSize: '2.5rem', display: 'block', marginBottom: 8 }}>inventory_2</span>
                        No schedules uploaded yet.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
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
  )
}


