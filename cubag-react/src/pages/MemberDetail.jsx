import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import AppLayout from '../components/AppLayout'

const API_URL = import.meta.env.VITE_API_URL

export default function MemberDetail() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [member, setMember] = useState(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function fetchMember() {
      try {
        const res = await fetch(`${API_URL}/members/${id}`, {
          headers: { 'Authorization': `Bearer ${localStorage.getItem('cubag_token')}` }
        })
        if (res.ok) {
          const data = await res.json()
          setMember(data)
        }
      } catch (e) {
        console.error(e)
      } finally {
        setLoading(false)
      }
    }
    fetchMember()
  }, [id])

  const initials = (name) => name?.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2) || 'M'

  return (
    <AppLayout title="Member Profile">
      <div style={{ maxWidth: 700, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>
        {loading ? (
          <div style={{ minHeight: '300px', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', background: 'var(--bg-card)', borderRadius: 12, border: '1px solid var(--border-subtle)' }}>
            <div className="spinner" style={{ marginBottom: 12 }}></div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600 }}>SYNCING PROFILE</div>
          </div>
        ) : !member ? (
          <div className="card" style={{ padding: '60px 20px', textAlign: 'center', borderRadius: 12 }}>
            <span className="material-symbols-outlined" style={{ fontSize: '3rem', color: 'var(--text-muted)', marginBottom: 16 }}>person_off</span>
            <h3 style={{ fontSize: '1.1rem' }}>Profile Not Found</h3>
            <button className="btn btn-outline btn-sm" style={{ marginTop: 20 }} onClick={() => navigate('/networking')}>Back to Directory</button>
          </div>
        ) : (
          <>
            {/* Page Title for Content */}
            <div style={{ marginBottom: 4 }}>
              <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Broker Profile</h2>
              <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Official member credentials and verification.</p>
            </div>

            <div className="feed-card" style={{ padding: 0, overflow: 'hidden', borderRadius: 12 }}>
              <div style={{ height: 100, background: 'var(--gradient-brand)' }}></div>
              <div style={{ padding: '0 20px 24px', position: 'relative' }}>
                <div style={{
                  width: 72, height: 72, borderRadius: '50%',
                  background: 'var(--brand-primary)', color: '#fff',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: '1.5rem', fontWeight: 800,
                  border: '3.5px solid var(--bg-surface)',
                  marginTop: -36, marginBottom: 12
                }}>
                  {initials(member.name)}
                </div>
                <h2 style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: 2 }}>{member.name}</h2>
                <p style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', marginBottom: 10 }}>{member.member_type}</p>
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, padding: '3px 12px', background: member.status === 'active' ? 'rgba(16,185,129,0.1)' : 'rgba(239,68,68,0.1)', color: member.status === 'active' ? '#10b981' : '#ef4444', borderRadius: 20, fontSize: '0.7rem', fontWeight: 800, textTransform: 'uppercase' }}>
                  {member.status}
                </span>

                <div style={{ display: 'flex', gap: 8, marginTop: 20 }}>
                  <a href={`mailto:${member.email}`} className="btn btn-primary btn-sm" style={{ flex: 1, height: 40, justifyContent: 'center' }}>
                    <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>mail</span> Email
                  </a>
                  <a href={`tel:${member.phone}`} className="btn btn-outline btn-sm" style={{ flex: 1, height: 40, justifyContent: 'center' }}>
                    <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>call</span> Call
                  </a>
                </div>
              </div>
            </div>

            {/* Details - High Density */}
            <div className="feed-card" style={{ borderRadius: 12 }}>
              <div className="card-header" style={{ padding: '10px 16px' }}><span className="card-title">Credentials</span></div>
              <div className="card-body" style={{ padding: '8px 16px' }}>
                {[
                  { icon: 'business', label: 'Agency', value: member.company },
                  { icon: 'badge', label: 'License', value: member.license_number },
                  { icon: 'directions_boat', label: 'Port', value: member.port_of_operation },
                ].filter(i => i.value).map((item, idx) => (
                  <div key={idx} style={{ display: 'flex', gap: 12, alignItems: 'center', padding: '10px 0', borderBottom: idx < 2 ? '1px solid var(--border-subtle)' : 'none' }}>
                    <div style={{ width: 32, height: 32, borderRadius: 8, background: 'rgba(240,130,50,0.08)', color: 'var(--brand-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                      <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>{item.icon}</span>
                    </div>
                    <div>
                      <div style={{ fontSize: '0.65rem', color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase' }}>{item.label}</div>
                      <div style={{ fontSize: '0.9rem', color: 'var(--text-primary)', fontWeight: 700 }}>{item.value}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </>
        )}
      </div>
    </AppLayout>
  )
}
