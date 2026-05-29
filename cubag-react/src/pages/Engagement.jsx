import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'
import CustomSelect from '../components/CustomSelect'
import { showToast } from '../utils/toast'

const STATUS_STYLES = {
  open:     { bg: 'rgba(240,130,50,0.1)',  color: 'var(--brand-primary)', label: 'Open' },
  pending:  { bg: 'rgba(245,158,11,0.1)',  color: '#f59e0b',              label: 'Pending' },
  resolved: { bg: 'rgba(16,185,129,0.1)',  color: '#10b981',              label: 'Resolved' },
}

const SUBJECTS = [
  { value: '', label: '— Select a subject —', disabled: true },
  { value: 'General Inquiry',    label: 'General Inquiry' },
  { value: 'License Support',    label: 'License Support' },
  { value: 'Payment Issue',      label: 'Payment Issue' },
  { value: 'Event Registration', label: 'Event Registration' },
  { value: 'Technical Problem',  label: 'Technical Problem' },
  { value: 'Complaint',          label: 'Complaint' },
]

const API_URL = import.meta.env.VITE_API_URL

export default function Engagement() {
  const [tab, setTab] = useState('contact')
  const [subject, setSubject] = useState('')
  const [message, setMessage] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [sent, setSent] = useState(false)
  const [tickets, setTickets] = useState([])
  const [newTicketId, setNewTicketId] = useState(null)
  const [selectedTicket, setSelectedTicket] = useState(null)

  const fetchTickets = async () => {
    try {
      const res = await fetch(`${API_URL}/tickets`, {
        headers: { Authorization: `Bearer ${localStorage.getItem('cubag_token')}` }
      })
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

  const refreshTickets = () => {
    fetchTickets()
  }

  const openTicket = (ticket) => {
    fetchTickets()
    setSelectedTicket(ticket)
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!message.trim() || !subject) return
    setIsSubmitting(true)
    
    try {
      const res = await fetch(`${API_URL}/tickets`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('cubag_token')}`
        },
        body: JSON.stringify({ subject, message })
      })
      if (res.ok) {
        const data = await res.json()
        setNewTicketId(data.id)
        setSent(true)
        setMessage('')
        setSubject('')
        setTab('tickets')
        fetchTickets()
      }
    } catch (e) {
      console.error(e)
    } finally {
      setIsSubmitting(false)
    }
  }



  return (
    <AppLayout title="Support Center">
      <div style={{ maxWidth: 720, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>

        {/* Page Title removed as it is now in the header */}


        {/* Tab Switcher */}
        <div style={{ display: 'flex', gap: 3, background: 'var(--bg-surface)', borderRadius: 10, padding: 3 }}>
          {[
            { id: 'contact', label: 'New Request',             icon: 'edit_note' },
            { id: 'tickets', label: `My Tickets (${tickets.length})`, icon: 'confirmation_number' }
          ].map(t => (
            <button key={t.id} onClick={() => { setTab(t.id); if (t.id === 'tickets') refreshTickets() }} style={{
              flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
              padding: '8px 10px', borderRadius: 8, border: 'none', cursor: 'pointer',
              fontWeight: 700, fontSize: '0.8rem',
              background: tab === t.id ? 'var(--brand-primary)' : 'transparent',
              color: tab === t.id ? '#fff' : 'var(--text-secondary)',
              transition: 'all 0.2s'
            }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>{t.icon}</span>
              {t.label}
            </button>
          ))}
        </div>

        {/* Send Message Tab */}
        {tab === 'contact' && (
          <div className="feed-card" style={{ borderRadius: 12 }}>
            <div className="card-header" style={{ padding: '12px 16px' }}><span className="card-title">New Support Ticket</span></div>
            <div className="card-body" style={{ flexDirection: 'column', padding: '16px' }}>
              {sent ? (
                <div style={{ textAlign: 'center', padding: '24px 8px' }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '3rem', color: '#10b981', display: 'block', marginBottom: 10 }}>check_circle</span>
                  <h3 style={{ marginBottom: 6, fontSize: '1.1rem' }}>Ticket Created</h3>
                  <div style={{ fontFamily: 'monospace', fontSize: '0.9rem', fontWeight: 800, color: 'var(--brand-primary)', marginBottom: 10 }}>{newTicketId}</div>
                  <p style={{ color: 'var(--text-secondary)', marginBottom: 20, fontSize: '0.8rem' }}>
                    We'll respond within 24 hours.
                  </p>
                  <div style={{ display: 'flex', gap: 8, flexDirection: 'column' }}>
                    <button className="btn btn-primary btn-sm" style={{ width: '100%', height: 44 }} onClick={() => setTab('tickets')}>View Tickets</button>
                    <button className="btn btn-outline btn-sm" style={{ width: '100%', height: 44 }} onClick={() => setSent(false)}>Another Request</button>
                  </div>
                </div>
              ) : (
                <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 14, width: '100%' }}>

                  <div className="form-group">
                    <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 700, marginBottom: 6, color: 'var(--text-primary)' }}>Subject</label>
                    <CustomSelect
                      value={subject}
                      onChange={setSubject}
                      options={SUBJECTS}
                    />
                  </div>

                  <div className="form-group">
                    <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 700, marginBottom: 6, color: 'var(--text-primary)' }}>Description</label>
                    <textarea
                      rows="4" required value={message}
                      onChange={e => setMessage(e.target.value)}
                      placeholder="Explain your issue..."
                      style={{ width: '100%', padding: '10px 12px', borderRadius: 8, border: '1.5px solid var(--border-default)', background: 'var(--bg-base)', color: 'var(--text-primary)', resize: 'none', outline: 'none', fontSize: '0.9rem', boxSizing: 'border-box' }}
                    />
                  </div>

                  <button type="submit" disabled={isSubmitting || !subject || !message.trim()}
                    className="btn btn-primary btn-lg"
                    style={{ width: '100%', justifyContent: 'center', height: 48, fontSize: '0.9rem', opacity: (!subject || !message.trim()) ? 0.5 : 1 }}>
                    {isSubmitting ? 'Submitting...' : 'Submit Ticket'}
                  </button>
                </form>
              )}
            </div>
          </div>
        )}

        {/* Tickets Tab */}
        {tab === 'tickets' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {selectedTicket ? (
              <div className="feed-card" style={{ padding: '14px', borderRadius: 12 }}>
                <button className="btn btn-ghost btn-sm" style={{ marginBottom: 12, height: 32, fontSize: '0.75rem' }} onClick={() => setSelectedTicket(null)}>
                  <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>arrow_back</span> Back
                </button>

                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 10, marginBottom: 12 }}>
                  <h3 style={{ margin: 0, fontSize: '0.95rem', flex: 1, minWidth: 0 }}>{selectedTicket.subject}</h3>
                  <span style={{ padding: '3px 10px', borderRadius: 20, background: (STATUS_STYLES[selectedTicket.status] || STATUS_STYLES.open).bg, color: (STATUS_STYLES[selectedTicket.status] || STATUS_STYLES.open).color, fontSize: '0.65rem', fontWeight: 800, flexShrink: 0 }}>
                    {(STATUS_STYLES[selectedTicket.status] || STATUS_STYLES.open).label}
                  </span>
                </div>

                <div style={{ padding: 12, background: 'var(--bg-elevated)', border: '1px solid var(--border-subtle)', borderRadius: 10, color: 'var(--text-secondary)', fontSize: '0.8rem', lineHeight: 1.5, marginBottom: 10 }}>
                  <div style={{ fontWeight: 700, marginBottom: 4, fontSize: '0.65rem', color: 'var(--text-muted)', textTransform: 'uppercase' }}>You · {selectedTicket.date}</div>
                  {selectedTicket.message}
                </div>

                {selectedTicket.replies?.map((r, i) => (
                  <div key={i} style={{ padding: 12, background: r.author === 'Admin' ? 'rgba(240,130,50,0.05)' : 'var(--bg-base)', border: '1px solid var(--border-subtle)', borderRadius: 10, color: 'var(--text-secondary)', fontSize: '0.8rem', lineHeight: 1.5, marginBottom: 8 }}>
                    <div style={{ fontWeight: 700, marginBottom: 4, fontSize: '0.65rem', color: r.author === 'Admin' ? 'var(--brand-primary)' : 'var(--text-muted)', textTransform: 'uppercase' }}>{r.author} · {r.date}</div>
                    {r.message}
                  </div>
                ))}
              </div>

            ) : tickets.length === 0 ? (
              <div className="card" style={{ padding: '48px 20px', textAlign: 'center', borderRadius: 12 }}>
                <span className="material-symbols-outlined" style={{ fontSize: '3rem', color: 'var(--text-muted)', display: 'block', marginBottom: 12 }}>confirmation_number</span>
                <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>No tickets yet.</p>
              </div>

            ) : tickets.map(ticket => {
              const style = STATUS_STYLES[ticket.status] || STATUS_STYLES.open
              return (
                <div key={ticket.id} className="feed-card" style={{ padding: '12px 14px', borderRadius: 12 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
                    <span style={{ fontWeight: 800, fontSize: '0.7rem', color: 'var(--text-muted)', fontFamily: 'monospace' }}>#{ticket.id.slice(-6)}</span>
                    <span style={{ padding: '2px 8px', borderRadius: 20, background: style.bg, color: style.color, fontSize: '0.6rem', fontWeight: 800 }}>{style.label}</span>
                  </div>

                  <div style={{ fontWeight: 700, color: 'var(--text-primary)', marginBottom: 4, fontSize: '0.9rem' }}>{ticket.subject}</div>

                  <p style={{ fontSize: '0.78rem', color: 'var(--text-secondary)', marginBottom: 10, overflow: 'hidden', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical' }}>{ticket.message}</p>

                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
                    <div style={{ fontSize: '0.65rem', color: 'var(--text-muted)' }}>
                      Updated: {ticket.lastUpdate}
                    </div>
                    <button className="btn btn-outline btn-sm" style={{ padding: '4px 10px', fontSize: '0.7rem' }}
                      onClick={() => openTicket(ticket)}>
                      View
                    </button>
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </div>
    </AppLayout>
  )
}
