import { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import AppLayout from '../components/AppLayout'

export default function AdminDashboard() {
  const [stats, setStats] = useState({
    totalMembers: 0,
    pendingLicenses: 0,
    revenue: 0,
    openTickets: 0
  })
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const fetchDashboardData = async () => {
      try {
        const token = localStorage.getItem('cubag_token')
        const authHeader = { 'Authorization': `Bearer ${token}` }

        const memRes = await fetch(`${import.meta.env.VITE_API_URL}/members/admin/all`, { headers: authHeader })
        let members = []
        if (memRes.ok) members = await memRes.json()

        const payRes = await fetch(`${import.meta.env.VITE_API_URL}/payments/admin/all`, { headers: authHeader })
        let payments = { kpis: { revenue: 0, pending: 0 } }
        if (payRes.ok) payments = await payRes.json()

        const ticketRes = await fetch(`${import.meta.env.VITE_API_URL}/tickets`, { headers: authHeader })
        let openTickets = 0
        if (ticketRes.ok) {
          const ticketData = await ticketRes.json()
          openTickets = Array.isArray(ticketData) ? ticketData.filter(t => t.status === 'open' || t.status === 'Open').length : 0
        }

        setStats({
          totalMembers: members.length,
          pendingLicenses: members.filter(m => m.status === 'pending').length,
          revenue: payments.kpis.revenue || 0,
          openTickets
        })
      } catch (e) {
        console.error('Failed to fetch dashboard stats', e)
      } finally {
        setLoading(false)
      }
    }
    fetchDashboardData()
  }, [])

  return (
    <AppLayout title="Admin Hub">
      <div style={{ maxWidth: 1200, margin: '0 auto', padding: '24px 16px', display: 'flex', flexDirection: 'column', gap: 24 }}>
        


        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: 24 }}>
          
          {/* Left Column: Key Metrics */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
            <h2 style={{ fontSize: '1.3rem', fontWeight: 700, margin: 0 }}>Platform Health</h2>
            
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
              {/* Metric 1 */}
              <div className="card" style={{ padding: 20, display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', background: '#fff' }}>
                <div style={{ width: 48, height: 48, borderRadius: '50%', background: 'rgba(16, 185, 129, 0.1)', color: '#10b981', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 12 }}>
                  <span className="material-symbols-outlined">group</span>
                </div>
                <div style={{ fontSize: '2rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1 }}>
                  {loading ? '...' : stats.totalMembers}
                </div>
                <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, marginTop: 8 }}>Total Members</div>
              </div>

              {/* Metric 2 */}
              <div className="card" style={{ padding: 20, display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', background: '#fff' }}>
                <div style={{ width: 48, height: 48, borderRadius: '50%', background: 'rgba(245, 158, 11, 0.1)', color: '#f59e0b', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 12 }}>
                  <span className="material-symbols-outlined">pending_actions</span>
                </div>
                <div style={{ fontSize: '2rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1 }}>
                  {loading ? '...' : stats.pendingLicenses}
                </div>
                <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, marginTop: 8 }}>Pending Approvals</div>
              </div>

              {/* Metric 3 */}
              <div className="card" style={{ padding: 20, display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', background: '#fff' }}>
                <div style={{ width: 48, height: 48, borderRadius: '50%', background: 'rgba(239, 68, 68, 0.1)', color: '#ef4444', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 12 }}>
                  <span className="material-symbols-outlined">support_agent</span>
                </div>
                <div style={{ fontSize: '2rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1 }}>
                  {loading ? '...' : stats.openTickets}
                </div>
                <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, marginTop: 8 }}>Open Tickets</div>
              </div>

              {/* Metric 4 */}
              <div className="card" style={{ padding: 20, display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', background: '#fff' }}>
                <div style={{ width: 48, height: 48, borderRadius: '50%', background: 'rgba(59, 130, 246, 0.1)', color: '#3b82f6', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 12 }}>
                  <span className="material-symbols-outlined">payments</span>
                </div>
                <div style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1, marginTop: 10, marginBottom: 4 }}>
                  {loading ? '...' : `GHS ${stats.revenue >= 1000 ? (stats.revenue/1000).toFixed(1)+'k' : stats.revenue}`}
                </div>
                <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, marginTop: 8 }}>Collected Dues</div>
              </div>
            </div>
          </div>

          {/* Right Column: Portal Management Hub */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
            <h2 style={{ fontSize: '1.3rem', fontWeight: 700, margin: 0 }}>Portal Management</h2>
            
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              
              <Link to="/admin/license-renewal" className="card" style={{ padding: '16px 20px', display: 'flex', alignItems: 'center', gap: 16, textDecoration: 'none', transition: 'all 0.2s', borderLeft: '4px solid #f59e0b' }} onMouseOver={e => e.currentTarget.style.transform = 'translateX(4px)'} onMouseOut={e => e.currentTarget.style.transform = 'translateX(0)'}>
                <span className="material-symbols-outlined" style={{ fontSize: '1.8rem', color: '#f59e0b' }}>fact_check</span>
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '1.1rem' }}>License Applications</div>
                  <div style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>Review member applications and renewals</div>
                </div>
                <span className="material-symbols-outlined" style={{ color: 'var(--border-strong)' }}>arrow_forward</span>
              </Link>

              <Link to="/admin/tasks" className="card" style={{ padding: '16px 20px', display: 'flex', alignItems: 'center', gap: 16, textDecoration: 'none', transition: 'all 0.2s', borderLeft: '4px solid #3b82f6' }} onMouseOver={e => e.currentTarget.style.transform = 'translateX(4px)'} onMouseOut={e => e.currentTarget.style.transform = 'translateX(0)'}>
                <span className="material-symbols-outlined" style={{ fontSize: '1.8rem', color: '#3b82f6' }}>assignment_add</span>
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '1.1rem' }}>Task & Compliance</div>
                  <div style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>Assign network-wide compliance duties</div>
                </div>
                <span className="material-symbols-outlined" style={{ color: 'var(--border-strong)' }}>arrow_forward</span>
              </Link>

              <Link to="/admin/announcements" className="card" style={{ padding: '16px 20px', display: 'flex', alignItems: 'center', gap: 16, textDecoration: 'none', transition: 'all 0.2s', borderLeft: '4px solid #10b981' }} onMouseOver={e => e.currentTarget.style.transform = 'translateX(4px)'} onMouseOut={e => e.currentTarget.style.transform = 'translateX(0)'}>
                <span className="material-symbols-outlined" style={{ fontSize: '1.8rem', color: '#10b981' }}>campaign</span>
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '1.1rem' }}>Broadcast Announcements</div>
                  <div style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>Send system alerts to all active users</div>
                </div>
                <span className="material-symbols-outlined" style={{ color: 'var(--border-strong)' }}>arrow_forward</span>
              </Link>

              <Link to="/admin/cargo-schedules" className="card" style={{ padding: '16px 20px', display: 'flex', alignItems: 'center', gap: 16, textDecoration: 'none', transition: 'all 0.2s', borderLeft: '4px solid #8b5cf6' }} onMouseOver={e => e.currentTarget.style.transform = 'translateX(4px)'} onMouseOut={e => e.currentTarget.style.transform = 'translateX(0)'}>
                <span className="material-symbols-outlined" style={{ fontSize: '1.8rem', color: '#8b5cf6' }}>local_shipping</span>
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '1.1rem' }}>Logistics Data</div>
                  <div style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>Publish and update live schedules</div>
                </div>
                <span className="material-symbols-outlined" style={{ color: 'var(--border-strong)' }}>arrow_forward</span>
              </Link>

              <Link to="/admin/fees" className="card" style={{ padding: '16px 20px', display: 'flex', alignItems: 'center', gap: 16, textDecoration: 'none', transition: 'all 0.2s', borderLeft: '4px solid #f97316' }} onMouseOver={e => e.currentTarget.style.transform = 'translateX(4px)'} onMouseOut={e => e.currentTarget.style.transform = 'translateX(0)'}>
                <span className="material-symbols-outlined" style={{ fontSize: '1.8rem', color: '#f97316' }}>request_quote</span>
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '1.1rem' }}>Platform Fees</div>
                  <div style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>Configure registration and renewal fees</div>
                </div>
                <span className="material-symbols-outlined" style={{ color: 'var(--border-strong)' }}>arrow_forward</span>
              </Link>

              <Link to="/admin/payment-settings" className="card" style={{ padding: '16px 20px', display: 'flex', alignItems: 'center', gap: 16, textDecoration: 'none', transition: 'all 0.2s', borderLeft: '4px solid #0ea5e9' }} onMouseOver={e => e.currentTarget.style.transform = 'translateX(4px)'} onMouseOut={e => e.currentTarget.style.transform = 'translateX(0)'}>
                <span className="material-symbols-outlined" style={{ fontSize: '1.8rem', color: '#0ea5e9' }}>payments</span>
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '1.1rem' }}>Payment Methods</div>
                  <div style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>Manage MoMo and Bank connections</div>
                </div>
                <span className="material-symbols-outlined" style={{ color: 'var(--border-strong)' }}>arrow_forward</span>
              </Link>

              <Link to="/admin/payments" className="card" style={{ padding: '16px 20px', display: 'flex', alignItems: 'center', gap: 16, textDecoration: 'none', transition: 'all 0.2s', borderLeft: '4px solid #10b981' }} onMouseOver={e => e.currentTarget.style.transform = 'translateX(4px)'} onMouseOut={e => e.currentTarget.style.transform = 'translateX(0)'}>
                <span className="material-symbols-outlined" style={{ fontSize: '1.8rem', color: '#10b981' }}>account_balance_wallet</span>
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '1.1rem' }}>Financial Control Center</div>
                  <div style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>View all payments, dues and revenue</div>
                </div>
                <span className="material-symbols-outlined" style={{ color: 'var(--border-strong)' }}>arrow_forward</span>
              </Link>

            </div>
          </div>
        </div>

      </div>
    </AppLayout>
  )
}
