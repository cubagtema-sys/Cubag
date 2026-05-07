import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

export default function AdminCargoSchedules() {
  const [loading, setLoading] = useState(false)
  const [success, setSuccess] = useState(false)
  const [schedules, setSchedules] = useState([])
  const [activeTab, setActiveTab] = useState('upload') // 'upload' or 'history'
  
  const [formData, setFormData] = useState({
    type: 'vanning',
    container: '',
    vessel: '',
    cargo: '',
    date: '',
    port: '',
    status: 'Scheduled'
  })

  const fetchSchedules = async () => {
    try {
      const res = await fetch(`${import.meta.env.VITE_API_URL}/schedules`)
      if (res.ok) setSchedules(await res.json())
    } catch (e) {
      console.error(e)
    }
  }

  useEffect(() => {
    fetchSchedules()
  }, [])

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value })
  }

  const handleUpload = async (e) => {
    e.preventDefault()
    setLoading(true)
    setSuccess(false)
    try {
      const res = await fetch(`${import.meta.env.VITE_API_URL}/schedules`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData)
      })
      if (res.ok) {
        setSuccess(true)
        setFormData({ type: 'vanning', container: '', vessel: '', cargo: '', date: '', port: '', status: 'Scheduled' })
        fetchSchedules()
        setTimeout(() => setSuccess(false), 3000)
      }
    } catch (e) {
      console.error(e)
    } finally {
      setLoading(false)
    }
  }

  return (
    <AppLayout title="Manage Schedules (Admin)" hideSearch>
      <div style={{ maxWidth: 1000, margin: '0 auto', padding: '24px 16px', display: 'flex', flexDirection: 'column', gap: 24 }}>
        <div>
          <h2 style={{ fontSize: '1.5rem', marginBottom: 8, display: 'flex', alignItems: 'center', gap: 8 }}>
            <span className="material-symbols-outlined" style={{ color: 'var(--brand-primary)' }}>local_shipping</span>
            Manage Logistics Data
          </h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '0.95rem' }}>Publish live vessel and vanning schedules or view uploaded history.</p>
        </div>

        <div style={{ display: 'flex', gap: '16px', marginBottom: '24px' }}>
          <button 
            className={`btn ${activeTab === 'upload' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => setActiveTab('upload')}
          >
            Upload Schedule
          </button>
          <button 
            className={`btn ${activeTab === 'history' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => setActiveTab('history')}
          >
            Upload History
          </button>
        </div>

        {activeTab === 'upload' ? (
          <div className="card" style={{ maxWidth: 700, margin: '0 auto' }}>
            <h2 style={{ fontSize: '1.4rem', marginBottom: 8, display: 'flex', alignItems: 'center', gap: 8 }}>
              <span className="material-symbols-outlined" style={{ color: 'var(--brand-primary)' }}>publish</span>
              Upload Cargo & Vessel Data
            </h2>
            <p style={{ color: 'var(--text-secondary)', fontSize: '0.95rem', marginBottom: 24 }}>
              Publish new vanning, devanning, or vessel movement schedules to the member portal.
            </p>

            {success && (
              <div style={{ padding: 12, background: 'rgba(16, 185, 129, 0.1)', color: 'var(--brand-success)', borderRadius: 8, marginBottom: 24, border: '1px solid rgba(16, 185, 129, 0.2)', display: 'flex', alignItems: 'center', gap: 8 }}>
                <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>check_circle</span>
                Schedule data published successfully!
              </div>
            )}

            <form onSubmit={handleUpload}>
              <div className="form-group" style={{ marginBottom: 16 }}>
                <label style={{ fontSize: '0.8rem', fontWeight: 700, color: '#000' }}>Schedule Type</label>
                <select name="type" value={formData.type} onChange={handleChange} style={{ width: '100%', padding: 12, border: '2px solid #e2e8f0', borderRadius: 8, background: '#fff' }}>
                  <option value="vanning">Vanning (Loading)</option>
                  <option value="devanning">Devanning (Unloading)</option>
                  <option value="movement">Vessel Movement</option>
                </select>
              </div>

              <div className="form-row" style={{ marginBottom: 16 }}>
                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700, color: '#000' }}>Container Number</label>
                  <input required type="text" name="container" placeholder="e.g. MSCU1234567" value={formData.container} onChange={handleChange} style={{ width: '100%', padding: 12, border: '2px solid #e2e8f0', borderRadius: 8, background: '#fff' }} />
                </div>
                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700, color: '#000' }}>Vessel Name</label>
                  <input required type="text" name="vessel" placeholder="e.g. Maersk Atlantic" value={formData.vessel} onChange={handleChange} style={{ width: '100%', padding: 12, border: '2px solid #e2e8f0', borderRadius: 8, background: '#fff' }} />
                </div>
              </div>

              <div className="form-row" style={{ marginBottom: 16 }}>
                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700, color: '#000' }}>Cargo Type</label>
                  <input required type="text" name="cargo" placeholder="e.g. Electronics" value={formData.cargo} onChange={handleChange} style={{ width: '100%', padding: 12, border: '2px solid #e2e8f0', borderRadius: 8, background: '#fff' }} />
                </div>
                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700, color: '#000' }}>Date / Time</label>
                  <input required type="text" name="date" placeholder="e.g. 10 May 2026" value={formData.date} onChange={handleChange} style={{ width: '100%', padding: 12, border: '2px solid #e2e8f0', borderRadius: 8, background: '#fff' }} />
                </div>
              </div>

              <div className="form-row" style={{ marginBottom: 32 }}>
                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700, color: '#000' }}>Port / Location</label>
                  <input required type="text" name="port" placeholder="e.g. Tema Port" value={formData.port} onChange={handleChange} style={{ width: '100%', padding: 12, border: '2px solid #e2e8f0', borderRadius: 8, background: '#fff' }} />
                </div>
                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700, color: '#000' }}>Status</label>
                  <select name="status" value={formData.status} onChange={handleChange} style={{ width: '100%', padding: 12, border: '2px solid #e2e8f0', borderRadius: 8, background: '#fff' }}>
                    <option value="Scheduled">Scheduled</option>
                    <option value="In Progress">In Progress</option>
                    <option value="Completed">Completed</option>
                  </select>
                </div>
              </div>

              <button type="submit" className="btn btn-primary btn-lg" style={{ width: '100%', height: 54 }} disabled={loading}>
                {loading ? 'Publishing Data...' : 'Upload Data to Portal'}
              </button>
            </form>
          </div>
        ) : (
          <div className="card">
            <h3 style={{ marginBottom: '16px' }}>Uploaded Schedules History</h3>
            <div className="responsive-table-wrapper">
              <table className="responsive-table" style={{ width: '100%', textAlign: 'left', borderCollapse: 'collapse' }}>
                <thead>
                  <tr style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Type</th>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Vessel / Container</th>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Port & Date</th>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {schedules.map((s, i) => (
                    <tr key={i} style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                      <td data-label="Type" style={{ padding: '12px', fontSize: '0.9rem', fontWeight: 600, textTransform: 'capitalize' }}>
                        {s.type}
                        <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 400 }}>{s.cargo}</div>
                      </td>
                      <td data-label="Vessel / Container" style={{ padding: '12px', fontSize: '0.9rem' }}>
                        <div style={{ fontWeight: 600 }}>{s.vessel}</div>
                        <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)', fontFamily: 'monospace' }}>{s.container}</div>
                      </td>
                      <td data-label="Port & Date" style={{ padding: '12px', fontSize: '0.9rem', color: 'var(--text-secondary)' }}>
                        <div>{s.port}</div>
                        <div style={{ fontSize: '0.8rem' }}>{s.date}</div>
                      </td>
                      <td data-label="Status" style={{ padding: '12px' }}>
                        <span className={`badge ${s.status === 'Completed' ? 'badge-success' : s.status === 'In Progress' ? 'badge-warning' : 'badge-info'}`}>
                          {s.status}
                        </span>
                      </td>
                    </tr>
                  ))}
                  {schedules.length === 0 && (
                    <tr>
                      <td colSpan="4" style={{ padding: '24px', textAlign: 'center', color: 'var(--text-muted)' }}>No schedules uploaded yet.</td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </div>
    </AppLayout>
  )
}
