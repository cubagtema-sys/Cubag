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

const PORT_OPTIONS = [
  { value: 'All', label: 'All Ports' },
  { value: 'Tema Port', label: 'Tema Port' },
  { value: 'KIA, Accra', label: 'KIA, Accra' },
  { value: 'Takoradi Port', label: 'Takoradi Port' },
  { value: 'Kumasi Airport', label: 'Kumasi Airport' },
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
  const [filterPort, setFilterPort] = useState('All')
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
    const matchPort = filterPort === 'All' || m.port_of_operation === filterPort
    return matchSearch && matchType && matchPort
  })

  const accentColor = (type) => TYPE_COLORS[type] || 'var(--brand-primary)'

  return (
    <AppLayout title="Member Networking">
      <div style={{ maxWidth: 1060, margin: '0 auto' }}>

        {/* Search & Filters */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12, marginBottom: 28 }}>
          {/* Search bar */}
          <div style={{ position: 'relative' }}>
            <span className="material-symbols-outlined" style={{ position: 'absolute', left: 14, top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', fontSize: '1.2rem' }}>search</span>
            <input
              type="text"
              placeholder="Search by name, company or specialization..."
              value={searchTerm}
              onChange={e => setSearchTerm(e.target.value)}
              style={{ width: '100%', padding: '13px 14px 13px 44px', borderRadius: 12, border: '1.5px solid var(--border-default)', background: 'var(--bg-base)', color: 'var(--text-primary)', outline: 'none', boxSizing: 'border-box', fontSize: '0.9rem' }}
            />
          </div>

          {/* Dropdown filters row */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <CustomSelect
              value={filterType}
              onChange={setFilterType}
              options={TYPE_OPTIONS}
              icon="work"
            />
            <CustomSelect
              value={filterPort}
              onChange={setFilterPort}
              options={PORT_OPTIONS}
              icon="location_on"
            />
          </div>

          {/* Active filter indicator */}
          {(filterType !== 'All' || filterPort !== 'All') && (
            <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
              <span style={{ fontSize: '0.78rem', color: 'var(--text-muted)' }}>Filtered by:</span>
              {filterType !== 'All' && (
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, padding: '3px 10px', borderRadius: 20, background: 'rgba(240,130,50,0.1)', color: 'var(--brand-primary)', fontSize: '0.78rem', fontWeight: 700 }}>
                  {filterType}
                  <button onClick={() => setFilterType('All')} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'inherit', padding: 0, lineHeight: 1, fontSize: '1rem' }}>×</button>
                </span>
              )}
              {filterPort !== 'All' && (
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, padding: '3px 10px', borderRadius: 20, background: 'rgba(59,130,246,0.1)', color: '#3b82f6', fontSize: '0.78rem', fontWeight: 700 }}>
                  {filterPort}
                  <button onClick={() => setFilterPort('All')} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'inherit', padding: 0, lineHeight: 1, fontSize: '1rem' }}>×</button>
                </span>
              )}
              <button onClick={() => { setFilterType('All'); setFilterPort('All') }} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)', fontSize: '0.78rem', fontWeight: 600, textDecoration: 'underline' }}>Clear all</button>
            </div>
          )}
        </div>

        {/* Results count */}
        {!loading && (
          <p style={{ fontSize: '0.82rem', color: 'var(--text-muted)', marginBottom: 16 }}>
            Showing <strong>{filtered.length}</strong> of <strong>{members.length}</strong> members
          </p>
        )}

        {/* Grid */}
        {loading ? (
          <div style={{ minHeight: 360, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', background: 'var(--bg-surface)', borderRadius: 16, border: '1px solid var(--border-subtle)' }}>
            <div className="spinner" style={{ marginBottom: 16 }} />
            <div style={{ fontSize: '0.85rem', color: 'var(--text-muted)', fontWeight: 600, letterSpacing: '0.05em' }}>SYNCING MEMBER DIRECTORY</div>
          </div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: 18 }}>
            {filtered.map(m => {
              const color = accentColor(m.member_type)
              const initials = getInitials(m.name)
              return (
                <div
                  key={m.id}
                  className="feed-card"
                  onClick={() => setSelected(m)}
                  style={{ cursor: 'pointer', transition: 'transform 0.15s, box-shadow 0.15s', padding: 0, overflow: 'hidden' }}
                  onMouseEnter={e => { e.currentTarget.style.transform = 'translateY(-2px)'; e.currentTarget.style.boxShadow = '0 8px 24px rgba(0,0,0,0.1)' }}
                  onMouseLeave={e => { e.currentTarget.style.transform = ''; e.currentTarget.style.boxShadow = '' }}
                >
                  {/* Coloured top strip */}
                  <div style={{ height: 6, background: color }} />

                  <div style={{ padding: '20px 20px 18px', display: 'flex', flexDirection: 'column', gap: 14 }}>
                    {/* Avatar + Name */}
                    <div style={{ display: 'flex', gap: 14, alignItems: 'center' }}>
                      <div style={{ width: 56, height: 56, borderRadius: '50%', background: `${color}22`, border: `2.5px solid ${color}`, color, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '1.3rem', fontWeight: 800, flexShrink: 0 }}>
                        {initials}
                      </div>
                      <div style={{ minWidth: 0 }}>
                        <div style={{ fontWeight: 800, fontSize: '1rem', color: 'var(--text-primary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{m.name}</div>
                        <div style={{ fontSize: '0.75rem', fontWeight: 700, color, marginTop: 2 }}>{m.member_type || 'Member'}</div>
                      </div>
                    </div>

                    {/* Info rows */}
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 7, fontSize: '0.82rem', color: 'var(--text-secondary)' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <span className="material-symbols-outlined" style={{ fontSize: '1rem', color: 'var(--text-muted)', flexShrink: 0 }}>business</span>
                        <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{m.company || '—'}</span>
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <span className="material-symbols-outlined" style={{ fontSize: '1rem', color: 'var(--text-muted)', flexShrink: 0 }}>location_on</span>
                        <span>{m.port_of_operation || '—'}</span>
                      </div>
                      {m.phone && (
                        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                          <span className="material-symbols-outlined" style={{ fontSize: '1rem', color: 'var(--text-muted)', flexShrink: 0 }}>call</span>
                          <span>{m.phone}</span>
                        </div>
                      )}
                    </div>

                    {/* CTA */}
                    <button
                      className="btn btn-outline btn-sm"
                      style={{ width: '100%', justifyContent: 'center' }}
                      onClick={e => { e.stopPropagation(); setSelected(m) }}
                    >
                      View Full Profile
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

      {/* Member Detail Modal */}
      {selected && (
        <div
          style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.55)', zIndex: 9999, display: 'flex', alignItems: 'flex-end', justifyContent: 'center', padding: '0 0 0 0' }}
          onClick={() => setSelected(null)}
        >
          <div
            style={{ background: 'var(--bg-surface)', borderRadius: '20px 20px 0 0', width: '100%', maxWidth: 520, maxHeight: '85vh', overflowY: 'auto', boxShadow: '0 -8px 40px rgba(0,0,0,0.25)', animation: 'fadeInUp 0.25s ease' }}
            onClick={e => e.stopPropagation()}
          >
            {/* Handle */}
            <div style={{ width: 40, height: 4, background: 'var(--border-default)', borderRadius: 2, margin: '12px auto 0' }} />

            {/* Header */}
            <div style={{ height: 8, background: accentColor(selected.member_type), marginTop: 12 }} />
            <div style={{ padding: '24px 24px 0' }}>
              <div style={{ display: 'flex', gap: 16, alignItems: 'center', marginBottom: 20 }}>
                <div style={{ width: 72, height: 72, borderRadius: '50%', background: `${accentColor(selected.member_type)}22`, border: `3px solid ${accentColor(selected.member_type)}`, color: accentColor(selected.member_type), display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '1.8rem', fontWeight: 800, flexShrink: 0 }}>
                  {getInitials(selected.name)}
                </div>
                <div>
                  <h2 style={{ margin: 0, fontSize: '1.25rem' }}>{selected.name}</h2>
                  <div style={{ fontSize: '0.82rem', fontWeight: 700, color: accentColor(selected.member_type), marginTop: 2 }}>{selected.member_type}</div>
                </div>
              </div>
            </div>

            {/* Details */}
            <div style={{ padding: '0 24px 32px', display: 'flex', flexDirection: 'column', gap: 12 }}>

              {[
                { icon: 'business',      label: 'Organisation',      value: selected.company },
                { icon: 'work',          label: 'Specialization',    value: selected.member_type },
                { icon: 'location_on',   label: 'Port of Operation', value: selected.port_of_operation },
                { icon: 'badge',         label: 'License No.',       value: selected.license_number || 'N/A' },
                { icon: 'mail',          label: 'Email',             value: selected.email },
                { icon: 'call',          label: 'Phone',             value: selected.phone || 'Not provided' },
              ].map(({ icon, label, value }) => (
                <div key={label} style={{ display: 'flex', alignItems: 'flex-start', gap: 14, padding: '12px 14px', background: 'var(--bg-base)', borderRadius: 12 }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '1.2rem', color: accentColor(selected.member_type), flexShrink: 0, marginTop: 1 }}>{icon}</span>
                  <div>
                    <div style={{ fontSize: '0.68rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, marginBottom: 2 }}>{label}</div>
                    <div style={{ fontSize: '0.9rem', fontWeight: 600, color: 'var(--text-primary)' }}>{value || '—'}</div>
                  </div>
                </div>
              ))}

              {/* Contact actions */}
              <div style={{ marginTop: 8 }}>
                <button 
                  className="btn btn-primary" 
                  style={{ width: '100%', justifyContent: 'center', display: 'flex', alignItems: 'center', gap: 8 }}
                  onClick={() => navigate('/messaging', { state: { chatUser: selected } })}
                >
                  <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>chat</span> 
                  Send Message
                </button>
              </div>

              <button className="btn btn-ghost btn-sm" onClick={() => setSelected(null)} style={{ marginTop: 4, width: '100%', display: 'flex', justifyContent: 'center' }}>
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </AppLayout>
  )
}
