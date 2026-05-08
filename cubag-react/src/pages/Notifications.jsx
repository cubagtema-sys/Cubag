import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'
import CustomSelect from '../components/CustomSelect'

const CATEGORIES = {
  payment: { icon: 'payments', color: '#10b981', label: 'Payment' },
  meeting: { icon: 'event', color: '#3b82f6', label: 'Meeting' },
  compliance: { icon: 'task_alt', color: '#f59e0b', label: 'Compliance' },
  system: { icon: 'info', color: 'var(--brand-primary)', label: 'System' },
  announcement: { icon: 'campaign', color: '#8b5cf6', label: 'Announcement' },
}

const FILTER_OPTIONS = [
  { value: 'all', label: 'All Notifications' },
  { value: 'unread', label: 'Unread Only' },
  { value: 'payment', label: 'Payment' },
  { value: 'meeting', label: 'Meeting' },
  { value: 'compliance', label: 'Compliance' },
  { value: 'announcement', label: 'Announcement' },
]

export default function Notifications() {
  const [notifications, setNotifications] = useState([])
  const [filter, setFilter] = useState('all')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function fetchNotifications() {
      try {
        const res = await fetch(`${import.meta.env.VITE_API_URL}/announcements`, {
          headers: { 'Authorization': `Bearer ${localStorage.getItem('cubag_token')}` }
        })
        if (res.ok) {
          const data = await res.json()
          // Map backend announcements to notifications
          const mapped = data.map(ann => ({
            id: ann.id,
            type: ann.category ? ann.category.toLowerCase() : 'announcement',
            title: ann.title,
            message: ann.body,
            time: new Date(ann.created_at).toLocaleDateString(),
            read: true // Since backend doesn't track read status per user yet, assume read or implement local storage track
          }))
          setNotifications(mapped)
        }
      } catch (e) {
        console.error(e)
      } finally {
        setLoading(false)
      }
    }
    fetchNotifications()
  }, [])

  const unreadCount = notifications.filter(n => !n.read).length

  const markAllRead = () => setNotifications(prev => prev.map(n => ({ ...n, read: true })))
  const markRead = (id) => setNotifications(prev => prev.map(n => n.id === id ? { ...n, read: true } : n))
  const deleteNotif = (id) => setNotifications(prev => prev.filter(n => n.id !== id))

  const filtered = filter === 'all' ? notifications : filter === 'unread' ? notifications.filter(n => !n.read) : notifications.filter(n => n.type === filter)

  return (
    <AppLayout title="Notifications">
      <div style={{ maxWidth: 750, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>
        
        {/* Page Title for Content */}
        <div style={{ marginBottom: 4 }}>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Activity Feed</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Latest system alerts and personal notifications.</p>
        </div>

        {/* Header Controls - Compact */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ width: '200px' }}>
            <CustomSelect
              value={filter}
              onChange={setFilter}
              options={FILTER_OPTIONS}
              icon="filter_list"
            />
          </div>
          {unreadCount > 0 && (
            <button onClick={markAllRead} style={{ background: 'none', border: 'none', color: 'var(--brand-primary)', cursor: 'pointer', fontWeight: 700, fontSize: '0.75rem' }}>
              Clear Unread
            </button>
          )}
        </div>

        {/* Notifications List */}
        {loading ? (
          <div style={{ textAlign: 'center', padding: 40, color: 'var(--text-muted)', fontSize: '0.8rem' }}>Syncing feed...</div>
        ) : filtered.length === 0 ? (
          <div className="card" style={{ padding: '60px 20px', textAlign: 'center', borderRadius: 12 }}>
            <span className="material-symbols-outlined" style={{ fontSize: '3rem', color: 'var(--text-muted)', marginBottom: 12 }}>notifications_none</span>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>No notifications yet.</p>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {filtered.map(notif => {
              const cat = CATEGORIES[notif.type] || CATEGORIES.system
              return (
                <div key={notif.id} onClick={() => markRead(notif.id)} className="feed-card" style={{
                  display: 'flex', gap: 12, padding: '14px 16px', cursor: 'pointer', borderRadius: 12,
                  borderLeft: notif.read ? 'none' : `3px solid ${cat.color}`,
                  opacity: notif.read ? 0.7 : 1, transition: 'all 0.2s'
                }}>
                  <div style={{ width: 36, height: 36, borderRadius: 10, background: `${cat.color}15`, color: cat.color, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                    <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>{cat.icon}</span>
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 2 }}>
                      <div style={{ display: 'flex', gap: 6, alignItems: 'center', minWidth: 0 }}>
                        <span style={{ fontWeight: 800, fontSize: '0.9rem', color: 'var(--text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{notif.title}</span>
                      </div>
                      <span style={{ fontSize: '0.65rem', color: 'var(--text-muted)', flexShrink: 0, marginLeft: 10 }}>{notif.time.split(',')[0]}</span>
                    </div>
                    <p style={{ fontSize: '0.8rem', color: 'var(--text-secondary)', lineHeight: 1.4, margin: 0, display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>{notif.message}</p>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 8 }}>
                      <span style={{ padding: '2px 8px', borderRadius: 4, background: `${cat.color}15`, color: cat.color, fontSize: '0.6rem', fontWeight: 800, textTransform: 'uppercase' }}>{cat.label}</span>
                      <button onClick={e => { e.stopPropagation(); deleteNotif(notif.id) }} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)', padding: 0, display: 'flex' }}>
                        <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>delete</span>
                      </button>
                    </div>
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
