import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'
import CustomSelect from '../components/CustomSelect'
import ConfirmModal from '../components/ConfirmModal'

const API_URL = import.meta.env.VITE_API_URL

export default function AdminPayments() {
  const [data, setData] = useState({ transactions: [], kpis: { revenue: 0, pending: 0, failed: 0 } })
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState('')
  const [filterStatus, setFilterStatus] = useState('all')
  const [filterType, setFilterType] = useState('all')
  const [actionLoading, setActionLoading] = useState(null)
  const [selectedTx, setSelectedTx] = useState(null)
  const [pendingPaid, setPendingPaid] = useState(null)       // { txId }
  const [pendingLicense, setPendingLicense] = useState(null) // { txId, memberId }
  const [toast, setToast] = useState(null)

  const showToast = (msg, type = 'success') => {
    setToast({ msg, type })
    setTimeout(() => setToast(null), 3000)
  }

  const fetchPayments = async () => {
    try {
      setLoading(true)
      const res = await fetch(`${API_URL}/payments/admin/all`, {
        headers: { 'Authorization': `Bearer ${localStorage.getItem('cubag_token')}` }
      })
      if (res.ok) setData(await res.json())
    } catch (e) {
      console.error(e)
    } finally {
      setLoading(false)
    }
  }

  const markAsPaid = async (txId) => {
    setActionLoading(txId)
    try {
      const res = await fetch(`${API_URL}/payments/admin/mark-paid/${txId}`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${localStorage.getItem('cubag_token')}` }
      })
      if (res.ok) { await fetchPayments(); showToast('Payment marked as paid.') }
      else showToast('Failed to update payment status.', 'error')
    } catch { showToast('Network error.', 'error') }
    finally { setActionLoading(null) }
  }

  const approveLicense = async (txId, memberId) => {
    setActionLoading(txId)
    try {
      const res = await fetch(`${API_URL}/payments/admin/approve-license/${txId}`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${localStorage.getItem('cubag_token')}` }
      })
      if (res.ok) { await fetchPayments(); showToast('License approved successfully!') }
      else showToast('Failed to approve license.', 'error')
    } catch { showToast('Network error.', 'error') }
    finally { setActionLoading(null) }
  }

  const exportCSV = () => {
    const rows = [['TX ID', 'Member', 'Description', 'Amount (GHS)', 'Status', 'Date']]
    filtered.forEach(tx => rows.push([
      tx.tx_id, tx.member_name, tx.description,
      parseFloat(tx.amount).toFixed(2), tx.status,
      new Date(tx.date).toLocaleDateString()
    ]))
    const csv = rows.map(r => r.map(c => `"${c}"`).join(',')).join('\n')
    const blob = new Blob([csv], { type: 'text/csv' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a'); a.href = url
    a.download = `cubag_payments_${new Date().toISOString().slice(0,10)}.csv`
    a.click(); URL.revokeObjectURL(url)
  }

  useEffect(() => {
    fetchPayments()
  }, [])

  const getPaymentType = (desc) => {
    const d = (desc || '').toLowerCase()
    if (d.includes('license') || d.includes('renewal')) return 'license'
    if (d.includes('dues') || d.includes('association')) return 'dues'
    if (d.includes('penalty') || d.includes('late')) return 'penalty'
    return 'other'
  }

  const filtered = data.transactions.filter(tx => {
    const q = searchTerm.toLowerCase()
    const matchSearch = (tx.member_name || '').toLowerCase().includes(q) || 
                        (tx.description || '').toLowerCase().includes(q) ||
                        (tx.tx_id || '').toString().includes(q)
    const matchStatus = filterStatus === 'all' || tx.status === filterStatus
    const matchType = filterType === 'all' || getPaymentType(tx.description) === filterType
    return matchSearch && matchStatus && matchType
  })

  const STATUS_OPTIONS = [
    { value: 'all', label: 'All Statuses', icon: 'filter_list' },
    { value: 'paid', label: 'Paid', icon: 'check_circle' },
    { value: 'pending', label: 'Pending', icon: 'pending_actions' },
    { value: 'overdue', label: 'Overdue', icon: 'error' }
  ]

  const TYPE_OPTIONS = [
    { value: 'all', label: 'All Payments', icon: 'payments' },
    { value: 'dues', label: 'Association Dues', icon: 'group' },
    { value: 'license', label: 'License Renewal', icon: 'badge' },
    { value: 'penalty', label: 'Late Penalty Fees', icon: 'gavel' }
  ]

  return (
    <AppLayout title="Financial Control Center">
      <div style={{ maxWidth: 1200, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 24 }}>
        
        {/* Header Section */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 16 }}>
          <div>
            <h2 style={{ margin: 0, fontSize: '1.6rem', color: 'var(--text-primary)', fontWeight: 800 }}>Payments & Financials</h2>
            <p style={{ margin: '4px 0 0', color: 'var(--text-secondary)', fontSize: '0.9rem' }}>Unified management of dues, licenses, and penalty revenue streams.</p>
          </div>
          <div style={{ display: 'flex', gap: 12 }}>
            <button className="btn btn-outline" style={{ gap: 8 }} onClick={fetchPayments}>
              <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>refresh</span>
              Refresh
            </button>
            <button className="btn btn-primary" style={{ gap: 8 }} onClick={exportCSV}>
              <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>download</span>
              Export CSV
            </button>
          </div>
        </div>

        {/* ── Details Modal ── */}
        {selectedTx && (
          <div onClick={() => setSelectedTx(null)} style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.55)', zIndex: 9999, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 20 }}>
            <div onClick={e => e.stopPropagation()} style={{ background: 'var(--bg-surface)', border: '1px solid var(--border-subtle)', borderRadius: 20, padding: 32, maxWidth: 480, width: '100%', boxShadow: '0 20px 60px rgba(0,0,0,0.3)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
                <h3 style={{ margin: 0, fontWeight: 800, color: 'var(--text-primary)' }}>Transaction Details</h3>
                <button onClick={() => setSelectedTx(null)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)' }}>
                  <span className="material-symbols-outlined">close</span>
                </button>
              </div>
              {[
                { label: 'TX ID',        value: `#${selectedTx.tx_id}` },
                { label: 'Member',       value: selectedTx.member_name },
                { label: 'Description', value: selectedTx.description },
                { label: 'Amount',       value: `GHS ${parseFloat(selectedTx.amount).toFixed(2)}`, highlight: true },
                { label: 'Status',       value: selectedTx.status.toUpperCase() },
                { label: 'Date',         value: new Date(selectedTx.date).toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric', hour: '2-digit', minute: '2-digit' }) },
              ].map(row => (
                <div key={row.label} style={{ display: 'flex', justifyContent: 'space-between', padding: '12px 0', borderBottom: '1px solid var(--border-subtle)' }}>
                  <span style={{ color: 'var(--text-muted)', fontWeight: 500, fontSize: '0.88rem' }}>{row.label}</span>
                  <span style={{ fontWeight: row.highlight ? 800 : 600, color: row.highlight ? 'var(--brand-primary)' : 'var(--text-primary)', fontSize: row.highlight ? '1.05rem' : '0.9rem' }}>{row.value}</span>
                </div>
              ))}
              <button onClick={() => setSelectedTx(null)} className="btn btn-primary" style={{ marginTop: 24, width: '100%', justifyContent: 'center' }}>Close</button>
            </div>
          </div>
        )}

        {/* Financial KPI Cards */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: 20 }}>
          <div style={{ background: 'var(--bg-surface)', border: '1px solid var(--border-subtle)', borderRadius: 24, padding: 24, boxShadow: '0 10px 25px -5px rgba(0,0,0,0.05)' }}>
             <div style={{ color: 'var(--text-muted)', fontSize: '0.75rem', fontWeight: 800, textTransform: 'uppercase', marginBottom: 12, letterSpacing: '0.05em' }}>Total Net Revenue</div>
             <div style={{ fontSize: '2.4rem', fontWeight: 900, color: '#10b981', fontFamily: 'monospace' }}>
               <small style={{ fontSize: '1rem', color: 'var(--text-muted)' }}>GHS</small> {parseFloat(data.kpis.revenue || 0).toLocaleString()}
             </div>
             <div style={{ marginTop: 12, height: 4, background: '#10b98122', borderRadius: 2 }}>
               <div style={{ width: '75%', height: '100%', background: '#10b981', borderRadius: 2 }} />
             </div>
          </div>

          <div style={{ background: 'var(--bg-surface)', border: '1px solid var(--border-subtle)', borderRadius: 24, padding: 24, boxShadow: '0 10px 25px -5px rgba(0,0,0,0.05)' }}>
             <div style={{ color: 'var(--text-muted)', fontSize: '0.75rem', fontWeight: 800, textTransform: 'uppercase', marginBottom: 12, letterSpacing: '0.05em' }}>Pending Invoices</div>
             <div style={{ fontSize: '2.4rem', fontWeight: 900, color: '#f59e0b', fontFamily: 'monospace' }}>
               <small style={{ fontSize: '1rem', color: 'var(--text-muted)' }}>GHS</small> {parseFloat(data.kpis.pending || 0).toLocaleString()}
             </div>
             <div style={{ marginTop: 12, display: 'flex', gap: 4 }}>
               <span className="material-symbols-outlined" style={{ color: '#f59e0b', fontSize: '1.2rem' }}>hourglass_empty</span>
               <span style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>Awaiting verification</span>
             </div>
          </div>

          <div style={{ background: 'var(--bg-surface)', border: '1px solid var(--border-subtle)', borderRadius: 24, padding: 24, boxShadow: '0 10px 25px -5px rgba(0,0,0,0.05)' }}>
             <div style={{ color: 'var(--text-muted)', fontSize: '0.75rem', fontWeight: 800, textTransform: 'uppercase', marginBottom: 12, letterSpacing: '0.05em' }}>System Flags</div>
             <div style={{ fontSize: '2.4rem', fontWeight: 900, color: '#ef4444', fontFamily: 'monospace' }}>
               {data.kpis.failed} <small style={{ fontSize: '1rem', color: 'var(--text-muted)' }}>Overdue</small>
             </div>
             <div style={{ marginTop: 12, fontSize: '0.85rem', color: 'var(--text-secondary)' }}>Immediate action required</div>
          </div>
        </div>

        {/* Search & Filter Toolbar */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr auto auto', gap: 16, alignItems: 'center', flexWrap: 'wrap' }}>
          <div style={{ position: 'relative' }}>
            <span className="material-symbols-outlined" style={{ position: 'absolute', left: 16, top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }}>search</span>
            <input 
              type="text" 
              placeholder="Filter by Name, TX ID or Description..."
              value={searchTerm}
              onChange={e => setSearchTerm(e.target.value)}
              style={{ width: '100%', padding: '16px 16px 16px 48px', borderRadius: 16, border: '1.5px solid var(--border-default)', background: 'var(--bg-surface)', color: 'var(--text-primary)', outline: 'none', fontSize: '0.95rem' }}
            />
          </div>
          <div style={{ width: 220 }}>
            <CustomSelect
              value={filterType}
              onChange={setFilterType}
              options={TYPE_OPTIONS}
              icon="category"
            />
          </div>
          <div style={{ width: 200 }}>
            <CustomSelect
              value={filterStatus}
              onChange={setFilterStatus}
              options={STATUS_OPTIONS}
              icon="payments"
            />
          </div>
        </div>

        {/* Main Financial Table */}
        <div className="feed-card" style={{ padding: 0, overflow: 'hidden', border: '1px solid var(--border-subtle)', borderRadius: 24 }}>
          {loading ? (
            <div style={{ padding: 100, textAlign: 'center' }}>
              <div className="spinner" style={{ margin: '0 auto 16px' }} />
              <p style={{ color: 'var(--text-secondary)' }}>Synchronizing financial data...</p>
            </div>
          ) : filtered.length === 0 ? (
            <div style={{ padding: 100, textAlign: 'center' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '4rem', color: 'var(--border-default)', marginBottom: 16 }}>no_accounts</span>
              <p style={{ color: 'var(--text-muted)', fontSize: '1.1rem' }}>No financial records found for current filters.</p>
            </div>
          ) : (
            <div style={{ overflowX: 'auto' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
                <thead>
                  <tr style={{ background: 'var(--bg-base)', borderBottom: '1px solid var(--border-subtle)' }}>
                    <th style={{ padding: '20px 24px', fontSize: '0.75rem', fontWeight: 800, color: 'var(--text-muted)', textTransform: 'uppercase' }}>Recipient & Type</th>
                    <th style={{ padding: '20px 24px', fontSize: '0.75rem', fontWeight: 800, color: 'var(--text-muted)', textTransform: 'uppercase' }}>Amount</th>
                    <th style={{ padding: '20px 24px', fontSize: '0.75rem', fontWeight: 800, color: 'var(--text-muted)', textTransform: 'uppercase' }}>TX Details</th>
                    <th style={{ padding: '20px 24px', fontSize: '0.75rem', fontWeight: 800, color: 'var(--text-muted)', textTransform: 'uppercase' }}>Status</th>
                    <th style={{ padding: '20px 24px', fontSize: '0.75rem', fontWeight: 800, color: 'var(--text-muted)', textTransform: 'uppercase', textAlign: 'right' }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((tx, i) => {
                    const type = getPaymentType(tx.description)
                    return (
                      <tr key={tx.tx_id} style={{ borderBottom: i < filtered.length - 1 ? '1px solid var(--border-subtle)' : 'none', transition: 'all 0.2s' }}
                        onMouseEnter={e => e.currentTarget.style.background = 'rgba(255,255,255,0.02)'}
                        onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
                      >
                        <td style={{ padding: '18px 24px' }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
                            <div style={{ width: 40, height: 40, borderRadius: 12, background: type === 'license' ? '#3b82f622' : type === 'dues' ? '#10b98122' : '#f59e0b22', color: type === 'license' ? '#3b82f6' : type === 'dues' ? '#10b981' : '#f59e0b', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                              <span className="material-symbols-outlined">{type === 'license' ? 'badge' : type === 'dues' ? 'group' : 'payments'}</span>
                            </div>
                            <div>
                              <div style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '0.95rem' }}>{tx.member_name}</div>
                              <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600 }}>{tx.description}</div>
                            </div>
                          </div>
                        </td>
                        <td style={{ padding: '18px 24px' }}>
                          <div style={{ fontWeight: 800, color: 'var(--text-primary)', fontSize: '1.05rem', fontFamily: 'monospace' }}>
                            GHS {parseFloat(tx.amount).toLocaleString()}
                          </div>
                        </td>
                        <td style={{ padding: '18px 24px' }}>
                          <div style={{ color: 'var(--text-secondary)', fontSize: '0.85rem', fontWeight: 500 }}>ID: {tx.tx_id}</div>
                          <div style={{ color: 'var(--text-muted)', fontSize: '0.75rem' }}>{new Date(tx.date).toLocaleDateString()}</div>
                        </td>
                        <td style={{ padding: '18px 24px' }}>
                          <span style={{ 
                            padding: '6px 12px', borderRadius: 20, fontSize: '0.7rem', fontWeight: 800, textTransform: 'uppercase', 
                            background: tx.status === 'paid' ? '#10b98115' : tx.status === 'pending' ? '#f59e0b15' : '#ef444415',
                            color: tx.status === 'paid' ? '#10b981' : tx.status === 'pending' ? '#f59e0b' : '#ef4444',
                            display: 'inline-flex', alignItems: 'center', gap: 6
                          }}>
                            <span className="material-symbols-outlined" style={{ fontSize: '0.9rem' }}>{tx.status === 'paid' ? 'check_circle' : 'pending'}</span>
                            {tx.status}
                          </span>
                        </td>
                        <td style={{ padding: '18px 24px', textAlign: 'right' }}>
                          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
                            {type === 'license' && tx.status === 'pending' && (
                              <button
                                className="btn btn-sm btn-primary"
                                style={{ padding: '6px 12px', fontSize: '0.75rem', opacity: actionLoading === tx.tx_id ? 0.5 : 1 }}
                                disabled={actionLoading === tx.tx_id}
                                onClick={() => setPendingLicense({ txId: tx.tx_id, memberId: tx.member_id })}
                              >
                                {actionLoading === tx.tx_id ? '...' : 'Approve License'}
                              </button>
                            )}
                            {tx.status === 'pending' && type !== 'license' && (
                              <button
                                className="btn btn-sm btn-outline"
                                style={{ padding: '6px 12px', fontSize: '0.75rem', color: '#10b981', borderColor: '#10b981', opacity: actionLoading === tx.tx_id ? 0.5 : 1 }}
                                disabled={actionLoading === tx.tx_id}
                                onClick={() => setPendingPaid(tx.tx_id)}
                              >
                                {actionLoading === tx.tx_id ? '...' : 'Mark Paid'}
                              </button>
                            )}
                            <button
                              className="btn btn-sm btn-ghost"
                              style={{ padding: '6px 12px', fontSize: '0.75rem' }}
                              onClick={() => setSelectedTx(tx)}
                            >Details</button>
                          </div>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>

      </div>
    </AppLayout>

    <ConfirmModal
      open={!!pendingPaid}
      message="Mark this payment as PAID? This cannot be undone."
      onConfirm={() => markAsPaid(pendingPaid)}
      onCancel={() => setPendingPaid(null)}
    />
    <ConfirmModal
      open={!!pendingLicense}
      message="Approve this license renewal? This will mark the member as licensed."
      onConfirm={() => approveLicense(pendingLicense?.txId, pendingLicense?.memberId)}
      onCancel={() => setPendingLicense(null)}
      danger={false}
    />
    {toast && (
      <div style={{
        position: 'fixed', top: 32, left: '50%', transform: 'translateX(-50%)',
        background: toast.type === 'success' ? '#10b981' : '#ef4444',
        color: '#fff', padding: '12px 24px', borderRadius: 8, fontWeight: 600,
        boxShadow: '0 8px 24px rgba(0,0,0,0.2)', zIndex: 9999,
        display: 'flex', alignItems: 'center', gap: 8
      }}>
        <span className="material-symbols-outlined">{toast.type === 'success' ? 'check_circle' : 'error'}</span>
        {toast.msg}
      </div>
    )}
  )
}

