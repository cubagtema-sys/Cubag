import { useState, useEffect } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import AppLayout from '../components/AppLayout'
import useAutoRefresh from '../hooks/useAutoRefresh'

const API_URL = import.meta.env.VITE_API_URL

export default function Dashboard() {
  const navigate = useNavigate()
  const [user, setUser] = useState({})
  const [tasks, setTasks] = useState([])
  const [announcements, setAnnouncements] = useState([])
  const [forex, setForex] = useState({ USD: '15.42', EUR: '16.85' })
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    try {
      const stored = localStorage.getItem('cubag_user')
      if (stored) setUser(JSON.parse(stored))
    } catch (e) {
      console.error("Error loading user", e)
    }

    async function loadData() {
      try {
        setLoading(true)
        // Load tasks from real API
        const taskRes = await fetch(`${API_URL}/tasks/summary`, {
          headers: { 'Authorization': `Bearer ${localStorage.getItem('cubag_token')}` }
        })
        if (taskRes.ok) {
          const taskData = await taskRes.json()
          if (Array.isArray(taskData)) setTasks(taskData)
        }

        // Load announcements
        const annRes = await fetch(`${API_URL}/announcements`, {
          headers: { 'Authorization': `Bearer ${localStorage.getItem('cubag_token')}` }
        })
        if (annRes.ok) {
          const annData = await annRes.json()
          if (Array.isArray(annData)) setAnnouncements(annData.slice(0, 3))
        }

        // Load forex
        const forexRes = await fetch('https://open.er-api.com/v6/latest/GHS')
        if (forexRes.ok) {
          const data = await forexRes.json()
          if (data && data.rates) {
            setForex({
              USD: (1 / data.rates['USD']).toFixed(2),
              EUR: (1 / data.rates['EUR']).toFixed(2)
            })
          }
        }
      } catch (e) {
        console.error("Dashboard load error", e)
      } finally {
        setLoading(false)
      }
    }
    loadData()
  }, [])

  useAutoRefresh(() => {
    // Silently refresh announcements every 60s
    const token = localStorage.getItem('cubag_token')
    fetch(`${API_URL}/announcements`, { headers: { Authorization: `Bearer ${token}` } })
      .then(r => r.ok ? r.json() : [])
      .then(data => { if (Array.isArray(data)) setAnnouncements(data.slice(0, 3)) })
      .catch(() => {})
  }, 60000)

  const toggleTask = (id) => {
    setTasks(tasks.map(t => t.id === id ? { ...t, done: !t.done } : t))
  }

  const firstName = user.name ? user.name.split(' ')[0] : 'Member'

  if (loading) return (
    <AppLayout title="Dashboard" hideSearch>
      <div style={{ padding: '0 0 20px' }}>
        <div className="skeleton" style={{ height: 160, width: '100%', borderRadius: 24, marginBottom: 24 }}></div>
        <div className="dashboard-grid">
          <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
            <div className="skeleton" style={{ height: 300, width: '100%' }}></div>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
            <div className="skeleton" style={{ height: 180, width: '100%' }}></div>
            <div className="skeleton" style={{ height: 150, width: '100%' }}></div>
          </div>
        </div>
      </div>
    </AppLayout>
  )

  return (
    <AppLayout title="Dashboard" hideSearch>
      {/* Welcome Banner - Focused on Action */}
      <div className="welcome-banner" style={{ marginBottom: 24 }}>
        <div className="welcome-overlay"></div>
        <div className="welcome-copy">
          <h2 style={{ fontSize: '1.15rem' }}>Good day, <span>{firstName}</span>!</h2>
          <p style={{ marginBottom: 10, fontSize: '0.8rem' }}>
            {user.status === 'active'
              ? <>Your license expires in <strong>{user.licenseExpiry || 'Dec 31, 2026'}</strong>.</>
              : <strong>License Inactive: Payment or Validation Required</strong>
            }
            &nbsp;You have <strong>{Array.isArray(tasks) ? tasks.filter(t => !t.done).length : 0} pending</strong> items.
          </p>
          <div style={{ display: 'flex', gap: 6, alignItems: 'center', flexWrap: 'wrap' }}>
            <div style={{ background: 'rgba(255,255,255,0.15)', padding: '3px 8px', borderRadius: '20px', fontSize: '0.65rem', color: '#fff', border: '1px solid rgba(255,255,255,0.2)', whiteSpace: 'nowrap' }}>
              USD: <strong>{forex.USD}</strong>
            </div>
            <div style={{ background: 'rgba(255,255,255,0.15)', padding: '3px 8px', borderRadius: '20px', fontSize: '0.65rem', color: '#fff', border: '1px solid rgba(255,255,255,0.2)', whiteSpace: 'nowrap' }}>
              EUR: <strong>{forex.EUR}</strong>
            </div>
          </div>
        </div>
        <button onClick={() => navigate('/license-renewal')} className="btn btn-white welcome-action">Renew License</button>
      </div>

      {/* Main Actionable Content */}
      <div className="dashboard-grid">
        {/* Urgent: Tasks & Compliance */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
          <div className="feed-card">
            <div className="card-header">
              <span className="card-title" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span className="material-symbols-outlined" style={{ color: 'var(--brand-primary)', fontSize: '1.2rem' }}>task_alt</span>
                Priority Tasks
              </span>
            </div>
            <div className="card-body">
              {tasks.length === 0 ? (
                <div style={{ padding: '20px', textAlign: 'center', color: 'var(--text-muted)' }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '2rem', marginBottom: 8 }}>check_circle</span>
                  <p style={{ fontSize: '0.85rem' }}>No pending tasks! You are all caught up.</p>
                </div>
              ) : (
                tasks.filter(t => !t.done).map(task => (
                  <div className="task-item" key={task.id} style={{ padding: '10px 0', borderBottom: '1px solid var(--border-subtle)' }}>
                    <div className={`task-check ${task.done ? 'done' : ''}`} onClick={() => toggleTask(task.id)}></div>
                    <div className="task-info">
                      <div className="task-name" style={{ fontWeight: 600, fontSize: '0.9rem' }}>{task.name}</div>
                      <div className={`task-due ${task.overdue ? 'overdue' : ''}`} style={{ fontSize: '0.75rem', color: task.overdue ? 'var(--brand-danger)' : 'var(--text-muted)' }}>
                        {task.overdue ? '⚠ Overdue: ' : 'Due: '} {task.due}
                      </div>
                    </div>
                    <span className={`task-priority priority-${task.priority.toLowerCase()}`} style={{ fontSize: '0.65rem' }}>
                      {task.priority}
                    </span>
                  </div>
                ))
              )}
              <Link to="/tasks" className="btn btn-ghost btn-sm" style={{ width: '100%', marginTop: 12, justifyContent: 'center', fontSize: '0.8rem' }}>View all tasks</Link>
            </div>
          </div>

          {/* Important: Recent Announcements */}
          <div className="feed-card">
            <div className="card-header">
              <span className="card-title" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span className="material-symbols-outlined" style={{ color: 'var(--brand-primary)', fontSize: '1.2rem' }}>campaign</span>
                Announcements
              </span>
            </div>
            <div className="card-body" style={{ padding: '0 16px 16px' }}>
              {announcements.length === 0 ? (
                <div style={{ padding: '20px', textAlign: 'center', color: 'var(--text-muted)' }}>
                  <p style={{ fontSize: '0.85rem' }}>No new announcements from the secretariat.</p>
                </div>
              ) : announcements.map(a => (
                <div key={a.id} style={{ padding: '10px 0', borderBottom: '1px solid var(--border-subtle)', display: 'flex', gap: 10 }}>
                  <span className="material-symbols-outlined" style={{ color: 'var(--brand-primary)', fontSize: '1rem', flexShrink: 0, marginTop: 2 }}>campaign</span>
                  <div>
                    <div style={{ fontWeight: 700, fontSize: '0.85rem', marginBottom: 2 }}>{a.title}</div>
                    <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>{a.content}</div>
                  </div>
                </div>
              ))}
              <Link to="/announcements" className="btn btn-ghost btn-sm" style={{ width: '100%', marginTop: 12, justifyContent: 'center', fontSize: '0.8rem' }}>View all announcements</Link>
            </div>
          </div>
        </div>

        {/* Secondary: Shortcuts & Data */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
          {/* Shortcuts */}
          <div className="feed-card">
            <div className="card-header">
              <span className="card-title">Quick Shortcuts</span>
            </div>
            <div className="card-body">
              <div className="quick-actions">
                <Link to="/payments" className="quick-action" style={{ padding: '12px' }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '1.5rem', color: 'var(--brand-primary)' }}>payments</span>
                  <span style={{ fontSize: '0.8rem', fontWeight: 600 }}>Pay Dues</span>
                </Link>
                <Link to="/live-data" className="quick-action" style={{ padding: '12px' }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '1.5rem', color: 'var(--brand-primary)' }}>monitoring</span>
                  <span style={{ fontSize: '0.8rem', fontWeight: 600 }}>Live Data</span>
                </Link>
                <Link to="/networking" className="quick-action" style={{ padding: '12px' }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '1.5rem', color: 'var(--brand-primary)' }}>group</span>
                  <span style={{ fontSize: '0.8rem', fontWeight: 600 }}>Networking</span>
                </Link>
                <Link to="/engagement" className="quick-action" style={{ padding: '12px' }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '1.5rem', color: 'var(--brand-primary)' }}>support_agent</span>
                  <span style={{ fontSize: '0.8rem', fontWeight: 600 }}>Support</span>
                </Link>
              </div>
            </div>
          </div>

          {/* Live Forex Mini-Widget */}
          <div className="feed-card" style={{ background: 'var(--bg-elevated)', border: '1px solid var(--brand-primary)' }}>
            <div className="card-header" style={{ borderBottom: '1px solid rgba(240,130,50,0.1)' }}>
              <span className="card-title" style={{ color: 'var(--brand-primary)' }}>Live Forex</span>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginLeft: 'auto' }}>
                <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontWeight: 600 }}>LIVE</span>
                <span className="live-dot"></span>
              </div>
            </div>
            <div className="card-body" style={{ padding: '20px' }}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <div style={{ width: 24, height: 24, borderRadius: '50%', background: 'rgba(240,130,50,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '0.7rem', fontWeight: 800, color: 'var(--brand-primary)' }}>$</div>
                    <span style={{ fontSize: '0.9rem', fontWeight: 600 }}>USD/GHS</span>
                  </div>
                  <span style={{ fontWeight: 800, fontSize: '1.1rem', color: 'var(--brand-primary)' }}>{forex.USD}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <div style={{ width: 24, height: 24, borderRadius: '50%', background: 'rgba(59,130,246,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '0.7rem', fontWeight: 800, color: '#3b82f6' }}>€</div>
                    <span style={{ fontSize: '0.9rem', fontWeight: 600 }}>EUR/GHS</span>
                  </div>
                  <span style={{ fontWeight: 800, fontSize: '1.1rem', color: 'var(--text-primary)' }}>{forex.EUR}</span>
                </div>
              </div>
              <button className="btn btn-ghost btn-sm" style={{ width: '100%', marginTop: 12, fontSize: '0.75rem' }} onClick={() => navigate('/live-data')}>View Full Data Hub</button>
            </div>
          </div>
        </div>
      </div>
    </AppLayout>
  )
}
