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
      <div style={{ maxWidth: 750, margin: '0 auto' }}>
        
        {/* Header Controls */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
          <div style={{ width: '250px' }}>
            <CustomSelect
              value={filter}
              onChange={setFilter}
              options={FILTER_OPTIONS}
              icon="filter_list"
            />
          </div>
          {unreadCount > 0 && (
            <button onClick={markAllRead} style={{ background: 'none', border: 'none', color: 'var(--brand-primary)', cursor: 'pointer', fontWeight: 700, fontSize: '0.85rem' }}>
              Mark all read
            </button>
          )}
        </div>

        {/* Notifications List */}
        {loading ? (
          <div style={{ textAlign: 'center', padding: 40, color: 'var(--text-muted)' }}>Loading...</div>
        ) : filtered.length === 0 ? (
          <div className="feed-card" style={{ padding: '60px 20px', textAlign: 'center' }}>
            <span className="material-symbols-outlined" style={{ fontSize: '4rem', color: 'var(--text-muted)', marginBottom: 16 }}>notifications_none</span>
            <h3 style={{ color: 'var(--text-primary)' }}>No Notifications</h3>
            <p style={{ color: 'var(--text-secondary)' }}>You're all caught up!</p>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {filtered.map(notif => {
              const cat = CATEGORIES[notif.type] || CATEGORIES.system
              return (
                <div key={notif.id} onClick={() => markRead(notif.id)} className="feed-card" style={{
                  display: 'flex', gap: 16, padding: '18px 20px', cursor: 'pointer',
                  borderLeft: notif.read ? '4px solid transparent' : `4px solid ${cat.color}`,
                  opacity: notif.read ? 0.75 : 1, transition: 'all 0.2s'
                }}>
                  <div style={{ width: 44, height: 44, borderRadius: 12, background: `${cat.color}15`, color: cat.color, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                    <span className="material-symbols-outlined">{cat.icon}</span>
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                      <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                        <span style={{ fontWeight: 800, fontSize: '0.95rem', color: 'var(--text-primary)' }}>{notif.title}</span>
                        {!notif.read && <span style={{ width: 8, height: 8, borderRadius: '50%', background: cat.color, flexShrink: 0 }}></span>}
                      </div>
                      <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', flexShrink: 0 }}>{notif.time}</span>
                    </div>
                    <p style={{ fontSize: '0.88rem', color: 'var(--text-secondary)', lineHeight: 1.5 }}>{notif.message}</p>
                    <span style={{ display: 'inline-block', marginTop: 8, padding: '2px 10px', borderRadius: 12, background: `${cat.color}15`, color: cat.color, fontSize: '0.72rem', fontWeight: 700 }}>{cat.label}</span>
                  </div>
                  <button onClick={e => { e.stopPropagation(); deleteNotif(notif.id) }} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)', padding: 4, flexShrink: 0 }}>
                    <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>close</span>
                  </button>
                </div>
              )
            })}
          </div>
        )}
      </div>
    </AppLayout>
  )
}
