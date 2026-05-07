import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'
import CustomSelect from '../components/CustomSelect'

const API_URL = import.meta.env.VITE_API_URL

const STATUS_STYLE = {
  active:  { bg: 'rgba(16,185,129,0.1)',  color: '#10b981', label: 'Active' },
  pending: { bg: 'rgba(245,158,11,0.1)',  color: '#f59e0b', label: 'Pending' },
  inactive:{ bg: 'rgba(100,116,139,0.1)', color: '#64748b', label: 'Inactive' },
  suspended:{ bg:'rgba(239,68,68,0.1)',   color: '#ef4444', label: 'Suspended' },
}

const TYPE_COLORS = {
  'Corporate Agency':  '#3b82f6',
  'Individual Broker': '#f08232',
  'Freight Forwarder': '#10b981',
  'Shipping Line':     '#8b5cf6',
}

const getInitials = (name = '') =>
  name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)

export default function AdminMembers() {
  const [members, setMembers] = useState([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [filterStatus, setFilterStatus] = useState('all')
  const [selected, setSelected] = useState(null)
  const [updating, setUpdating] = useState(false)

  const token = localStorage.getItem('cubag_token')

  const fetchMembers = async () => {
    setLoading(true)
    try {
      const res = await fetch(`${API_URL}/members/admin/all`, {
        headers: { Authorization: `Bearer ${token}` }
      })
      const data = await res.json()
      setMembers(Array.isArray(data) ? data : [])
    } catch {
      setMembers([])
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchMembers() }, [])

  const updateStatus = async (id, newStatus) => {
    setUpdating(true)
    try {
      await fetch(`${API_URL}/members/admin/status/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ status: newStatus })
      })
      // Update local state immediately
      setMembers(prev => prev.map(m => m.id === id ? { ...m, status: newStatus } : m))
      if (selected?.id === id) setSelected(s => ({ ...s, status: newStatus }))
    } catch {
    } finally {
      setUpdating(false)
    }
  }

  const filtered = members.filter(m => {
    const q = search.toLowerCase()
    const matchSearch = (m.name || '').toLowerCase().includes(q) ||
                        (m.company || '').toLowerCase().includes(q) ||
                        (m.email || '').toLowerCase().includes(q) ||
                        (m.license_number || '').toLowerCase().includes(q)
    const matchStatus = filterStatus === 'all' || m.status === filterStatus
    return matchSearch && matchStatus
  })

  const stats = {
    total:   members.length,
    active:  members.filter(m => m.status === 'active').length,
    pending: members.filter(m => m.status === 'pending').length,
    inactive: members.filter(m => m.status === 'inactive').length,
    suspended: members.filter(m => m.status === 'suspended').length,
  }

  const FILTER_OPTIONS = [
    { value: 'all', label: `All (${stats.total})`, icon: 'filter_list' },
    { value: 'active', label: `Active (${stats.active})`, icon: 'verified_user' },
    { value: 'pending', label: `Pending (${stats.pending})`, icon: 'pending_actions' },
    { value: 'inactive', label: `Inactive (${stats.inactive})`, icon: 'do_not_disturb_on' },
    { value: 'suspended', label: `Suspended (${stats.suspended})`, icon: 'block' },
  ]

  return (
    <AppLayout title="Members">
      <div style={{ maxWidth: 1000, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 24 }}>

        {/* Header */}
        <div>
          <h2 style={{ margin: 0, fontSize: '1.4rem' }}>Registered Members</h2>
          <p style={{ margin: '4px 0 0', color: 'var(--text-muted)', fontSize: '0.88rem' }}>
            View and manage all CUBAG registered members.
          </p>
        </div>

        {/* KPI Strip */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: 14 }}>
          {[
            { label: 'Total Members', value: stats.total,   icon: 'group',           color: '#3b82f6' },
            { label: 'Active',        value: stats.active,  icon: 'verified_user',    color: '#10b981' },
            { label: 'Pending',       value: stats.pending, icon: 'pending_actions',  color: '#f59e0b' },
          ].map(k => (
            <div key={k.label} className="card" style={{ padding: '16px 18px', display: 'flex', gap: 14, alignItems: 'center' }}>
              <div style={{ width: 44, height: 44, borderRadius: 12, background: `${k.color}18`, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <span className="material-symbols-outlined" style={{ color: k.color, fontSize: '1.3rem' }}>{k.icon}</span>
              </div>
              <div>
                <div style={{ fontSize: '1.5rem', fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1 }}>{loading ? '…' : k.value}</div>
                <div style={{ fontSize: '0.72rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, marginTop: 3 }}>{k.label}</div>
              </div>
            </div>
          ))}
        </div>

        {/* Search + Status Filter */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16, marginBottom: 10 }}>
          <div style={{ position: 'relative', width: '100%' }}>
            <span className="material-symbols-outlined" style={{ position: 'absolute', left: 14, top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }}>search</span>
            <input
              type="text"
              placeholder="Search by name, email, company or license..."
              value={search}
              onChange={e => setSearch(e.target.value)}
              style={{ width: '100%', padding: '14px 14px 14px 44px', borderRadius: 12, border: '1.5px solid var(--border-default)', background: 'var(--bg-surface)', color: 'var(--text-primary)', outline: 'none', fontSize: '0.95rem', boxSizing: 'border-box' }}
            />
          </div>
          <div style={{ width: '100%' }}>
            <CustomSelect
              value={filterStatus}
              onChange={setFilterStatus}
              options={FILTER_OPTIONS}
              icon="filter_alt"
            />
          </div>
        </div>

        {/* Members List */}
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          {loading ? (
            <div style={{ padding: 60, textAlign: 'center', color: 'var(--text-muted)' }}>
              <div className="spinner" style={{ margin: '0 auto 16px' }} />
              Loading members...
            </div>
          ) : filtered.length === 0 ? (
            <div style={{ padding: '60px 24px', textAlign: 'center' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '3rem', color: 'var(--text-muted)', display: 'block', marginBottom: 12 }}>group_off</span>
              <p style={{ color: 'var(--text-muted)' }}>No members found.</p>
            </div>
          ) : (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(min(100%, 280px), 1fr))', gap: 16, padding: '16px 0' }}>
              {filtered.map(m => {
                const statusStyle = STATUS_STYLE[m.status] || STATUS_STYLE.inactive
                const typeColor = TYPE_COLORS[m.member_type] || 'var(--brand-primary)'
                return (
                  <div 
                    key={m.id} 
                    style={{ 
                      background: 'var(--bg-base)', border: '1px solid var(--border-subtle)', borderRadius: 16, 
                      padding: 20, display: 'flex', flexDirection: 'column', gap: 16, cursor: 'pointer', transition: 'all 0.2s', position: 'relative', overflow: 'hidden' 
                    }}
                    onClick={() => setSelected(m)}
                    onMouseEnter={e => { e.currentTarget.style.borderColor = typeColor; e.currentTarget.style.transform = 'translateY(-2px)' }}
                    onMouseLeave={e => { e.currentTarget.style.borderColor = 'var(--border-subtle)'; e.currentTarget.style.transform = 'none' }}
                  >
                    {/* Top Right Status Badge */}
                    <div style={{ position: 'absolute', top: 16, right: 16 }}>
                      <span style={{ fontSize: '0.65rem', fontWeight: 800, color: statusStyle.color, background: statusStyle.bg, padding: '4px 10px', borderRadius: 20, textTransform: 'uppercase' }}>
                        {statusStyle.label}
                      </span>
                    </div>

                    {/* Member Details */}
                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', gap: 10, marginTop: 10 }}>
                      <div style={{ width: 64, height: 64, borderRadius: '50%', background: `${typeColor}15`, border: `2px solid ${typeColor}`, color: typeColor, display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: '1.4rem' }}>
                        {getInitials(m.name)}
                      </div>
                      <div>
                        <div style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '1.05rem' }}>{m.name}</div>
                        <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>{m.email}</div>
                      </div>
                    </div>

                    <div style={{ height: 1, background: 'var(--border-subtle)', margin: '4px 0' }} />

                    {/* Meta Info */}
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Company</span>
                        <span style={{ fontSize: '0.8rem', color: 'var(--text-primary)', fontWeight: 600 }}>{m.company || 'N/A'}</span>
                      </div>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Type</span>
                        <span style={{ fontSize: '0.75rem', fontWeight: 700, color: typeColor }}>{m.member_type || 'Member'}</span>
                      </div>
                    </div>

                    {/* Actions */}
                    <div style={{ display: 'flex', gap: 8, marginTop: 'auto', paddingTop: 8 }} onClick={e => e.stopPropagation()}>
                      <button className="btn btn-sm btn-ghost" style={{ flex: 1, padding: '8px', fontSize: '0.75rem' }} onClick={() => setSelected(m)}>
                        View Profile
                      </button>
                      {m.status === 'pending' && (
                        <button className="btn btn-sm btn-primary" disabled={updating} style={{ flex: 1, padding: '8px', fontSize: '0.75rem' }} onClick={() => updateStatus(m.id, 'active')}>
                          Approve
                        </button>
                      )}
                      {m.status === 'active' && (
                        <button className="btn btn-sm btn-danger" disabled={updating} style={{ flex: 1, padding: '8px', fontSize: '0.75rem' }} onClick={() => updateStatus(m.id, 'suspended')}>
                          Suspend
                        </button>
                      )}
                      {m.status === 'suspended' && (
                        <button className="btn btn-sm btn-outline" disabled={updating} style={{ flex: 1, padding: '8px', fontSize: '0.75rem' }} onClick={() => updateStatus(m.id, 'active')}>
                          Restore
                        </button>
                      )}
                    </div>
                  </div>
                )
              })}
            </div>
          )}
        </div>

        <p style={{ textAlign: 'center', fontSize: '0.8rem', color: 'var(--text-muted)' }}>
          {filtered.length} of {members.length} members shown
        </p>
      </div>

      {/* Member Detail Modal */}
      {selected && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.55)', zIndex: 9999, display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }}
          onClick={() => setSelected(null)}>
          <div style={{ background: 'var(--bg-surface)', borderRadius: '20px 20px 0 0', width: '100%', maxWidth: 520, maxHeight: '90vh', overflowY: 'auto', animation: 'fadeInUp 0.25s ease' }}
            onClick={e => e.stopPropagation()}>
            <div style={{ width: 40, height: 4, background: 'var(--border-default)', borderRadius: 2, margin: '12px auto 0' }} />
            <div style={{ height: 6, background: TYPE_COLORS[selected.member_type] || 'var(--brand-primary)', marginTop: 12 }} />

            <div style={{ padding: '20px 24px 32px', display: 'flex', flexDirection: 'column', gap: 14 }}>
              {/* Avatar + name */}
              <div style={{ display: 'flex', gap: 14, alignItems: 'center' }}>
                <div style={{ width: 60, height: 60, borderRadius: '50%', background: `${TYPE_COLORS[selected.member_type] || 'var(--brand-primary)'}20`, border: `3px solid ${TYPE_COLORS[selected.member_type] || 'var(--brand-primary)'}`, color: TYPE_COLORS[selected.member_type] || 'var(--brand-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: '1.4rem', flexShrink: 0 }}>
                  {getInitials(selected.name)}
                </div>
                <div>
                  <h3 style={{ margin: 0 }}>{selected.name}</h3>
                  <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>{selected.email}</div>
                </div>
              </div>

              {/* Details grid */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                {[
                  { icon: 'business',    label: 'Organisation',      val: selected.company },
                  { icon: 'work',        label: 'Member Type',       val: selected.member_type },
                  { icon: 'location_on', label: 'Port of Operation', val: selected.port_of_operation },
                  { icon: 'badge',       label: 'License No.',       val: selected.license_number || 'N/A' },
                  { icon: 'call',        label: 'Phone',             val: selected.phone || 'Not provided' },
                  { icon: 'calendar_month', label: 'Registered',    val: selected.created_at ? new Date(selected.created_at).toLocaleDateString() : 'N/A' },
                ].map(({ icon, label, val }) => (
                  <div key={label} style={{ display: 'flex', gap: 12, alignItems: 'flex-start', padding: '10px 12px', background: 'var(--bg-base)', borderRadius: 10 }}>
                    <span className="material-symbols-outlined" style={{ fontSize: '1.1rem', color: TYPE_COLORS[selected.member_type] || 'var(--brand-primary)', flexShrink: 0 }}>{icon}</span>
                    <div>
                      <div style={{ fontSize: '0.65rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700 }}>{label}</div>
                      <div style={{ fontSize: '0.88rem', fontWeight: 600, color: 'var(--text-primary)' }}>{val || '—'}</div>
                    </div>
                  </div>
                ))}
              </div>

              {/* Status badge */}
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <span style={{ padding: '4px 14px', borderRadius: 20, fontWeight: 800, fontSize: '0.8rem', background: (STATUS_STYLE[selected.status] || STATUS_STYLE.inactive).bg, color: (STATUS_STYLE[selected.status] || STATUS_STYLE.inactive).color }}>
                  {(STATUS_STYLE[selected.status] || STATUS_STYLE.inactive).label}
                </span>
                <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Current account status</span>
              </div>

              {/* Status Actions */}
              <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
                {selected.status !== 'active' && (
                  <button className="btn btn-primary" disabled={updating} style={{ flex: 1 }}
                    onClick={() => updateStatus(selected.id, 'active')}>
                    {updating ? 'Updating…' : '✓ Activate'}
                  </button>
                )}
                {selected.status !== 'suspended' && (
                  <button className="btn btn-danger" disabled={updating} style={{ flex: 1 }}
                    onClick={() => updateStatus(selected.id, 'suspended')}>
                    {updating ? 'Updating…' : 'Suspend'}
                  </button>
                )}
                {selected.status !== 'inactive' && (
                  <button className="btn btn-outline" disabled={updating} style={{ flex: 1 }}
                    onClick={() => updateStatus(selected.id, 'inactive')}>
                    {updating ? 'Updating…' : 'Deactivate'}
                  </button>
                )}
              </div>

              <div style={{ textAlign: 'center', marginTop: 12 }}>
                <button className="btn btn-ghost btn-sm" onClick={() => setSelected(null)}>Close</button>
              </div>
            </div>
          </div>
        </div>
      )}
    </AppLayout>
  )
}
