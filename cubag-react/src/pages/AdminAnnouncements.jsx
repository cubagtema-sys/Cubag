import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout.jsx'
import CustomSelect from '../components/CustomSelect.jsx'

const API = import.meta.env.VITE_API_URL
const PAGE_SIZE = 8

function Pagination({ page, totalPages, onPage }) {
  if (totalPages <= 1) return null
  return (
    <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 8, padding: '14px 0' }}>
      <button
        onClick={() => onPage(p => Math.max(1, p - 1))}
        disabled={page === 1}
        style={{ padding: '6px 14px', borderRadius: 8, border: '1px solid var(--border-subtle)', background: 'var(--bg-card)', color: page === 1 ? 'var(--text-muted)' : 'var(--text-primary)', cursor: page === 1 ? 'default' : 'pointer', fontWeight: 600, opacity: page === 1 ? 0.5 : 1 }}
      >← Prev</button>
      {Array.from({ length: totalPages }, (_, i) => i + 1).map(n => (
        <button key={n} onClick={() => onPage(n)}
          style={{ width: 34, height: 34, borderRadius: 8, border: 'none', background: page === n ? 'var(--brand-primary)' : 'var(--bg-card)', color: page === n ? '#fff' : 'var(--text-secondary)', fontWeight: 700, cursor: 'pointer' }}
        >{n}</button>
      ))}
      <button
        onClick={() => onPage(p => Math.min(totalPages, p + 1))}
        disabled={page === totalPages}
        style={{ padding: '6px 14px', borderRadius: 8, border: '1px solid var(--border-subtle)', background: 'var(--bg-card)', color: page === totalPages ? 'var(--text-muted)' : 'var(--text-primary)', cursor: page === totalPages ? 'default' : 'pointer', fontWeight: 600, opacity: page === totalPages ? 0.5 : 1 }}
      >Next →</button>
    </div>
  )
}

export default function AdminAnnouncements() {
  const [announcements, setAnnouncements] = useState([])
  const [title, setTitle]       = useState('')
  const [body, setBody]         = useState('')
  const [category, setCategory] = useState('General')
  const [message, setMessage]   = useState('')
  const [activeTab, setActiveTab] = useState('create')
  const [deletingId, setDeletingId] = useState(null)
  const [actionMsg, setActionMsg] = useState('')

  // Per-tab pagination
  const [histPage, setHistPage] = useState(1)
  const [archPage, setArchPage] = useState(1)

  const token = () => localStorage.getItem('cubag_token')

  const fetchAnnouncements = async () => {
    try {
      const res = await fetch(`${API}/announcements/admin/all`, {
        headers: { 'Authorization': `Bearer ${token()}` }
      })
      if (res.ok) setAnnouncements(await res.json())
    } catch (e) { console.error(e) }
  }

  useEffect(() => { fetchAnnouncements() }, [])  // eslint-disable-line

  const handleSubmit = async (e) => {
    e.preventDefault()
    try {
      const res = await fetch(`${API}/announcements`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token()}` },
        body: JSON.stringify({ title, body, category, posted_by: 'System Administrator' })
      })
      if (res.ok) {
        setMessage('Announcement successfully broadcasted.')
        setTitle(''); setBody('')
        fetchAnnouncements()
        setTimeout(() => setMessage(''), 3000)
      } else {
        setMessage('Failed to create announcement.')
      }
    } catch { setMessage('Network error.') }
  }

  const handleDelete = async (id) => {
    try {
      const res = await fetch(`${API}/announcements/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token()}` }
      })
      if (res.ok) {
        setActionMsg('Announcement archived successfully.')
        fetchAnnouncements()
      } else {
        setActionMsg('Failed to archive announcement.')
      }
    } catch { setActionMsg('Network error.') }
    setDeletingId(null)
    setTimeout(() => setActionMsg(''), 3000)
  }

  const handleRestore = async (id) => {
    try {
      const res = await fetch(`${API}/announcements/${id}/restore`, {
        method: 'PATCH',
        headers: { 'Authorization': `Bearer ${token()}` }
      })
      if (res.ok) {
        setActionMsg('Announcement restored.')
        fetchAnnouncements()
      }
    } catch { setActionMsg('Network error.') }
    setTimeout(() => setActionMsg(''), 3000)
  }

  const active   = announcements.filter(a => !a.is_deleted)
  const archived = announcements.filter(a =>  a.is_deleted)

  // Pagination
  const histTotalPages = Math.max(1, Math.ceil(active.length   / PAGE_SIZE))
  const archTotalPages = Math.max(1, Math.ceil(archived.length / PAGE_SIZE))
  const paginatedActive   = active.slice((histPage - 1) * PAGE_SIZE, histPage * PAGE_SIZE)
  const paginatedArchived = archived.slice((archPage - 1) * PAGE_SIZE, archPage * PAGE_SIZE)

  const TABS = [
    { id: 'create',   label: 'New Broadcast',         icon: 'campaign' },
    { id: 'history',  label: `History (${active.length})`,   icon: 'history' },
    { id: 'archived', label: `Archived (${archived.length})`, icon: 'inventory_2' },
  ]

  return (
    <AppLayout title="Announcements">
      <div style={{ maxWidth: 1000, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>

        <div style={{ marginBottom: 4 }}>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Announcements</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Broadcast system-wide alerts to all members.</p>
        </div>

        {/* ── 3-Tab bar ── */}
        <div style={{ display: 'flex', gap: 4, background: 'var(--bg-surface)', borderRadius: 10, padding: 3 }}>
          {TABS.map(t => (
            <button key={t.id} onClick={() => setActiveTab(t.id)} style={{
              flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
              padding: '8px 10px', borderRadius: 8, border: 'none', cursor: 'pointer',
              fontWeight: 700, fontSize: '0.75rem',
              background: activeTab === t.id ? 'var(--brand-primary)' : 'transparent',
              color: activeTab === t.id ? '#fff' : 'var(--text-secondary)',
              transition: 'all 0.2s'
            }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>{t.icon}</span>
              {t.label}
            </button>
          ))}
        </div>

        {/* ── Create Tab ── */}
        {activeTab === 'create' && (
          <div className="feed-card" style={{ maxWidth: '600px', margin: '0 auto', width: '100%', borderRadius: 12 }}>
            <div className="card-header" style={{ padding: '12px 16px' }}>
              <span className="card-title">Compose Message</span>
            </div>
            <div className="card-body" style={{ padding: '16px' }}>
              {message && (
                <div style={{ padding: '10px 14px', background: message.includes('success') ? '#10b981' : '#ef4444', color: '#fff', borderRadius: 8, marginBottom: 16, fontSize: '0.8rem', fontWeight: 600 }}>
                  {message}
                </div>
              )}
              <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700, marginBottom: 4 }}>Alert Type</label>
                  <CustomSelect
                    options={[
                      { value: 'General',            label: 'General Announcement' },
                      { value: 'Urgent Alert',       label: 'Urgent Alert' },
                      { value: 'System Maintenance', label: 'Maintenance' },
                      { value: 'Event',              label: 'Event Notice' }
                    ]}
                    value={category}
                    onChange={setCategory}
                  />
                </div>
                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700, marginBottom: 4 }}>Subject</label>
                  <input type="text" required value={title} onChange={e => setTitle(e.target.value)} placeholder="Enter title..." style={{ padding: '10px 12px', fontSize: '0.9rem' }} />
                </div>
                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700, marginBottom: 4 }}>Content</label>
                  <textarea required value={body} onChange={e => setBody(e.target.value)} rows="4" placeholder="Broadcast details..." style={{ padding: '10px 12px', fontSize: '0.9rem', borderRadius: 8, border: '1.5px solid var(--border-default)', outline: 'none', width: '100%', boxSizing: 'border-box' }} />
                </div>
                <button type="submit" className="btn btn-primary btn-full" style={{ height: 48, fontSize: '0.9rem' }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>send</span> Broadcast Now
                </button>
              </form>
            </div>
          </div>
        )}

        {/* ── History Tab ── */}
        {activeTab === 'history' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {actionMsg && (
              <div style={{ padding: '10px 14px', background: 'rgba(16,185,129,0.1)', color: '#10b981', borderRadius: 10, fontSize: '0.82rem', fontWeight: 700, border: '1px solid rgba(16,185,129,0.2)' }}>
                {actionMsg}
              </div>
            )}

            {active.length === 0 ? (
              <div className="card" style={{ padding: 40, textAlign: 'center' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '2.5rem', display: 'block', marginBottom: 12, opacity: 0.3 }}>campaign</span>
                <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>No active announcements.</p>
              </div>
            ) : (
              <>
                {paginatedActive.map(ann => (
                  <div key={ann.id} className="feed-card" style={{ padding: '14px 16px', borderRadius: 12 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8, gap: 8 }}>
                      <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap', minWidth: 0 }}>
                        <span className={`badge ${ann.category === 'Urgent Alert' ? 'badge-danger' : 'badge-info'}`} style={{ fontSize: '0.6rem', flexShrink: 0 }}>
                          {ann.category}
                        </span>
                        <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>
                          {new Date(ann.created_at).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })}
                        </span>
                      </div>
                      {deletingId !== ann.id && (
                        <button
                          onClick={() => setDeletingId(ann.id)}
                          title="Archive this announcement"
                          style={{ width: 30, height: 30, borderRadius: 8, border: '1px solid rgba(239,68,68,0.3)', background: 'rgba(239,68,68,0.06)', color: '#ef4444', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}
                        >
                          <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>delete</span>
                        </button>
                      )}
                    </div>

                    <div style={{ fontWeight: 800, color: 'var(--text-primary)', fontSize: '0.95rem', marginBottom: 4 }}>{ann.title}</div>
                    <p style={{ margin: 0, fontSize: '0.8rem', color: 'var(--text-secondary)', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden', lineHeight: 1.4 }}>
                      {ann.body}
                    </p>
                    <div style={{ marginTop: 10, paddingTop: 10, borderTop: '1px solid var(--border-subtle)', fontSize: '0.7rem', color: 'var(--text-muted)' }}>
                      Posted by: <strong>{ann.posted_by}</strong>
                    </div>

                    {deletingId === ann.id && (
                      <div style={{ marginTop: 12, padding: '10px 12px', background: 'rgba(239,68,68,0.06)', border: '1px solid rgba(239,68,68,0.2)', borderRadius: 10, display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10 }}>
                        <span style={{ fontSize: '0.75rem', fontWeight: 700, color: '#ef4444', display: 'flex', alignItems: 'center', gap: 5 }}>
                          <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>warning</span>
                          Archive this announcement?
                        </span>
                        <div style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
                          <button onClick={() => setDeletingId(null)} style={{ padding: '6px 14px', borderRadius: 8, border: '1px solid var(--border-default)', background: 'var(--bg-surface)', fontSize: '0.75rem', fontWeight: 700, cursor: 'pointer', color: 'var(--text-secondary)' }}>
                            Cancel
                          </button>
                          <button onClick={() => handleDelete(ann.id)} style={{ padding: '6px 14px', borderRadius: 8, border: 'none', background: '#ef4444', color: '#fff', fontSize: '0.75rem', fontWeight: 800, cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 4 }}>
                            <span className="material-symbols-outlined" style={{ fontSize: '0.9rem' }}>delete_forever</span>
                            Confirm
                          </button>
                        </div>
                      </div>
                    )}
                  </div>
                ))}

                <Pagination page={histPage} totalPages={histTotalPages} onPage={setHistPage} />
              </>
            )}
          </div>
        )}

        {/* ── Archived Tab ── */}
        {activeTab === 'archived' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {actionMsg && (
              <div style={{ padding: '10px 14px', background: 'rgba(16,185,129,0.1)', color: '#10b981', borderRadius: 10, fontSize: '0.82rem', fontWeight: 700, border: '1px solid rgba(16,185,129,0.2)' }}>
                {actionMsg}
              </div>
            )}

            {archived.length === 0 ? (
              <div className="card" style={{ padding: 40, textAlign: 'center' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '2.5rem', display: 'block', marginBottom: 12, opacity: 0.3 }}>inventory_2</span>
                <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>No archived announcements.</p>
              </div>
            ) : (
              <>
                {paginatedArchived.map(ann => (
                  <div key={ann.id} className="feed-card" style={{ padding: '14px 16px', borderRadius: 12, opacity: 0.65 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 8, gap: 10 }}>
                      <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
                        <span className="badge" style={{ fontSize: '0.6rem', background: 'var(--bg-surface)', color: 'var(--text-muted)' }}>{ann.category}</span>
                        <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)' }}>
                          {new Date(ann.created_at).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })}
                        </span>
                      </div>
                      <button
                        onClick={() => handleRestore(ann.id)}
                        style={{ padding: '5px 10px', borderRadius: 8, border: '1px solid rgba(16,185,129,0.3)', background: 'rgba(16,185,129,0.06)', color: '#10b981', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 4, fontSize: '0.7rem', fontWeight: 800, flexShrink: 0 }}
                      >
                        <span className="material-symbols-outlined" style={{ fontSize: '0.95rem' }}>restore</span>
                        Restore
                      </button>
                    </div>
                    <div style={{ fontWeight: 800, color: 'var(--text-secondary)', fontSize: '0.95rem', marginBottom: 4, textDecoration: 'line-through' }}>{ann.title}</div>
                    <p style={{ margin: 0, fontSize: '0.8rem', color: 'var(--text-muted)', lineHeight: 1.4 }}>{ann.body}</p>
                    <div style={{ marginTop: 10, paddingTop: 10, borderTop: '1px solid var(--border-subtle)', fontSize: '0.7rem', color: 'var(--text-muted)' }}>
                      Posted by: <strong>{ann.posted_by}</strong>
                    </div>
                  </div>
                ))}

                <Pagination page={archPage} totalPages={archTotalPages} onPage={setArchPage} />
              </>
            )}
          </div>
        )}

      </div>
    </AppLayout>
  )
}
