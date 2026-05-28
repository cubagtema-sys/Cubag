import { useState, useEffect, useRef } from 'react'
import AppLayout from '../components/AppLayout'
import useAutoRefresh from '../hooks/useAutoRefresh'
import { useSocket } from '../hooks/useSocket'

export default function CargoSchedules() {
  const [activeTab, setActiveTab] = useState('vanning')
  const [searchQuery, setSearchQuery] = useState('')

  const [schedules, setSchedules] = useState([])
  const [liveVessels, setLiveVessels] = useState({})
  const [loading, setLoading] = useState(true)

  const firstLoad = useRef(true)
  const socket = useSocket()

  useAutoRefresh(() => {
    if (firstLoad.current) setLoading(true)
    fetch(`${import.meta.env.VITE_API_URL}/schedules`)
      .then(r => r.ok ? r.json() : [])
      .then(data => setSchedules(Array.isArray(data) ? data : []))
      .catch(() => setSchedules([]))
      .finally(() => { setLoading(false); firstLoad.current = false })
  }, 20000)

  useEffect(() => {
    if (!socket) return
    socket.on('vessel_update', (vessel) => {
      setLiveVessels(prev => ({
        ...prev,
        [vessel.mmsi]: vessel
      }))
    })
    return () => { socket.off('vessel_update') }
  }, [socket])

  const filteredSchedules = [...schedules]
    .sort((a, b) => new Date(b.created_at || 0) - new Date(a.created_at || 0)) // Sort newest first
    .filter(s =>
      s.type === activeTab &&
      (
        (s.container || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
        (s.vessel || '').toLowerCase().includes(searchQuery.toLowerCase())
      )
    )
    .slice(0, searchQuery ? 50 : 10)

  const liveVesselList = Object.values(liveVessels).filter(v =>
    (v.name || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
    (v.mmsi || '').toString().includes(searchQuery) ||
    (v.destination || '').toLowerCase().includes(searchQuery.toLowerCase())
  )

  return (
    <AppLayout title="Schedules">
      <div style={{ maxWidth: 800, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 12 }}>

        {/* Page Title for Content */}
        <div style={{ marginBottom: 2 }}>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Logistics Hub</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Global cargo schedules and real-time vessel tracking.</p>
        </div>

        <div style={{ display: 'flex', background: 'var(--bg-elevated)', padding: 3, borderRadius: 12, gap: 2, overflowX: 'auto', WebkitOverflowScrolling: 'touch', scrollbarWidth: 'none', border: '1px solid var(--border-subtle)' }}>
          {['vanning', 'devanning', 'live tracking'].map(tab => (
            <button 
              key={tab}
              onClick={() => setActiveTab(tab)}
              style={{ 
                flex: 1, padding: '10px 4px', border: 'none', borderRadius: 9,
                background: activeTab === tab ? 'var(--brand-primary)' : 'transparent', 
                color: activeTab === tab ? '#fff' : 'var(--text-secondary)',
                fontWeight: 700, cursor: 'pointer', textTransform: 'uppercase', transition: 'all 0.2s',
                fontSize: '0.65rem', textAlign: 'center', minWidth: '90px', letterSpacing: '0.02em'
              }}
            >
              {tab}
            </button>
          ))}
        </div>

        <div style={{ position: 'relative' }}>
          <span className="material-symbols-outlined" style={{ position: 'absolute', left: 14, top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', fontSize: '1.1rem' }}>search</span>
          <input 
            type="text" 
            placeholder={activeTab === 'live tracking' ? "Search by vessel name or MMSI..." : "Search container or vessel..."}
            autoComplete="off"
            value={searchQuery}
            onChange={e => {
              const val = e.target.value
              setSearchQuery(val)
              // If user types a 9-digit MMSI in live tracking, tell the backend to track it globally
              if (activeTab === 'live tracking' && /^\d{9}$/.test(val) && socket) {
                socket.emit('track_vessel', { mmsi: val })
                showToast(`Searching global network for MMSI ${val}...`, 'info')
              }
            }}
            style={{ width: '100%', padding: '12px 12px 12px 42px', border: '1.5px solid var(--border-subtle)', borderRadius: 12, background: 'var(--bg-card)', fontSize: '0.9rem', color: 'var(--text-primary)', outline: 'none' }}
          />
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 12, paddingBottom: 40 }}>

          {activeTab === 'live tracking' ? (
            liveVesselList.length > 0 ? liveVesselList.map((v) => (
              <div key={v.mmsi} className="feed-card" style={{ padding: 16, borderRadius: 14, border: '1.5px solid var(--border-subtle)' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                    <div style={{ width: 36, height: 36, background: 'rgba(240,130,50,0.1)', borderRadius: 8, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--brand-primary)' }}>
                      <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>sailing</span>
                    </div>
                    <div>
                      <div style={{ fontWeight: 800, fontSize: '0.95rem' }}>{v.name}</div>
                      <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)' }}>{v.type} • {v.mmsi}</div>
                    </div>
                  </div>
                  <span className="badge badge-success" style={{ fontSize: '0.6rem' }}>LIVE</span>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, background: 'var(--bg-base)', padding: 12, borderRadius: 10, border: '1px solid var(--border-subtle)' }}>
                  <div>
                    <div style={{ fontSize: '0.6rem', color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase' }}>Destination</div>
                    <div style={{ fontSize: '0.8rem', fontWeight: 800 }}>{v.destination || 'N/A'}</div>
                  </div>
                  <div>
                    <div style={{ fontSize: '0.6rem', color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase' }}>ETA</div>
                    <div style={{ fontSize: '0.8rem', fontWeight: 800 }}>{v.eta || 'N/A'}</div>
                  </div>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 12 }}>
                   <div style={{ fontSize: '0.65rem', color: 'var(--text-muted)' }}>Update: {new Date(v.last_update).toLocaleTimeString()}</div>
                   <button className="btn btn-ghost btn-sm" onClick={() => window.open(`https://www.marinetraffic.com/en/ais/details/ships/mmsi:${v.mmsi}`)}>Track Map</button>
                </div>
              </div>
            )) : (
              <div style={{ textAlign: 'center', padding: 40, background: 'var(--bg-card)', borderRadius: 16 }}>
                 <span className="material-symbols-outlined" style={{ fontSize: '2.5rem', color: 'var(--text-muted)', marginBottom: 12 }}>radar</span>
                 <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Scanning global AIS network... Vessels will appear here as data is received.</p>
              </div>
            )
          ) : (
            loading ? (
              <div style={{ padding: 40, textAlign: 'center', color: 'var(--text-muted)', fontSize: '0.8rem' }}>Loading schedules...</div>
            ) : filteredSchedules.length > 0 ? filteredSchedules.map((s, i) => (
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
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Location</span>
                    <span style={{ fontWeight: 600, fontSize: '0.8rem' }}>{s.port}</span>
                  </div>
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
                <div style={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>No {activeTab} schedules found.</div>
              </div>
            )
          )}
        </div>

      </div>
    </AppLayout>
  )
}
