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

  if (loading) return <AppLayout title="Loading Intelligence Hub...">Loading...</AppLayout>

  return (
    <AppLayout title="Intelligence Hub Manager">
      <div style={{ maxWidth: 800, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 32, paddingBottom: 60 }}>
        
        <div style={{ background: 'var(--bg-surface)', padding: 24, borderRadius: 16, border: '1px solid var(--border-subtle)' }}>
          <h2 style={{ margin: '0 0 8px', fontSize: '1.2rem' }}>Manual Intelligence Feeds</h2>
          <p style={{ margin: 0, color: 'var(--text-secondary)', fontSize: '0.9rem' }}>
            Update port congestion and supply chain alerts manually to ensure members see accurate local info.
          </p>
        </div>

        {message && (
          <div style={{ padding: 16, borderRadius: 12, background: message.includes('Success') ? '#10b98122' : '#ef444422', color: message.includes('Success') ? '#10b981' : '#ef4444', fontWeight: 600 }}>
            {message}
          </div>
        )}

        {/* Port Congestion Section */}
        <section>
          <h3 style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 16 }}>
            <span className="material-symbols-outlined" style={{ color: '#f59e0b' }}>directions_boat</span>
            Port Congestion Index
          </h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {data.ports.map((p, i) => (
              <div key={i} style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 150px', gap: 12, background: 'var(--bg-base)', padding: 12, borderRadius: 10 }}>
                <input type="text" value={p.port} onChange={e => updatePort(i, 'port', e.target.value)} placeholder="Port Name" style={{ background: 'transparent', border: '1px solid var(--border-subtle)', color: 'var(--text-primary)', padding: '8px 12px', borderRadius: 8 }} />
                <input type="text" value={p.status} onChange={e => updatePort(i, 'status', e.target.value)} placeholder="Status (e.g. High (4 Days))" style={{ background: 'transparent', border: '1px solid var(--border-subtle)', color: 'var(--text-primary)', padding: '8px 12px', borderRadius: 8 }} />
                <select value={p.color} onChange={e => updatePort(i, 'color', e.target.value)} style={{ background: 'transparent', border: '1px solid var(--border-subtle)', color: 'var(--text-primary)', padding: '8px 12px', borderRadius: 8 }}>
                  <option value="#ef4444">Red (High)</option>
                  <option value="#f59e0b">Orange (Med)</option>
                  <option value="#10b981">Green (Low)</option>
                </select>
              </div>
            ))}
          </div>
        </section>



        {/* Alerts Section */}
        <section>
          <h3 style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 16 }}>
            <span className="material-symbols-outlined" style={{ color: '#ef4444' }}>warning</span>
            Security & Supply Chain Alerts
          </h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {data.alerts.map((a, i) => (
              <div key={i} style={{ background: 'var(--bg-base)', padding: 16, borderRadius: 10, display: 'flex', flexDirection: 'column', gap: 12 }}>
                <input type="text" value={a.title} onChange={e => updateAlert(i, 'title', e.target.value)} placeholder="Alert Title" style={{ background: 'transparent', border: '1px solid var(--border-subtle)', color: 'var(--text-primary)', padding: '8px 12px', borderRadius: 8, fontWeight: 700 }} />
                <textarea value={a.detail} onChange={e => updateAlert(i, 'detail', e.target.value)} placeholder="Alert Details" style={{ background: 'transparent', border: '1px solid var(--border-subtle)', color: 'var(--text-secondary)', padding: '8px 12px', borderRadius: 8, minHeight: 80, fontFamily: 'inherit' }} />
                <select value={a.severity} onChange={e => updateAlert(i, 'severity', e.target.value)} style={{ background: 'transparent', border: '1px solid var(--border-subtle)', color: 'var(--text-primary)', padding: '8px 12px', borderRadius: 8, width: 150 }}>
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
          style={{ 
            background: 'var(--brand-primary)', 
            color: '#fff', 
            border: 'none', 
            padding: '16px', 
            borderRadius: 12, 
            fontWeight: 700, 
            fontSize: '1rem',
            cursor: 'pointer',
            boxShadow: '0 4px 15px rgba(240,130,50,0.3)',
            transition: 'all 0.2s'
          }}
          onMouseEnter={e => e.currentTarget.style.transform = 'translateY(-2px)'}
          onMouseLeave={e => e.currentTarget.style.transform = 'none'}
        >
          {saving ? 'Saving Changes...' : 'Publish Intelligence Updates'}
        </button>

      </div>
    </AppLayout>
  )
}
