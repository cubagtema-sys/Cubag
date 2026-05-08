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
    <>
    <AppLayout title="Financials">
      <div style={{ maxWidth: 1200, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>
        
        {/* Header Section */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 10 }}>
          <div>
            <h2 style={{ margin: 0, fontSize: '1.4rem', color: 'var(--text-primary)', fontWeight: 800 }}>Financial Center</h2>
            <p style={{ margin: '2px 0 0', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Management of dues and revenue streams.</p>
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button className="btn btn-outline btn-sm" onClick={fetchPayments} style={{ height: 36, padding: '0 12px' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>refresh</span> Refresh
            </button>
            <button className="btn btn-primary btn-sm" onClick={exportCSV} style={{ height: 36, padding: '0 12px' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>download</span> CSV
            </button>
          </div>
        </div>

        {/* Financial KPI Cards - Mobile Tighter */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: 10 }}>
          {[
            { label: 'Revenue', value: `GH₵ ${parseFloat(data.kpis.revenue || 0).toLocaleString()}`, color: '#10b981' },
            { label: 'Pending', value: `GH₵ ${parseFloat(data.kpis.pending || 0).toLocaleString()}`, color: '#f59e0b' },
            { label: 'Overdue', value: data.kpis.failed, color: '#ef4444' }
          ].map(kpi => (
            <div key={kpi.label} className="feed-card" style={{ padding: '12px 16px', borderRadius: 12, textAlign: 'center' }}>
              <div style={{ color: 'var(--text-muted)', fontSize: '0.65rem', fontWeight: 800, textTransform: 'uppercase', marginBottom: 4 }}>{kpi.label}</div>
              <div style={{ fontSize: '1.25rem', fontWeight: 900, color: kpi.color, fontFamily: 'monospace' }}>{kpi.value}</div>
            </div>
          ))}
        </div>

        {/* Search & Filter Toolbar - Mobile Vertical Stack */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <div style={{ position: 'relative' }}>
            <span className="material-symbols-outlined" style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', fontSize: '1.1rem' }}>search</span>
            <input 
              type="text" 
              placeholder="Search TX ID or Member..."
              value={searchTerm}
              onChange={e => setSearchTerm(e.target.value)}
              style={{ width: '100%', padding: '10px 12px 10px 38px', borderRadius: 10, border: '1.5px solid var(--border-default)', background: 'var(--bg-base)', color: 'var(--text-primary)', outline: 'none', fontSize: '0.9rem' }}
            />
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
            <CustomSelect
              value={filterType}
              onChange={setFilterType}
              options={TYPE_OPTIONS}
              icon="category"
            />
            <CustomSelect
              value={filterStatus}
              onChange={setFilterStatus}
              options={STATUS_OPTIONS}
              icon="payments"
            />
          </div>
        </div>

        {/* Main List - Replaced Table with Cards for Mobile */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {loading ? (
            <div style={{ padding: 40, textAlign: 'center', color: 'var(--text-muted)' }}>Loading financials...</div>
          ) : filtered.length === 0 ? (
            <div className="card" style={{ padding: 40, textAlign: 'center', borderRadius: 12 }}>
              <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>No records found.</p>
            </div>
          ) : (
            filtered.map((tx, i) => {
              const type = getPaymentType(tx.description)
              return (
                <div key={tx.tx_id} className="feed-card" style={{ padding: '12px 16px', borderRadius: 12, display: 'flex', flexDirection: 'column', gap: 10 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                    <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
                      <div style={{ width: 32, height: 32, borderRadius: 8, background: type === 'license' ? '#3b82f622' : type === 'dues' ? '#10b98122' : '#f59e0b22', color: type === 'license' ? '#3b82f6' : type === 'dues' ? '#10b981' : '#f59e0b', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>{type === 'license' ? 'badge' : type === 'dues' ? 'group' : 'payments'}</span>
                      </div>
                      <div>
                        <div style={{ fontWeight: 800, fontSize: '0.9rem', color: 'var(--text-primary)' }}>{tx.member_name}</div>
                        <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontWeight: 600 }}>ID: {tx.tx_id.toString().slice(-6)}</div>
                      </div>
                    </div>
                    <div style={{ textAlign: 'right' }}>
                      <div style={{ fontWeight: 900, color: 'var(--text-primary)', fontSize: '1rem', fontFamily: 'monospace' }}>₵{parseFloat(tx.amount).toLocaleString()}</div>
                      <span style={{ fontSize: '0.6rem', fontWeight: 800, color: tx.status === 'paid' ? '#10b981' : '#f59e0b', textTransform: 'uppercase' }}>{tx.status}</span>
                    </div>
                  </div>

                  <div style={{ display: 'flex', gap: 6 }}>
                    {tx.status === 'pending' && (
                      <button className="btn btn-primary btn-sm" style={{ flex: 1, height: 32, fontSize: '0.7rem', padding: 0 }}
                        onClick={() => type === 'license' ? setPendingLicense({ txId: tx.tx_id }) : setPendingPaid(tx.tx_id)}>
                        Approve
                      </button>
                    )}
                    <button className="btn btn-ghost btn-sm" style={{ flex: 1, height: 32, fontSize: '0.7rem', padding: 0 }} onClick={() => setSelectedTx(tx)}>Details</button>
                  </div>
                </div>
              )
            })
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
  </>
  )
}

