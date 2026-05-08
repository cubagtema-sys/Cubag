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
    <AppLayout title="Vanning & Devanning">
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        
        <div style={{ position: 'relative' }}>
          <span className="material-symbols-outlined" style={{ position: 'absolute', left: 16, top: 14, color: 'var(--text-muted)' }}>search</span>
          <input 
            type="text" 
            placeholder="Search schedules by terminal or cargo..." autoComplete="off" 
            value={searchTerm}
            onChange={e => setSearchTerm(e.target.value)}
            style={{ width: '100%', padding: '16px 16px 16px 48px', borderRadius: 12, border: '1px solid var(--border-subtle)', outline: 'none', fontSize: '1rem' }}
          />
        </div>

        <div style={{ display: 'flex', gap: 8, overflowX: 'auto', paddingBottom: 8 }}>
          <button className="badge badge-info" style={{ border: 'none', padding: '8px 16px' }} onClick={() => setSearchTerm('')}>All</button>
          <button className="badge" style={{ background: 'rgba(240,130,50,0.1)', color: 'var(--brand-primary)', border: 'none', padding: '8px 16px' }} onClick={() => setSearchTerm('VAN')}>Vanning Only</button>
          <button className="badge" style={{ background: 'rgba(99,102,241,0.1)', color: '#6366f1', border: 'none', padding: '8px 16px' }} onClick={() => setSearchTerm('DEVAN')}>Devanning Only</button>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {filteredSchedules.length > 0 ? filteredSchedules.map((s, i) => (
            <div key={s.id || i} style={{ background: 'var(--bg-card)', padding: 16, borderRadius: 12, border: '1px solid var(--border-subtle)', display: 'flex', gap: 16, alignItems: 'center' }}>
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', minWidth: 60, height: 60, background: s.type === 'VAN' ? 'rgba(240,130,50,0.1)' : 'rgba(99,102,241,0.1)', color: s.type === 'VAN' ? 'var(--brand-primary)' : '#6366f1', borderRadius: 8 }}>
                <span className="material-symbols-outlined">{s.type === 'VAN' ? 'unarchive' : 'archive'}</span>
                <span style={{ fontSize: '0.65rem', fontWeight: 800 }}>{s.type}</span>
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 700, fontSize: '1rem', color: 'var(--text-primary)' }}>{s.location}</div>
                <div style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>{s.time}</div>
                <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: 4 }}>{s.details}</div>
              </div>
            </div>
          )) : (
            <div style={{ textAlign: 'center', padding: 30, color: 'var(--text-muted)' }}>No schedules matching "{searchTerm}"</div>
          )}
        </div>
        
      </div>
    </AppLayout>
  )
}
