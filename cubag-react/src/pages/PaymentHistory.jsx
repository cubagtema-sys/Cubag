import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

const STATUS_COLORS = {
  paid:    { bg: 'rgba(16,185,129,0.1)',  text: '#10b981', icon: 'check_circle' },
  pending: { bg: 'rgba(245,158,11,0.1)',  text: '#f59e0b', icon: 'pending_actions' },
  overdue: { bg: 'rgba(239,68,68,0.1)',   text: '#ef4444', icon: 'cancel' },
}

const PAGE_SIZE = 10

function printReceipt(pay) {
  const win = window.open('', '_blank', 'width=600,height=500')
  win.document.write(`
    <html><head><title>CUBAG Receipt</title>
    <style>
      body { font-family: Arial, sans-serif; padding: 40px; color: #222; }
      .logo { font-size: 1.5rem; font-weight: 900; color: #f08232; margin-bottom: 4px; }
      .sub  { font-size: 0.85rem; color: #888; margin-bottom: 32px; }
      table { width: 100%; border-collapse: collapse; }
      td    { padding: 12px 0; border-bottom: 1px solid #eee; font-size: 0.9rem; }
      td:last-child { text-align: right; font-weight: 700; }
      .amount { font-size: 1.6rem; font-weight: 900; color: #f08232; text-align: center; margin: 24px 0; }
      .badge  { display: inline-block; padding: 4px 12px; border-radius: 20px; font-size: 0.75rem; font-weight: 800; text-transform: uppercase; background: ${STATUS_COLORS[pay.status]?.bg || '#eee'}; color: ${STATUS_COLORS[pay.status]?.text || '#555'}; }
      .footer { text-align: center; color: #aaa; font-size: 0.75rem; margin-top: 40px; }
    </style></head><body>
    <div class="logo">CUBAG</div>
    <div class="sub">Customs Brokers Association of Ghana — Official Receipt</div>
    <div class="amount">GH₵ ${parseFloat(pay.amount).toFixed(2)}</div>
    <table>
      <tr><td>Description</td><td>${pay.description}</td></tr>
      <tr><td>Transaction ID</td><td>${pay.id}</td></tr>
      <tr><td>Date</td><td>${new Date(pay.created_at).toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric', hour: '2-digit', minute: '2-digit' })}</td></tr>
      <tr><td>Status</td><td><span class="badge">${pay.status}</span></td></tr>
    </table>
    <div class="footer">This is an official digital receipt from CUBAG. Keep for your records.</div>
    <script>window.onload=()=>window.print()</script>
    </body></html>
  `)
  win.document.close()
}

export default function PaymentHistory() {
  const [payments, setPayments] = useState([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('all')
  const [page, setPage] = useState(1)

  useEffect(() => {
    fetch(`${import.meta.env.VITE_API_URL}/payments`, {
      headers: { 'Authorization': `Bearer ${localStorage.getItem('cubag_token')}` }
    })
      .then(res => res.json())
      .then(data => setPayments(Array.isArray(data) ? data : []))
      .catch(() => setPayments([]))
      .finally(() => setLoading(false))
  }, [])

  const filtered = filter === 'all' ? payments : payments.filter(p => p.status === filter)
  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE))
  const paginated = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)

  // Reset page when filter changes
  const handleFilter = (f) => { setFilter(f); setPage(1) }

  const totals = {
    paid:    payments.filter(p => p.status === 'paid').reduce((s, p) => s + parseFloat(p.amount || 0), 0),
    pending: payments.filter(p => p.status === 'pending').reduce((s, p) => s + parseFloat(p.amount || 0), 0),
  }

  return (
    <AppLayout title="Payment History">
      <div style={{ maxWidth: 800, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 24 }}>

        {/* Summary KPIs */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16 }}>
          {[
            { label: 'Total Paid', value: `GH₵ ${totals.paid.toFixed(2)}`, color: '#10b981', icon: 'check_circle', bg: 'rgba(16,185,129,0.08)' },
            { label: 'Pending', value: `GH₵ ${totals.pending.toFixed(2)}`, color: '#f59e0b', icon: 'pending_actions', bg: 'rgba(245,158,11,0.08)' },
            { label: 'Total Transactions', value: payments.length, color: 'var(--brand-primary)', icon: 'receipt_long', bg: 'rgba(240,130,50,0.08)' },
          ].map(kpi => (
            <div key={kpi.label} style={{ background: 'var(--bg-card)', border: '1px solid var(--border-subtle)', borderRadius: 'var(--radius-lg)', padding: '18px 20px', display: 'flex', gap: 14, alignItems: 'center' }}>
              <div style={{ width: 44, height: 44, borderRadius: 12, background: kpi.bg, color: kpi.color, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <span className="material-symbols-outlined">{kpi.icon}</span>
              </div>
              <div>
                <div style={{ fontSize: '1.2rem', fontWeight: 800, color: 'var(--text-primary)' }}>{kpi.value}</div>
                <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', fontWeight: 500 }}>{kpi.label}</div>
              </div>
            </div>
          ))}
        </div>

        {/* Filter Tabs */}
        <div style={{ display: 'flex', gap: 8 }}>
          {['all', 'paid', 'pending', 'overdue'].map(f => (
            <button key={f} onClick={() => handleFilter(f)} style={{ padding: '7px 18px', borderRadius: 'var(--radius-pill)', border: 'none', fontWeight: 600, fontSize: '0.85rem', cursor: 'pointer', transition: 'all 0.2s', background: filter === f ? 'var(--brand-primary)' : 'var(--bg-elevated)', color: filter === f ? '#fff' : 'var(--text-secondary)', textTransform: 'capitalize' }}>
              {f === 'all' ? 'All' : f.charAt(0).toUpperCase() + f.slice(1)}
            </button>
          ))}
          <span style={{ marginLeft: 'auto', fontSize: '0.82rem', color: 'var(--text-muted)', alignSelf: 'center' }}>{filtered.length} record{filtered.length !== 1 ? 's' : ''}</span>
        </div>

        {/* Transaction List */}
        <div className="feed-card">
          <div className="card-header">
            <span className="card-title">Transactions</span>
            <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Page {page} of {totalPages}</span>
          </div>
          <div className="card-body" style={{ padding: 0 }}>
            {loading ? (
              <div style={{ padding: '48px', textAlign: 'center' }}>
                <div className="spinner" style={{ margin: '0 auto 12px' }} />
                <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem' }}>Loading transactions...</p>
              </div>
            ) : paginated.length === 0 ? (
              <div style={{ padding: '60px 24px', textAlign: 'center' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '3rem', color: 'var(--border-default)', display: 'block', marginBottom: 12 }}>receipt_long</span>
                <h3 style={{ color: 'var(--text-primary)', marginBottom: 8 }}>No transactions found</h3>
                <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>
                  {filter === 'all' ? 'Your payment history will appear here.' : `No ${filter} payments.`}
                </p>
              </div>
            ) : paginated.map((pay, i) => {
              const s = STATUS_COLORS[pay.status] || STATUS_COLORS.pending
              return (
                <div key={pay.id} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '16px 20px', borderBottom: i === paginated.length - 1 ? 'none' : '1px solid var(--border-subtle)' }}>
                  <div style={{ display: 'flex', gap: 16, alignItems: 'center' }}>
                    <div style={{ width: 44, height: 44, borderRadius: 12, background: s.bg, color: s.text, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                      <span className="material-symbols-outlined">{s.icon}</span>
                    </div>
                    <div>
                      <div style={{ fontWeight: 600, color: 'var(--text-primary)', marginBottom: 3 }}>{pay.description}</div>
                      <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)' }}>
                        {new Date(pay.created_at).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })}
                      </div>
                    </div>
                  </div>
                  <div style={{ textAlign: 'right', display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 6 }}>
                    <div style={{ fontWeight: 800, color: 'var(--text-primary)', fontSize: '1rem' }}>GH₵ {parseFloat(pay.amount).toFixed(2)}</div>
                    <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                      <span style={{ padding: '3px 10px', borderRadius: 20, fontSize: '0.7rem', fontWeight: 800, textTransform: 'uppercase', background: s.bg, color: s.text }}>{pay.status}</span>
                      {pay.status === 'paid' && (
                        <button
                          title="Download Receipt"
                          onClick={() => printReceipt(pay)}
                          style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)', display: 'flex', alignItems: 'center' }}
                        >
                          <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>download</span>
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              )
            })}
          </div>

          {/* Pagination */}
          {totalPages > 1 && (
            <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 8, padding: '16px 20px', borderTop: '1px solid var(--border-subtle)' }}>
              <button
                onClick={() => setPage(p => Math.max(1, p - 1))}
                disabled={page === 1}
                style={{ padding: '6px 14px', borderRadius: 'var(--radius-md)', border: '1px solid var(--border-subtle)', background: 'var(--bg-elevated)', color: page === 1 ? 'var(--text-muted)' : 'var(--text-primary)', cursor: page === 1 ? 'default' : 'pointer', fontWeight: 600 }}
              >← Prev</button>
              {Array.from({ length: totalPages }, (_, i) => i + 1).map(n => (
                <button key={n} onClick={() => setPage(n)} style={{ width: 34, height: 34, borderRadius: 'var(--radius-md)', border: 'none', background: page === n ? 'var(--brand-primary)' : 'var(--bg-elevated)', color: page === n ? '#fff' : 'var(--text-secondary)', fontWeight: 700, cursor: 'pointer' }}>{n}</button>
              ))}
              <button
                onClick={() => setPage(p => Math.min(totalPages, p + 1))}
                disabled={page === totalPages}
                style={{ padding: '6px 14px', borderRadius: 'var(--radius-md)', border: '1px solid var(--border-subtle)', background: 'var(--bg-elevated)', color: page === totalPages ? 'var(--text-muted)' : 'var(--text-primary)', cursor: page === totalPages ? 'default' : 'pointer', fontWeight: 600 }}
              >Next →</button>
            </div>
          )}
        </div>

      </div>
    </AppLayout>
  )
}
