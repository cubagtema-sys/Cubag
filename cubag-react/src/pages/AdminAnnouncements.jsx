import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout.jsx'
import CustomSelect from '../components/CustomSelect.jsx'

export default function AdminAnnouncements() {
  const [announcements, setAnnouncements] = useState([])
  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [category, setCategory] = useState('General')
  const [message, setMessage] = useState('')
  const [activeTab, setActiveTab] = useState('create') // 'create' or 'history'

  const fetchAnnouncements = async () => {
    try {
      const res = await fetch(`${import.meta.env.VITE_API_URL}/announcements/admin/all`, {
        headers: { 'Authorization': `Bearer ${localStorage.getItem('cubag_token')}` }
      })
      if (res.ok) {
        setAnnouncements(await res.json())
      }
    } catch (e) {
      console.error(e)
    }
  }

  useEffect(() => {
    fetchAnnouncements()
  }, [])

  const handleSubmit = async (e) => {
    e.preventDefault()
    try {
      const res = await fetch(`${import.meta.env.VITE_API_URL}/announcements`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('cubag_token')}`
        },
        body: JSON.stringify({ title, body, category, posted_by: 'System Administrator' })
      })

      if (res.ok) {
        setMessage('Announcement successfully broadcasted.')
        setTitle('')
        setBody('')
        fetchAnnouncements()
        setTimeout(() => setMessage(''), 3000)
      } else {
        setMessage('Failed to create announcement.')
      }
    } catch (e) {
      setMessage('Network error.')
    }
  }

  return (
    <AppLayout title="Announcements">
      <div style={{ maxWidth: 1000, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>

        {/* Page Title for Content */}
        <div style={{ marginBottom: 4 }}>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Announcements</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Broadcast system-wide alerts to all members.</p>
        </div>

        <div style={{ display: 'flex', gap: 6, background: 'var(--bg-surface)', borderRadius: 10, padding: 3 }}>
          {[
            { id: 'create', label: 'New Broadcast', icon: 'campaign' },
            { id: 'history', label: 'History', icon: 'history' }
          ].map(t => (
            <button key={t.id} onClick={() => setActiveTab(t.id)} style={{
              flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
              padding: '8px 12px', borderRadius: 8, border: 'none', cursor: 'pointer',
              fontWeight: 700, fontSize: '0.8rem',
              background: activeTab === t.id ? 'var(--brand-primary)' : 'transparent',
              color: activeTab === t.id ? '#fff' : 'var(--text-secondary)',
              transition: 'all 0.2s'
            }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>{t.icon}</span>
              {t.label}
            </button>
          ))}
        </div>

        {activeTab === 'create' ? (
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
                      { value: 'General', label: 'General Announcement' },
                      { value: 'Urgent Alert', label: 'Urgent Alert' },
                      { value: 'System Maintenance', label: 'Maintenance' },
                      { value: 'Event', label: 'Event Notice' }
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
                  <textarea required value={body} onChange={e => setBody(e.target.value)} rows="4" placeholder="Broadcast details..." style={{ padding: '10px 12px', fontSize: '0.9rem', borderRadius: 8, border: '1.5px solid var(--border-default)', outline: 'none' }}></textarea>
                </div>
                <button type="submit" className="btn btn-primary btn-full" style={{ height: 48, fontSize: '0.9rem' }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>send</span> Broadcast Now
                </button>
              </form>
            </div>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {announcements.map((ann, i) => (
              <div key={i} className="feed-card" style={{ padding: '14px 16px', borderRadius: 12 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                  <span className={`badge ${ann.category === 'Urgent Alert' ? 'badge-danger' : 'badge-info'}`} style={{ fontSize: '0.6rem' }}>
                    {ann.category}
                  </span>
                  <span style={{ fontSize: '0.7rem', color: 'var(--text-muted)' }}>{new Date(ann.created_at).toLocaleDateString()}</span>
                </div>
                <div style={{ fontWeight: 800, color: 'var(--text-primary)', fontSize: '0.95rem', marginBottom: 4 }}>{ann.title}</div>
                <p style={{ margin: 0, fontSize: '0.8rem', color: 'var(--text-secondary)', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden', lineHeight: 1.4 }}>{ann.body}</p>
                <div style={{ marginTop: 10, paddingTop: 10, borderTop: '1px solid var(--border-subtle)', fontSize: '0.7rem', color: 'var(--text-muted)' }}>
                  Posted by: <strong>{ann.posted_by}</strong>
                </div>
              </div>
            ))}
            {announcements.length === 0 && (
              <div className="card" style={{ padding: 40, textAlign: 'center' }}>
                <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>No broadcast history.</p>
              </div>
            )}
          </div>
        )}
      </div>
    </AppLayout>
  )
}
