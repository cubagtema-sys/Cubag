import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

const API_URL = import.meta.env.VITE_API_URL

export default function LiveData() {
  const [forex, setForex] = useState({ USD: '...', EUR: '...', GBP: '...', CNY: '...' })
  const [loading, setLoading] = useState(true)
  const [lastUpdated, setLastUpdated] = useState(new Date().toLocaleTimeString())
  
  // Real-time feeds from Backend
  const [intelligence, setIntelligence] = useState({ ports: [], bunkers: [], alerts: [] })

  useEffect(() => {
    async function loadData() {
      try {
        setLoading(true)
        // 1. Real-time Forex (Actual API)
        const forexRes = await fetch('https://open.er-api.com/v6/latest/GHS')
        if (forexRes.ok) {
          const data = await forexRes.json()
          setForex({
            USD: (1 / data.rates['USD']).toFixed(2),
            EUR: (1 / data.rates['EUR']).toFixed(2),
            GBP: (1 / data.rates['GBP']).toFixed(2),
            CNY: (1 / data.rates['CNY']).toFixed(2),
          })
        }

        // 2. Intelligence Hub (From CUBAG Admin)
        const intelRes = await fetch(`${API_URL}/intelligence`)
        if (intelRes.ok) {
          setIntelligence(await intelRes.json())
        }
        
        setLastUpdated(new Date().toLocaleTimeString())
      } catch (e) {
        console.error("Live Data load error", e)
      } finally {
        setLoading(false)
      }
    }

    loadData()
    const interval = setInterval(loadData, 60000) // Refresh every minute
    return () => clearInterval(interval)
  }, [])

  return (
    <AppLayout title="Live Intelligence Hub">
      <div style={{ maxWidth: 1000, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 24, paddingBottom: 40 }}>
        
        {/* Header summary */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', borderBottom: '1px solid var(--border-subtle)', paddingBottom: 16 }}>
          <div>
            <h2 style={{ fontSize: '1.6rem', color: 'var(--text-primary)', marginBottom: 4 }}>Real-Time Intelligence Hub</h2>
            <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem', margin: 0 }}>
              Official monitoring of global logistics, maritime indices, and financial markets.
            </p>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, color: '#10b981', fontWeight: 700, fontSize: '0.8rem', textTransform: 'uppercase' }}>
              <span className="live-dot"></span>
              Live Feed Active
            </div>
            <div style={{ color: 'var(--text-muted)', fontSize: '0.75rem', marginTop: 4 }}>Last sync: {lastUpdated}</div>
          </div>
        </div>

        <div className="dashboard-grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 20 }}>
          
          {/* Forex Widget (Actual API Data) */}
          <div className="feed-card" style={{ height: 'fit-content' }}>
            <div className="card-header">
              <span className="card-title" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span className="material-symbols-outlined" style={{ color: 'var(--brand-primary)' }}>currency_exchange</span>
                Forex Rates (BoG Live)
              </span>
            </div>
            <div className="card-body">
              <div className="forex-grid" style={{ width: '100%' }}>
                {Object.entries(forex).map(([currency, rate]) => (
                  <div key={currency} className="forex-item" style={{ padding: '12px 0' }}>
                    <span className="forex-pair" style={{ fontWeight: 600 }}>{currency} / GHS</span>
                    <span className="forex-rate" style={{ fontFamily: 'monospace', fontWeight: 800, fontSize: '1.1rem' }}>{rate}</span>
                    <span className={`forex-change ${rate !== '...' ? 'up' : ''}`} style={{ fontSize: '0.7rem' }}>Live</span>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Port Congestion Index (From Admin) */}
          <div className="feed-card" style={{ height: 'fit-content' }}>
            <div className="card-header">
              <span className="card-title" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span className="material-symbols-outlined" style={{ color: '#f59e0b' }}>directions_boat</span>
                Port Congestion Index
              </span>
            </div>
            <div className="card-body" style={{ flexDirection: 'column', gap: 12 }}>
              {intelligence.ports.map(p => (
                <div key={p.port} style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: 10, borderBottom: '1px solid var(--border-subtle)' }}>
                  <span style={{ color: 'var(--text-secondary)', fontWeight: 600 }}>{p.port}</span>
                  <span style={{ color: p.color, fontWeight: 800, fontSize: '0.9rem' }}>{p.status}</span>
                </div>
              ))}
              {intelligence.ports.length === 0 && <p style={{ textAlign: 'center', color: 'var(--text-muted)' }}>No port data available.</p>}
            </div>
          </div>



          {/* Dynamic Supply Chain & Security Alerts */}
          <div className="feed-card" style={{ gridColumn: '1 / -1' }}>
            <div className="card-header">
              <span className="card-title" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span className="material-symbols-outlined" style={{ color: '#ef4444' }}>warning</span>
                Supply Chain & Security Feed
              </span>
              <button onClick={() => window.location.reload()} style={{ background: 'none', border: 'none', color: 'var(--brand-primary)', fontSize: '0.75rem', fontWeight: 700, cursor: 'pointer' }}>REFRESH FEED</button>
            </div>
            <div className="card-body" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: 20 }}>
              {intelligence.alerts.map(alert => (
                <div key={alert.id} style={{ background: 'var(--bg-base)', padding: 16, borderRadius: 12, borderLeft: `4px solid ${alert.severity === 'high' ? '#ef4444' : (alert.severity === 'medium' ? '#f59e0b' : '#3b82f6')}` }}>
                  <div style={{ fontWeight: 700, color: 'var(--text-primary)', marginBottom: 6, fontSize: '1rem' }}>{alert.title}</div>
                  <p style={{ margin: 0, color: 'var(--text-secondary)', fontSize: '0.85rem', lineHeight: 1.5 }}>{alert.detail}</p>
                </div>
              ))}
              {intelligence.alerts.length === 0 && <p style={{ textAlign: 'center', color: 'var(--text-muted)', gridColumn: '1 / -1' }}>No active alerts.</p>}
            </div>
          </div>

        </div>
      </div>
    </AppLayout>
  )
}
