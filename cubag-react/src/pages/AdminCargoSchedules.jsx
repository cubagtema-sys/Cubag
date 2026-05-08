import { useState, Fragment } from 'react'
import AppLayout from '../components/AppLayout'
import CustomSelect from '../components/CustomSelect'
import useAutoRefresh from '../hooks/useAutoRefresh'
import ConfirmModal from '../components/ConfirmModal'

const API_URL = import.meta.env.VITE_API_URL

const TYPE_OPTIONS = [
  { value: 'vanning',   label: 'Vanning (Loading)',   icon: 'inventory_2' },
  { value: 'devanning', label: 'Devanning (Unloading)',icon: 'unarchive' },
  { value: 'movement',  label: 'Vessel Movement',     icon: 'directions_boat' },
]

const STATUS_OPTIONS = [
  { value: 'Scheduled',   label: 'Scheduled',   icon: 'schedule' },
  { value: 'In Progress', label: 'In Progress', icon: 'sync' },
  { value: 'Completed',   label: 'Completed',   icon: 'check_circle' },
  { value: 'Cancelled',   label: 'Cancelled',   icon: 'cancel' },
]

const statusStyle = {
  'Scheduled':  { bg: 'rgba(59,130,246,0.12)',  color: '#3b82f6' },
  'In Progress':{ bg: 'rgba(245,158,11,0.12)',  color: '#f59e0b' },
  'Completed':  { bg: 'rgba(16,185,129,0.12)',  color: '#10b981' },
  'Cancelled':  { bg: 'rgba(239,68,68,0.12)',   color: '#ef4444' },
}

const typeIcon = { vanning: 'inventory_2', devanning: 'unarchive', movement: 'directions_boat' }

export default function AdminCargoSchedules() {
  const [loading, setLoading]     = useState(false)
  const [success, setSuccess]     = useState(false)
  const [schedules, setSchedules] = useState([])
  const [activeTab, setActiveTab] = useState('upload')
  const [savingId, setSavingId]   = useState(null)
  const [deletingId, setDeletingId] = useState(null)
  const [pendingDelete, setPendingDelete] = useState(null)
  const [filterStatus, setFilterStatus] = useState('All')

  const [formData, setFormData] = useState({
    type: 'vanning', container: '', vessel: '', cargo: '',
    date: '', port: '', status: 'Scheduled',
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
    e.preventDefault(); setLoading(true); setSuccess(false)
    try {
      const res = await fetch(`${API_URL}/schedules`, {
        method: 'POST', headers: authHeader, body: JSON.stringify(formData)
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
        method: 'PATCH', headers: authHeader, body: JSON.stringify({ status: newStatus })
      })
    } catch (e) { fetchSchedules() }
    finally { setSavingId(null) }
  }

  const handleDelete = async (id) => {
    setDeletingId(id)
    try {
      const res = await fetch(`${API_URL}/schedules/${id}`, { method: 'DELETE', headers: authHeader })
      if (res.ok) setSchedules(prev => prev.filter(s => s.id !== id))
    } catch (e) { console.error(e) }
    finally { setDeletingId(null); setPendingDelete(null) }
  }

  const FILTER_OPTIONS = [
    { value: 'All', label: 'All Statuses', icon: 'filter_list' },
    ...STATUS_OPTIONS
  ]

  const displayed = filterStatus === 'All' ? schedules : schedules.filter(s => s.status === filterStatus)

  return (
    <Fragment>
    <AppLayout title="Cargo">
      <div style={{ maxWidth: 1000, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>

        <div style={{ marginBottom: 4 }}>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Logistics Management</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Publish live vessel and container schedules.</p>
        </div>

        {/* Tab bar */}
        <div style={{ display: 'flex', gap: 6, background: 'var(--bg-surface)', borderRadius: 10, padding: 3 }}>
          {[
            { id: 'upload',  label: 'New Entry', icon: 'publish' },
            { id: 'history', label: 'History',   icon: 'history', badge: schedules.length }
          ].map(t => (
            <button key={t.id} onClick={() => setActiveTab(t.id)} style={{
              flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
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

        {/* ── Upload Tab ── */}
        {activeTab === 'upload' ? (
          <div className="feed-card" style={{ maxWidth: 700, margin: '0 auto', width: '100%', borderRadius: 14 }}>
            <div className="card-header" style={{ padding: '12px 16px' }}><span className="card-title">Compose Entry</span></div>
            <div className="card-body" style={{ padding: '16px' }}>
              {success && (
                <div style={{ padding: '10px 14px', background: 'rgba(16,185,129,0.1)', color: '#10b981', borderRadius: 10, marginBottom: 16, fontSize: '0.85rem', fontWeight: 700, border: '1px solid rgba(16,185,129,0.2)' }}>
                  Published successfully!
                </div>
              )}
              <form onSubmit={handleUpload} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>

                {/* Type — CustomSelect */}
                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700, marginBottom: 4, display: 'block' }}>Type</label>
                  <CustomSelect
                    value={formData.type}
                    onChange={val => setFormData({ ...formData, type: val })}
                    options={TYPE_OPTIONS}
                    icon="local_shipping"
                  />
                </div>

                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700, marginBottom: 4, display: 'block' }}>Container ID</label>
                  <input required type="text" name="container" placeholder="MSCU..." value={formData.container} onChange={handleChange} style={{ width: '100%', padding: 10, border: '1.5px solid var(--border-default)', borderRadius: 8, background: 'var(--bg-base)', fontSize: '0.9rem', boxSizing: 'border-box' }} />
                </div>

                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700, marginBottom: 4, display: 'block' }}>Vessel Name</label>
                  <input required type="text" name="vessel" placeholder="Vessel..." value={formData.vessel} onChange={handleChange} style={{ width: '100%', padding: 10, border: '1.5px solid var(--border-default)', borderRadius: 8, background: 'var(--bg-base)', fontSize: '0.9rem', boxSizing: 'border-box' }} />
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                  <div className="form-group">
                    <label style={{ fontSize: '0.8rem', fontWeight: 700, marginBottom: 4, display: 'block' }}>Date</label>
                    <input required type="text" name="date" placeholder="10 May" value={formData.date} onChange={handleChange} style={{ width: '100%', padding: 10, border: '1.5px solid var(--border-default)', borderRadius: 8, background: 'var(--bg-base)', fontSize: '0.9rem', boxSizing: 'border-box' }} />
                  </div>
                  <div className="form-group">
                    <label style={{ fontSize: '0.8rem', fontWeight: 700, marginBottom: 4, display: 'block' }}>Port</label>
                    <input required type="text" name="port" placeholder="Tema" value={formData.port} onChange={handleChange} style={{ width: '100%', padding: 10, border: '1.5px solid var(--border-default)', borderRadius: 8, background: 'var(--bg-base)', fontSize: '0.9rem', boxSizing: 'border-box' }} />
                  </div>
                </div>

                {/* Status — CustomSelect */}
                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700, marginBottom: 4, display: 'block' }}>Status</label>
                  <CustomSelect
                    value={formData.status}
                    onChange={val => setFormData({ ...formData, status: val })}
                    options={STATUS_OPTIONS}
                    icon="flag"
                  />
                </div>

                {formData.type === 'movement' && (
                  <div style={{ padding: 12, background: 'rgba(59,130,246,0.05)', borderRadius: 10, border: '1px solid rgba(59,130,246,0.1)' }}>
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
                      <div className="form-group">
                        <label style={{ fontSize: '0.75rem', fontWeight: 700, display: 'block', marginBottom: 4 }}>Origin</label>
                        <input type="text" name="origin" value={formData.origin} onChange={handleChange} style={{ width: '100%', padding: 8, border: '1.5px solid var(--border-default)', borderRadius: 6, fontSize: '0.85rem', boxSizing: 'border-box' }} />
                      </div>
                      <div className="form-group">
                        <label style={{ fontSize: '0.75rem', fontWeight: 700, display: 'block', marginBottom: 4 }}>Destination</label>
                        <input type="text" name="destination" value={formData.destination} onChange={handleChange} style={{ width: '100%', padding: 8, border: '1.5px solid var(--border-default)', borderRadius: 6, fontSize: '0.85rem', boxSizing: 'border-box' }} />
                      </div>
                    </div>
                  </div>
                )}

                <button type="submit" className="btn btn-primary btn-lg" style={{ width: '100%', height: 48, fontSize: '0.95rem', justifyContent: 'center' }} disabled={loading}>
                  <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>publish</span>
                  {loading ? 'Publishing...' : 'Upload to Portal'}
                </button>
              </form>
            </div>
          </div>

        ) : (
          /* ── History Tab ── */
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>

            {/* Filter bar — no record count */}
            <div style={{ flex: 1 }}>
              <CustomSelect value={filterStatus} onChange={setFilterStatus} options={FILTER_OPTIONS} icon="filter_list" />
            </div>

            {displayed.length === 0 ? (
              <div className="card" style={{ padding: 48, textAlign: 'center', borderRadius: 14 }}>
                <span className="material-symbols-outlined" style={{ fontSize: '3rem', display: 'block', marginBottom: 12, opacity: 0.3 }}>directions_boat</span>
                <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem', fontWeight: 600 }}>No schedules found.</p>
              </div>
            ) : displayed.map(s => {
              const ss = statusStyle[s.status] || statusStyle['Scheduled']
              const icon = typeIcon[s.type] || 'local_shipping'
              return (
                <div key={s.id} className="feed-card" style={{ padding: 0, borderRadius: 14, opacity: deletingId === s.id ? 0.4 : 1 }}>
                  {/* Colored top stripe */}
                  <div style={{ height: 3, background: ss.color }} />

                  <div style={{ padding: '14px 16px', display: 'flex', flexDirection: 'column', gap: 10 }}>
                      {/* Header row — icon + vessel + container only */}
                      <div style={{ display: 'flex', gap: 12, alignItems: 'center', minWidth: 0 }}>
                        <div style={{ width: 40, height: 40, borderRadius: 10, background: `${ss.color}18`, color: ss.color, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                          <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>{icon}</span>
                        </div>
                        <div style={{ minWidth: 0 }}>
                          <div style={{ fontWeight: 800, fontSize: '0.95rem', color: 'var(--text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{s.vessel}</div>
                          <div style={{ fontSize: '0.72rem', color: 'var(--text-muted)', fontFamily: 'monospace', marginTop: 1 }}>{s.container}</div>
                        </div>
                      </div>

                    {/* Detail row */}
                    <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap', fontSize: '0.75rem', color: 'var(--text-secondary)' }}>
                      <span style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                        <span className="material-symbols-outlined" style={{ fontSize: '0.9rem', color: 'var(--text-muted)' }}>location_on</span>
                        {s.port}
                      </span>
                      <span style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                        <span className="material-symbols-outlined" style={{ fontSize: '0.9rem', color: 'var(--text-muted)' }}>calendar_today</span>
                        {s.date}
                      </span>
                      <span style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                        <span className="material-symbols-outlined" style={{ fontSize: '0.9rem', color: 'var(--brand-primary)' }}>category</span>
                        <span style={{ color: 'var(--brand-primary)', fontWeight: 700, textTransform: 'capitalize' }}>{s.type}</span>
                      </span>
                      {s.origin && (
                        <span style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                          <span className="material-symbols-outlined" style={{ fontSize: '0.9rem', color: 'var(--text-muted)' }}>route</span>
                          {s.origin} → {s.destination}
                        </span>
                      )}
                    </div>

                    {/* Footer — status dropdown + remove button */}
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10, paddingTop: 8, borderTop: '1px solid var(--border-subtle)' }}>
                      {/* Status selector — full width before remove */}
                      <div style={{ flex: 1 }}>
                        <CustomSelect
                          value={s.status}
                          onChange={val => handleStatusChange(s.id, val)}
                          options={STATUS_OPTIONS}
                          icon="flag"
                        />
                      </div>
                      <button
                        onClick={() => setPendingDelete(s.id)}
                        style={{ display: 'flex', alignItems: 'center', gap: 4, padding: '7px 12px', borderRadius: 8, border: '1px solid rgba(239,68,68,0.2)', background: 'rgba(239,68,68,0.06)', color: '#ef4444', cursor: 'pointer', fontSize: '0.72rem', fontWeight: 700, flexShrink: 0 }}
                      >
                        <span className="material-symbols-outlined" style={{ fontSize: '0.95rem' }}>delete</span>
                        Remove
                      </button>
                    </div>
                  </div>
                </div>
              )
            })}
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
