import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

const API_URL = import.meta.env.VITE_API_URL

export default function AdminIntelligence() {
  const [data, setData] = useState({ ports: [], bunkers: [], alerts: [] })
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState('')

  useEffect(() => {
    fetch(`${API_URL}/intelligence`)
      .then(res => res.json())
      .then(d => {
        setData(d)
        setLoading(false)
      })
  }, [])

  const handleSave = async () => {
    setSaving(true)
    setMessage('')
    try {
      const res = await fetch(`${API_URL}/intelligence`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('cubag_token')}`
        },
        body: JSON.stringify(data)
      })
      if (res.ok) {
        setMessage('Successfully updated intelligence data!')
      } else {
        setMessage('Failed to update data.')
      }
    } catch (e) {
      setMessage('Error connecting to server.')
    } finally {
      setSaving(false)
    }
  }

  const updatePort = (idx, field, val) => {
    const newPorts = [...data.ports]
    newPorts[idx][field] = val
    setData({ ...data, ports: newPorts })
  }

  const updateAlert = (idx, field, val) => {
    const newAlerts = [...data.alerts]
    newAlerts[idx][field] = val
    setData({ ...data, alerts: newAlerts })
  }

  if (loading) return <AppLayout title="Intelligence">Loading...</AppLayout>

  return (
    <AppLayout title="Intelligence">
      <div style={{ maxWidth: 800, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16, paddingBottom: 60 }}>
        
        {/* Page Title for Content */}
        <div style={{ marginBottom: 4 }}>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Intelligence Control</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Manually update port data and security alerts.</p>
        </div>

        <div style={{ padding: '16px 20px', background: 'var(--bg-elevated)', borderRadius: 12 }}>
          <h2 style={{ margin: '0 0 4px', fontSize: '1.1rem', fontWeight: 700 }}>Manual Feeds</h2>
          <p style={{ margin: 0, color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
            Update data shown to members in the live feed.
          </p>
        </div>

        {message && (
          <div style={{ padding: 12, borderRadius: 8, background: message.includes('Success') ? '#10b981' : '#ef4444', color: '#fff', fontWeight: 600, fontSize: '0.85rem' }}>
            {message}
          </div>
        )}

        {/* Port Congestion Section */}
        <section>
          <h3 style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 12, fontSize: '1rem', fontWeight: 700 }}>
            <span className="material-symbols-outlined" style={{ color: '#f59e0b', fontSize: '1.2rem' }}>directions_boat</span>
            Port Index
          </h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {data.ports.map((p, i) => (
              <div key={i} style={{ display: 'flex', flexDirection: 'column', gap: 8, background: 'var(--bg-base)', padding: 12, borderRadius: 10, border: '1px solid var(--border-subtle)' }}>
                <input type="text" value={p.port} onChange={e => updatePort(i, 'port', e.target.value)} placeholder="Port Name" style={{ width: '100%', background: 'transparent', border: '1px solid var(--border-default)', color: 'var(--text-primary)', padding: '10px', borderRadius: 8, fontSize: '0.9rem' }} />
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                  <input type="text" value={p.status} onChange={e => updatePort(i, 'status', e.target.value)} placeholder="Status" style={{ background: 'transparent', border: '1px solid var(--border-default)', color: 'var(--text-primary)', padding: '10px', borderRadius: 8, fontSize: '0.9rem' }} />
                  <select value={p.color} onChange={e => updatePort(i, 'color', e.target.value)} style={{ background: 'transparent', border: '1px solid var(--border-default)', color: 'var(--text-primary)', padding: '10px', borderRadius: 8, fontSize: '0.9rem' }}>
                    <option value="#ef4444">High</option>
                    <option value="#f59e0b">Med</option>
                    <option value="#10b981">Low</option>
                  </select>
                </div>
              </div>
            ))}
          </div>
        </section>

        {/* Alerts Section */}
        <section>
          <h3 style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 12, fontSize: '1rem', fontWeight: 700 }}>
            <span className="material-symbols-outlined" style={{ color: '#ef4444', fontSize: '1.2rem' }}>warning</span>
            Alerts Feed
          </h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {data.alerts.map((a, i) => (
              <div key={i} style={{ background: 'var(--bg-base)', padding: 12, borderRadius: 10, display: 'flex', flexDirection: 'column', gap: 8, border: '1px solid var(--border-subtle)' }}>
                <input type="text" value={a.title} onChange={e => updateAlert(i, 'title', e.target.value)} placeholder="Alert Title" style={{ background: 'transparent', border: '1px solid var(--border-default)', color: 'var(--text-primary)', padding: '10px', borderRadius: 8, fontWeight: 700, fontSize: '0.9rem' }} />
                <textarea value={a.detail} onChange={e => updateAlert(i, 'detail', e.target.value)} placeholder="Details..." style={{ background: 'transparent', border: '1px solid var(--border-default)', color: 'var(--text-secondary)', padding: '10px', borderRadius: 8, minHeight: 60, fontFamily: 'inherit', fontSize: '0.85rem' }} />
                <select value={a.severity} onChange={e => updateAlert(i, 'severity', e.target.value)} style={{ background: 'transparent', border: '1px solid var(--border-default)', color: 'var(--text-primary)', padding: '10px', borderRadius: 8, fontSize: '0.9rem' }}>
                  <option value="high">Critical</option>
                  <option value="medium">Warning</option>
                  <option value="low">Info</option>
                </select>
              </div>
            ))}
          </div>
        </section>

        <button 
          onClick={handleSave} 
          disabled={saving}
          className="btn btn-primary btn-lg"
          style={{ width: '100%', height: 48, borderRadius: 24, fontSize: '0.95rem' }}
        >
          {saving ? 'Saving...' : 'Update Intelligence'}
        </button>

      </div>
    </AppLayout>
  )
}
