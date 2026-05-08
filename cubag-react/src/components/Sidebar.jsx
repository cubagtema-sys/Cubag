import { useState, useEffect } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'

const ALL_NAV_ITEMS = [
  {
    section: 'Main',
    items: [
      { to: '/dashboard',      icon: 'home',             label: 'Dashboard',       isPrimary: true },
      { to: '/announcements',  icon: 'campaign',         label: 'Announcements',   isPrimary: true },
      { to: '/events',         icon: 'event',            label: 'Events' },
    ],
  },
  {
    section: 'Member Services',
    items: [
      { to: '/networking',     icon: 'groups',           label: 'Networking',      isPrimary: true },
      { to: '/messaging',      icon: 'chat_bubble',      label: 'Messages' },
      { to: '/payments',       icon: 'payments',         label: 'Payments',        isPrimary: true },
      { to: '/payment-history', icon: 'receipt_long',     label: 'Payment History' },
      { to: '/tasks',          icon: 'task_alt',         label: 'Tasks & Compliance' },
      { to: '/surveys',        icon: 'how_to_vote',      label: 'Surveys & Elections' },
      { to: '/license-renewal',icon: 'badge',            label: 'Receipts & Licenses' },
    ],
  },
  {
    section: 'Data & Analytics',
    items: [
      { to: '/live-data',      icon: 'cell_tower',       label: 'Live Logistics Data' },
      { to: '/cargo-schedules',icon: 'directions_boat',  label: 'Cargo Schedules' },
    ],
  },
  {
    section: 'Support & Settings',
    items: [
      { to: '/engagement',     icon: 'support_agent',    label: 'Contact Support' },
      { to: '/settings',       icon: 'settings',         label: 'Settings' },
      { to: '/profile',        icon: 'account_circle',   label: 'My Profile',      isPrimary: true },
    ],
  }
]

const ADMIN_NAV_ITEMS = [
  {
    section: 'Core Management',
    items: [
      { to: '/admin',                  icon: 'admin_panel_settings', label: 'Admin Hub', isPrimary: true },
      { to: '/admin/members',          icon: 'group',                label: 'Members' },
      { to: '/admin/announcements',    icon: 'campaign',             label: 'Announcements' },
      { to: '/admin/public-materials', icon: 'file_download',        label: 'Public Materials' },
    ],
  },
  {
    section: 'Operations & Support',
    items: [
      { to: '/admin/cargo-schedules',  icon: 'local_shipping',       label: 'Cargo Schedules' },
      { to: '/admin/intelligence',      icon: 'cell_tower',           label: 'Intelligence Hub' },
      { to: '/admin/tickets',          icon: 'confirmation_number',  label: 'Support Tickets' },
      { to: '/admin/tasks',            icon: 'assignment_add',       label: 'Task & Compliance' },
    ],
  },
  {
    section: 'Financials & Records',
    items: [
      { to: '/admin/payments',         icon: 'account_balance',      label: 'Financial Center' },
      { to: '/admin/payment-settings', icon: 'payments',             label: 'Payment Settings' },
      { to: '/admin/fees',             icon: 'request_quote',        label: 'Platform Fees' },
    ],
  },
  {
    section: 'Engagement & Events',
    items: [
      { to: '/admin/events',           icon: 'event',                label: 'Events & Workshops' },
      { to: '/admin/surveys',          icon: 'how_to_vote',          label: 'Surveys & Elections' },
    ],
  }
]

export default function Sidebar({ isOpen, onClose, badgeCount, taskCount }) {
  const [isMobile, setIsMobile] = useState(() => window.innerWidth <= 768)
  const location = useLocation()
  const isAdminRoute = location.pathname.startsWith('/admin')

  // Find which section contains the currently active route
  const findActiveSection = (pathname) => {
    const navItems = isAdminRoute ? ADMIN_NAV_ITEMS : ALL_NAV_ITEMS
    for (const group of navItems) {
      if (group.items.some(item => item.to === pathname)) {
        return group.section
      }
    }
    return navItems[0]?.section ?? null
  }

  // Accordion: open the section containing current route. null = collapsed
  const [openSection, setOpenSection] = useState(() => {
    if (window.innerWidth <= 768) return null
    return findActiveSection(window.location.pathname)
  })

  useEffect(() => {
    const handleResize = () => setIsMobile(window.innerWidth <= 768)
    window.addEventListener('resize', handleResize)
    return () => window.removeEventListener('resize', handleResize)
  }, [])

  // Whenever the route changes, expand the section that owns the new page
  useEffect(() => {
    if (!isMobile) {
      setOpenSection(findActiveSection(location.pathname))
    }
  }, [location.pathname])

  // When switching between admin <-> member portal, re-derive active section
  useEffect(() => {
    setOpenSection(isMobile ? null : findActiveSection(location.pathname))
  }, [isAdminRoute])

  const toggleSection = (section) => {
    setOpenSection(prev => prev === section ? null : section)
  }

  // Inject dynamic badge counts
  const baseNavItems = isAdminRoute ? ADMIN_NAV_ITEMS : ALL_NAV_ITEMS
  const navItems = baseNavItems.map(section => ({
    ...section,
    items: section.items.map(item => {
      if (item.to === '/announcements') return { ...item, badge: badgeCount > 0 ? badgeCount : null }
      if (item.to === '/tasks') return { ...item, badge: taskCount > 0 ? taskCount : null, badgeColor: 'var(--brand-warning)' }
      return item
    })
  }))

  // On mobile the bottom nav already covers primary items — but keep all in sidebar for discoverability
  const displayNavGroups = navItems.filter(group => group.items.length > 0)

  return (
    <>
      {/* Overlay for mobile */}
      {isOpen && (
        <div
          onClick={onClose}
          style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.4)', zIndex: 99 }}
        />
      )}

      <aside className={`sidebar ${isOpen ? 'open' : ''}`}>
        {/* Brand */}
        <div style={{ padding: '16px 12px', borderBottom: '1px solid var(--border-subtle)', textAlign: 'center', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '6px' }}>
          <Link to={isAdminRoute ? '/admin' : '/'} style={{ textDecoration: 'none', display: 'flex', flexDirection: 'column', alignItems: 'center' }} onClick={onClose}>
            <img src="/logo.jpeg" alt="CUBAG" style={{ height: '40px', width: '40px', borderRadius: '10px', objectFit: 'cover', boxShadow: 'var(--shadow-sm)', marginBottom: '2px' }}
              onError={e => { e.target.style.display = 'none' }} />
            <span style={{ fontSize: '0.95rem', color: 'var(--text-primary)', letterSpacing: '0.01em', fontWeight: 700 }}>CUBAG</span>
            <span style={{ fontSize: '0.6rem', color: isAdminRoute ? '#ef4444' : 'var(--brand-primary)', textTransform: 'uppercase', letterSpacing: '0.04em', fontWeight: 800 }}>
              {isAdminRoute ? 'Admin Control' : 'Enterprise Platform'}
            </span>
          </Link>
        </div>

        {/* Nav */}
        <nav className="sidebar-nav" style={{ flex: 1, overflowY: 'auto', paddingBottom: '60px', padding: '12px 8px' }}>
          {displayNavGroups.map(group => {
            const isExpanded = openSection === group.section
            return (
              <div key={group.section} style={{ marginBottom: '2px' }}>
                {/* Section Header — clickable toggle */}
                <div
                  className="nav-section-label"
                  onClick={() => toggleSection(group.section)}
                  style={{
                    cursor: 'pointer',
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center',
                    padding: '8px 12px',
                    userSelect: 'none',
                    WebkitUserSelect: 'none',
                    fontSize: '0.6rem',
                    letterSpacing: '0.05em'
                  }}
                >
                  <span>{group.section}</span>
                  <span
                    className="material-symbols-outlined"
                    style={{
                      fontSize: '1rem',
                      transition: 'transform 0.25s ease',
                      transform: isExpanded ? 'rotate(180deg)' : 'rotate(0deg)',
                      color: 'var(--text-muted)',
                    }}
                  >
                    expand_more
                  </span>
                </div>

                {/* Collapsible content — use grid trick for reliable animation */}
                <div style={{
                  display: 'grid',
                  gridTemplateRows: isExpanded ? '1fr' : '0fr',
                  transition: 'grid-template-rows 0.28s ease',
                }}>
                  <div style={{ overflow: 'hidden' }}>
                    {group.items.map(item => (
                      <Link
                        key={item.to}
                        to={item.to}
                        className={`sidebar-nav-item ${location.pathname === item.to ? 'active' : ''}`}
                        onClick={onClose}
                      >
                        <span className="nav-icon material-symbols-outlined">{item.icon}</span>
                        <span style={{ flex: 1, minWidth: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {item.label}
                        </span>
                        {item.badge && (
                          <span className="nav-badge" style={item.badgeColor ? { background: item.badgeColor } : {}}>
                            {item.badge}
                          </span>
                        )}
                      </Link>
                    ))}
                  </div>
                </div>
              </div>
            )
          })}
        </nav>
      </aside>
    </>
  )
}
