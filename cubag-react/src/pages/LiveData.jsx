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
    <AppLayout title="Intelligence">
      <div style={{ maxWidth: 1000, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16, paddingBottom: 40 }}>
        
        {/* Header summary */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '1px solid var(--border-subtle)', paddingBottom: 12 }}>
          <div>
            <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: 2 }}>Intelligence Hub</h2>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.8rem', margin: 0 }}>
              Live monitoring of global markets & logistics.
            </p>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, color: '#10b981', fontWeight: 700, fontSize: '0.65rem', textTransform: 'uppercase' }}>
              <span className="live-dot" style={{ width: 6, height: 6 }}></span>
              Live
            </div>
            <div style={{ color: 'var(--text-muted)', fontSize: '0.65rem', marginTop: 2 }}>{lastUpdated.split(' ')[0]}</div>
          </div>
        </div>

        <div className="dashboard-grid" style={{ gridTemplateColumns: '1fr', gap: 16 }}>
          
          {/* Forex Widget */}
          <div className="feed-card">
            <div className="card-header" style={{ padding: '10px 14px' }}>
              <span className="card-title" style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: '0.85rem' }}>
                <span className="material-symbols-outlined" style={{ color: 'var(--brand-primary)', fontSize: '1rem' }}>currency_exchange</span>
                Forex Rates
              </span>
            </div>
            <div className="card-body" style={{ padding: '10px 14px' }}>
              <div className="forex-grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(100px, 1fr))', gap: 8 }}>
                {Object.entries(forex).map(([currency, rate]) => (
                  <div key={currency} className="forex-item" style={{ padding: '8px', borderRadius: 8, background: 'var(--bg-base)', border: '1px solid var(--border-subtle)', textAlign: 'center' }}>
                    <div style={{ fontSize: '0.65rem', fontWeight: 600, color: 'var(--text-muted)' }}>{currency}/GHS</div>
                    <div style={{ fontFamily: 'monospace', fontWeight: 800, fontSize: '1rem', margin: '2px 0' }}>{rate}</div>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Port Congestion Index */}
          <div className="feed-card">
            <div className="card-header" style={{ padding: '10px 14px' }}>
              <span className="card-title" style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: '0.85rem' }}>
                <span className="material-symbols-outlined" style={{ color: '#f59e0b', fontSize: '1rem' }}>directions_boat</span>
                Port Congestion
              </span>
            </div>
            <div className="card-body" style={{ padding: '10px 14px', gap: 8 }}>
              {intelligence.ports.map(p => (
                <div key={p.port} style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: 8, borderBottom: '1px solid var(--border-subtle)' }}>
                  <span style={{ color: 'var(--text-secondary)', fontWeight: 600, fontSize: '0.8rem' }}>{p.port}</span>
                  <span style={{ color: p.color, fontWeight: 800, fontSize: '0.8rem' }}>{p.status}</span>
                </div>
              ))}
              {intelligence.ports.length === 0 && <p style={{ textAlign: 'center', color: 'var(--text-muted)', fontSize: '0.8rem' }}>No port data.</p>}
            </div>
          </div>

          {/* Alerts Feed */}
          <div className="feed-card">
            <div className="card-header" style={{ padding: '10px 14px' }}>
              <span className="card-title" style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: '0.85rem' }}>
                <span className="material-symbols-outlined" style={{ color: '#ef4444', fontSize: '1rem' }}>warning</span>
                Supply Chain Alerts
              </span>
            </div>
            <div className="card-body" style={{ padding: '10px 14px', gap: 10 }}>
              {intelligence.alerts.map(alert => (
                <div key={alert.id} style={{ background: 'var(--bg-base)', padding: 12, borderRadius: 10, borderLeft: `3px solid ${alert.severity === 'high' ? '#ef4444' : (alert.severity === 'medium' ? '#f59e0b' : '#3b82f6')}` }}>
                  <div style={{ fontWeight: 700, color: 'var(--text-primary)', marginBottom: 2, fontSize: '0.85rem' }}>{alert.title}</div>
                  <p style={{ margin: 0, color: 'var(--text-secondary)', fontSize: '0.75rem', lineHeight: 1.4 }}>{alert.detail}</p>
                </div>
              ))}
              {intelligence.alerts.length === 0 && <p style={{ textAlign: 'center', color: 'var(--text-muted)', fontSize: '0.8rem' }}>No active alerts.</p>}
            </div>
          </div>

        </div>
      </div>
    </AppLayout>
  )
}
