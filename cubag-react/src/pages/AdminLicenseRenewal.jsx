import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout.jsx'

export default function AdminLicenseRenewal() {
  const [members, setMembers] = useState([])
  const [message, setMessage] = useState('')
  const [activeTab, setActiveTab] = useState('pending') // 'pending' or 'history'

  const fetchMembers = async () => {
    try {
      const res = await fetch(`${import.meta.env.VITE_API_URL}/members/admin/all`)
      if (res.ok) {
        setMembers(await res.json())
      }
    } catch (e) {
      console.error(e)
    }
  }

  useEffect(() => {
    fetchMembers()
  }, [])

  const handleUpdateStatus = async (id, newStatus) => {
    try {
      const res = await fetch(`${import.meta.env.VITE_API_URL}/members/admin/status/${id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('cubag_token')}`
        },
        body: JSON.stringify({ status: newStatus })
      })

      if (res.ok) {
        setMessage(`Application ${newStatus === 'active' ? 'approved' : 'rejected'}.`)
        fetchMembers()
        setTimeout(() => setMessage(''), 3000)
      } else {
        setMessage('Failed to update status.')
      }
    } catch (e) {
      setMessage('Network error.')
    }
  }

  const [selectedPayment, setSelectedPayment] = useState(null)

  const pendingRenewals = members.filter(m => m.status === 'pending')
  const historyRenewals = members.filter(m => m.status === 'active' || m.status === 'suspended')

  return (
    <AppLayout title="Approvals">
      {/* Payment Info Bottom Sheet */}
      {selectedPayment && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.55)', zIndex: 9999, display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }}>
          <div style={{ background: 'var(--bg-surface)', borderRadius: '16px 16px 0 0', padding: '24px 20px 32px', width: '100%', maxWidth: 520, maxHeight: '80vh', overflowY: 'auto', boxShadow: '0 -8px 32px rgba(0,0,0,0.2)', animation: 'fadeInUp 0.2s ease' }}>
            <div style={{ width: 36, height: 4, background: 'var(--border-default)', borderRadius: 2, margin: '0 auto 16px' }} />

            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
              <h3 style={{ margin: 0, fontSize: '1.1rem' }}>Payment Verification</h3>
              <button onClick={() => setSelectedPayment(null)} style={{ background: 'none', border: 'none', color: 'var(--text-muted)' }}>
                <span className="material-symbols-outlined">close</span>
              </button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 12, marginBottom: 24 }}>
              <div style={{ padding: 12, background: 'var(--bg-elevated)', borderRadius: 10, border: '1px solid var(--border-subtle)' }}>
                <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase', marginBottom: 2 }}>Applicant</div>
                <div style={{ fontWeight: 700, fontSize: '1rem' }}>{selectedPayment.name}</div>
              </div>
              <div style={{ padding: 12, background: 'var(--bg-elevated)', borderRadius: 10, border: '1px solid var(--border-subtle)' }}>
                <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase', marginBottom: 2 }}>Reference</div>
                <div style={{ fontWeight: 800, fontFamily: 'monospace', fontSize: '1.1rem', color: 'var(--brand-primary)' }}>
                  {selectedPayment.payment_ref || 'PENDING'}
                </div>
              </div>
            </div>

            <div style={{ display: 'flex', gap: 10 }}>
              <button className="btn btn-success" style={{ flex: 2, height: 48 }} onClick={() => { handleUpdateStatus(selectedPayment.id, 'active'); setSelectedPayment(null); }}>Verify & Approve</button>
              <button className="btn btn-danger" style={{ flex: 1, height: 48 }} onClick={() => { handleUpdateStatus(selectedPayment.id, 'suspended'); setSelectedPayment(null); }}>Reject</button>
            </div>
          </div>
        </div>
      )}

      <div style={{ maxWidth: 1000, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>

        {/* Page Title for Content */}
        <div style={{ marginBottom: 4 }}>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>License Queue</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Review and process member renewals.</p>
        </div>

        <div style={{ display: 'flex', gap: 6, background: 'var(--bg-surface)', borderRadius: 10, padding: 3 }}>
          {[
            { id: 'pending', label: `Pending (${pendingRenewals.length})`, icon: 'pending_actions' },
            { id: 'history', label: 'History', icon: 'history' }
          ].map(t => (
            <button key={t.id} onClick={() => setActiveTab(t.id)} style={{
              flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
              padding: '8px 12px', borderRadius: 8, border: 'none', cursor: 'pointer',
              fontWeight: 700, fontSize: '0.8rem',
              background: activeTab === t.id ? 'var(--brand-primary)' : 'transparent',
              color: activeTab === t.id ? '#fff' : 'var(--text-secondary)',
              transition: 'all 0.2s'
            }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>{t.icon}</span>
              {t.label.split(' ')[0]}
            </button>
          ))}
        </div>

        {message && (
          <div style={{ padding: 10, borderRadius: 8, background: message.includes('approved') ? '#10b981' : '#ef4444', color: '#fff', fontSize: '0.85rem', fontWeight: 600 }}>
            {message}
          </div>
        )}

        {activeTab === 'pending' ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {pendingRenewals.length === 0 ? (
              <div className="card" style={{ textAlign: 'center', padding: 40 }}>
                <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>No pending renewals.</p>
              </div>
            ) : pendingRenewals.map((m, i) => (
              <div key={i} className="feed-card" style={{ padding: '14px 16px', borderRadius: 12, display: 'flex', flexDirection: 'column', gap: 12 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                  <div>
                    <div style={{ fontWeight: 800, fontSize: '1rem', color: 'var(--text-primary)' }}>{m.name}</div>
                    <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{m.company || 'Independent'}</div>
                  </div>
                  <span className="badge badge-warning" style={{ fontSize: '0.6rem' }}>PENDING</span>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                  <div style={{ padding: '6px 10px', background: 'var(--bg-elevated)', borderRadius: 8, border: '1px solid var(--border-subtle)' }}>
                    <div style={{ fontSize: '0.6rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700 }}>License</div>
                    <div style={{ fontSize: '0.8rem', fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis' }}>{m.license_number || 'TBD'}</div>
                  </div>
                  <div style={{ padding: '6px 10px', background: 'var(--bg-elevated)', borderRadius: 8, border: '1px solid var(--border-subtle)' }}>
                    <div style={{ fontSize: '0.6rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700 }}>Port</div>
                    <div style={{ fontSize: '0.8rem', fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis' }}>{m.port_of_operation || '—'}</div>
                  </div>
                </div>

                <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>
                  <button className="btn btn-outline btn-sm" style={{ flex: 1, height: 36, fontSize: '0.75rem' }} onClick={() => setSelectedPayment(m)}>Verify Pay</button>
                  <button className="btn btn-primary btn-sm" style={{ flex: 1, height: 36, fontSize: '0.75rem' }} onClick={() => handleUpdateStatus(m.id, 'active')}>Approve</button>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {historyRenewals.map((m, i) => (
              <div key={i} className="feed-card" style={{ padding: '12px 16px', borderRadius: 12, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div style={{ minWidth: 0 }}>
                  <div style={{ fontWeight: 700, fontSize: '0.9rem', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{m.name}</div>
                  <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)' }}>{new Date(m.created_at).toLocaleDateString()}</div>
                </div>
                <span className={`badge ${m.status === 'active' ? 'badge-success' : 'badge-danger'}`} style={{ fontSize: '0.6rem' }}>
                  {m.status}
                </span>
              </div>
            ))}
          </div>
        )}
      </div>
    </AppLayout>
  )
}
