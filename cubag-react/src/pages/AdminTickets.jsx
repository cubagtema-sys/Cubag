import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'
import CustomSelect from '../components/CustomSelect'
import { showToast } from '../utils/toast'

const STATUS_STYLES = {
  open:     { bg: 'rgba(240,130,50,0.1)',  color: 'var(--brand-primary)', label: 'Open' },
  pending:  { bg: 'rgba(245,158,11,0.1)',  color: '#f59e0b',              label: 'Pending' },
  resolved: { bg: 'rgba(16,185,129,0.1)',  color: '#10b981',              label: 'Resolved' },
}

const statusOptions = [
  { value: 'open', label: 'Status: Open' },
  { value: 'pending', label: 'Status: Pending' },
  { value: 'resolved', label: 'Status: Resolved' },
]

const API_URL = import.meta.env.VITE_API_URL

export default function AdminTickets() {
  const [tickets, setTickets] = useState([])
  const [selectedTicket, setSelectedTicket] = useState(null)
  const [reply, setReply] = useState('')

  const fetchTickets = async () => {
    try {
      const res = await fetch(`${API_URL}/tickets/admin/all`)
      if (res.ok) {
        const data = await res.json()
        setTickets(data)
        if (selectedTicket) {
          const fresh = data.find(t => t.id === selectedTicket.id)
          if (fresh) setSelectedTicket(fresh)
        }
      }
    } catch (e) {
      console.error(e)
    }
  }

  useEffect(() => {
    fetchTickets()
  }, [])

  const handleUpdateStatus = async (newStatus) => {
    if (!selectedTicket) return;
    const id = selectedTicket.id;
    
    try {
      const res = await fetch(`${API_URL}/tickets/admin/${id}/status`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: newStatus })
      })
      if (res.ok) {
        showToast(`Updated to ${newStatus}`, 'success')
        fetchTickets()
      }
    } catch (e) {
      console.error(e)
    }
  }

  const handleReply = async (e) => {
    e.preventDefault()
    if (!reply.trim() || !selectedTicket) return
    
    try {
      const res = await fetch(`${API_URL}/tickets/admin/${selectedTicket.id}/reply`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: reply })
      })
      if (res.ok) {
        showToast(`Reply sent!`, 'success')
        setReply('')
        fetchTickets()
      }
    } catch (e) {
      console.error(e)
    }
  }

  return (
    <AppLayout title="Tickets">
      <div style={{ maxWidth: 1000, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>
        
        {/* Page Title for Content */}
        <div style={{ marginBottom: 4 }}>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Support Tickets</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Review and respond to member help requests.</p>
        </div>

        {/* Ticket List Panel */}
        {!selectedTicket ? (
          <div className="feed-card" style={{ flex: 1, borderRadius: 12 }}>
            <div className="card-header" style={{ padding: '12px 16px' }}><span className="card-title">User Inbox</span></div>
            <div className="card-body" style={{ padding: 0, display: 'flex', flexDirection: 'column' }}>
              {tickets.length === 0 ? (
                <div style={{ padding: 40, textAlign: 'center', color: 'var(--text-muted)', fontSize: '0.85rem' }}>No tickets found.</div>
              ) : (
                tickets.map(ticket => {
                  const style = STATUS_STYLES[ticket.status] || STATUS_STYLES.open
                  return (
                    <div key={ticket.id}
                      onClick={() => setSelectedTicket(ticket)}
                      style={{
                        padding: '14px 16px', borderBottom: '1px solid var(--border-subtle)', cursor: 'pointer',
                        background: 'transparent',
                        borderLeft: '4px solid transparent',
                        transition: 'all 0.2s'
                      }}
                    >
                      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                        <span style={{ fontWeight: 800, fontSize: '0.7rem', color: 'var(--text-muted)', fontFamily: 'monospace' }}>#{ticket.id.slice(-6)}</span>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                          <span style={{ padding: '2px 8px', borderRadius: 12, background: style.bg, color: style.color, fontSize: '0.6rem', fontWeight: 800, textTransform: 'uppercase' }}>{style.label}</span>
                        </div>
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 2 }}>
                        <span style={{ fontWeight: 800, color: 'var(--brand-primary)', fontSize: '0.9rem' }}>{ticket.member_name}</span>
                      </div>
                      <div style={{ fontWeight: 600, color: 'var(--text-primary)', marginBottom: 2, fontSize: '0.85rem', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{ticket.subject}</div>
                      <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)' }}>Opened: {ticket.date}</div>
                    </div>
                  )
                })
              )}
            </div>
          </div>
        ) : (
          /* Reply/Action Panel - Full screen on mobile when selected */
          <div className="feed-card" style={{ flex: 1, borderRadius: 12 }}>
            <div className="card-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '10px 16px' }}>
              <button className="btn btn-ghost btn-sm" style={{ padding: '4px 8px', fontSize: '0.75rem' }} onClick={() => setSelectedTicket(null)}>
                <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>arrow_back</span> Back
              </button>
              <div style={{ minWidth: '130px' }}>
                <CustomSelect
                  options={statusOptions}
                  value={selectedTicket.status}
                  onChange={handleUpdateStatus}
                />
              </div>
            </div>
            <div className="card-body" style={{ flexDirection: 'column', gap: 16, padding: '16px' }}>
              
              <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                <div style={{ padding: 12, background: 'var(--bg-elevated)', border: '1px solid var(--border-subtle)', borderRadius: 10, color: 'var(--text-secondary)', fontSize: '0.85rem', lineHeight: 1.5 }}>
                  <div style={{ fontWeight: 700, marginBottom: 4, fontSize: '0.7rem', color: 'var(--text-muted)' }}>MEMBER MESSAGE:</div>
                  {selectedTicket.message}
                </div>

                {selectedTicket.replies && selectedTicket.replies.map((r, i) => (
                  <div key={i} style={{ padding: 12, background: r.author === 'Admin' ? 'rgba(240,130,50,0.05)' : 'var(--bg-base)', border: '1px solid var(--border-subtle)', borderRadius: 10, color: 'var(--text-secondary)', fontSize: '0.85rem', lineHeight: 1.5 }}>
                    <div style={{ fontWeight: 700, marginBottom: 4, fontSize: '0.7rem', color: r.author === 'Admin' ? 'var(--brand-primary)' : 'var(--text-muted)' }}>{r.author.toUpperCase()} ({r.date}):</div>
                    {r.message}
                  </div>
                ))}
              </div>

              <form onSubmit={handleReply} style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                <textarea
                  rows="4"
                  required
                  value={reply}
                  onChange={e => setReply(e.target.value)}
                  placeholder="Type reply..."
                  style={{ width: '100%', padding: 12, border: '1.5px solid var(--border-default)', borderRadius: 10, resize: 'none', background: 'var(--bg-base)', outline: 'none', fontSize: '0.9rem', fontFamily: 'inherit' }}
                ></textarea>
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
