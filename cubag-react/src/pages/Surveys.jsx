import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

const API_URL = import.meta.env.VITE_API_URL

export default function Surveys() {
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function fetchItems() {
      try {
        setLoading(true)
        const res = await fetch(`${API_URL}/surveys`, {
          headers: { 'Authorization': `Bearer ${localStorage.getItem('cubag_token')}` }
        })
        if (res.ok) {
          const data = await res.json()
          if (Array.isArray(data)) setItems(data)
        }
      } catch (e) {
        console.error("Surveys load error", e)
      } finally {
        setLoading(false)
      }
    }
    fetchItems()
  }, [])

  return (
    <AppLayout title="Surveys & Elections">
      <div style={{ maxWidth: 800, margin: '0 auto' }}>
        
        {loading ? (
          <div style={{ minHeight: '300px', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', background: 'var(--bg-card)', borderRadius: 'var(--radius-xl)' }}>
            <div className="spinner" style={{ marginBottom: 16 }}></div>
            <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', fontWeight: 600 }}>SYNCING SURVEYS</div>
          </div>
        ) : items.length === 0 ? (
          <div className="feed-card" style={{ padding: '60px 20px', textAlign: 'center' }}>
            <span className="material-symbols-outlined" style={{ fontSize: '4rem', color: 'var(--text-muted)', marginBottom: 20 }}>ballot</span>
            <h3 style={{ color: 'var(--text-primary)', marginBottom: 12 }}>No Active Polls</h3>
            <p style={{ color: 'var(--text-secondary)', maxWidth: 400, margin: '0 auto' }}>There are currently no active surveys or association elections requiring your vote.</p>
          </div>
        ) : (
          <div style={{ display: 'grid', gap: 20 }}>
            {items.map(item => (
              <div key={item.id} className="feed-card">
                <div className="card-body" style={{ padding: '24px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 12 }}>
                    <div>
                      <span className="badge badge-warning" style={{ marginBottom: 8 }}>{item.type}</span>
                      <h3 style={{ color: 'var(--text-primary)' }}>{item.title}</h3>
                    </div>
                    <div style={{ textAlign: 'right', fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                      Ends: {item.expiry}
                    </div>
                  </div>
                  <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem', marginBottom: 20 }}>{item.description}</p>
                  <button className="btn btn-primary" style={{ width: '100%', justifyContent: 'center' }}>Participate Now</button>
                </div>
              </div>
            ))}
          </div>
        )}

      </div>
    </AppLayout>
  )
}
