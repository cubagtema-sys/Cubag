import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'
import useAutoRefresh from '../hooks/useAutoRefresh'
import { useSocket } from '../hooks/useSocket'
import { showToast } from '../utils/toast'

const API_URL = import.meta.env.VITE_API_URL

const COMMON_VESSELS = [
  { name: 'Maersk Charleston', mmsi: '563297800', imo: '9454199', flag: 'Singapore', type: 'Container Ship', length: 266, width: 37, callsign: '9V8129' },
  { name: 'Maersk Cubango', mmsi: '477174700', imo: '9513361', flag: 'Hong Kong', type: 'Container Ship', length: 254, width: 32, callsign: 'VRJZ8' },
  { name: 'Maersk Tema', mmsi: '477353900', imo: '9624275', flag: 'Hong Kong', type: 'Container Ship', length: 255, width: 37, callsign: 'VRNX6' },
  { name: 'MSC Johannesburg V', mmsi: '636024423', imo: '9308637', flag: 'Liberia', type: 'Container Ship', length: 275, width: 40, callsign: 'A8IF9' },
  { name: 'MSC Assunta III', mmsi: '636023923', imo: '9211028', flag: 'Liberia', type: 'Container Ship', length: 259, width: 32, callsign: 'A8GX6' },
  { name: 'MSC Aniello', mmsi: '372741000', imo: '9203928', flag: 'Panama', type: 'Container Ship', length: 259, width: 32, callsign: '3FYQ9' },
  { name: 'MSC Pamela', mmsi: '636022359', imo: '9290531', flag: 'Liberia', type: 'Container Ship', length: 337, width: 46, callsign: 'A8HR2' },
  { name: 'One Presence', mmsi: '563290200', imo: '9347504', flag: 'Singapore', type: 'Container Ship', length: 300, width: 40, callsign: '9V7182' },
  { name: 'Grande Argentina', mmsi: '215949000', imo: '9220976', flag: 'Malta', type: 'Ro-Ro/Cargo', length: 214, width: 32, callsign: '9HNM6' },
  { name: 'Grande Tema', mmsi: '247343700', imo: '9672105', flag: 'Italy', type: 'Ro-Ro/Cargo', length: 236, width: 36, callsign: 'IBDR' },
  { name: 'Grande Dakar', mmsi: '247341900', imo: '9680724', flag: 'Italy', type: 'Ro-Ro/Container Carrier', length: 236, width: 36, callsign: 'IBDK' },
  { name: 'African Wind', mmsi: '305537000', imo: '9372107', flag: 'Antigua Barbuda', type: 'General Cargo', length: 132, width: 16, callsign: 'V2CG9' },
  { name: 'Oslo Trader', mmsi: '636014459', imo: '9239082', flag: 'Liberia', type: 'Container Ship', length: 200, width: 30, callsign: 'A8HF8' },
]

export default function CargoSchedules() {
  const [activeTab, setActiveTab] = useState('vanning')
  const [searchQuery, setSearchQuery] = useState('')
  const [showSuggestions, setShowSuggestions] = useState(false)
  const [schedules, setSchedules] = useState([])
  const [loading, setLoading] = useState(true)
  const [liveVessels, setLiveVessels] = useState({}) // mmsi -> data

  const socket = useSocket()

  const fetchSchedules = async () => {
    setLoading(true)
    try {
      const res = await fetch(`${API_URL}/schedules?type=${activeTab}`)
      if (res.ok) setSchedules(await res.json())
    } catch {
      setSchedules([])
    } finally {
      setLoading(false)
    }
  }

  useAutoRefresh(fetchSchedules, 60000, [activeTab])

  useEffect(() => {
    if (!socket) return
    socket.on('vessel_update', (data) => {
      setLiveVessels(prev => ({ ...prev, [data.mmsi]: data }))
    })
    return () => socket.off('vessel_update')
  }, [socket])

  const filteredSchedules = schedules.filter(s =>
    (s.container || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
    (s.vessel || '').toLowerCase().includes(searchQuery.toLowerCase())
  )

  const liveVesselList = Object.values(liveVessels).filter(v =>
    (v.name || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
    (v.mmsi || '').toString().includes(searchQuery) ||
    (v.destination || '').toLowerCase().includes(searchQuery.toLowerCase())
  )

  const isMMSI = /^\d{9}$/.test(searchQuery)

  const suggestions = COMMON_VESSELS.filter(v =>
    v.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    v.mmsi.includes(searchQuery)
  ).slice(0, 5)

  const matchedVessel = COMMON_VESSELS.find(v => v.mmsi === searchQuery)
  const vesselData = {
    ...matchedVessel,
    ...liveVesselList[0]
  }

  return (
    <AppLayout title="Logistics Hub">
      <div style={{ maxWidth: 800, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 12 }}>

        {/* Status Bar */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '6px 12px', background: 'var(--bg-elevated)', borderRadius: 8, border: '1px solid var(--border-subtle)' }}>
           <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: '0.65rem', fontWeight: 700, color: socket ? '#10b981' : '#f59e0b' }}>
              <span className={`live-dot ${!socket ? 'warning' : ''}`} style={{ width: 6, height: 6 }}></span>
              {socket ? 'LIVE SATELLITE LINK ACTIVE' : 'CONNECTING TO SATELLITE...'}
           </div>
           <div style={{ fontSize: '0.65rem', color: 'var(--text-muted)' }}>
              {liveVesselList.length} ships in range
           </div>
        </div>

        <div style={{ display: 'flex', background: 'var(--bg-elevated)', padding: 3, borderRadius: 12, gap: 2, overflowX: 'auto', WebkitOverflowScrolling: 'touch', scrollbarWidth: 'none', border: '1px solid var(--border-subtle)' }}>
          {['vanning', 'devanning', 'live tracking'].map(t => (
            <button key={t} onClick={() => { setActiveTab(t); setSearchQuery('') }} style={{
              flex: 1, padding: '10px 14px', borderRadius: 10, border: 'none', cursor: 'pointer',
              fontSize: '0.7rem', fontWeight: 800, textTransform: 'uppercase', letterSpacing: '0.05em', whiteSpace: 'nowrap',
              background: activeTab === t ? 'var(--brand-primary)' : 'transparent',
              color: activeTab === t ? '#fff' : 'var(--text-muted)',
              transition: 'all 0.2s'
            }}>
              {t}
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
            onFocus={() => setShowSuggestions(true)}
            onBlur={() => setTimeout(() => setShowSuggestions(false), 200)}
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

          {/* Intelligent Suggestions Dropdown */}
          {activeTab === 'live tracking' && showSuggestions && searchQuery.length > 1 && suggestions.length > 0 && (
            <div style={{ position: 'absolute', top: '100%', left: 0, right: 0, background: 'var(--bg-surface)', borderRadius: 12, border: '1px solid var(--border-subtle)', boxShadow: 'var(--shadow-lg)', zIndex: 100, marginTop: 4, overflow: 'hidden' }}>
              {suggestions.map(v => (
                <div
                  key={v.mmsi}
                  onClick={() => {
                    setSearchQuery(v.mmsi)
                    if (socket) socket.emit('track_vessel', { mmsi: v.mmsi })
                  }}
                  style={{ padding: '12px 16px', borderBottom: '1px solid var(--border-subtle)', cursor: 'pointer', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}
                >
                  <div>
                    <div style={{ fontWeight: 700, fontSize: '0.85rem' }}>{v.name}</div>
                    <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)' }}>MMSI: {v.mmsi}</div>
                  </div>
                  <span className="material-symbols-outlined" style={{ fontSize: '1rem', color: 'var(--brand-primary)' }}>arrow_forward</span>
                </div>
              ))}
            </div>
          )}
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 12, paddingBottom: 40 }}>

          {activeTab === 'live tracking' ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
              {isMMSI ? (
                <>
                  {/* Embedded Professional Map */}
                  <div className="feed-card" style={{ padding: 0, overflow: 'hidden', borderRadius: 20, height: 400, border: '1.5px solid var(--border-subtle)', background: 'var(--bg-card)' }}>
                    <iframe
                      title="Vessel Tracker"
                      width="100%"
                      height="100%"
                      frameBorder="0"
                      src={`https://www.marinetraffic.com/en/ais/embed/mmsi:${searchQuery}/zoom:8/maptype:1/show_vessels:true`}
                      style={{ border: 'none' }}
                    />
                  </div>

                  {/* Voyage Detail Card */}
                  <div className="feed-card" style={{ padding: '24px', borderRadius: 20 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
                       <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                          <div style={{ width: 44, height: 44, background: 'rgba(240,130,50,0.1)', borderRadius: 12, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--brand-primary)' }}>
                             <span className="material-symbols-outlined" style={{ fontSize: '1.5rem' }}>sailing</span>
                          </div>
                          <div>
                             <div style={{ fontWeight: 800, fontSize: '1.1rem' }}>
                                {vesselData.name || 'Detecting Vessel...'}
                             </div>
                             <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>MMSI: {searchQuery}</div>
                          </div>
                       </div>
                       <span className="badge badge-success" style={{ fontSize: '0.65rem', padding: '4px 12px' }}>{vesselData.last_update ? 'LIVE DATA' : 'CONNECTING'}</span>
                    </div>

                    <div style={{ background: 'var(--bg-base)', borderRadius: 16, padding: '24px', border: '1px solid var(--border-subtle)' }}>
                       <div style={{ display: 'flex', gap: 20 }}>
                          {/* Vertical Timeline Track */}
                          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
                             <div style={{ width: 12, height: 12, borderRadius: '50%', background: 'var(--brand-primary)', border: '3px solid #fff', boxShadow: '0 0 0 2px var(--brand-primary)' }}></div>
                             <div style={{ width: 2, flex: 1, background: 'linear-gradient(to bottom, var(--brand-primary), #10b981)', margin: '4px 0' }}></div>
                             <div style={{ width: 12, height: 12, borderRadius: '50%', background: '#10b981', border: '3px solid #fff', boxShadow: '0 0 0 2px #10b981' }}></div>
                          </div>

                          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 32 }}>
                             {/* Departure Block */}
                             <div>
                                <div style={{ fontSize: '0.65rem', fontWeight: 800, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Departure Port</div>
                                <div style={{ fontSize: '1rem', fontWeight: 800, color: 'var(--text-primary)', marginTop: 2 }}>
                                   {vesselData.origin || 'International Waters'}
                                </div>
                                <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)', marginTop: 4 }}>
                                   Actual time of departure: <span style={{ fontWeight: 700 }}>{vesselData.atd || '📡 Syncing...'}</span>
                                </div>
                             </div>

                             {/* Arrival Block */}
                             <div>
                                <div style={{ fontSize: '0.65rem', fontWeight: 800, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Arrival Port</div>
                                <div style={{ fontSize: '1rem', fontWeight: 800, color: '#10b981', marginTop: 2 }}>
                                   {vesselData.destination || 'Detecting via AIS...'}
                                </div>
                                <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)', marginTop: 4 }}>
                                   Reported ETA: <span style={{ fontWeight: 700 }}>{vesselData.eta || 'Awaiting Signal...'}</span>
                                </div>
                             </div>
                          </div>
                       </div>
                    </div>

                    {!vesselData.last_update && (
                       <p style={{ fontSize: '0.7rem', color: 'var(--text-muted)', textAlign: 'center', marginTop: 16 }}>
                          Waiting for ship to transmit voyage data. This usually takes 1-3 minutes.
                       </p>
                    )}
                  </div>

                  {/* Summary Section */}
                  <div className="feed-card" style={{ padding: '24px', borderRadius: 20 }}>
                     <h3 style={{ fontSize: '1rem', fontWeight: 800, marginBottom: 16, color: 'var(--text-primary)' }}>Summary</h3>
                     <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                        <div>
                           <div style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)' }}>Where is the ship?</div>
                           <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginTop: 4 }}>
                              {vesselData.type || 'Vessel'} <strong>{vesselData.name || searchQuery}</strong> is currently located in the <strong>{vesselData.region || 'Global network'}</strong>
                              {vesselData.last_update ? ` (reported ${Math.max(1, Math.floor((new Date() - new Date(vesselData.last_update)) / 60000))} minutes ago)` : ' (syncing...)'}.
                           </p>
                        </div>
                        <div>
                           <div style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)' }}>What kind of ship is this?</div>
                           <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginTop: 4 }}>
                              <strong>{vesselData.name || searchQuery}</strong> (IMO: {vesselData.imo || '—'}) is a <strong>{vesselData.type || 'Vessel'}</strong> and is sailing under the flag of <strong>{vesselData.flag?.toUpperCase() || 'UNKNOWN'}</strong>. Her length overall (LOA) is <strong>{vesselData.length || '—'} meters</strong> and her width is <strong>{vesselData.width || '—'} meters</strong>.
                           </p>
                        </div>
                     </div>
                  </div>

                  {/* General Details Section */}
                  <div className="feed-card" style={{ padding: '24px', borderRadius: 20 }}>
                     <h3 style={{ fontSize: '1rem', fontWeight: 800, marginBottom: 16, color: 'var(--text-primary)' }}>General</h3>
                     <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 16 }}>
                        {[
                           { label: 'Name', val: vesselData.name || '—' },
                           { label: 'Flag', val: vesselData.flag || 'Unknown' },
                           { label: 'IMO', val: vesselData.imo || '—' },
                           { label: 'MMSI', val: searchQuery },
                           { label: 'Call Sign', val: vesselData.callsign || '—' },
                           { label: 'AIS transponder class', val: 'Class A' },
                           { label: 'General vessel type', val: 'Cargo' },
                           { label: 'Detailed vessel type', val: vesselData.type || '—' }
                        ].map(item => (
                           <div key={item.label} style={{ borderBottom: '1px solid var(--border-subtle)', paddingBottom: 8 }}>
                              <div style={{ fontSize: '0.65rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase' }}>{item.label}</div>
                              <div style={{ fontSize: '0.9rem', fontWeight: 700, color: 'var(--text-primary)', marginTop: 2 }}>{item.val}</div>
                           </div>
                        ))}
                     </div>
                  </div>

                  {/* Latest AIS Info Section */}
                  <div className="feed-card" style={{ padding: '24px', borderRadius: 20, marginBottom: 40 }}>
                     <h3 style={{ fontSize: '1rem', fontWeight: 800, marginBottom: 16, color: 'var(--text-primary)' }}>Latest AIS Information</h3>
                     <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 16 }}>
                        {[
                           { label: 'Navigational Status', val: vesselData.status || '—' },
                           { label: 'Position Received', val: vesselData.last_update ? 'Live' : '—' },
                           { label: 'Speed', val: vesselData.speed !== undefined ? `${vesselData.speed} kn` : '0 kn' },
                           { label: 'Course', val: vesselData.course ? `${vesselData.course} °` : '—' },
                           { label: 'True Heading', val: vesselData.heading ? `${vesselData.heading} °` : '—' },
                           { label: 'Rate of Turn', val: vesselData.rot || '0 °/min' },
                           { label: 'Draught', val: vesselData.draught ? `${vesselData.draught} m` : '—' },
                           { label: 'Reported Destination', val: vesselData.destination || '—' },
                           { label: 'Reported ETA', val: vesselData.eta || '—' },
                           { label: 'AIS Source', val: 'Satellite' }
                        ].map(item => (
                           <div key={item.label} style={{ borderBottom: '1px solid var(--border-subtle)', paddingBottom: 8 }}>
                              <div style={{ fontSize: '0.65rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase' }}>{item.label}</div>
                              <div style={{ fontSize: '0.9rem', fontWeight: 700, color: 'var(--text-primary)', marginTop: 2 }}>{item.val}</div>
                           </div>
                        ))}
                     </div>
                  </div>
                </>
              ) : (
                <div style={{ textAlign: 'center', padding: 40, background: 'var(--bg-card)', borderRadius: 16 }}>
                 <span className="material-symbols-outlined" style={{ fontSize: '2.5rem', color: 'var(--text-muted)', marginBottom: 12 }}>radar</span>
                 <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginBottom: 16 }}>Scanning global AIS network... Vessels will appear here as data is received.</p>

                 {isMMSI && (
                   <div style={{ padding: '16px', background: 'rgba(240,130,50,0.05)', borderRadius: 12, border: '1px dashed var(--brand-primary)' }}>
                      <p style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--brand-primary)', marginBottom: 10 }}>WAITING FOR SATELLITE PING...</p>
                      <button
                        className="btn btn-primary btn-sm"
                        onClick={() => window.open(`https://www.marinetraffic.com/en/ais/details/ships/mmsi:${searchQuery}`)}
                        style={{ width: '100%' }}
                      >
                        <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>map</span>
                        View Latest Global Map
                      </button>
                   </div>
                 )}
              </div>
              )}
            </div>
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
