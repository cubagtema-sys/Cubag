import { useState, useEffect, useCallback } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import AppLayout from '../components/AppLayout'

export default function AdminDashboard() {
  const [stats, setStats] = useState({
    total_members: 0,
    active_members: 0,
    revenue: 0,
    pending_members: 0,
    open_tickets: 0
  })
  const [recentMembers, setRecentMembers] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const navigate = useNavigate()

  const fetchDashboardData = useCallback(async () => {
    try {
      setLoading(true)
      setError(null)
      const token = localStorage.getItem('cubag_token')
      const res = await fetch(`${import.meta.env.VITE_API_URL}/admin/dashboard`, {
        headers: { 'Authorization': `Bearer ${token}` }
      })

      if (res.ok) {
        const data = await res.json()
        if (data.kpis) setStats(data.kpis)
        if (data.recent_members) setRecentMembers(data.recent_members)
      } else {
        const errData = await res.json().catch(() => ({}))
        setError(errData.message || `API Error: ${res.status}`)
        if (res.status === 401 || res.status === 403) navigate('/login')
      }
    } catch (e) {
      console.error('Failed to fetch dashboard stats', e)
      setError("Network error. Please check your connection.")
    } finally {
      setLoading(false)
    }
  }, [navigate])

  useEffect(() => {
    fetchDashboardData()
  }, [fetchDashboardData])

  return (
    <AppLayout title="Admin Hub">
      <div style={{ maxWidth: 1200, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>
        
        {/* Page Title removed as it is now in the header */}
        <div style={{ marginBottom: 4, display: 'flex', justifyContent: 'flex-end', alignItems: 'center' }}>
          <button
            className="btn btn-ghost btn-sm"
            onClick={fetchDashboardData}
            disabled={loading}
            style={{ borderRadius: '50%', width: 40, height: 40, padding: 0, justifyContent: 'center' }}
          >
            <span className={`material-symbols-outlined ${loading ? 'spin' : ''}`}>refresh</span>
          </button>
        </div>

        {error && (
          <div style={{ padding: '12px 16px', background: 'rgba(239,68,68,0.1)', color: '#ef4444', borderRadius: 12, fontSize: '0.85rem', fontWeight: 600, display: 'flex', alignItems: 'center', gap: 10 }}>
            <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>error</span>
            {error}
          </div>
        )}

        {/* Debug Info (Hidden in production usually, but shown here for verification) */}
        <div style={{ fontSize: '0.65rem', color: 'var(--text-muted)', background: 'var(--bg-base)', padding: '4px 10px', borderRadius: 6, alignSelf: 'flex-start', border: '1px solid var(--border-subtle)' }}>
           Admin Session: <strong>{localStorage.getItem('cubag_user') ? JSON.parse(localStorage.getItem('cubag_user')).email : 'None'}</strong> |
           Role: <strong>{localStorage.getItem('cubag_user') ? JSON.parse(localStorage.getItem('cubag_user')).role : 'None'}</strong>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: 16 }}>
          
          {/* Left Column: Key Metrics */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <h2 style={{ fontSize: '1.1rem', fontWeight: 700, margin: 0 }}>Platform Health</h2>
            
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              {/* Total Members */}
              <div className="card" style={{ padding: 16, display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', background: '#fff', borderBottom: '3px solid var(--brand-primary)' }}>
                <div style={{ width: 40, height: 40, borderRadius: '50%', background: 'rgba(240, 130, 50, 0.1)', color: 'var(--brand-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 10 }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>group</span>
                </div>
                <div style={{ fontSize: '1.5rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1 }}>
                  {loading ? '...' : (stats.total_members)}
                </div>
                <div style={{ fontSize: '0.65rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, marginTop: 6 }}>Total Users</div>
              </div>

              {/* Active Members */}
              <div className="card" style={{ padding: 16, display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', background: '#fff', borderBottom: '3px solid #10b981' }}>
                <div style={{ width: 40, height: 40, borderRadius: '50%', background: 'rgba(16, 185, 129, 0.1)', color: '#10b981', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 10 }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>verified_user</span>
                </div>
                <div style={{ fontSize: '1.5rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1 }}>
                  {loading ? '...' : (stats.active_members)}
                </div>
                <div style={{ fontSize: '0.65rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, marginTop: 6 }}>Active Licenses</div>
              </div>

              {/* Pending Approvals */}
              <div className="card" style={{ padding: 16, display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', background: '#fff', borderBottom: '3px solid #f59e0b' }}>
                <div style={{ width: 40, height: 40, borderRadius: '50%', background: 'rgba(245, 158, 11, 0.1)', color: '#f59e0b', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 10 }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>pending_actions</span>
                </div>
                <div style={{ fontSize: '1.5rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1 }}>
                  {loading ? '...' : stats.pending_members}
                </div>
                <div style={{ fontSize: '0.65rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, marginTop: 6 }}>Pending Approval</div>
              </div>

              {/* Revenue */}
              <div className="card" style={{ padding: 16, display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', background: '#fff', borderBottom: '3px solid #3b82f6' }}>
                <div style={{ width: 40, height: 40, borderRadius: '50%', background: 'rgba(59, 130, 246, 0.1)', color: '#3b82f6', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 10 }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>payments</span>
                </div>
                <div style={{ fontSize: '1.1rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1, marginTop: 4 }}>
                  {loading ? '...' : (stats.revenue > 0 ? `₵${stats.revenue >= 1000 ? (stats.revenue/1000).toFixed(1)+'k' : stats.revenue}` : '₵0.00')}
                </div>
                <div style={{ fontSize: '0.65rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, marginTop: 6 }}>Revenue</div>
              </div>
            </div>

            {/* Recent Activity Table */}
            <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
              <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--border-subtle)', background: 'var(--bg-elevated)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <h3 style={{ fontSize: '0.9rem', fontWeight: 700 }}>Recent Registrations</h3>
                <Link to="/admin/members" style={{ fontSize: '0.75rem', fontWeight: 700 }}>View All</Link>
              </div>
              <div style={{ overflowX: 'auto' }}>
                <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                  <thead style={{ background: 'var(--bg-base)', textAlign: 'left' }}>
                    <tr>
                      <th style={{ padding: '10px 20px', fontSize: '0.65rem', textTransform: 'uppercase', color: 'var(--text-muted)' }}>Name</th>
                      <th style={{ padding: '10px 20px', fontSize: '0.65rem', textTransform: 'uppercase', color: 'var(--text-muted)' }}>Type</th>
                      <th style={{ padding: '10px 20px', fontSize: '0.65rem', textTransform: 'uppercase', color: 'var(--text-muted)', textAlign: 'right' }}>Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {recentMembers.length === 0 ? (
                      <tr><td colSpan="3" style={{ padding: 30, textAlign: 'center', color: 'var(--text-muted)', fontSize: '0.8rem' }}>No recent registrations</td></tr>
                    ) : recentMembers.map(m => (
                      <tr key={m.id} style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                        <td style={{ padding: '12px 20px', fontSize: '0.85rem', fontWeight: 600 }}>{m.name}</td>
                        <td style={{ padding: '12px 20px', fontSize: '0.8rem', color: 'var(--text-secondary)' }}>{m.member_type}</td>
                        <td style={{ padding: '12px 20px', textAlign: 'right' }}>
                          <span className={`badge badge-${m.status === 'active' ? 'success' : m.status === 'pending' ? 'warning' : 'danger'}`} style={{ fontSize: '0.6rem' }}>{m.status}</span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>

          {/* Right Column: Portal Management Hub */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <h2 style={{ fontSize: '1.1rem', fontWeight: 700, margin: 0 }}>Portal Management</h2>
            
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              
              <Link to="/admin/license-renewal" className="card" style={{ padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 12, textDecoration: 'none', transition: 'all 0.2s', borderLeft: '3px solid #f59e0b' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '1.4rem', color: '#f59e0b' }}>fact_check</span>
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '0.95rem' }}>Licenses</div>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>Review renewals & expiries</div>
                </div>
                <span className="material-symbols-outlined" style={{ fontSize: '1.1rem', color: 'var(--border-strong)' }}>arrow_forward</span>
              </Link>

              <Link to="/admin/members" className="card" style={{ padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 12, textDecoration: 'none', transition: 'all 0.2s', borderLeft: '3px solid var(--brand-primary)' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '1.4rem', color: 'var(--brand-primary)' }}>group</span>
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '0.95rem' }}>Member Directory</div>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>Manage all registered accounts</div>
                </div>
                <span className="material-symbols-outlined" style={{ fontSize: '1.1rem', color: 'var(--border-strong)' }}>arrow_forward</span>
              </Link>

              <Link to="/admin/tasks" className="card" style={{ padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 12, textDecoration: 'none', transition: 'all 0.2s', borderLeft: '3px solid #3b82f6' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '1.4rem', color: '#3b82f6' }}>assignment_add</span>
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '0.95rem' }}>Compliance & Tasks</div>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>Assign and verify duties</div>
                </div>
                <span className="material-symbols-outlined" style={{ fontSize: '1.1rem', color: 'var(--border-strong)' }}>arrow_forward</span>
              </Link>

              <Link to="/admin/announcements" className="card" style={{ padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 12, textDecoration: 'none', transition: 'all 0.2s', borderLeft: '3px solid #10b981' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '1.4rem', color: '#10b981' }}>campaign</span>
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '0.95rem' }}>Broadcast Alerts</div>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>Send push notifications</div>
                </div>
                <span className="material-symbols-outlined" style={{ fontSize: '1.1rem', color: 'var(--border-strong)' }}>arrow_forward</span>
              </Link>

              <Link to="/admin/cargo-schedules" className="card" style={{ padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 12, textDecoration: 'none', transition: 'all 0.2s', borderLeft: '3px solid #8b5cf6' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '1.4rem', color: '#8b5cf6' }}>local_shipping</span>
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '0.95rem' }}>Logistics Master</div>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>Update vanning schedules</div>
                </div>
                <span className="material-symbols-outlined" style={{ fontSize: '1.1rem', color: 'var(--border-strong)' }}>arrow_forward</span>
              </Link>

              <Link to="/admin/payments" className="card" style={{ padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 12, textDecoration: 'none', transition: 'all 0.2s', borderLeft: '3px solid #10b981' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '1.4rem', color: '#10b981' }}>account_balance_wallet</span>
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '0.95rem' }}>Revenue Control</div>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>Audit and confirm payments</div>
                </div>
                <span className="material-symbols-outlined" style={{ fontSize: '1.1rem', color: 'var(--border-strong)' }}>arrow_forward</span>
              </Link>

            </div>
          </div>
        </div>

      </div>
    </AppLayout>
  )
}

