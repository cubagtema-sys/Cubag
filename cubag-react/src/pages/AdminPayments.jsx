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
  const [pendingPaid, setPendingPaid] = useState(null)
  const [toast, setToast] = useState(null)
  const [page, setPage] = useState(1)
  
  const PAGE_SIZE = 10

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
      if (res.ok) {
        await fetchPayments()
        showToast('Payment confirmed successfully.')
        setPendingPaid(null)
      }
      else showToast('Failed to update payment.', 'error')
    } catch { showToast('Network error.', 'error') }
    finally { setActionLoading(null) }
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
    { value: 'all', label: 'All Types', icon: 'category' },
    { value: 'license', label: 'License Renewal', icon: 'fact_check' },
    { value: 'dues', label: 'Association Dues', icon: 'payments' },
    { value: 'penalty', label: 'Penalty/Late', icon: 'gavel' },
    { value: 'other', label: 'Other', icon: 'more_horiz' }
  ]

  return (
    <>
    <AppLayout title="Payments">
      <div style={{ maxWidth: 1000, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>
        
        {/* Header Section */}
        <div>
          <h2 style={{ margin: 0, fontSize: '1.4rem', color: 'var(--text-primary)', fontWeight: 800 }}>Revenue Control</h2>
          <p style={{ margin: '2px 0 0', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Monitor association dues and platform transactions.</p>
        </div>

        {/* Financial KPIs - High Density */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: 12 }}>
          <div className="feed-card" style={{ padding: '16px', borderRadius: 12, background: 'var(--gradient-brand)', color: '#fff', border: 'none' }}>
            <div style={{ fontSize: '0.65rem', fontWeight: 800, textTransform: 'uppercase', opacity: 0.8, marginBottom: 4 }}>Total Revenue</div>
            <div style={{ fontSize: '1.6rem', fontWeight: 900, fontFamily: 'monospace' }}>₵{parseFloat(data.kpis.revenue || 0).toLocaleString()}</div>
          </div>
        </div>

        {/* Toolbar */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <div style={{ position: 'relative' }}>
            <span className="material-symbols-outlined" style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', fontSize: '1.1rem' }}>search</span>
            <input 
              type="text" 
              placeholder="Search by name or ID..."
              value={searchTerm}
              onChange={e => setSearchTerm(e.target.value)}
              style={{ width: '100%', padding: '10px 12px 10px 38px', borderRadius: 10, border: '1.5px solid var(--border-default)', background: 'var(--bg-base)', color: 'var(--text-primary)', outline: 'none', fontSize: '0.9rem' }}
            />
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
            <CustomSelect
              label="Type"
              value={filterType}
              onChange={(val) => { setFilterType(val); setPage(1); }}
              options={TYPE_OPTIONS}
              icon="category"
            />
            <CustomSelect
              label="Status"
              value={filterStatus}
              onChange={(val) => { setFilterStatus(val); setPage(1); }}
              options={STATUS_OPTIONS}
              icon="payments"
            />
          </div>
        </div>

        {/* Transaction Cards */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {loading ? (
            <div style={{ padding: 40, textAlign: 'center', color: 'var(--text-muted)' }}>Syncing transactions...</div>
          ) : filtered.length === 0 ? (
            <div className="card" style={{ padding: 40, textAlign: 'center', borderRadius: 12 }}>
              <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>No payment records found.</p>
            </div>
          ) : (
            filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE).map((tx) => (
              <div key={tx.tx_id} className="feed-card" style={{ padding: '14px 16px', borderRadius: 12, display: 'flex', flexDirection: 'column', gap: 12 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div style={{ display: 'flex', gap: 10, alignItems: 'center', minWidth: 0 }}>
                    <div style={{ width: 36, height: 36, borderRadius: 8, background: 'var(--bg-base)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                      <span className="material-symbols-outlined" style={{ fontSize: '1.2rem', color: 'var(--brand-primary)' }}>account_balance_wallet</span>
                    </div>
                    <div style={{ minWidth: 0 }}>
                      <div style={{ fontWeight: 800, fontSize: '0.9rem', color: 'var(--text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{tx.member_name}</div>
                      <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)' }}>{new Date(tx.date).toLocaleDateString()} &bull; ID: {tx.tx_id.toString().slice(-5)}</div>
                    </div>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <div style={{ fontWeight: 900, color: 'var(--text-primary)', fontSize: '1.1rem' }}>₵{parseFloat(tx.amount).toLocaleString()}</div>
                    <span style={{ fontSize: '0.55rem', fontWeight: 900, color: tx.status === 'paid' ? '#10b981' : '#f59e0b', textTransform: 'uppercase', padding: '2px 6px', background: tx.status === 'paid' ? 'rgba(16,185,129,0.1)' : 'rgba(245,158,11,0.1)', borderRadius: 4 }}>{tx.status}</span>
                  </div>
                </div>

                <div style={{ padding: '8px 10px', background: 'var(--bg-base)', borderRadius: 8, fontSize: '0.75rem', color: 'var(--text-secondary)' }}>
                  {tx.description}
                </div>

                <div style={{ display: 'flex', gap: 8 }}>
                  {tx.status === 'pending' && (
                    <button className="btn btn-primary btn-sm" style={{ flex: 1, height: 36, fontSize: '0.75rem' }}
                      onClick={() => setPendingPaid(tx.tx_id)}>
                      Approve Payment
                    </button>
                  )}
                  <button className="btn btn-outline btn-sm" style={{ flex: 1, height: 36, fontSize: '0.75rem' }} onClick={() => setSelectedTx(tx)}>View Details</button>
                </div>
              </div>
            ))
          )}

          {/* Pagination Controls */}
          {!loading && filtered.length > PAGE_SIZE && (
            <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 8, padding: '12px 0' }}>
              <button
                onClick={() => setPage(p => Math.max(1, p - 1))}
                disabled={page === 1}
                style={{ padding: '6px 14px', borderRadius: 8, border: '1px solid var(--border-subtle)', background: 'var(--bg-card)', color: page === 1 ? 'var(--text-muted)' : 'var(--text-primary)', cursor: page === 1 ? 'default' : 'pointer', fontWeight: 600, opacity: page === 1 ? 0.5 : 1 }}
              >← Prev</button>
              {Array.from({ length: Math.ceil(filtered.length / PAGE_SIZE) }, (_, i) => i + 1).map(n => (
                <button key={n} onClick={() => setPage(n)} style={{ width: 34, height: 34, borderRadius: 8, border: 'none', background: page === n ? 'var(--brand-primary)' : 'var(--bg-card)', color: page === n ? '#fff' : 'var(--text-secondary)', fontWeight: 700, cursor: 'pointer' }}>{n}</button>
              ))}
              <button
                onClick={() => setPage(p => Math.min(Math.ceil(filtered.length / PAGE_SIZE), p + 1))}
                disabled={page === Math.ceil(filtered.length / PAGE_SIZE)}
                style={{ padding: '6px 14px', borderRadius: 8, border: '1px solid var(--border-subtle)', background: 'var(--bg-card)', color: page === Math.ceil(filtered.length / PAGE_SIZE) ? 'var(--text-muted)' : 'var(--text-primary)', cursor: page === Math.ceil(filtered.length / PAGE_SIZE) ? 'default' : 'pointer', fontWeight: 600, opacity: page === Math.ceil(filtered.length / PAGE_SIZE) ? 0.5 : 1 }}
              >Next →</button>
            </div>
          )}
        </div>
      </div>
    </AppLayout>

    <ConfirmModal
      open={!!pendingPaid}
      message="Confirm this payment as RECEIVED? This will update the member's balance."
      onConfirm={() => markAsPaid(pendingPaid)}
      onCancel={() => setPendingPaid(null)}
      danger={false}
    />

    {selectedTx && (
      <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)', zIndex: 9999, display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }} onClick={() => setSelectedTx(null)}>
        <div style={{ background: 'var(--bg-surface)', borderRadius: '20px 20px 0 0', padding: '20px 20px 40px', width: '100%', maxWidth: 500, animation: 'fadeInUp 0.2s' }} onClick={e => e.stopPropagation()}>
          <div style={{ width: 40, height: 4, background: 'var(--border-default)', borderRadius: 2, margin: '0 auto 20px' }} />
          <h3 style={{ margin: '0 0 16px', fontSize: '1.2rem' }}>Transaction Details</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {[
              { label: 'Transaction ID', val: selectedTx.tx_id },
              { label: 'Member Name', val: selectedTx.member_name },
              { label: 'Amount', val: `₵ ${parseFloat(selectedTx.amount).toLocaleString()}` },
              { label: 'Status', val: selectedTx.status.toUpperCase() },
              { label: 'Date', val: new Date(selectedTx.date).toLocaleString() },
              { label: 'Reference', val: selectedTx.payment_ref || 'N/A' },
              { label: 'Description', val: selectedTx.description }
            ].map(row => (
              <div key={row.label} style={{ borderBottom: '1px solid var(--border-subtle)', paddingBottom: 8 }}>
                <div style={{ fontSize: '0.65rem', color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase' }}>{row.label}</div>
                <div style={{ fontSize: '0.95rem', fontWeight: 600, color: 'var(--text-primary)', marginTop: 2 }}>{row.val}</div>
              </div>
            ))}
          </div>
          <button className="btn btn-primary" style={{ width: '100%', marginTop: 24, height: 48 }} onClick={() => setSelectedTx(null)}>Close Window</button>
        </div>
      </div>
    )}

    {toast && (
      <div style={{ position: 'fixed', top: 20, left: '50%', transform: 'translateX(-50%)', background: '#10b981', color: '#fff', padding: '10px 20px', borderRadius: 8, zIndex: 10000, fontWeight: 700 }}>
        {toast.msg}
      </div>
    )}
  </>
  )
}
