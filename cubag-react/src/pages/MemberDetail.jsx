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
      <div style={{ maxWidth: 700, margin: '0 auto' }}>
        {loading ? (
          <div style={{ minHeight: '300px', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', background: 'var(--bg-card)', borderRadius: 'var(--radius-xl)' }}>
            <div className="spinner" style={{ marginBottom: 16 }}></div>
            <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', fontWeight: 600 }}>LOADING PROFILE</div>
          </div>
        ) : !member ? (
          <div className="feed-card" style={{ padding: '60px 20px', textAlign: 'center' }}>
            <span className="material-symbols-outlined" style={{ fontSize: '4rem', color: 'var(--text-muted)' }}>person_off</span>
            <h3 style={{ marginTop: 16 }}>Member Not Found</h3>
            <button className="btn btn-outline" style={{ marginTop: 20 }} onClick={() => navigate('/networking')}>Back to Directory</button>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
            {/* Profile Hero */}
            <div className="feed-card" style={{ padding: 0, overflow: 'hidden' }}>
              <div style={{ height: 120, background: 'var(--gradient-brand)' }}></div>
              <div style={{ padding: '0 32px 32px', position: 'relative' }}>
                <div style={{
                  width: 90, height: 90, borderRadius: '50%',
                  background: 'var(--brand-primary)', color: '#fff',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: '2rem', fontWeight: 800,
                  border: '4px solid #fff',
                  marginTop: -45, marginBottom: 16
                }}>
                  {initials(member.name)}
                </div>
                <h2 style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: 4 }}>{member.name}</h2>
                <p style={{ color: 'var(--text-secondary)', marginBottom: 12 }}>{member.member_type} · {member.port_of_operation}</p>
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, padding: '4px 14px', background: member.status === 'active' ? 'rgba(16,185,129,0.1)' : 'rgba(239,68,68,0.1)', color: member.status === 'active' ? '#10b981' : '#ef4444', borderRadius: 20, fontSize: '0.8rem', fontWeight: 700 }}>
                  <span style={{ width: 7, height: 7, borderRadius: '50%', background: 'currentColor' }}></span>
                  {member.status?.toUpperCase()}
                </span>

                <div style={{ display: 'flex', gap: 12, marginTop: 24 }}>
                  <a href={`mailto:${member.email}`} className="btn btn-primary" style={{ flex: 1, justifyContent: 'center' }}>
                    <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>mail</span> Email
                  </a>
                  <a href={`tel:${member.phone}`} className="btn btn-outline" style={{ flex: 1, justifyContent: 'center' }}>
                    <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>call</span> Call
                  </a>
                </div>
              </div>
            </div>

            {/* Details */}
            <div className="feed-card">
              <div className="card-header"><span className="card-title">Professional Details</span></div>
              <div className="card-body" style={{ flexDirection: 'column', gap: 16 }}>
                {[
                  { icon: 'business', label: 'Company', value: member.company },
                  { icon: 'badge', label: 'License Number', value: member.license_number },
                  { icon: 'tag', label: 'Agency Code', value: member.agency_code },
                  { icon: 'directions_boat', label: 'Primary Port', value: member.port_of_operation },
                  { icon: 'mail', label: 'Email', value: member.email },
                  { icon: 'phone', label: 'Phone', value: member.phone },
                ].filter(i => i.value).map((item, idx) => (
                  <div key={idx} style={{ display: 'flex', gap: 16, alignItems: 'center', padding: '12px 0', borderBottom: '1px solid var(--border-subtle)' }}>
                    <span className="material-symbols-outlined" style={{ color: 'var(--brand-primary)', fontSize: '1.3rem' }}>{item.icon}</span>
                    <div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600, marginBottom: 2 }}>{item.label}</div>
                      <div style={{ color: 'var(--text-primary)', fontWeight: 600 }}>{item.value}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}
      </div>
    </AppLayout>
  )
}
