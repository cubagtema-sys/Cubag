import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'
import CustomSelect from '../components/CustomSelect'
import { showToast } from '../utils/toast'

const STATUS_STYLES = {
  open:     { bg: 'rgba(240,130,50,0.1)',  color: 'var(--brand-primary)', label: 'Open' },
  pending:  { bg: 'rgba(245,158,11,0.1)',  color: '#f59e0b',              label: 'Pending' },
  resolved: { bg: 'rgba(16,185,129,0.1)',  color: '#10b981',              label: 'Resolved' },
  archived: { bg: 'rgba(148,163,184,0.1)', color: '#94a3b8',              label: 'Archived' },
}

const statusOptions = [
  { value: 'open',     label: 'Open',     icon: 'inbox' },
  { value: 'pending',  label: 'Pending',  icon: 'pending_actions' },
  { value: 'resolved', label: 'Resolved', icon: 'check_circle' },
  { value: 'archived', label: 'Archived', icon: 'archive' },
]

const API_URL = import.meta.env.VITE_API_URL

export default function AdminTickets() {
  const [tickets, setTickets] = useState([])
  const [selectedTicket, setSelectedTicket] = useState(null)
  const [reply, setReply] = useState('')
  const [activeTab, setActiveTab] = useState('inbox')  // 'inbox' | 'archived'

  const fetchTickets = async () => {
    try {
      const res = await fetch(`${API_URL}/tickets/admin/all`, {
        headers: { 'Authorization': `Bearer ${localStorage.getItem('cubag_token')}` }
      })
      if (res.ok) {
        const data = await res.json()
        setTickets(data)
        if (selectedTicket) {
          const fresh = data.find(t => t.id === selectedTicket.id)
          if (fresh) setSelectedTicket(fresh)
        }
      }
    } catch (e) { console.error(e) }
  }

  useEffect(() => { fetchTickets() }, [])  // eslint-disable-line

  const handleUpdateStatus = async (newStatus) => {
    if (!selectedTicket) return
    try {
      const res = await fetch(`${API_URL}/tickets/admin/${selectedTicket.id}/status`, {
        method: 'PUT',
        headers: { 
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('cubag_token')}`
        },
        body: JSON.stringify({ status: newStatus })
      })
      if (res.ok) {
        showToast(`Status → ${newStatus}`, 'success')
        fetchTickets()
        // If archived, go back to list
        if (newStatus === 'archived') setSelectedTicket(null)
      }
    } catch (e) { console.error(e) }
  }

  const handleReply = async (e) => {
    e.preventDefault()
    if (!reply.trim() || !selectedTicket) return
    try {
      const res = await fetch(`${API_URL}/tickets/admin/${selectedTicket.id}/reply`, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('cubag_token')}`
        },
        body: JSON.stringify({ message: reply })
      })
      if (res.ok) {
        showToast('Reply sent!', 'success')
        setReply('')
        fetchTickets()
      }
    } catch (e) { console.error(e) }
  }

  const inbox    = tickets.filter(t => t.status !== 'archived')
  const archived = tickets.filter(t => t.status === 'archived')
  const displayed = activeTab === 'inbox' ? inbox : archived

  return (
    <AppLayout title="Support Tickets">
      <div style={{ maxWidth: 1000, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>

        {/* Page Title removed as it is now in the header */}

        {/* ── Tab bar ── */}
        <div style={{ display: 'flex', gap: 6, background: 'var(--bg-surface)', borderRadius: 10, padding: 3 }}>
          {[
            { id: 'inbox',    label: 'Inbox',    icon: 'inbox',   count: inbox.length },
            { id: 'archived', label: 'Archived', icon: 'archive', count: archived.length }
          ].map(t => (
            <button key={t.id} onClick={() => { setActiveTab(t.id); setSelectedTicket(null) }} style={{
              flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
              padding: '8px 12px', borderRadius: 8, border: 'none', cursor: 'pointer',
              fontWeight: 700, fontSize: '0.8rem',
              background: activeTab === t.id ? 'var(--brand-primary)' : 'transparent',
              color: activeTab === t.id ? '#fff' : 'var(--text-secondary)',
              transition: 'all 0.2s'
            }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>{t.icon}</span>
              {t.label}
              {t.count > 0 && (
                <span style={{ marginLeft: 2, background: activeTab === t.id ? 'rgba(255,255,255,0.25)' : 'var(--bg-elevated)', borderRadius: 20, padding: '1px 7px', fontSize: '0.65rem', fontWeight: 800 }}>
                  {t.count}
                </span>
              )}
            </button>
          ))}
        </div>

        {/* ── Ticket List ── */}
        {!selectedTicket ? (
          <div className="feed-card" style={{ borderRadius: 14, overflow: 'hidden' }}>
            <div className="card-header" style={{ padding: '12px 16px' }}>
              <span className="card-title">{activeTab === 'inbox' ? 'Active Tickets' : 'Archived Tickets'}</span>
            </div>
            <div className="card-body" style={{ padding: 0 }}>
              {displayed.length === 0 ? (
                <div style={{ padding: '48px 24px', textAlign: 'center', color: 'var(--text-muted)' }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '3rem', display: 'block', marginBottom: 12, opacity: 0.3 }}>
                    {activeTab === 'inbox' ? 'inbox' : 'archive'}
                  </span>
                  <p style={{ fontWeight: 600, fontSize: '0.85rem' }}>
                    {activeTab === 'inbox' ? 'No open tickets.' : 'No archived tickets.'}
                  </p>
                </div>
              ) : displayed.map(ticket => {
                const s = STATUS_STYLES[ticket.status] || STATUS_STYLES.open
                return (
                  <div
                    key={ticket.id}
                    onClick={() => setSelectedTicket(ticket)}
                    style={{
                      padding: '14px 16px', borderBottom: '1px solid var(--border-subtle)',
                      cursor: 'pointer', transition: 'background 0.15s',
                      borderLeft: `3px solid ${s.color}`
                    }}
                    onMouseEnter={e => e.currentTarget.style.background = 'var(--bg-base)'}
                    onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
                  >
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                      <span style={{ fontWeight: 800, fontSize: '0.7rem', color: 'var(--text-muted)', fontFamily: 'monospace' }}>
                        #{typeof ticket.id === 'string' ? ticket.id.slice(-6) : ticket.id}
                      </span>
                      <span style={{ padding: '2px 8px', borderRadius: 12, background: s.bg, color: s.color, fontSize: '0.6rem', fontWeight: 800, textTransform: 'uppercase' }}>
                        {s.label}
                      </span>
                    </div>
                    <div style={{ fontWeight: 800, color: 'var(--brand-primary)', fontSize: '0.88rem', marginBottom: 2 }}>{ticket.member_name}</div>
                    <div style={{ fontWeight: 600, color: 'var(--text-primary)', fontSize: '0.85rem', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{ticket.subject}</div>
                    <div style={{ fontSize: '0.68rem', color: 'var(--text-muted)', marginTop: 4 }}>Opened: {ticket.date}</div>
                  </div>
                )
              })}
            </div>
          </div>

        ) : (
          /* ── Reply Panel ── */
          <div className="feed-card" style={{ borderRadius: 14 }}>
            <div className="card-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '10px 16px' }}>
              <button className="btn btn-ghost btn-sm" style={{ padding: '4px 8px', fontSize: '0.75rem' }} onClick={() => setSelectedTicket(null)}>
                <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>arrow_back</span> Back
              </button>
              <div style={{ minWidth: 150 }}>
                <CustomSelect options={statusOptions} value={selectedTicket.status} onChange={handleUpdateStatus} icon="flag" />
              </div>
            </div>
            <div className="card-body" style={{ flexDirection: 'column', gap: 16, padding: '16px' }}>

              {/* Ticket meta */}
              <div style={{ padding: '10px 14px', background: 'var(--bg-base)', borderRadius: 10, fontSize: '0.78rem', color: 'var(--text-muted)', display: 'flex', gap: 16, flexWrap: 'wrap' }}>
                <span><strong style={{ color: 'var(--text-secondary)' }}>From:</strong> {selectedTicket.member_name}</span>
                <span><strong style={{ color: 'var(--text-secondary)' }}>Subject:</strong> {selectedTicket.subject}</span>
                <span><strong style={{ color: 'var(--text-secondary)' }}>Opened:</strong> {selectedTicket.date}</span>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                {/* Original message */}
                <div style={{ padding: 12, background: 'var(--bg-elevated)', border: '1px solid var(--border-subtle)', borderRadius: 10, color: 'var(--text-secondary)', fontSize: '0.85rem', lineHeight: 1.5 }}>
                  <div style={{ fontWeight: 700, marginBottom: 4, fontSize: '0.7rem', color: 'var(--text-muted)' }}>MEMBER MESSAGE:</div>
                  {selectedTicket.message}
                </div>

                {/* Replies */}
                {selectedTicket.replies && selectedTicket.replies.map((r, i) => (
                  <div key={i} style={{
                    padding: 12,
                    background: r.author === 'Admin' ? 'rgba(240,130,50,0.05)' : 'var(--bg-base)',
                    border: `1px solid ${r.author === 'Admin' ? 'rgba(240,130,50,0.15)' : 'var(--border-subtle)'}`,
                    borderRadius: 10, color: 'var(--text-secondary)', fontSize: '0.85rem', lineHeight: 1.5
                  }}>
                    <div style={{ fontWeight: 700, marginBottom: 4, fontSize: '0.7rem', color: r.author === 'Admin' ? 'var(--brand-primary)' : 'var(--text-muted)' }}>
                      {r.author.toUpperCase()} ({r.date}):
                    </div>
                    {r.message}
                  </div>
                ))}
              </div>

              {/* Archive quick action */}
              {selectedTicket.status !== 'archived' && (
                <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
                  <button
                    onClick={() => handleUpdateStatus('archived')}
                    style={{ display: 'flex', alignItems: 'center', gap: 5, padding: '5px 12px', borderRadius: 8, border: '1px solid rgba(148,163,184,0.3)', background: 'rgba(148,163,184,0.08)', color: '#94a3b8', cursor: 'pointer', fontSize: '0.75rem', fontWeight: 700 }}
                  >
                    <span className="material-symbols-outlined" style={{ fontSize: '0.95rem' }}>archive</span>
                    Move to Archive
                  </button>
                </div>
              )}

              {/* Reply form */}
              <form onSubmit={handleReply} style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                <textarea
                  rows="4" required value={reply}
                  onChange={e => setReply(e.target.value)}
                  placeholder="Type your reply..."
                  style={{ width: '100%', padding: 12, border: '1.5px solid var(--border-default)', borderRadius: 10, resize: 'none', background: 'var(--bg-base)', outline: 'none', fontSize: '0.9rem', fontFamily: 'inherit', boxSizing: 'border-box' }}
                />
                <button type="submit" className="btn btn-primary" style={{ width: '100%', height: 44, justifyContent: 'center', fontSize: '0.9rem' }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>send</span> Send Reply
                </button>
              </form>

            </div>
          </div>
        )}
      </div>
    </AppLayout>
  )
}
