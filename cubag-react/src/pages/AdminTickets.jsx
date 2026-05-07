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
  const [archiveConfirm, setArchiveConfirm] = useState(null) // ticketId pending confirmation

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
        showToast(`Ticket ${id} status updated to ${newStatus}`, 'success')
        fetchTickets()
      }
    } catch (e) {
      console.error(e)
    }
  }

  const handleArchive = async (ticketId, e) => {
    e.stopPropagation()
    setArchiveConfirm(ticketId)
  }

  const confirmArchive = async (ticketId) => {
    try {
      const res = await fetch(`${API_URL}/tickets/admin/${ticketId}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${localStorage.getItem('cubag_token')}` }
      })
      if (res.ok) {
        showToast(`Ticket ${ticketId} archived successfully`, 'success')
        if (selectedTicket?.id === ticketId) setSelectedTicket(null)
        fetchTickets()
      }
    } catch (e) {
      console.error(e)
    } finally {
      setArchiveConfirm(null)
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
        showToast(`Reply sent to user for ticket ${selectedTicket.id}`, 'success')
        setReply('')
        fetchTickets()
      }
    } catch (e) {
      console.error(e)
    }
  }

  return (
    <AppLayout title="Manage Support Tickets" hideSearch>
      <div style={{ maxWidth: 1000, margin: '0 auto', display: 'flex', gap: 24, alignItems: 'flex-start', flexWrap: 'wrap' }}>
        
        {/* Ticket List Panel */}
        <div className="feed-card" style={{ flex: '1 1 300px' }}>
          <div className="card-header"><span className="card-title">User Tickets</span></div>
          <div className="card-body" style={{ padding: 0, display: 'flex', flexDirection: 'column' }}>
            {tickets.length === 0 ? (
              <div style={{ padding: 40, textAlign: 'center', color: 'var(--text-muted)' }}>No support tickets in the system.</div>
            ) : (
              tickets.map(ticket => {
                const style = STATUS_STYLES[ticket.status] || STATUS_STYLES.open
                const isSelected = selectedTicket?.id === ticket.id
                return (
                  <div key={ticket.id}
                    onClick={() => setSelectedTicket(ticket)}
                    style={{
                      padding: '16px 20px', borderBottom: '1px solid var(--border-subtle)', cursor: 'pointer',
                      background: isSelected ? 'rgba(59, 130, 246, 0.05)' : 'transparent',
                      borderLeft: isSelected ? '4px solid var(--brand-primary)' : '4px solid transparent',
                      transition: 'all 0.2s'
                    }}
                  >
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
                      <span style={{ fontWeight: 800, fontSize: '0.85rem', color: 'var(--text-muted)' }}>{ticket.id}</span>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <span style={{ padding: '2px 8px', borderRadius: 12, background: style.bg, color: style.color, fontSize: '0.7rem', fontWeight: 800 }}>{style.label}</span>
                        <button
                          title="Archive ticket"
                          onClick={(e) => handleArchive(ticket.id, e)}
                          style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', padding: 2, borderRadius: 4 }}
                          onMouseOver={e => e.currentTarget.style.color = '#ef4444'}
                          onMouseOut={e => e.currentTarget.style.color = 'var(--text-muted)'}
                        >
                          <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>archive</span>
                        </button>
                      </div>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
                      <span className="material-symbols-outlined" style={{ fontSize: '1rem', color: 'var(--brand-primary)' }}>person</span>
                      <span style={{ fontWeight: 800, color: 'var(--brand-primary)', fontSize: '0.9rem' }}>{ticket.member_name || 'Unknown Member'}</span>
                    </div>
                    <div style={{ fontWeight: 600, color: 'var(--text-secondary)', marginBottom: 4, fontSize: '0.88rem' }}>{ticket.subject}</div>
                    <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)' }}>Opened: {ticket.date}</div>

                    {/* Inline archive confirmation */}
                    {archiveConfirm === ticket.id && (
                      <div onClick={e => e.stopPropagation()}
                        style={{ marginTop: 10, padding: '10px 14px', background: 'rgba(239,68,68,0.06)', border: '1px solid rgba(239,68,68,0.2)', borderRadius: 10, display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10 }}>
                        <span style={{ fontSize: '0.85rem', fontWeight: 600, color: '#ef4444' }}>Archive this ticket?</span>
                        <div style={{ display: 'flex', gap: 8 }}>
                          <button onClick={() => confirmArchive(ticket.id)}
                            style={{ padding: '5px 14px', background: '#ef4444', color: '#fff', border: 'none', borderRadius: 6, cursor: 'pointer', fontSize: '0.8rem', fontWeight: 700 }}>
                            Yes
                          </button>
                          <button onClick={() => setArchiveConfirm(null)}
                            style={{ padding: '5px 14px', background: 'var(--bg-elevated)', color: 'var(--text-secondary)', border: '1px solid var(--border-subtle)', borderRadius: 6, cursor: 'pointer', fontSize: '0.8rem', fontWeight: 600 }}>
                            No
                          </button>
                        </div>
                      </div>
                    )}
                  </div>
                )
              })
            )}
          </div>
        </div>

        {/* Reply/Action Panel */}
        {selectedTicket && (
          <div className="feed-card" style={{ flex: '1 1 400px', position: 'sticky', top: 24 }}>
            <div className="card-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span className="card-title">Ticket Details</span>
              <button className="btn btn-ghost" style={{ padding: 4 }} onClick={() => setSelectedTicket(null)}>
                <span className="material-symbols-outlined">close</span>
              </button>
            </div>
            <div className="card-body" style={{ flexDirection: 'column', gap: 24 }}>
              
              <div style={{ background: 'var(--bg-elevated)', padding: 20, borderRadius: 12 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: 12, marginBottom: 16 }}>
                  <div>
                    <h3 style={{ margin: 0, color: 'var(--text-primary)', fontSize: '1.1rem' }}>{selectedTicket.subject}</h3>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 8 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6, background: 'rgba(240,130,50,0.08)', border: '1px solid rgba(240,130,50,0.2)', borderRadius: 20, padding: '4px 12px' }}>
                        <span className="material-symbols-outlined" style={{ fontSize: '1rem', color: 'var(--brand-primary)' }}>person</span>
                        <span style={{ fontWeight: 800, color: 'var(--brand-primary)', fontSize: '0.88rem' }}>{selectedTicket.member_name || 'Unknown Member'}</span>
                      </div>
                      <span style={{ fontSize: '0.82rem', color: 'var(--text-muted)' }}>ID: {selectedTicket.id} · {selectedTicket.date}</span>
                    </div>
                  </div>
                  
                  <div style={{ minWidth: '150px' }}>
                    <CustomSelect 
                      options={statusOptions}
                      value={selectedTicket.status} 
                      onChange={handleUpdateStatus}
                    />
                  </div>
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                  <div style={{ padding: 16, background: '#fff', border: '1px solid var(--border-subtle)', borderRadius: 8, color: 'var(--text-secondary)', fontSize: '0.95rem', lineHeight: 1.6 }}>
                    <div style={{ fontWeight: 700, marginBottom: '8px', fontSize: '0.8rem', color: 'var(--text-muted)' }}>MEMBER:</div>
                    {selectedTicket.message}
                  </div>
                  
                  {selectedTicket.replies && selectedTicket.replies.map((r, i) => (
                    <div key={i} style={{ padding: 16, background: r.author === 'Admin' ? 'rgba(240,130,50,0.05)' : '#fff', border: '1px solid var(--border-subtle)', borderRadius: 8, color: 'var(--text-secondary)', fontSize: '0.95rem', lineHeight: 1.6 }}>
                      <div style={{ fontWeight: 700, marginBottom: '8px', fontSize: '0.8rem', color: r.author === 'Admin' ? 'var(--brand-primary)' : 'var(--text-muted)' }}>{r.author.toUpperCase()} ({r.date}):</div>
                      {r.message}
                    </div>
                  ))}
                </div>
              </div>

              <form onSubmit={handleReply} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                <div>
                  <label style={{ display: 'block', fontWeight: 700, marginBottom: 8, fontSize: '0.85rem' }}>Send Reply to Member</label>
                  <textarea
                    rows="6"
                    required
                    value={reply}
                    onChange={e => setReply(e.target.value)}
                    placeholder="Type your official response here..."
                    style={{ width: '100%', padding: 16, border: '2px solid var(--border-subtle)', borderRadius: 12, resize: 'none', background: 'var(--bg-base)', outline: 'none', boxSizing: 'border-box', fontFamily: 'inherit' }}
                  ></textarea>
                </div>
                <button type="submit" className="btn btn-primary" style={{ alignSelf: 'flex-end', display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>send</span> Send Reply
                </button>
              </form>

            </div>
          </div>
        )}
      </div>
    </AppLayout>
  )
}
