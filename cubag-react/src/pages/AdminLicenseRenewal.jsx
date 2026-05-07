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
    <AppLayout title="License Renewals">
      {selectedPayment && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.5)', zIndex: 9999, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <div className="card animate-fadeInUp" style={{ width: '400px', maxWidth: '90%', position: 'relative' }}>
            <button
              style={{ position: 'absolute', top: 16, right: 16, background: 'transparent', border: 'none', cursor: 'pointer' }}
              onClick={() => setSelectedPayment(null)}
            >
              <span className="material-symbols-outlined">close</span>
            </button>
            <h3 style={{ marginBottom: 16, display: 'flex', alignItems: 'center', gap: 8 }}>
              <span className="material-symbols-outlined" style={{ color: 'var(--brand-primary)' }}>receipt_long</span>
              Payment Info
            </h3>
            <div style={{ padding: 12, background: 'var(--bg-base)', borderRadius: 8, marginBottom: 16 }}>
              <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Member Name</div>
              <div style={{ fontWeight: 600, marginBottom: 12 }}>{selectedPayment.name}</div>
              <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Payment Reference</div>
              <div style={{ fontWeight: 600, fontFamily: 'monospace', fontSize: '1.1rem', color: 'var(--brand-primary)' }}>
                {selectedPayment.payment_ref || 'No payment reference attached'}
              </div>
            </div>
            <div style={{ display: 'flex', gap: 12 }}>
              <button className="btn btn-success" style={{ flex: 1 }} onClick={() => { handleUpdateStatus(selectedPayment.id, 'active'); setSelectedPayment(null); }}>Approve</button>
              <button className="btn btn-danger" style={{ flex: 1 }} onClick={() => { handleUpdateStatus(selectedPayment.id, 'suspended'); setSelectedPayment(null); }}>Reject</button>
            </div>
          </div>
        </div>
      )}

      <div style={{ maxWidth: 1000, margin: '0 auto', padding: '24px 16px', display: 'flex', flexDirection: 'column', gap: 24 }}>
        <div>
          <h2 style={{ fontSize: '1.5rem', marginBottom: 8, display: 'flex', alignItems: 'center', gap: 8 }}>
            <span className="material-symbols-outlined" style={{ color: 'var(--brand-primary)' }}>fact_check</span>
            License Applications
          </h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '0.95rem' }}>Review and process member license renewals and applications.</p>
        </div>

        <div style={{ display: 'flex', gap: '16px', marginBottom: '24px' }}>
          <button
            className={`btn ${activeTab === 'pending' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => setActiveTab('pending')}
          >
            Pending Approvals ({pendingRenewals.length})
          </button>
          <button
            className={`btn ${activeTab === 'history' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => setActiveTab('history')}
          >
            Processed History
          </button>
        </div>

        {message && (
          <div style={{ padding: '12px', background: message.includes('failed') ? 'var(--brand-danger)' : 'var(--brand-success)', color: '#fff', borderRadius: 'var(--radius-md)', marginBottom: '16px', fontSize: '0.9rem', maxWidth: '800px' }}>
            {message}
          </div>
        )}

        {activeTab === 'pending' ? (
          <div className="card">
            <h3 style={{ marginBottom: '16px' }}>Requires Action</h3>
            <div className="responsive-table-wrapper">
              <table className="responsive-table" style={{ width: '100%', textAlign: 'left', borderCollapse: 'collapse' }}>
                <thead>
                  <tr style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Applicant</th>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Company</th>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>License No.</th>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {pendingRenewals.map((m, i) => (
                    <tr key={i} style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                      <td data-label="Applicant" style={{ padding: '12px', fontSize: '0.9rem', fontWeight: 600 }}>
                        {m.name}
                        <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 400 }}>{m.email}</div>
                      </td>
                      <td data-label="Company" style={{ padding: '12px', fontSize: '0.9rem' }}>{m.company || 'N/A'}</td>
                      <td data-label="License No." style={{ padding: '12px', fontSize: '0.9rem', fontFamily: 'monospace' }}>{m.license_number || 'PENDING'}</td>
                      <td data-label="Actions" style={{ padding: '12px', display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
                        <button className="btn btn-sm btn-outline" onClick={() => setSelectedPayment(m)}>
                          <span className="material-symbols-outlined" style={{ fontSize: '1rem', marginRight: 4 }}>visibility</span>
                          View Payment
                        </button>
                        <button className="btn btn-sm btn-success" onClick={() => handleUpdateStatus(m.id, 'active')}>Approve</button>
                        <button className="btn btn-sm btn-danger" onClick={() => handleUpdateStatus(m.id, 'suspended')}>Reject</button>
                      </td>
                    </tr>
                  ))}
                  {pendingRenewals.length === 0 && (
                    <tr>
                      <td colSpan="4" style={{ padding: '24px', textAlign: 'center', color: 'var(--text-muted)' }}>No pending applications.</td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        ) : (
          <div className="card">
            <h3 style={{ marginBottom: '16px' }}>Processed History</h3>
            <div className="responsive-table-wrapper">
              <table className="responsive-table" style={{ width: '100%', textAlign: 'left', borderCollapse: 'collapse' }}>
                <thead>
                  <tr style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Member</th>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Company</th>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Date Processed</th>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Final Status</th>
                  </tr>
                </thead>
                <tbody>
                  {historyRenewals.map((m, i) => (
                    <tr key={i} style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                      <td data-label="Member" style={{ padding: '12px', fontSize: '0.9rem', fontWeight: 600 }}>{m.name}</td>
                      <td data-label="Company" style={{ padding: '12px', fontSize: '0.9rem' }}>{m.company || 'N/A'}</td>
                      <td data-label="Date Processed" style={{ padding: '12px', fontSize: '0.9rem', color: 'var(--text-secondary)' }}>{new Date(m.created_at).toLocaleDateString()}</td>
                      <td data-label="Final Status" style={{ padding: '12px' }}>
                        <span className={`badge ${m.status === 'active' ? 'badge-success' : 'badge-danger'}`}>
                          {m.status.toUpperCase()}
                        </span>
                      </td>
                    </tr>
                  ))}
                  {historyRenewals.length === 0 && (
                    <tr>
                      <td colSpan="4" style={{ padding: '24px', textAlign: 'center', color: 'var(--text-muted)' }}>No history available.</td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </div>
    </AppLayout>
  )
}
