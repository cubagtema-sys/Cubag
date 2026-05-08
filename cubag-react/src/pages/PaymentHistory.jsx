import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'
import CustomSelect from '../components/CustomSelect'

const STATUS_COLORS = {
  paid:    { bg: 'rgba(16,185,129,0.12)',  text: '#10b981', icon: 'check_circle' },
  pending: { bg: 'rgba(245,158,11,0.12)',  text: '#f59e0b', icon: 'pending_actions' },
  overdue: { bg: 'rgba(239,68,68,0.12)',   text: '#ef4444', icon: 'cancel' },
}

const FILTER_OPTIONS = [
  { value: 'all',     label: 'All Transactions',  icon: 'receipt_long' },
  { value: 'paid',    label: 'Paid',               icon: 'check_circle' },
  { value: 'pending', label: 'Pending',            icon: 'pending_actions' },
  { value: 'overdue', label: 'Overdue',            icon: 'cancel' },
]

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

  const handleFilter = (f) => { setFilter(f); setPage(1) }

  const totals = {
    paid:    payments.filter(p => p.status === 'paid').reduce((s, p) => s + parseFloat(p.amount || 0), 0),
    pending: payments.filter(p => p.status === 'pending').reduce((s, p) => s + parseFloat(p.amount || 0), 0),
  }

  const fmt = (n) => n.toLocaleString('en-GH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })

  return (
    <AppLayout title="History">
      <div style={{ maxWidth: 800, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>

        {/* Page Title */}
        <div style={{ marginBottom: 4 }}>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Transaction History</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Review and download receipts for all payments.</p>
        </div>

        {/* ── KPI Cards — stacked vertically so values never truncate ── */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>

          {/* Total Paid */}
          <div style={{ background: 'var(--bg-card)', border: '1.5px solid rgba(16,185,129,0.25)', borderRadius: 14, padding: '16px 16px', display: 'flex', alignItems: 'center', gap: 16, position: 'relative', overflow: 'hidden' }}>
            <div style={{ position: 'absolute', top: -12, right: -12, width: 60, height: 60, background: 'rgba(16,185,129,0.08)', borderRadius: '50%' }} />
            <div style={{ width: 48, height: 48, borderRadius: 12, background: 'rgba(16,185,129,0.12)', color: '#10b981', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1.6rem' }}>check_circle</span>
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: '0.65rem', color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.04em', marginBottom: 2 }}>Total Paid</div>
              <div style={{ fontSize: 'clamp(1.2rem, 5vw, 1.8rem)', fontWeight: 900, color: '#10b981', lineHeight: 1.1, wordBreak: 'break-all' }}>
                GH₵ {fmt(totals.paid)}
              </div>
            </div>
          </div>

          {/* Pending */}
          <div style={{ background: 'var(--bg-card)', border: '1.5px solid rgba(245,158,11,0.25)', borderRadius: 14, padding: '16px 16px', display: 'flex', alignItems: 'center', gap: 16, position: 'relative', overflow: 'hidden' }}>
            <div style={{ position: 'absolute', top: -12, right: -12, width: 60, height: 60, background: 'rgba(245,158,11,0.08)', borderRadius: '50%' }} />
            <div style={{ width: 48, height: 48, borderRadius: 12, background: 'rgba(245,158,11,0.12)', color: '#f59e0b', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1.6rem' }}>pending_actions</span>
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: '0.65rem', color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.04em', marginBottom: 2 }}>Pending</div>
              <div style={{ fontSize: 'clamp(1.2rem, 5vw, 1.8rem)', fontWeight: 900, color: '#f59e0b', lineHeight: 1.1, wordBreak: 'break-all' }}>
                GH₵ {fmt(totals.pending)}
              </div>
            </div>
          </div>

          {/* Total Transactions */}
          <div style={{ background: 'var(--bg-card)', border: '1.5px solid rgba(240,130,50,0.25)', borderRadius: 14, padding: '16px 16px', display: 'flex', alignItems: 'center', gap: 16, position: 'relative', overflow: 'hidden' }}>
            <div style={{ position: 'absolute', top: -12, right: -12, width: 60, height: 60, background: 'rgba(240,130,50,0.08)', borderRadius: '50%' }} />
            <div style={{ width: 48, height: 48, borderRadius: 12, background: 'rgba(240,130,50,0.12)', color: 'var(--brand-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1.6rem' }}>receipt_long</span>
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: '0.65rem', color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.04em', marginBottom: 2 }}>Total Transactions</div>
              <div style={{ fontSize: 'clamp(1.2rem, 5vw, 1.8rem)', fontWeight: 900, color: 'var(--brand-primary)', lineHeight: 1.1 }}>
                {payments.length} <span style={{ fontSize: '0.8rem', fontWeight: 700 }}>txns</span>
              </div>
            </div>
          </div>

        </div>

        {/* ── Filter — using CustomSelect (app dropdown) ── */}
        <CustomSelect
          value={filter}
          onChange={handleFilter}
          options={FILTER_OPTIONS}
          icon="filter_list"
        />

        {/* ── Transaction List ── */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {loading ? (
            <div style={{ padding: '48px', textAlign: 'center' }}>
              <div className="spinner" style={{ margin: '0 auto 12px' }} />
              <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem' }}>Syncing history...</p>
            </div>
          ) : paginated.length === 0 ? (
            <div className="card" style={{ padding: '60px 24px', textAlign: 'center' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '3rem', color: 'var(--border-default)', display: 'block', marginBottom: 12 }}>receipt_long</span>
              <h3 style={{ color: 'var(--text-primary)', marginBottom: 8 }}>No records found</h3>
              <p style={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
                {filter === 'all' ? 'Your payment history is currently empty.' : `No ${filter} payments found.`}
              </p>
            </div>
          ) : paginated.map((pay) => {
            const s = STATUS_COLORS[pay.status] || STATUS_COLORS.pending
            return (
              <div key={pay.id} className="feed-card" style={{ padding: '14px 16px', borderRadius: 12, display: 'flex', alignItems: 'center', gap: 12 }}>
                <div style={{ width: 44, height: 44, borderRadius: 10, background: s.bg, color: s.text, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '1.4rem' }}>{s.icon}</span>
                </div>

                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 8, marginBottom: 4 }}>
                    <h3 style={{ fontSize: '0.88rem', fontWeight: 800, color: 'var(--text-primary)', margin: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', flex: 1 }}>
                      {pay.description}
                    </h3>
                    <div style={{ fontWeight: 900, color: 'var(--text-primary)', fontSize: '0.95rem', whiteSpace: 'nowrap', flexShrink: 0 }}>
                      GH₵ {fmt(parseFloat(pay.amount))}
                    </div>
                  </div>

                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div style={{ fontSize: '0.68rem', color: 'var(--text-muted)', fontWeight: 600 }}>
                      {new Date(pay.created_at).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })}
                      <span style={{ margin: '0 5px', opacity: 0.4 }}>•</span>
                      #{pay.id.toString().slice(-6).toUpperCase()}
                    </div>
                    <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                      <span style={{ fontSize: '0.6rem', fontWeight: 900, textTransform: 'uppercase', color: s.text, padding: '2px 8px', background: s.bg, borderRadius: 4 }}>
                        {pay.status}
                      </span>
                      {pay.status === 'paid' && (
                        <button
                          onClick={() => printReceipt(pay)}
                          style={{ width: 30, height: 30, borderRadius: '50%', background: 'var(--bg-base)', border: '1px solid var(--border-subtle)', cursor: 'pointer', color: 'var(--brand-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
                          title="Download Receipt"
                        >
                          <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>download</span>
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              </div>
            )
          })}
        </div>

        {/* ── Pagination ── */}
        {totalPages > 1 && (
          <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 8, padding: '12px 0' }}>
            <button
              onClick={() => setPage(p => Math.max(1, p - 1))}
              disabled={page === 1}
              style={{ padding: '6px 14px', borderRadius: 8, border: '1px solid var(--border-subtle)', background: 'var(--bg-card)', color: page === 1 ? 'var(--text-muted)' : 'var(--text-primary)', cursor: page === 1 ? 'default' : 'pointer', fontWeight: 600, opacity: page === 1 ? 0.5 : 1 }}
            >← Prev</button>
            {Array.from({ length: totalPages }, (_, i) => i + 1).map(n => (
              <button key={n} onClick={() => setPage(n)} style={{ width: 34, height: 34, borderRadius: 8, border: 'none', background: page === n ? 'var(--brand-primary)' : 'var(--bg-card)', color: page === n ? '#fff' : 'var(--text-secondary)', fontWeight: 700, cursor: 'pointer' }}>{n}</button>
            ))}
            <button
              onClick={() => setPage(p => Math.min(totalPages, p + 1))}
              disabled={page === totalPages}
              style={{ padding: '6px 14px', borderRadius: 8, border: '1px solid var(--border-subtle)', background: 'var(--bg-card)', color: page === totalPages ? 'var(--text-muted)' : 'var(--text-primary)', cursor: page === totalPages ? 'default' : 'pointer', fontWeight: 600, opacity: page === totalPages ? 0.5 : 1 }}
            >Next →</button>
          </div>
        )}

      </div>
    </AppLayout>
  )
}
