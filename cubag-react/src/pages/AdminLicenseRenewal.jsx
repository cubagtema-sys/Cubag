import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout.jsx'

const API = import.meta.env.VITE_API_URL

// Duration presets — calculated from the approval date
const DURATION_PRESETS = [
  { label: '1 Month',  months: 1  },
  { label: '3 Months', months: 3  },
  { label: '6 Months', months: 6  },
  { label: '1 Year',   months: 12 },
]

function addMonths(dateStr, months) {
  const d = new Date(dateStr)
  d.setMonth(d.getMonth() + months)
  return d.toISOString().split('T')[0]   // 'YYYY-MM-DD'
}

function formatDate(str) {
  if (!str) return '—'
  return new Date(str).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })
}

export default function AdminLicenseRenewal() {
  const [members, setMembers]         = useState([])
  const [message, setMessage]         = useState({ text: '', ok: true })
  const [activeTab, setActiveTab]     = useState('pending')
  const [selectedPayment, setSelectedPayment] = useState(null)

  // Per-member expiry editor state: { [id]: { preset: null|months, customDate: '', saving: false } }
  const [editors, setEditors] = useState({})

  const token = () => localStorage.getItem('cubag_token')

  const fetchMembers = async () => {
    try {
      const res = await fetch(`${API}/members/admin/all`, {
        headers: { 'Authorization': `Bearer ${token()}` }
      })
      if (res.ok) {
        const data = await res.json()
        setMembers(data)
        // Init editors from existing expiry dates
        setEditors(prev => {
          const next = { ...prev }
          data.forEach(m => {
            if (!next[m.id]) {
              next[m.id] = {
                preset: null,
                customDate: m.license_expiry_date ? m.license_expiry_date.split('T')[0] : '',
                saving: false
              }
            }
          })
          return next
        })
      }
    } catch (e) { console.error(e) }
  }

  useEffect(() => { fetchMembers() }, []) // eslint-disable-line

  const setEditor = (id, patch) =>
    setEditors(prev => ({ ...prev, [id]: { ...prev[id], ...patch } }))

  const handleUpdateStatus = async (id, newStatus) => {
    try {
      const res = await fetch(`${API}/members/admin/status/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token()}` },
        body: JSON.stringify({ status: newStatus })
      })
      if (res.ok) {
        setMessage({ text: `Member ${newStatus === 'active' ? 'approved ✓' : 'rejected'}.`, ok: true })
        fetchMembers()
      } else { setMessage({ text: 'Failed to update status.', ok: false }) }
    } catch { setMessage({ text: 'Network error.', ok: false }) }
    setTimeout(() => setMessage({ text: '', ok: true }), 3000)
  }

  // Per-member license history state
  const [histories, setHistories]     = useState({})   // { [memberId]: [] }
  const [showHistory, setShowHistory] = useState({})   // { [memberId]: bool }

  const toggleHistory = async (memberId) => {
    const nowShowing = !showHistory[memberId]
    setShowHistory(prev => ({ ...prev, [memberId]: nowShowing }))
    if (nowShowing && !histories[memberId]) {
      try {
        const res = await fetch(`${API}/members/admin/license-history/${memberId}`, {
          headers: { 'Authorization': `Bearer ${token()}` }
        })
        if (res.ok) {
          const data = await res.json()
          setHistories(prev => ({ ...prev, [memberId]: data }))
        }
      } catch {}
    }
  }

  const handleSaveExpiry = async (member) => {
    const ed = editors[member.id]
    if (!ed) return

    let expiryDate   = ''
    let durationLabel = ''
    const today = new Date().toISOString().split('T')[0]

    if (ed.preset) {
      expiryDate    = addMonths(today, ed.preset)
      durationLabel = DURATION_PRESETS.find(p => p.months === ed.preset)?.label || ''
    } else if (ed.customDate) {
      expiryDate    = ed.customDate
      durationLabel = 'Custom'
    }

    if (!expiryDate) return
    setEditor(member.id, { saving: true })

    try {
      const res = await fetch(`${API}/members/admin/set-expiry/${member.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token()}` },
        body: JSON.stringify({
          license_expiry_date: expiryDate,
          duration_label:      durationLabel,
          start_date:          today
        })
      })
      if (res.ok) {
        setMessage({ text: `✓ ${durationLabel || 'Custom'} period set for ${member.name}. Old license archived.`, ok: true })
        // Clear cached history so it reloads fresh
        setHistories(prev => ({ ...prev, [member.id]: undefined }))
        fetchMembers()
      } else { setMessage({ text: 'Failed to save expiry date.', ok: false }) }
    } catch { setMessage({ text: 'Network error.', ok: false }) }

    setEditor(member.id, { saving: false })
    setTimeout(() => setMessage({ text: '', ok: true }), 5000)
  }


  const pendingList = members.filter(m => m.status === 'pending')
  const activeList  = members.filter(m => m.status === 'active' || m.status === 'suspended')

  return (
    <AppLayout title="License Queue">

      {/* Payment Verification Sheet */}
      {selectedPayment && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.55)', zIndex: 9999, display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }}>
          <div style={{ background: 'var(--bg-surface)', borderRadius: '16px 16px 0 0', padding: '24px 20px 32px', width: '100%', maxWidth: 520, boxShadow: '0 -8px 32px rgba(0,0,0,0.2)', animation: 'fadeInUp 0.2s ease' }}>
            <div style={{ width: 36, height: 4, background: 'var(--border-default)', borderRadius: 2, margin: '0 auto 16px' }} />
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
              <h3 style={{ margin: 0, fontSize: '1.1rem' }}>Payment Verification</h3>
              <button onClick={() => setSelectedPayment(null)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)' }}>
                <span className="material-symbols-outlined">close</span>
              </button>
            </div>
            {[['Applicant', selectedPayment.name], ['Reference', selectedPayment.payment_ref || 'PENDING'], ['Company', selectedPayment.company || '—']].map(([label, val]) => (
              <div key={label} style={{ padding: '10px 12px', background: 'var(--bg-elevated)', borderRadius: 10, border: '1px solid var(--border-subtle)', marginBottom: 10 }}>
                <div style={{ fontSize: '0.65rem', color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase', marginBottom: 2 }}>{label}</div>
                <div style={{ fontWeight: 800, fontSize: '0.95rem' }}>{val}</div>
              </div>
            ))}
            <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
              <button className="btn btn-success" style={{ flex: 2, height: 48 }}
                onClick={() => { handleUpdateStatus(selectedPayment.id, 'active'); setSelectedPayment(null) }}>
                Verify &amp; Approve
              </button>
              <button className="btn btn-danger" style={{ flex: 1, height: 48 }}
                onClick={() => { handleUpdateStatus(selectedPayment.id, 'suspended'); setSelectedPayment(null) }}>
                Reject
              </button>
            </div>
          </div>
        </div>
      )}

      <div style={{ maxWidth: 1000, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>
        {/* Page Title removed as it is now in the header */}

        {/* Tabs */}
        <div style={{ display: 'flex', gap: 6, background: 'var(--bg-surface)', borderRadius: 10, padding: 3 }}>
          {[
            { id: 'pending', label: `Pending (${pendingList.length})`, icon: 'pending_actions' },
            { id: 'active',  label: `Active (${activeList.length})`,   icon: 'verified' }
          ].map(t => (
            <button key={t.id} onClick={() => setActiveTab(t.id)} style={{
              flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
              padding: '8px 12px', borderRadius: 8, border: 'none', cursor: 'pointer',
              fontWeight: 700, fontSize: '0.8rem',
              background: activeTab === t.id ? 'var(--brand-primary)' : 'transparent',
              color:      activeTab === t.id ? '#fff' : 'var(--text-secondary)',
              transition: 'all 0.2s'
            }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>{t.icon}</span>
              {t.label}
            </button>
          ))}
        </div>

        {/* Toast */}
        {message.text && (
          <div style={{ padding: '10px 14px', borderRadius: 8, background: message.ok ? '#10b981' : '#ef4444', color: '#fff', fontSize: '0.85rem', fontWeight: 600 }}>
            {message.text}
          </div>
        )}

        {/* ── Pending Tab ── */}
        {activeTab === 'pending' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {pendingList.length === 0 ? (
              <div className="card" style={{ textAlign: 'center', padding: 40 }}>
                <span className="material-symbols-outlined" style={{ fontSize: '2rem', opacity: 0.3, display: 'block', marginBottom: 8 }}>pending_actions</span>
                <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>No pending renewals.</p>
              </div>
            ) : pendingList.map((m) => (
              <div key={m.id} className="feed-card" style={{ padding: '14px 16px', borderRadius: 12, display: 'flex', flexDirection: 'column', gap: 12 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                  <div>
                    <div style={{ fontWeight: 800, fontSize: '1rem', color: 'var(--text-primary)' }}>{m.name}</div>
                    <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{m.company || 'Independent'} · {m.port_of_operation || '—'}</div>
                  </div>
                  <span className="badge badge-warning" style={{ fontSize: '0.6rem', flexShrink: 0 }}>PENDING</span>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                  <div style={{ padding: '6px 10px', background: 'var(--bg-elevated)', borderRadius: 8, border: '1px solid var(--border-subtle)' }}>
                    <div style={{ fontSize: '0.6rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700 }}>License</div>
                    <div style={{ fontSize: '0.8rem', fontWeight: 600 }}>{m.license_number || 'TBD'}</div>
                  </div>
                  <div style={{ padding: '6px 10px', background: 'var(--bg-elevated)', borderRadius: 8, border: '1px solid var(--border-subtle)' }}>
                    <div style={{ fontSize: '0.6rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700 }}>Ref</div>
                    <div style={{ fontSize: '0.8rem', fontWeight: 600, fontFamily: 'monospace' }}>{m.payment_ref || 'N/A'}</div>
                  </div>
                </div>
                <div style={{ display: 'flex', gap: 8 }}>
                  <button className="btn btn-outline btn-sm" style={{ flex: 1, height: 36, fontSize: '0.75rem' }} onClick={() => setSelectedPayment(m)}>Verify Pay</button>
                  <button className="btn btn-primary btn-sm" style={{ flex: 1, height: 36, fontSize: '0.75rem' }} onClick={() => handleUpdateStatus(m.id, 'active')}>Approve</button>
                </div>
              </div>
            ))}
          </div>
        )}

        {/* ── Active Tab ── */}
        {activeTab === 'active' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {activeList.length === 0 ? (
              <div className="card" style={{ textAlign: 'center', padding: 40 }}>
                <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>No active members yet.</p>
              </div>
            ) : activeList.map((m) => {
              const ed          = editors[m.id] || { preset: null, customDate: '', saving: false }
              const currentExp  = m.license_expiry_date ? m.license_expiry_date.split('T')[0] : null
              const isExpired   = currentExp && new Date(currentExp) < new Date()
              const isSoon      = currentExp && !isExpired && (new Date(currentExp) - new Date()) < 30 * 86400 * 1000

              // Preview what the expiry would be
              const today = new Date().toISOString().split('T')[0]
              const previewDate = ed.preset
                ? addMonths(today, ed.preset)
                : ed.customDate || null

              return (
                <div key={m.id} className="feed-card" style={{ padding: '16px', borderRadius: 12 }}>
                  {/* Header */}
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 12 }}>
                    <div style={{ minWidth: 0 }}>
                      <div style={{ fontWeight: 800, fontSize: '0.95rem', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{m.name}</div>
                      <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)' }}>{m.license_number || 'No license #'}</div>
                    </div>
                    <div style={{ display: 'flex', gap: 5, flexShrink: 0, flexWrap: 'wrap', justifyContent: 'flex-end' }}>
                      {isExpired && <span className="badge badge-danger"  style={{ fontSize: '0.58rem' }}>EXPIRED</span>}
                      {isSoon    && <span className="badge badge-warning" style={{ fontSize: '0.58rem' }}>EXPIRING SOON</span>}
                      <span className={`badge ${m.status === 'active' ? 'badge-success' : 'badge-danger'}`} style={{ fontSize: '0.58rem' }}>{m.status.toUpperCase()}</span>
                    </div>
                  </div>

                  {/* Current expiry */}
                  <div style={{ padding: '8px 10px', background: 'var(--bg-elevated)', borderRadius: 8, border: '1px solid var(--border-subtle)', marginBottom: 12, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontSize: '0.7rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase' }}>Current Expiry</span>
                    <span style={{ fontSize: '0.85rem', fontWeight: 800, color: isExpired ? '#ef4444' : isSoon ? '#f59e0b' : 'var(--text-primary)' }}>
                      {currentExp ? formatDate(currentExp) : 'Not set'}
                    </span>
                  </div>

                  {/* Duration presets */}
                  <div style={{ marginBottom: 10 }}>
                    <div style={{ fontSize: '0.68rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', marginBottom: 6 }}>
                      Set Duration — starts from today ({formatDate(today)})
                    </div>
                    <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                      {DURATION_PRESETS.map(p => (
                        <button key={p.months} onClick={() => setEditor(m.id, { preset: p.months, customDate: '' })}
                          style={{
                            padding: '6px 14px', borderRadius: 8, fontSize: '0.78rem', fontWeight: 700, cursor: 'pointer',
                            border: ed.preset === p.months ? 'none' : '1px solid var(--border-default)',
                            background: ed.preset === p.months ? 'var(--brand-primary)' : 'var(--bg-elevated)',
                            color:      ed.preset === p.months ? '#fff' : 'var(--text-secondary)',
                            transition: 'all 0.15s'
                          }}
                        >{p.label}</button>
                      ))}
                      <button onClick={() => setEditor(m.id, { preset: null })}
                        style={{
                          padding: '6px 14px', borderRadius: 8, fontSize: '0.78rem', fontWeight: 700, cursor: 'pointer',
                          border: ed.preset === null ? 'none' : '1px solid var(--border-default)',
                          background: ed.preset === null ? 'var(--brand-primary)' : 'var(--bg-elevated)',
                          color:      ed.preset === null ? '#fff' : 'var(--text-secondary)',
                          transition: 'all 0.15s'
                        }}
                      >Custom</button>
                    </div>
                  </div>

                  {/* Custom date picker (shown only when Custom selected) */}
                  {ed.preset === null && (
                    <div style={{ marginBottom: 10 }}>
                      <label style={{ fontSize: '0.68rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', display: 'block', marginBottom: 4 }}>Custom Expiry Date</label>
                      <input type="date" value={ed.customDate}
                        onChange={e => setEditor(m.id, { customDate: e.target.value })}
                        style={{ width: '100%', maxWidth: '220px', minHeight: '44px', padding: '8px 12px', borderRadius: 8, border: '1.5px solid var(--border-default)', background: 'var(--bg-elevated)', color: 'var(--text-primary)', fontSize: '0.85rem', boxSizing: 'border-box' }}
                      />
                    </div>
                  )}

                  {/* Preview + Save */}
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 4 }}>
                    <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                      {previewDate
                        ? <><strong style={{ color: '#10b981' }}>→ Expires:</strong> {formatDate(previewDate)}</>
                        : 'Select a duration or enter a custom date'
                      }
                    </div>
                    <button
                      onClick={() => handleSaveExpiry(m)}
                      disabled={ed.saving || !previewDate}
                      style={{ padding: '8px 20px', borderRadius: 8, border: 'none', background: previewDate ? 'var(--brand-primary)' : 'var(--bg-surface)', color: previewDate ? '#fff' : 'var(--text-muted)', fontWeight: 800, fontSize: '0.82rem', cursor: previewDate ? 'pointer' : 'default', flexShrink: 0, transition: 'all 0.15s' }}
                    >
                      {ed.saving ? 'Saving…' : 'Apply & Save'}
                    </button>
                  </div>

                  {/* License History toggle */}
                  <button
                    onClick={() => toggleHistory(m.id)}
                    style={{ marginTop: 10, width: '100%', padding: '7px', borderRadius: 8, border: '1px solid var(--border-subtle)', background: 'transparent', color: 'var(--text-muted)', fontSize: '0.75rem', fontWeight: 700, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 5 }}
                  >
                    <span className="material-symbols-outlined" style={{ fontSize: '0.95rem' }}>
                      {showHistory[m.id] ? 'expand_less' : 'history'}
                    </span>
                    {showHistory[m.id] ? 'Hide' : 'View'} License History
                  </button>

                  {/* License History Panel */}
                  {showHistory[m.id] && (
                    <div style={{ marginTop: 6, borderTop: '1px solid var(--border-subtle)', paddingTop: 10 }}>
                      {!histories[m.id] || histories[m.id].length === 0 ? (
                        <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textAlign: 'center', margin: '8px 0' }}>No history yet — history is recorded from the first renewal.</p>
                      ) : (
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                          {histories[m.id].map((h, idx) => {
                            const expired = h.expiry_date && new Date(h.expiry_date) < new Date()
                            const isCurrent = idx === 0
                            return (
                              <div key={h.id} style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
                                {/* Timeline dot */}
                                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', paddingTop: 2 }}>
                                  <div style={{ width: 10, height: 10, borderRadius: '50%', background: isCurrent ? '#10b981' : expired ? '#ef4444' : 'var(--text-muted)', flexShrink: 0 }} />
                                  {idx < histories[m.id].length - 1 && <div style={{ width: 1, flex: 1, background: 'var(--border-subtle)', minHeight: 16, marginTop: 3 }} />}
                                </div>
                                <div style={{ flex: 1, padding: '6px 10px', background: 'var(--bg-elevated)', borderRadius: 8, border: `1px solid ${isCurrent ? 'rgba(16,185,129,0.3)' : 'var(--border-subtle)'}` }}>
                                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 2 }}>
                                    <span style={{ fontSize: '0.68rem', fontWeight: 800, color: isCurrent ? '#10b981' : 'var(--text-muted)', textTransform: 'uppercase' }}>
                                      {isCurrent ? 'Current' : 'Archived'} · {h.duration_label || '—'}
                                    </span>
                                    <span style={{ fontSize: '0.6rem', color: 'var(--text-muted)' }}>
                                      {h.archived_at ? new Date(h.archived_at).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' }) : ''}
                                    </span>
                                  </div>
                                  <div style={{ fontSize: '0.78rem', fontWeight: 700, color: 'var(--text-primary)', fontFamily: 'monospace' }}>
                                    {h.license_number || '—'}
                                  </div>
                                  <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)', marginTop: 2 }}>
                                    {formatDate(h.start_date)} → <span style={{ color: expired && !isCurrent ? '#ef4444' : 'var(--text-secondary)', fontWeight: 700 }}>{formatDate(h.expiry_date)}</span>
                                  </div>
                                </div>
                              </div>
                            )
                          })}
                        </div>
                      )}
                    </div>
                  )}

                </div>
              )
            })}
          </div>
        )}

      </div>
    </AppLayout>
  )
}
