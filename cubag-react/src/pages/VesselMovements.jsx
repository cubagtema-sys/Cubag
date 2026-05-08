import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

const API_URL = import.meta.env.VITE_API_URL

export default function VesselMovements() {
  const [vessels, setVessels] = useState([])
  const [searchTerm, setSearchTerm] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function loadData() {
      try {
        setLoading(true)
        const res = await fetch(`${API_URL}/vessels`, { headers: { 'Authorization': `Bearer ${localStorage.getItem('cubag_token')}` } })
        if (res.ok) {
          const data = await res.json()
          setVessels(data)
        } else {
          // Fallback mock for demo if backend not ready
          setVessels([
            { id: 1, name: 'MSC ANIELLO', type: 'Container Ship', eta: 'Today, 14:00', status: 'In Port', status_color: 'success', lat: 5.62, lng: -0.01 },
            { id: 2, name: 'MAERSK TEMA', type: 'Container Ship', eta: 'Tomorrow, 08:00', status: 'Arriving', status_color: 'warning', lat: 5.4, lng: -0.2 },
            { id: 3, name: 'CMA CGM DAKAR', type: 'Cargo', eta: 'Oct 24, 18:00', status: 'Delayed', status_color: 'danger', lat: 5.1, lng: -0.5 }
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

  const filteredVessels = vessels.filter(v => 
    v.name.toLowerCase().includes(searchTerm.toLowerCase()) || 
    v.status.toLowerCase().includes(searchTerm.toLowerCase())
  )

  return (
    <AppLayout title="Vessel Movements">
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        
        <div style={{ position: 'relative' }}>
          <span className="material-symbols-outlined" style={{ position: 'absolute', left: 16, top: 14, color: 'var(--text-muted)' }}>search</span>
          <input 
            type="text" 
            placeholder="Search vessels by name or status..." autoComplete="off" 
            value={searchTerm}
            onChange={e => setSearchTerm(e.target.value)}
            style={{ width: '100%', padding: '16px 16px 16px 48px', borderRadius: 12, border: '1px solid var(--border-subtle)', outline: 'none', fontSize: '1rem' }}
          />
        </div>

        {/* Live Map Area */}
        <div style={{ height: 250, borderRadius: 12, overflow: 'hidden', border: '1px solid var(--border-subtle)', position: 'relative' }}>
          <iframe 
            width="100%" 
            height="100%" 
            frameBorder="0" 
            scrolling="no" 
            marginHeight="0" 
            marginWidth="0" 
            src="https://www.openstreetmap.org/export/embed.html?bbox=-0.08,5.55,0.02,5.65&layer=mapnik&marker=5.6,-0.02" 
            style={{ border: 'none' }}
          ></iframe>
          <div style={{ position: 'absolute', top: 10, right: 10, background: 'rgba(255,255,255,0.9)', padding: '4px 8px', borderRadius: 20, fontSize: '0.7rem', fontWeight: 700, display: 'flex', alignItems: 'center', gap: 6, boxShadow: '0 2px 4px rgba(0,0,0,0.1)' }}>
            <span className="live-dot"></span> Live GPS Track
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {filteredVessels.length > 0 ? filteredVessels.map((v, i) => (
            <div key={v.id || i} style={{ background: 'var(--bg-card)', padding: 16, borderRadius: 12, border: '1px solid var(--border-subtle)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                <div style={{ width: 40, height: 40, background: 'rgba(240,130,50,0.1)', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--brand-primary)' }}>
                  <span className="material-symbols-outlined">directions_boat</span>
                </div>
                <div>
                  <div style={{ fontWeight: 700, fontSize: '1rem', color: 'var(--text-primary)' }}>{v.name}</div>
                  <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>{v.type} • ETA {v.eta}</div>
                </div>
              </div>
              <span className={`badge badge-${v.status_color || 'info'}`}>{v.status}</span>
            </div>
          )) : (
            <div style={{ textAlign: 'center', padding: 30, color: 'var(--text-muted)' }}>No vessels matching "{searchTerm}"</div>
          )}
        </div>
        
      </div>
    </AppLayout>
  )
}
