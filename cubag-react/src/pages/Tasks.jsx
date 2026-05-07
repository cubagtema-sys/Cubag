import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

const API_URL = import.meta.env.VITE_API_URL

export default function Tasks() {
  const [tasks, setTasks] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    async function fetchTasks() {
      try {
        setLoading(true)
        const res = await fetch(`${API_URL}/tasks`, {
          headers: { 'Authorization': `Bearer ${localStorage.getItem('cubag_token')}` }
        })
        if (!res.ok) throw new Error('Failed to fetch tasks')
        const data = await res.json()
        setTasks(data)
      } catch (err) {
        setError(err.message)
      } finally {
        setLoading(false)
      }
    }
    fetchTasks()
  }, [])

  return (
    <AppLayout title="Tasks & Compliance">
      <div style={{ maxWidth: 800, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 24 }}>
        
        <div className="feed-card" style={{ background: 'var(--gradient-brand)', color: '#fff', border: 'none' }}>
          <div className="card-body" style={{ display: 'flex', alignItems: 'center', gap: 20, padding: '24px' }}>
            <div style={{ width: 60, height: 60, borderRadius: '50%', background: 'rgba(255,255,255,0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '2rem', animation: loading ? 'spin 1s linear infinite' : 'none' }}>
                {loading ? 'sync' : tasks.filter(t => !t.completed).length > 0 ? 'assignment_late' : 'verified_user'}
              </span>
            </div>
            <div>
              <h2 style={{ fontSize: '1.25rem', marginBottom: 4 }}>Compliance Status</h2>
              <p style={{ opacity: 0.9, fontSize: '0.9rem' }}>
                {tasks.length > 0 
                  ? `You have ${tasks.filter(t => !t.completed).length} pending items to address.` 
                  : 'Checking your compliance records...'}
              </p>
            </div>
          </div>
        </div>

        {loading ? (
          <div style={{ 
            minHeight: '300px', 
            display: 'flex', 
            flexDirection: 'column', 
            alignItems: 'center', 
            justifyContent: 'center',
            background: 'var(--bg-card)',
            borderRadius: 'var(--radius-xl)',
            border: '1px solid var(--border-subtle)',
            boxShadow: 'var(--shadow-sm)'
          }}>
            <div className="spinner" style={{ marginBottom: 16 }}></div>
            <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', fontWeight: 600, letterSpacing: '0.05em' }}>
              SYNCING COMPLIANCE RECORDS
            </div>
          </div>
        ) : error ? (
          <div className="feed-card" style={{ border: '1px solid var(--brand-danger)', background: 'rgba(239, 68, 68, 0.05)' }}>
            <div className="card-body" style={{ textAlign: 'center', padding: '48px 20px' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '3rem', color: 'var(--brand-danger)', marginBottom: 16 }}>cloud_off</span>
              <h3 style={{ marginBottom: 8, color: 'var(--text-primary)' }}>API Connection Failed</h3>
              <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem', marginBottom: 24, maxWidth: 350, margin: '0 auto 24px' }}>
                We are unable to reach the CUBAG servers. This usually happens when the backend API is offline or the server address is incorrect.
              </p>
              <button className="btn btn-primary" style={{ background: 'var(--brand-danger)', border: 'none' }} onClick={() => window.location.reload()}>
                Retry Sync
              </button>
            </div>
          </div>
        ) : tasks.length === 0 ? (
          <div className="feed-card">
            <div className="card-body" style={{ textAlign: 'center', padding: '60px 20px' }}>
              <div style={{ width: 80, height: 80, background: 'var(--bg-base)', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 20px' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '2.5rem', color: 'var(--text-muted)' }}>inventory_2</span>
              </div>
              <h3 style={{ color: 'var(--text-primary)', marginBottom: 8 }}>All caught up!</h3>
              <p style={{ color: 'var(--text-secondary)', maxWidth: 300, margin: '0 auto' }}>You have no pending compliance tasks at this time. Great job staying up to date!</p>
            </div>
          </div>
        ) : (
          <div className="feed-card">
            <div className="card-header">
              <span className="card-title">Pending Requirements</span>
            </div>
            <div className="card-body" style={{ padding: 0 }}>
              {tasks.map(task => (
                <div key={task.id} style={{ padding: '20px', borderBottom: '1px solid var(--border-subtle)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div style={{ display: 'flex', gap: 16, alignItems: 'center' }}>
                    <div style={{ 
                      width: 44, height: 44, borderRadius: '12px', 
                      background: task.urgent ? 'rgba(239, 68, 68, 0.1)' : 'rgba(240, 130, 50, 0.1)',
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      color: task.urgent ? 'var(--brand-danger)' : 'var(--brand-primary)'
                    }}>
                      <span className="material-symbols-outlined">{task.icon || 'description'}</span>
                    </div>
                    <div>
                      <div style={{ fontWeight: 600, color: 'var(--text-primary)' }}>{task.title}</div>
                      <div style={{ fontSize: '0.8rem', color: task.urgent ? 'var(--brand-danger)' : 'var(--text-muted)', marginTop: 2 }}>
                        {task.urgent ? '⚠ Action Required' : `Due: ${task.due_date}`}
                      </div>
                    </div>
                  </div>
                  <button className="btn btn-outline btn-sm">Resolve</button>
                </div>
              ))}
            </div>
          </div>
        )}

      </div>
    </AppLayout>
  )
}
