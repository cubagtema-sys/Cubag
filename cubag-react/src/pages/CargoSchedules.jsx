import { useState } from 'react'
import AppLayout from '../components/AppLayout'

export default function CargoSchedules() {
  const [activeTab, setActiveTab] = useState('vanning')
  const [searchQuery, setSearchQuery] = useState('')

  // Data will be fetched from API/database as uploaded by the admin
  const schedules = []

  const filtered = schedules.filter(s => 
    s.type === activeTab && 
    (s.container.toLowerCase().includes(searchQuery.toLowerCase()) || s.vessel.toLowerCase().includes(searchQuery.toLowerCase()))
  )

  return (
    <AppLayout title="Cargo Schedules" hideSearch>
      <div style={{ maxWidth: 800, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 24 }}>
        <div style={{ display: 'flex', background: 'var(--bg-elevated)', padding: 4, borderRadius: 12, gap: 4, overflowX: 'auto', WebkitOverflowScrolling: 'touch' }}>
          {['vanning', 'devanning', 'movement'].map(tab => (
            <button 
              key={tab}
              onClick={() => setActiveTab(tab)}
              style={{ 
                flex: 1, padding: '10px 4px', border: 'none', borderRadius: 8, 
                background: activeTab === tab ? 'var(--brand-primary)' : 'transparent', 
                color: activeTab === tab ? '#fff' : 'var(--text-secondary)',
                fontWeight: 600, cursor: 'pointer', textTransform: 'capitalize', transition: 'all 0.2s',
                fontSize: '0.8rem', textAlign: 'center', minWidth: '80px'
              }}
            >
              {tab === 'movement' ? 'Movement' : tab}
            </button>
          ))}
        </div>

        <div style={{ position: 'relative' }}>
          <span className="material-symbols-outlined" style={{ position: 'absolute', left: 16, top: 16, color: 'var(--text-muted)' }}>search</span>
          <input 
            type="text" 
            placeholder="Search Container Number or Vessel Name..." 
            value={searchQuery}
            onChange={e => setSearchQuery(e.target.value)}
            style={{ width: '100%', padding: '16px 16px 16px 48px', border: '2px solid var(--border-subtle)', borderRadius: 12, background: 'var(--bg-base)', fontSize: '1rem', color: 'var(--text-primary)' }}
          />
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 16, paddingBottom: 20 }}>
          {filtered.length > 0 ? filtered.map((s, i) => (
            <div key={i} style={{ background: 'var(--bg-base)', borderRadius: 16, padding: 20, border: '1px solid var(--border-subtle)', boxShadow: 'var(--shadow-sm)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 16 }}>
                <div>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', marginBottom: 4, fontWeight: 700 }}>Container Number</div>
                  <div style={{ fontWeight: 800, color: 'var(--brand-primary)', fontSize: '1.2rem', letterSpacing: '0.05em' }}>{s.container}</div>
                </div>
                <span style={{ 
                  padding: '4px 10px', borderRadius: 20, fontSize: '0.75rem', fontWeight: 700, whiteSpace: 'nowrap',
                  background: s.status === 'In Progress' ? 'rgba(59, 130, 246, 0.1)' : 'rgba(16, 185, 129, 0.1)',
                  color: s.status === 'In Progress' ? '#3b82f6' : 'var(--brand-success)'
                }}>
                  {s.status}
                </span>
              </div>
              
              <div style={{ background: '#f8fafc', borderRadius: 12, padding: 16, display: 'flex', flexDirection: 'column', gap: 12, border: '1px solid #e2e8f0' }}>
                {s.type === 'movement' && s.origin && s.destination ? (
                  <div style={{ margin: '20px 10px 30px' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
                      <span style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)' }}>Origin</span>
                      <span style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)' }}>Destination</span>
                    </div>
                    <div style={{ position: 'relative', height: 6, background: '#e2e8f0', borderRadius: 6 }}>
                      {/* Active Progress Bar */}
                      <div style={{ position: 'absolute', top: 0, left: 0, height: '100%', width: `${s.progress || 50}%`, background: 'var(--brand-primary)', borderRadius: 6 }}></div>
                      
                      {/* Origin Dot */}
                      <div style={{ position: 'absolute', top: -3, left: 0, width: 12, height: 12, background: 'var(--brand-primary)', borderRadius: '50%', transform: 'translateX(-50%)', border: '2px solid #fff' }}></div>
                      <div style={{ position: 'absolute', top: 16, left: 0, fontSize: '0.7rem', fontWeight: 800, color: 'var(--text-primary)', transform: 'translateX(-10%)' }}>{s.origin}</div>
                      
                      {/* Ship Indicator */}
                      <div style={{ position: 'absolute', top: -16, left: `${s.progress || 50}%`, fontSize: '1.4rem', transform: 'translateX(-50%)', zIndex: 10, filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.2))' }}>🚢</div>
                      
                      {/* Destination Dot */}
                      <div style={{ position: 'absolute', top: -3, right: 0, width: 12, height: 12, background: '#cbd5e1', borderRadius: '50%', transform: 'translateX(50%)', border: '2px solid #fff' }}></div>
                      <div style={{ position: 'absolute', top: 16, right: 0, fontSize: '0.7rem', fontWeight: 800, color: 'var(--text-primary)', transform: 'translateX(10%)' }}>{s.destination}</div>
                    </div>
                  </div>
                ) : (
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Location</span>
                    <span style={{ fontWeight: 600, fontSize: '0.9rem', color: 'var(--text-primary)' }}>{s.port}</span>
                  </div>
                )}
                
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Vessel</span>
                  <span style={{ fontWeight: 700, fontSize: '0.9rem', color: 'var(--text-primary)' }}>{s.vessel}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Date</span>
                  <span style={{ fontWeight: 600, fontSize: '0.9rem', color: 'var(--text-primary)' }}>{s.date}</span>
                </div>
              </div>
            </div>
          )) : (
            <div style={{ background: 'var(--bg-base)', padding: 40, textAlign: 'center', borderRadius: 16, border: '1px solid var(--border-subtle)' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '2.5rem', color: 'var(--text-muted)', marginBottom: 12 }}>search_off</span>
              <div style={{ color: 'var(--text-secondary)', fontWeight: 600 }}>No schedules found.</div>
            </div>
          )}
        </div>

      </div>
    </AppLayout>
  )
}
