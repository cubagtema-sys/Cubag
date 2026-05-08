import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

const API_URL = import.meta.env.VITE_API_URL

export default function VanningSchedules() {
  const [schedules, setSchedules] = useState([])
  const [searchTerm, setSearchTerm] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function loadData() {
      try {
        setLoading(true)
        const res = await fetch(`${API_URL}/schedules`, { headers: { 'Authorization': `Bearer ${localStorage.getItem('cubag_token')}` } })
        if (res.ok) {
          const data = await res.json()
          setSchedules(data)
        } else {
          // Fallback mock for demo
          setSchedules([
            { id: 1, type: 'VAN', location: 'Terminal 3, Bay A', time: '08:00 - 12:00', details: 'Consolidated Cargo' },
            { id: 2, type: 'DEVAN', location: 'Tema Main Port', time: '13:00 - 17:00', details: 'Auto Imports' },
            { id: 3, type: 'VAN', location: 'MPS Terminal', time: 'Tomorrow, 09:00', details: 'Export Cocoa' }
          ])
        }
      } catch (e) {
        console.error(e)
      } finally {
        setLoading(false)
      }
    }
    loadData()
  }, [])

  const filteredSchedules = schedules.filter(s => 
    s.location.toLowerCase().includes(searchTerm.toLowerCase()) || 
    s.type.toLowerCase().includes(searchTerm.toLowerCase()) ||
    s.details.toLowerCase().includes(searchTerm.toLowerCase())
  )

  return (
    <AppLayout title="Vanning">
      <div style={{ maxWidth: 800, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 12 }}>
        
        {/* Page Title for Content */}
        <div style={{ marginBottom: 2 }}>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Terminal Schedules</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Real-time loading and unloading bay activities.</p>
        </div>

        <div style={{ position: 'relative' }}>
          <span className="material-symbols-outlined" style={{ position: 'absolute', left: 14, top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', fontSize: '1.1rem' }}>search</span>
          <input 
            type="text" 
            placeholder="Search terminal or cargo..." autoComplete="off"
            value={searchTerm}
            onChange={e => setSearchTerm(e.target.value)}
            style={{ width: '100%', padding: '10px 12px 10px 40px', border: '1.5px solid var(--border-subtle)', borderRadius: 10, background: 'var(--bg-base)', fontSize: '0.9rem', color: 'var(--text-primary)', outline: 'none' }}
          />
        </div>

        <div style={{ display: 'flex', gap: 6, overflowX: 'auto', paddingBottom: 4, scrollbarWidth: 'none' }}>
          <button className="badge badge-info" style={{ border: 'none', padding: '6px 14px', borderRadius: 20, fontSize: '0.75rem', cursor: 'pointer' }} onClick={() => setSearchTerm('')}>All</button>
          <button className="badge" style={{ background: 'rgba(240,130,50,0.1)', color: 'var(--brand-primary)', border: 'none', padding: '6px 14px', borderRadius: 20, fontSize: '0.75rem', cursor: 'pointer' }} onClick={() => setSearchTerm('VAN')}>Vanning</button>
          <button className="badge" style={{ background: 'rgba(99,102,241,0.1)', color: '#6366f1', border: 'none', padding: '6px 14px', borderRadius: 20, fontSize: '0.75rem', cursor: 'pointer' }} onClick={() => setSearchTerm('DEVAN')}>Devanning</button>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {filteredSchedules.length > 0 ? filteredSchedules.map((s, i) => (
            <div key={s.id || i} className="feed-card" style={{ padding: '12px 16px', borderRadius: 12, display: 'flex', gap: 14, alignItems: 'center' }}>
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', width: 50, height: 50, background: s.type.includes('VAN') && !s.type.includes('DE') ? 'rgba(240,130,50,0.1)' : 'rgba(99,102,241,0.1)', color: s.type.includes('VAN') && !s.type.includes('DE') ? 'var(--brand-primary)' : '#6366f1', borderRadius: 10, flexShrink: 0 }}>
                <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>{s.type.includes('VAN') && !s.type.includes('DE') ? 'unarchive' : 'archive'}</span>
                <span style={{ fontSize: '0.55rem', fontWeight: 900 }}>{s.type}</span>
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 800, fontSize: '0.95rem', color: 'var(--text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{s.location}</div>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)', marginBottom: 2 }}>{s.time}</div>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', display: '-webkit-box', WebkitLineClamp: 1, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>{s.details}</div>
              </div>
            </div>
          )) : (
            <div className="card" style={{ textAlign: 'center', padding: 32, borderRadius: 12 }}>
              <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>No activities found.</p>
            </div>
          )}
        </div>
        
      </div>
    </AppLayout>
  )
}
