import { useState, useEffect, useRef } from 'react'
import { Link, useNavigate, useLocation } from 'react-router-dom'
import Sidebar from './Sidebar.jsx'
import { usePushNotifications } from '../hooks/usePushNotifications'
import { mapUser, getStoredUser, saveUser } from '../utils/user'

export default function AppLayout({ children, title, hideSearch }) {
  const [sidebarOpen, setSidebarOpen] = useState(false)

  // Initialize Push Notifications
  usePushNotifications();

  const [dropdownOpen, setDropdownOpen] = useState(false)
  const [isDarkMode, setIsDarkMode] = useState(() => localStorage.getItem('cubag_theme') === 'dark')
  const [notifCount, setNotifCount] = useState(0)
  const [taskCount, setTaskCount] = useState(0)
  const [isOffline, setIsOffline] = useState(false)
  // Initialize photo from localStorage immediately — no waiting for /me fetch
  const [userPhoto, setUserPhoto] = useState(() => {
    const u = getStoredUser()
    return u?.photo || u?.profile_photo || null
  })
  const failCount = useRef(0)
  const navigate = useNavigate()
  const location = useLocation()

  useEffect(() => {
    const url = import.meta.env.VITE_API_URL
    const authHeader = () => ({ 'Authorization': `Bearer ${localStorage.getItem('cubag_token')}` })

    // ── 1. Profile photo + expiry — runs FIRST, independently ────────────
    async function fetchProfile() {
      try {
        const res = await fetch(`${url}/auth/me`, { headers: authHeader() })
        if (res.ok) {
          const me = await res.json()
          const currentUser = getStoredUser()
          const updatedUser = mapUser(me, currentUser || {})
          if (JSON.stringify(currentUser) !== JSON.stringify(updatedUser)) {
            saveUser(updatedUser)
          }
          const photo = updatedUser.photo || updatedUser.profile_photo
          if (photo) setUserPhoto(photo)
        }
      } catch (e) {
        console.warn('[AppLayout] Profile fetch failed:', e)
      }
    }

    // ── 2. Notification counts — separate, can fail without blocking photo
    async function fetchCounts() {
      try {
        const annRes = await fetch(`${url}/announcements`, { headers: authHeader() })
        if (annRes.ok) {
          const data = await annRes.json()
          if (Array.isArray(data)) {
            try {
              const readIds = new Set(JSON.parse(localStorage.getItem('cubag_read_announcements') || '[]'))
              setNotifCount(data.filter(a => !readIds.has(a.id)).length)
            } catch {
              setNotifCount(data.length)
            }
          }
        }
      } catch {}

      try {
        const taskRes = await fetch(`${url}/tasks/summary`, { headers: authHeader() })
        if (taskRes.ok) {
          const data = await taskRes.json()
          if (Array.isArray(data)) setTaskCount(data.filter(t => !t.done).length)
        }
      } catch {}
    }

    async function init() {
      try {
        await fetchProfile()
        await fetchCounts()
        failCount.current = 0
        setIsOffline(false)
      } catch {
        failCount.current += 1
        if (failCount.current >= 2) setIsOffline(true)
      }
    }

    init()
    const id = setInterval(init, 60000)
    return () => clearInterval(id)
  }, [])


  useEffect(() => {
    const theme = isDarkMode ? 'dark' : 'light'
    document.documentElement.setAttribute('data-theme', theme)
    localStorage.setItem('cubag_theme', theme)
  }, [isDarkMode])

  const toggleDarkMode = () => setIsDarkMode(!isDarkMode)

  let user = getStoredUser() || { name: 'Member', role: 'Member' }

  // Use reactive photo — initialized from localStorage, updated by /me fetch
  const displayPhoto = userPhoto || user.photo || user.profile_photo || null


  const isAdminRoute = location.pathname.startsWith('/admin')

  const initials = (user.name || 'M').split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)

  const handleLogout = () => {
    localStorage.removeItem('cubag_user')
    localStorage.removeItem('cubag_token')
    navigate('/login')
  }

  const MEMBER_BOTTOM_NAV = [
    { to: '/dashboard',       icon: 'home',           label: 'Home' },
    { to: '/networking',      icon: 'groups',         label: 'Network' },
    { to: '/payments',        icon: 'payments',       label: 'Payments' },
    { to: '/profile',         icon: 'account_circle', label: 'Profile' }
  ].map(item => {
    // For inactive users, swap "Network" with "Announcements" to keep 4 icons
    if (user.status !== 'active' && item.to === '/networking') {
      return { to: '/announcements', icon: 'campaign', label: 'Alerts' }
    }
    return item
  })

  const ADMIN_BOTTOM_NAV = [
    { to: '/admin',                  icon: 'admin_panel_settings', label: 'Hub' },
    { to: '/admin/payments',         icon: 'payments',             label: 'Payments' },
    { to: '/admin/license-renewal',  icon: 'fact_check',           label: 'Licenses' },
    { to: '/admin/tickets',          icon: 'confirmation_number',  label: 'Tickets' },
    { to: '/admin/members',          icon: 'group',                label: 'Members' }
  ]

  const BOTTOM_NAV = isAdminRoute ? ADMIN_BOTTOM_NAV : MEMBER_BOTTOM_NAV

  return (
    <div className="app-layout">
      {/* Visual Flashes */}
      <div className="ambient-glow glow-1" />
      <div className="ambient-glow glow-2" />
      <div key={location.key} className="page-flash" />

      <Sidebar 
        isOpen={sidebarOpen} 
        onClose={() => setSidebarOpen(false)} 
        badgeCount={notifCount}
        taskCount={taskCount}
      />

      <main className="main-content">
        {/* Top Header */}
        <header className="top-header">
          <div className="header-left">
            <button
              className="mobile-menu-btn"
              onClick={() => setSidebarOpen(o => !o)}
              aria-label="Menu"
            >
              <span className="material-symbols-outlined" style={{ fontSize: '1.4rem', lineHeight: 1 }}>menu</span></button>
          </div>

          <div className="header-right">
            {!isAdminRoute && (
              <button
                className="icon-btn"
                onClick={() => navigate('/announcements')}
                title="Notifications"
                style={{ color: 'var(--text-primary)' }}
              >
                <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>notifications</span>
                {notifCount > 0 && <span className="notif-badge">{notifCount}</span>}
              </button>
            )}
            
            {/* User Dropdown Wrapper */}
            <div style={{ position: 'relative' }}>
              <div
                className="user-avatar"
                style={{
                  cursor: 'pointer',
                  overflow: 'hidden',
                  background: isAdminRoute ? '#ef4444' : 'var(--gradient-brand)',
                  width: '32px', /* Reduced from default */
                  height: '32px',
                  fontSize: '0.8rem'
                }}
                onClick={() => setDropdownOpen(!dropdownOpen)}
                title="Account Settings"
              >
                {!isAdminRoute && displayPhoto ? (
                  <img src={displayPhoto} alt="Me" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                ) : (
                  isAdminRoute ? 'AD' : initials
                )}
              </div>

              {dropdownOpen && (
                <>
                  <div 
                    onClick={() => setDropdownOpen(false)} 
                    style={{ position: 'fixed', inset: 0, zIndex: 999 }}
                  />
                  <div style={{
                    position: 'absolute',
                    top: '100%',
                    right: 0,
                    marginTop: '8px',
                    width: '210px',
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-subtle)',
                    borderRadius: 'var(--radius-md)',
                    boxShadow: 'var(--shadow-lg)',
                    zIndex: 1000,
                    padding: '8px 0',
                    animation: 'fadeInUp 0.2s ease-out'
                  }}>
                    <div style={{ padding: '12px 16px', borderBottom: '1px solid var(--border-subtle)', marginBottom: '4px' }}>
                      <div style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '0.9rem' }}>
                        {isAdminRoute ? 'System Administrator' : user.name}
                      </div>
                      <div style={{ fontSize: '0.75rem', color: isAdminRoute ? '#ef4444' : 'var(--text-muted)' }}>
                        {isAdminRoute ? 'Platform Admin' : user.role}
                      </div>
                    </div>
                    
                    {!isAdminRoute && (
                      <Link to="/profile" onClick={() => setDropdownOpen(false)} style={{ display: 'flex', alignItems: 'center', gap: '10px', padding: '10px 16px', textDecoration: 'none', color: 'var(--text-secondary)', fontSize: '0.9rem' }}>
                        <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>person</span> My Profile
                      </Link>
                    )}
                    
                    <Link to={isAdminRoute ? '/admin/settings' : '/settings'} onClick={() => setDropdownOpen(false)} style={{ display: 'flex', alignItems: 'center', gap: '10px', padding: '10px 16px', textDecoration: 'none', color: 'var(--text-secondary)', fontSize: '0.9rem' }}>
                      <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>settings</span> {isAdminRoute ? 'Admin Settings' : 'Settings'}
                    </Link>

                    <div onClick={toggleDarkMode} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '10px 16px', cursor: 'pointer', color: 'var(--text-secondary)', fontSize: '0.9rem' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                        <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>{isDarkMode ? 'light_mode' : 'dark_mode'}</span>
                        {isDarkMode ? 'Light Mode' : 'Dark Mode'}
                      </div>
                      <div style={{ 
                        width: '32px', height: '18px', background: isDarkMode ? 'var(--brand-primary)' : 'var(--text-muted)', borderRadius: '20px', position: 'relative', transition: 'background 0.3s'
                      }}>
                        <div style={{ 
                          position: 'absolute', top: '2px', left: isDarkMode ? '16px' : '2px', width: '14px', height: '14px', background: '#fff', borderRadius: '50%', transition: 'left 0.3s' 
                        }} />
                      </div>
                    </div>
                    
                    <div style={{ height: '1px', background: 'var(--border-subtle)', margin: '4px 0' }} />
                    
                    <div onClick={handleLogout} style={{ display: 'flex', alignItems: 'center', gap: '10px', padding: '10px 16px', cursor: 'pointer', color: 'var(--brand-danger)', fontSize: '0.9rem' }}>
                      <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>logout</span> Sign Out
                    </div>
                  </div>
                </>
              )}
            </div>
          </div>
        </header>

        {/* Connection lost banner */}
        {isOffline && (
          <div style={{
            background: '#ef4444', color: 'white',
            padding: '8px 20px', textAlign: 'center', fontSize: '0.85rem',
            fontWeight: 600, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8
          }}>
            <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>wifi_off</span>
            Connection lost — trying to reconnect…
          </div>
        )}

        {/* Page content */}
        <div className="page-body">
          {children}
        </div>

        {/* Mobile Bottom Navigation */}
        <nav className="mobile-bottom-nav">
          {BOTTOM_NAV.map(item => (
            <Link 
              key={item.to} 
              to={item.to} 
              className={`mobile-nav-item ${location.pathname === item.to ? 'active' : ''}`}
            >
              <span className={`mobile-nav-icon ${item.icon.length > 2 ? 'material-symbols-outlined' : ''}`}>{item.icon}</span>
              <span>{item.label}</span>
            </Link>
          ))}
        </nav>
      </main>
    </div>
  )
}
