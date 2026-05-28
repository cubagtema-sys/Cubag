import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'
import { useSocket } from '../hooks/useSocket'

const API_URL = import.meta.env.VITE_API_URL

export default function VesselMovements() {
  const [vessels, setVessels] = useState({})
  const [searchTerm, setSearchTerm] = useState('')
  const [loading, setLoading] = useState(false)
  const socket = useSocket()

  useEffect(() => {
    if (!socket) return

    socket.on('vessel_update', (vessel) => {
      setVessels(prev => ({
        ...prev,
        [vessel.mmsi]: vessel
      }))
    })

    return () => {
      socket.off('vessel_update')
    }
  }, [socket])

  const vesselList = Object.values(vessels).sort((a, b) =>
    new Date(b.last_update) - new Date(a.last_update)
  )

  const filteredVessels = vesselList.filter(v =>
    (v.name || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
    (v.mmsi || '').toString().includes(searchTerm) ||
    (v.destination || '').toLowerCase().includes(searchTerm.toLowerCase())
  )

  return (
    <AppLayout title="Vessels">
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        
        {/* Page Title for Content */}
        <div style={{ marginBottom: 4 }}>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Live Vessel Tracking</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Real-time AIS tracking for vessels in the Ghana region.</p>
        </div>

        <div style={{ position: 'relative' }}>
          <span className="material-symbols-outlined" style={{ position: 'absolute', left: 14, top: 12, color: 'var(--text-muted)', fontSize: '1.2rem' }}>search</span>
          <input 
            type="text" 
            placeholder="Search by vessel name, MMSI or destination..." autoComplete="off"
            value={searchTerm}
            onChange={e => {
              const val = e.target.value
              setSearchTerm(val)
              // If user types a 9-digit MMSI, tell the backend to track it globally
              if (/^\d{9}$/.test(val) && socket) {
                socket.emit('track_vessel', { mmsi: val })
              }
            }}
            style={{ width: '100%', padding: '12px 16px 12px 42px', borderRadius: 10, border: '1.5px solid var(--border-subtle)', outline: 'none', fontSize: '0.9rem', background: 'var(--bg-card)', color: 'var(--text-primary)' }}
          />
        </div>

        {/* Status bar */}
        <div style={{ padding: '8px 12px', background: 'rgba(240,130,50,0.05)', borderRadius: 8, display: 'flex', justifyContent: 'space-between', alignItems: 'center', border: '1px solid rgba(240,130,50,0.1)' }}>
          <span style={{ fontSize: '0.7rem', fontWeight: 700, color: 'var(--brand-primary)', textTransform: 'uppercase' }}>
            {socket ? '● Live AIS Stream Connected' : '○ Connecting to AIS...'}
          </span>
          <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)' }}>
            {vesselList.length} vessels in range
          </span>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 12, paddingBottom: 40 }}>
          {filteredVessels.length > 0 ? filteredVessels.map((v) => (
            <div key={v.mmsi} className="feed-card" style={{ padding: 16, borderRadius: 12, border: '1px solid var(--border-subtle)', display: 'flex', flexDirection: 'column', gap: 12 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <div style={{ width: 40, height: 40, background: 'rgba(240,130,50,0.1)', borderRadius: 10, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--brand-primary)' }}>
                    <span className="material-symbols-outlined">directions_boat</span>
                  </div>
                  <div>
                    <div style={{ fontWeight: 800, fontSize: '1rem', color: 'var(--text-primary)' }}>{v.name}</div>
                    <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>MMSI: {v.mmsi} • {v.type}</div>
                  </div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div style={{ fontSize: '0.7rem', fontWeight: 700, color: 'var(--brand-success)' }}>{v.speed ? `${v.speed} kn` : 'At Anchor'}</div>
                  <div style={{ fontSize: '0.6rem', color: 'var(--text-muted)' }}>{new Date(v.last_update).toLocaleTimeString()}</div>
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, padding: '10px', background: 'var(--bg-base)', borderRadius: 8 }}>
                <div>
                  <div style={{ fontSize: '0.6rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700 }}>Destination</div>
                  <div style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-primary)' }}>{v.destination || 'N/A'}</div>
                </div>
                <div>
                  <div style={{ fontSize: '0.6rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700 }}>ETA</div>
                  <div style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-primary)' }}>{v.eta || 'N/A'}</div>
                </div>
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)' }}>
                  Pos: {v.lat?.toFixed(4)}, {v.lng?.toFixed(4)}
                </div>
                <button className="btn btn-ghost btn-sm" onClick={() => window.open(`https://www.marinetraffic.com/en/ais/details/ships/mmsi:${v.mmsi}`)}>
                  View Details
                </button>
              </div>
            </div>
          )) : (
            <div className="card" style={{ padding: 60, textAlign: 'center' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '3rem', color: 'var(--border-default)', marginBottom: 16 }}>sailing</span>
              <h3>No vessels in range</h3>
              <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginTop: 8 }}>Waiting for live AIS data from the Gulf of Guinea...</p>
            </div>
          )}
        </div>
        
      </div>
    </AppLayout>
  )
}
