import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import AppLayout from '../components/AppLayout'
import CustomSelect from '../components/CustomSelect'

const API_URL = import.meta.env.VITE_API_URL


const TYPE_OPTIONS = [
  { value: 'All', label: 'All Types' },
  { value: 'Corporate Agency', label: 'Corporate Agency' },
  { value: 'Individual Broker', label: 'Individual Broker' },
  { value: 'Freight Forwarder', label: 'Freight Forwarder' },
  { value: 'Shipping Line', label: 'Shipping Line' },
]

// Colour per member type for the avatar ring
const TYPE_COLORS = {
  'Corporate Agency':   '#3b82f6',
  'Individual Broker':  '#f08232',
  'Freight Forwarder':  '#10b981',
  'Shipping Line':      '#8b5cf6',
}

const getInitials = (name = '') =>
  name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)

export default function Networking() {
  const [members, setMembers] = useState([])
  const [searchTerm, setSearchTerm] = useState('')
  const [filterType, setFilterType] = useState('All')
  const [loading, setLoading] = useState(true)
  const [selected, setSelected] = useState(null) // member detail modal
  const navigate = useNavigate()

  useEffect(() => {
    async function fetchMembers() {
      try {
        setLoading(true)
        const res = await fetch(`${API_URL}/members`, {
          headers: { Authorization: `Bearer ${localStorage.getItem('cubag_token')}` }
        })
        if (res.ok) setMembers(await res.json())
      } catch (e) {
        console.error('Networking load error', e)
      } finally {
        setLoading(false)
      }
    }
    fetchMembers()
  }, [])

  const filtered = (members || []).filter(m => {
    // Completely hide the Admin / Secretariat profile from the public networking directory
    if (m.role === 'admin' || (m.name && m.name.includes('CUBAG Admin'))) return false;

    const q = searchTerm.toLowerCase()
    const matchSearch = (m.name || '').toLowerCase().includes(q) ||
                        (m.company || '').toLowerCase().includes(q) ||
                        (m.member_type || '').toLowerCase().includes(q)
    const matchType = filterType === 'All' || m.member_type === filterType
    return matchSearch && matchType
  })

  const accentColor = (type) => TYPE_COLORS[type] || 'var(--brand-primary)'

  return (
    <AppLayout title="Network">
      <div style={{ maxWidth: 1060, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>

        {/* Page Title for Content */}
        <div style={{ marginBottom: 4 }}>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Member Directory</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Connect with licensed brokers and agencies across Ghana.</p>
        </div>

        {/* Search & Filters */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 16 }}>
          {/* Search bar */}
          <div style={{ position: 'relative' }}>
            <span className="material-symbols-outlined" style={{ position: 'absolute', left: 14, top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', fontSize: '1.1rem' }}>search</span>
            <input
              type="text"
              placeholder="Search members..." autoComplete="off"
              value={searchTerm}
              onChange={e => setSearchTerm(e.target.value)}
              style={{ width: '100%', padding: '11px 12px 11px 40px', borderRadius: 10, border: '1.5px solid var(--border-default)', background: 'var(--bg-base)', color: 'var(--text-primary)', outline: 'none', boxSizing: 'border-box', fontSize: '0.9rem' }}
            />
          </div>

          <CustomSelect
            value={filterType}
            onChange={setFilterType}
            options={TYPE_OPTIONS}
            icon="work"
            placeholder="Filter by type"
          />
        </div>

        {/* Results count */}
        {!loading && (
          <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginBottom: 8 }}>
            Found <strong>{filtered.length}</strong> members
          </p>
        )}

        {/* Grid */}
        {loading ? (
          <div style={{ minHeight: 300, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', background: 'var(--bg-surface)', borderRadius: 16, border: '1px solid var(--border-subtle)' }}>
            <div className="spinner" style={{ marginBottom: 12 }} />
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600, letterSpacing: '0.05em' }}>SYNCING DIRECTORY</div>
          </div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(min(100%, 280px), 1fr))', gap: 14 }}>
            {filtered.map(m => {
              const color = accentColor(m.member_type)
              const initials = getInitials(m.name)
              return (
                <div
                  key={m.id}
                  className="feed-card"
                  style={{ transition: 'transform 0.15s, box-shadow 0.15s', padding: 0, overflow: 'hidden', borderRadius: 12 }}
                >
                  <div style={{ height: 4, background: color }} />

                  <div style={{ padding: '16px', display: 'flex', flexDirection: 'column', gap: 10 }}>
                    <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
                      <div style={{ width: 44, height: 44, borderRadius: '50%', background: `${color}22`, border: `2px solid ${color}`, color, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '1rem', fontWeight: 800, flexShrink: 0 }}>
                        {initials}
                      </div>
                      <div style={{ minWidth: 0 }}>
                        <div style={{ fontWeight: 800, fontSize: '0.9rem', color: 'var(--text-primary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{m.name}</div>
                        <div style={{ fontSize: '0.7rem', fontWeight: 700, color, marginTop: 1 }}>{m.member_type.split(' ')[0]}</div>
                      </div>
                    </div>

                    <div style={{ display: 'flex', flexDirection: 'column', gap: 4, fontSize: '0.75rem', color: 'var(--text-secondary)' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                        <span className="material-symbols-outlined" style={{ fontSize: '0.9rem', color: 'var(--text-muted)' }}>business</span>
                        <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{m.company || 'Independent'}</span>
                      </div>
                    </div>

                    <button
                      className="btn btn-primary btn-sm"
                      style={{ width: '100%', height: 36, marginTop: 4, justifyContent: 'center' }}
                      onClick={(e) => { e.stopPropagation(); setSelected(m); }}
                    >
                      View
                    </button>
                  </div>
                </div>
              )
            })}

            {filtered.length === 0 && (
              <div style={{ gridColumn: '1 / -1', textAlign: 'center', padding: 60, color: 'var(--text-muted)' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '3rem', display: 'block', marginBottom: 12 }}>search_off</span>
                <p>No members match your search.</p>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Member Detail Bottom Sheet Modal */}
      {selected && (() => {
        const color = accentColor(selected.member_type)
        const initials = getInitials(selected.name)
        return (
          <div
            style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)', zIndex: 9999, display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }}
            onClick={() => setSelected(null)}
          >
            <div
              style={{ background: 'var(--bg-surface)', borderRadius: '20px 20px 0 0', width: '100%', maxWidth: 520, maxHeight: '90vh', overflowY: 'auto', boxShadow: '0 -8px 40px rgba(0,0,0,0.25)', animation: 'fadeInUp 0.22s ease' }}
              onClick={e => e.stopPropagation()}
            >
              {/* Drag handle */}
              <div style={{ width: 40, height: 4, background: 'var(--border-default)', borderRadius: 2, margin: '12px auto 0' }} />



              <div style={{ padding: '0 20px 28px', display: 'flex', flexDirection: 'column', gap: 14 }}>
                {/* Avatar + name row */}
                <div style={{ display: 'flex', gap: 14, alignItems: 'center', marginTop: 8 }}>
                  <div style={{
                    width: 60, height: 60, borderRadius: '50%',
                    background: `${color}20`,
                    border: `2.5px solid ${color}`,
                    color, display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: '1.4rem', fontWeight: 900, flexShrink: 0
                  }}>
                    {initials}
                  </div>
                  <div style={{ minWidth: 0 }}>
                    <h2 style={{ margin: 0, fontSize: '1.1rem', fontWeight: 900, color: 'var(--text-primary)', lineHeight: 1.2 }}>{selected.name}</h2>
                    <span style={{ display: 'inline-block', fontSize: '0.68rem', fontWeight: 800, color, background: `${color}18`, padding: '2px 10px', borderRadius: 20, marginTop: 4, textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                      {selected.member_type}
                    </span>
                  </div>
                </div>

                {/* Status badge */}
                <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                  <span style={{
                    display: 'inline-flex', alignItems: 'center', gap: 5,
                    padding: '4px 12px',
                    background: selected.status === 'active' ? 'rgba(16,185,129,0.1)' : 'rgba(239,68,68,0.1)',
                    color: selected.status === 'active' ? '#10b981' : '#ef4444',
                    borderRadius: 20, fontSize: '0.7rem', fontWeight: 800, textTransform: 'uppercase'
                  }}>
                    <span className="material-symbols-outlined" style={{ fontSize: '0.9rem' }}>
                      {selected.status === 'active' ? 'verified' : 'cancel'}
                    </span>
                    {selected.status}
                  </span>
                </div>

                {/* Info rows */}
                <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                  {[
                    { icon: 'business',     label: 'Organisation',   val: selected.company },
                    { icon: 'location_on',  label: 'Port / Operation', val: selected.port_of_operation },
                    { icon: 'badge',        label: 'License No.',    val: selected.license_number },
                    { icon: 'mail',         label: 'Email',          val: selected.email },
                    { icon: 'call',         label: 'Phone',          val: selected.phone },
                  ].filter(row => row.val).map(({ icon, label, val }) => (
                    <div key={label} style={{ display: 'flex', gap: 12, alignItems: 'center', padding: '10px 12px', background: 'var(--bg-base)', borderRadius: 10 }}>
                      <div style={{ width: 34, height: 34, borderRadius: 10, background: `${color}15`, color, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                        <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>{icon}</span>
                      </div>
                      <div style={{ minWidth: 0 }}>
                        <div style={{ fontSize: '0.6rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700 }}>{label}</div>
                        <div style={{ fontSize: '0.85rem', color: 'var(--text-primary)', fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{val}</div>
                      </div>
                    </div>
                  ))}
                </div>

                {/* Action buttons */}
                <div style={{ display: 'flex', gap: 10, marginTop: 4 }}>
                  <button
                    className="btn btn-primary"
                    style={{ flex: 2, height: 46, justifyContent: 'center', gap: 8, fontSize: '0.9rem', fontWeight: 800 }}
                    onClick={() => { setSelected(null); navigate('/messaging', { state: { chatUser: selected } }) }}
                  >
                    <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>chat</span>
                    Message
                  </button>
                  <a
                    href={`mailto:${selected.email}`}
                    className="btn btn-outline"
                    style={{ flex: 1, height: 46, justifyContent: 'center', gap: 6, fontSize: '0.85rem', textDecoration: 'none' }}
                  >
                    <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>mail</span>
                    Email
                  </a>
                </div>

                <button className="btn btn-ghost btn-sm" onClick={() => setSelected(null)} style={{ width: '100%', color: 'var(--text-muted)', justifyContent: 'center', textAlign: 'center' }}>
                  Close
                </button>
              </div>
            </div>
          </div>
        )
      })()}
    </AppLayout>
  )
}
