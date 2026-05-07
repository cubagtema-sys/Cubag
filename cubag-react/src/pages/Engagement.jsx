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

  const CONTACTS = [
    { icon: 'call',  color: 'var(--brand-primary)', bg: 'rgba(240,130,50,0.1)', label: 'Call Support', value: '+233 (0) 302 123 456', href: 'tel:+233302123456' },
    { icon: 'mail',  color: '#3b82f6',              bg: 'rgba(59,130,246,0.1)',  label: 'Email Us',    value: 'support@cubag.org.gh',  href: 'mailto:support@cubag.org.gh' },
    { icon: 'forum', color: '#10b981',              bg: 'rgba(16,185,129,0.1)',  label: 'Live Chat',   value: 'Available 8am – 5pm',   href: '#' },
  ]

  return (
    <AppLayout title="Support & Engagement">
      <div style={{ maxWidth: 720, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 20 }}>

        {/* Quick Contact Strip */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {CONTACTS.map((c, i) => (
            <a key={i} href={c.href}
              style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '14px 16px', background: 'var(--bg-surface)', border: '1px solid var(--border-subtle)', borderRadius: 14, textDecoration: 'none', transition: 'background 0.15s' }}
              onMouseEnter={e => e.currentTarget.style.background = 'var(--bg-elevated)'}
              onMouseLeave={e => e.currentTarget.style.background = 'var(--bg-surface)'}
            >
              <div style={{ width: 44, height: 44, borderRadius: 12, background: c.bg, color: c.color, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <span className="material-symbols-outlined">{c.icon}</span>
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '0.9rem' }}>{c.label}</div>
                <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{c.value}</div>
              </div>
              <span className="material-symbols-outlined" style={{ color: 'var(--text-muted)', fontSize: '1.1rem', flexShrink: 0 }}>chevron_right</span>
            </a>
          ))}
        </div>

        {/* Tab Switcher — full width */}
        <div style={{ display: 'flex', gap: 4, background: 'var(--bg-surface)', borderRadius: 12, padding: 4 }}>
          {[
            { id: 'contact', label: 'Send Message',             icon: 'edit_note' },
            { id: 'tickets', label: `My Tickets (${tickets.length})`, icon: 'confirmation_number' }
          ].map(t => (
            <button key={t.id} onClick={() => { setTab(t.id); if (t.id === 'tickets') refreshTickets() }} style={{
              flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
              padding: '10px 12px', borderRadius: 9, border: 'none', cursor: 'pointer',
              fontWeight: 700, fontSize: '0.85rem',
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
          <div className="feed-card">
            <div className="card-header"><span className="card-title">Submit a Support Request</span></div>
            <div className="card-body" style={{ flexDirection: 'column', padding: '20px 16px' }}>
              {sent ? (
                <div style={{ textAlign: 'center', padding: '32px 8px' }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '3.5rem', color: '#10b981', display: 'block', marginBottom: 12 }}>check_circle</span>
                  <h3 style={{ marginBottom: 8 }}>Ticket Created</h3>
                  <div style={{ fontFamily: 'monospace', fontSize: '1rem', fontWeight: 800, color: 'var(--brand-primary)', marginBottom: 12 }}>{newTicketId}</div>
                  <p style={{ color: 'var(--text-secondary)', marginBottom: 24, fontSize: '0.88rem' }}>
                    Your request has been submitted. Our team will respond within 24 hours.
                  </p>
                  <div style={{ display: 'flex', gap: 10, flexDirection: 'column' }}>
                    <button className="btn btn-primary" style={{ width: '100%' }} onClick={() => setTab('tickets')}>View My Tickets</button>
                    <button className="btn btn-outline" style={{ width: '100%' }} onClick={() => setSent(false)}>Submit Another</button>
                  </div>
                </div>
              ) : (
                <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 18, width: '100%' }}>

                  <div className="form-group">
                    <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 700, marginBottom: 8, color: 'var(--text-primary)' }}>Inquiry Subject</label>
                    <div style={{ position: 'relative' }}>
                      <CustomSelect
                        value={subject}
                        onChange={setSubject}
                        options={SUBJECTS}
                      />
                    </div>
                  </div>

                  <div className="form-group">
                    <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 700, marginBottom: 8, color: 'var(--text-primary)' }}>Describe Your Issue</label>
                    <textarea
                      rows="5" required value={message}
                      onChange={e => setMessage(e.target.value)}
                      placeholder="Provide as much detail as possible so our team can assist you quickly..."
                      style={{ width: '100%', padding: '12px 14px', borderRadius: 'var(--radius-md)', border: '1.5px solid var(--border-default)', background: 'var(--bg-base)', color: 'var(--text-primary)', resize: 'none', outline: 'none', fontSize: '0.9rem', boxSizing: 'border-box', fontFamily: 'inherit' }}
                    />
                  </div>

                  <button type="submit" disabled={isSubmitting || !subject || !message.trim()}
                    className="btn btn-primary btn-lg"
                    style={{ width: '100%', justifyContent: 'center', opacity: (!subject || !message.trim()) ? 0.5 : 1 }}>
                    {isSubmitting ? 'Submitting...' : 'Submit Request'}
                  </button>
                </form>
              )}
            </div>
          </div>
        )}

        {/* Tickets Tab */}
        {tab === 'tickets' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {selectedTicket ? (
              <div className="feed-card" style={{ padding: '16px' }}>
                <button className="btn btn-ghost btn-sm" style={{ marginBottom: 14, display: 'flex', alignItems: 'center', gap: 6 }} onClick={() => setSelectedTicket(null)}>
                  <span className="material-symbols-outlined">arrow_back</span> Back to Tickets
                </button>

                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: 10, marginBottom: 14 }}>
                  <h3 style={{ margin: 0, fontSize: '1rem', flex: 1, minWidth: 0 }}>{selectedTicket.subject}</h3>
                  <span style={{ padding: '4px 12px', borderRadius: 20, background: (STATUS_STYLES[selectedTicket.status] || STATUS_STYLES.open).bg, color: (STATUS_STYLES[selectedTicket.status] || STATUS_STYLES.open).color, fontSize: '0.75rem', fontWeight: 800, flexShrink: 0 }}>
                    {(STATUS_STYLES[selectedTicket.status] || STATUS_STYLES.open).label}
                  </span>
                </div>

                <div style={{ padding: 14, background: 'var(--bg-base)', border: '1px solid var(--border-subtle)', borderRadius: 10, color: 'var(--text-secondary)', fontSize: '0.88rem', lineHeight: 1.6, marginBottom: 12 }}>
                  <div style={{ fontWeight: 700, marginBottom: 6, fontSize: '0.72rem', color: 'var(--text-muted)', textTransform: 'uppercase' }}>You · {selectedTicket.date}</div>
                  {selectedTicket.message}
                </div>

                {selectedTicket.replies?.map((r, i) => (
                  <div key={i} style={{ padding: 14, background: r.author === 'Admin' ? 'rgba(240,130,50,0.05)' : 'var(--bg-base)', border: '1px solid var(--border-subtle)', borderRadius: 10, color: 'var(--text-secondary)', fontSize: '0.88rem', lineHeight: 1.6, marginBottom: 10 }}>
                    <div style={{ fontWeight: 700, marginBottom: 6, fontSize: '0.72rem', color: r.author === 'Admin' ? 'var(--brand-primary)' : 'var(--text-muted)', textTransform: 'uppercase' }}>{r.author} · {r.date}</div>
                    {r.message}
                  </div>
                ))}
              </div>

            ) : tickets.length === 0 ? (
              <div className="feed-card" style={{ padding: '48px 20px', textAlign: 'center' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '3.5rem', color: 'var(--text-muted)', display: 'block', marginBottom: 12 }}>confirmation_number</span>
                <h3 style={{ marginBottom: 8 }}>No Support Tickets</h3>
                <p style={{ color: 'var(--text-secondary)', marginBottom: 20, fontSize: '0.88rem' }}>You haven't submitted any support requests yet.</p>
                <button className="btn btn-primary" style={{ width: '100%' }} onClick={() => setTab('contact')}>Submit a Request</button>
              </div>

            ) : tickets.map(ticket => {
              const style = STATUS_STYLES[ticket.status] || STATUS_STYLES.open
              return (
                <div key={ticket.id} className="feed-card" style={{ padding: '16px' }}>
                  {/* ID + Status row */}
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                    <span style={{ fontWeight: 800, fontSize: '0.8rem', color: 'var(--text-muted)', fontFamily: 'monospace' }}>{ticket.id}</span>
                    <span style={{ padding: '3px 10px', borderRadius: 20, background: style.bg, color: style.color, fontSize: '0.72rem', fontWeight: 800 }}>{style.label}</span>
                  </div>

                  {/* Subject */}
                  <div style={{ fontWeight: 700, color: 'var(--text-primary)', marginBottom: 6, fontSize: '0.95rem' }}>{ticket.subject}</div>

                  {/* Preview */}
                  <p style={{ fontSize: '0.83rem', color: 'var(--text-secondary)', marginBottom: 12, overflow: 'hidden', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical' }}>{ticket.message}</p>

                  {/* Footer: dates + button */}
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 8 }}>
                    <div style={{ fontSize: '0.72rem', color: 'var(--text-muted)' }}>
                      Opened: {ticket.date} · Updated: {ticket.lastUpdate}
                    </div>
                    <button className="btn btn-outline btn-sm" style={{ display: 'flex', alignItems: 'center', gap: 4, flexShrink: 0 }}
                      onClick={() => { showToast(`Viewing ${ticket.id}`, 'info'); openTicket(ticket) }}>
                      <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>visibility</span> View
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
