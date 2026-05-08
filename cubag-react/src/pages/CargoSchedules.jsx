import { useState, useEffect, useRef } from 'react'
import AppLayout from '../components/AppLayout'
import useAutoRefresh from '../hooks/useAutoRefresh'

export default function CargoSchedules() {
  const [activeTab, setActiveTab] = useState('vanning')
  const [searchQuery, setSearchQuery] = useState('')

  const [schedules, setSchedules] = useState([])
  const [loading, setLoading] = useState(true)

  const firstLoad = useRef(true)

  useAutoRefresh(() => {
    if (firstLoad.current) setLoading(true)
    fetch(`${import.meta.env.VITE_API_URL}/schedules`)
      .then(r => r.ok ? r.json() : [])
      .then(data => setSchedules(Array.isArray(data) ? data : []))
      .catch(() => setSchedules([]))
      .finally(() => { setLoading(false); firstLoad.current = false })
  }, 20000)

  const filtered = schedules.filter(s =>
    s.type === activeTab &&
    (
      (s.container || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
      (s.vessel || '').toLowerCase().includes(searchQuery.toLowerCase())
    )
  )

  return (
    <AppLayout title="Schedules">
      <div style={{ maxWidth: 800, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 12 }}>

        {/* Page Title for Content */}
        <div style={{ marginBottom: 2 }}>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Cargo Schedules</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Real-time updates on vanning and container movements.</p>
        </div>

        <div style={{ display: 'flex', background: 'var(--bg-elevated)', padding: 3, borderRadius: 10, gap: 2, overflowX: 'auto', WebkitOverflowScrolling: 'touch', scrollbarWidth: 'none' }}>
          {['vanning', 'devanning', 'movement'].map(tab => (
            <button 
              key={tab}
              onClick={() => setActiveTab(tab)}
              style={{ 
                flex: 1, padding: '8px 4px', border: 'none', borderRadius: 8,
                background: activeTab === tab ? 'var(--brand-primary)' : 'transparent', 
                color: activeTab === tab ? '#fff' : 'var(--text-secondary)',
                fontWeight: 700, cursor: 'pointer', textTransform: 'capitalize', transition: 'all 0.2s',
                fontSize: '0.7rem', textAlign: 'center', minWidth: '70px'
              }}
            >
              {tab === 'movement' ? 'Track' : tab}
            </button>
          ))}
        </div>

        <div style={{ position: 'relative' }}>
          <span className="material-symbols-outlined" style={{ position: 'absolute', left: 14, top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', fontSize: '1.1rem' }}>search</span>
          <input 
            type="text" 
            placeholder="Search container or vessel..." autoComplete="off"
            value={searchQuery}
            onChange={e => setSearchQuery(e.target.value)}
            style={{ width: '100%', padding: '10px 12px 10px 40px', border: '1.5px solid var(--border-subtle)', borderRadius: 10, background: 'var(--bg-base)', fontSize: '0.9rem', color: 'var(--text-primary)', outline: 'none' }}
          />
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 12, paddingBottom: 20 }}>
          {loading ? (
            <div style={{ padding: 40, textAlign: 'center', color: 'var(--text-muted)', fontSize: '0.8rem' }}>Loading schedules...</div>
          ) : filtered.length > 0 ? filtered.map((s, i) => (
            <div key={i} className="feed-card" style={{ padding: '14px 16px', borderRadius: 12 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 12, gap: 10 }}>
                <div style={{ minWidth: 0 }}>
                  <div style={{ fontSize: '0.65rem', color: 'var(--text-muted)', textTransform: 'uppercase', marginBottom: 1, fontWeight: 700 }}>Container</div>
                  <div style={{ fontWeight: 800, color: 'var(--brand-primary)', fontSize: '1rem', letterSpacing: '0.02em', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{s.container}</div>
                </div>
                <span style={{ 
                  padding: '3px 8px', borderRadius: 20, fontSize: '0.6rem', fontWeight: 800, whiteSpace: 'nowrap', textTransform: 'uppercase',
                  background: s.status === 'In Progress' ? 'rgba(59, 130, 246, 0.1)' : 'rgba(16, 185, 129, 0.1)',
                  color: s.status === 'In Progress' ? '#3b82f6' : 'var(--brand-success)'
                }}>
                  {s.status}
                </span>
              </div>
              
              <div style={{ background: 'var(--bg-elevated)', borderRadius: 10, padding: 12, display: 'flex', flexDirection: 'column', gap: 8, border: '1px solid var(--border-subtle)' }}>
                {s.type === 'movement' && s.origin && s.destination ? (
                  <div style={{ margin: '12px 0 20px' }}>
                    <div style={{ position: 'relative', height: 4, background: 'var(--border-strong)', borderRadius: 6 }}>
                      <div style={{ position: 'absolute', top: 0, left: 0, height: '100%', width: `${s.status === 'Completed' ? 100 : s.status === 'In Progress' ? 50 : 0}%`, background: 'var(--brand-primary)', borderRadius: 6 }}></div>
                      <div style={{ position: 'absolute', top: -14, left: `${s.status === 'Completed' ? 100 : s.status === 'In Progress' ? 50 : 0}%`, fontSize: '1.2rem', transform: 'translateX(-50%)' }}>🚢</div>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8 }}>
                      <span style={{ fontSize: '0.65rem', fontWeight: 800, color: 'var(--text-primary)' }}>{s.origin}</span>
                      <span style={{ fontSize: '0.65rem', fontWeight: 800, color: 'var(--text-primary)' }}>{s.destination}</span>
                    </div>
                  </div>
                ) : (
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Location</span>
                    <span style={{ fontWeight: 600, fontSize: '0.8rem' }}>{s.port}</span>
                  </div>
                )}
                
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Vessel</span>
                  <span style={{ fontWeight: 700, fontSize: '0.8rem', color: 'var(--text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', maxWidth: '60%' }}>{s.vessel}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Date</span>
                  <span style={{ fontWeight: 600, fontSize: '0.8rem' }}>{s.date}</span>
                </div>
              </div>
            </div>
          )) : (
            <div className="card" style={{ padding: 40, textAlign: 'center', borderRadius: 12 }}>
              <span className="material-symbols-outlined" style={{ fontSize: '2.5rem', color: 'var(--text-muted)', marginBottom: 8 }}>search_off</span>
              <div style={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>No schedules found.</div>
            </div>
          )}
        </div>

      </div>
    </AppLayout>
  )
}
