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
      const res = await fetch(`${import.meta.env.VITE_API_URL}/announcements/admin/all`)
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
    <AppLayout title="Announcements Management">
      <div style={{ maxWidth: 1000, margin: '0 auto', padding: '24px 16px', display: 'flex', flexDirection: 'column', gap: 24 }}>
        <div>
          <h2 style={{ fontSize: '1.5rem', marginBottom: 8, display: 'flex', alignItems: 'center', gap: 8 }}>
            <span className="material-symbols-outlined" style={{ color: 'var(--brand-primary)' }}>campaign</span>
            Broadcast Announcements
          </h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '0.95rem' }}>Send critical alerts and system-wide announcements to all platform members.</p>
        </div>

        <div style={{ display: 'flex', gap: '16px', marginBottom: '24px' }}>
          <button 
            className={`btn ${activeTab === 'create' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => setActiveTab('create')}
          >
            Create Announcement
          </button>
          <button 
            className={`btn ${activeTab === 'history' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => setActiveTab('history')}
          >
            Broadcast History
          </button>
        </div>

        {activeTab === 'create' ? (
          <div className="card" style={{ maxWidth: '600px', margin: '0 auto' }}>
            <h3 style={{ marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <span className="material-symbols-outlined">campaign</span>
              New Broadcast
            </h3>
            {message && (
              <div style={{ padding: '12px', background: message.includes('success') ? 'var(--brand-success)' : 'var(--brand-danger)', color: '#fff', borderRadius: 'var(--radius-md)', marginBottom: '16px', fontSize: '0.9rem' }}>
                {message}
              </div>
            )}
            <form onSubmit={handleSubmit}>
              <div className="form-group" style={{ zIndex: 10 }}>
                <CustomSelect 
                  label="Category"
                  options={[
                    { value: 'General', label: 'General' },
                    { value: 'Urgent Alert', label: 'Urgent Alert' },
                    { value: 'System Maintenance', label: 'System Maintenance' },
                    { value: 'Event', label: 'Event' }
                  ]}
                  value={category} 
                  onChange={setCategory}
                />
              </div>
              <div className="form-group" style={{ marginTop: '16px' }}>
                <label>Title</label>
                <input type="text" required value={title} onChange={e => setTitle(e.target.value)} placeholder="e.g. Server Maintenance Notice" />
              </div>
              <div className="form-group">
                <label>Message Body</label>
                <textarea required value={body} onChange={e => setBody(e.target.value)} rows="5" placeholder="Enter the full announcement details here..."></textarea>
              </div>
              <button type="submit" className="btn btn-primary btn-full" style={{ marginTop: '16px' }}>
                <span className="material-symbols-outlined">send</span> Send Broadcast
              </button>
            </form>
          </div>
        ) : (
          <div className="card">
            <h3 style={{ marginBottom: '16px' }}>Broadcast History</h3>
            <div className="responsive-table-wrapper">
              <table className="responsive-table" style={{ width: '100%', textAlign: 'left', borderCollapse: 'collapse' }}>
                <thead>
                  <tr style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Date</th>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Category</th>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Title</th>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Author</th>
                  </tr>
                </thead>
                <tbody>
                  {announcements.map((ann, i) => (
                    <tr key={i} style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                      <td data-label="Date" style={{ padding: '12px', fontSize: '0.9rem', color: 'var(--text-secondary)' }}>{new Date(ann.created_at).toLocaleString()}</td>
                      <td data-label="Category" style={{ padding: '12px' }}>
                        <span className={`badge ${ann.category === 'Urgent Alert' ? 'badge-danger' : 'badge-info'}`}>
                          {ann.category}
                        </span>
                      </td>
                      <td data-label="Title" style={{ padding: '12px', fontSize: '0.9rem', fontWeight: 600 }}>{ann.title}</td>
                      <td data-label="Author" style={{ padding: '12px', fontSize: '0.9rem', color: 'var(--text-secondary)' }}>{ann.posted_by}</td>
                    </tr>
                  ))}
                  {announcements.length === 0 && (
                    <tr>
                      <td colSpan="4" style={{ padding: '24px', textAlign: 'center', color: 'var(--text-muted)' }}>No announcements found.</td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </div>
    </AppLayout>
  )
}
