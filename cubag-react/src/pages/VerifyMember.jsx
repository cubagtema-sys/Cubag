import { useState, useEffect } from 'react'
import { useParams, Link } from 'react-router-dom'

const API_URL = import.meta.env.VITE_API_URL

export default function VerifyMember() {
  const { id } = useParams()
  const [member, setMember] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    async function fetchVerification() {
      try {
        const res = await fetch(`${API_URL}/members/verify/${id}`)
        if (res.ok) {
          setMember(await res.json())
        } else {
          setError("Member records could not be verified.")
        }
      } catch {
        setError("Network error. Please try again.")
      } finally {
        setLoading(false)
      }
    }
    fetchVerification()
  }, [id])

  if (loading) return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#f8fafc', padding: 20 }}>
       <div style={{ textAlign: 'center' }}>
          <div className="spinner" style={{ margin: '0 auto 16px' }} />
          <p style={{ color: '#64748b', fontWeight: 600 }}>VERIFYING CUBAG CREDENTIALS...</p>
       </div>
    </div>
  )

  if (error || !member) return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#f8fafc', padding: 20 }}>
       <div style={{ maxWidth: 400, width: '100%', background: '#fff', borderRadius: 24, padding: 32, textAlign: 'center', boxShadow: '0 10px 25px -5px rgba(0,0,0,0.1)' }}>
          <span className="material-symbols-outlined" style={{ fontSize: '4rem', color: '#ef4444', marginBottom: 16 }}>error</span>
          <h2 style={{ fontSize: '1.5rem', fontWeight: 800, color: '#0f172a', marginBottom: 12 }}>Invalid ID</h2>
          <p style={{ color: '#64748b', lineHeight: 1.6, marginBottom: 24 }}>{error || "This QR code does not correspond to an active CUBAG member."}</p>
          <Link to="/" className="btn btn-primary" style={{ width: '100%', height: 48 }}>Return to Home</Link>
       </div>
    </div>
  )

  const initials = (member.name || 'M').split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)
  const status = member.status?.toLowerCase() || 'pending'
  const isVerified = status === 'active'

  return (
    <div style={{ minHeight: '100vh', background: '#f8fafc', padding: '40px 20px' }}>
      <div style={{ maxWidth: 450, margin: '0 auto' }}>

        {/* Verification Badge */}
        <div style={{
          background: isVerified ? '#10b981' : '#f59e0b',
          color: '#fff', padding: '12px', borderRadius: '16px 16px 0 0',
          textAlign: 'center', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8
        }}>
          <span className="material-symbols-outlined" style={{ fontSize: '1.5rem' }}>{isVerified ? 'verified' : 'pending_actions'}</span>
          <span style={{ fontWeight: 800, letterSpacing: '0.05em', textTransform: 'uppercase', fontSize: '0.9rem' }}>
            {isVerified ? 'Authentic CUBAG Member' : 'Member Status: ' + status}
          </span>
        </div>

        <div style={{ background: '#fff', borderRadius: '0 0 24px 24px', padding: '32px 24px', boxShadow: '0 20px 50px rgba(0,0,0,0.1)', textAlign: 'center' }}>

          <div style={{ width: 100, height: 100, borderRadius: '50%', margin: '0 auto 20px', border: `4px solid ${isVerified ? '#10b981' : '#f59e0b'}`, padding: 3, background: '#fff', overflow: 'hidden' }}>
            {member.profile_photo ? (
              <img src={member.profile_photo} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover', borderRadius: '50%' }} />
            ) : (
              <div style={{ width: '100%', height: '100%', background: '#f1f5f9', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '2.5rem', fontWeight: 800, color: '#94a3b8' }}>
                {initials}
              </div>
            )}
          </div>

          <h1 style={{ fontSize: '1.6rem', fontWeight: 900, color: '#0f172a', marginBottom: 4 }}>{member.name}</h1>
          <p style={{ fontSize: '0.95rem', color: '#64748b', fontWeight: 600, marginBottom: 24 }}>{member.company || 'Independent Broker'}</p>

          <div style={{ display: 'grid', gap: 12, textAlign: 'left' }}>
            {[
              { label: 'Role', val: member.member_type, icon: 'work' },
              { label: 'License ID', val: member.license_number || 'PENDING', icon: 'badge' },
              { label: 'Port', val: member.port_of_operation, icon: 'location_on' },
              { label: 'Status', val: isVerified ? 'Verified Active' : status, icon: 'shield_check' },
            ].map(row => (
              <div key={row.label} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 16px', background: '#f8fafc', borderRadius: 12, border: '1px solid #e2e8f0' }}>
                <span className="material-symbols-outlined" style={{ color: isVerified ? '#10b981' : '#f59e0b', fontSize: '1.2rem' }}>{row.icon}</span>
                <div>
                   <div style={{ fontSize: '0.65rem', color: '#94a3b8', textTransform: 'uppercase', fontWeight: 700 }}>{row.label}</div>
                   <div style={{ fontSize: '0.95rem', fontWeight: 700, color: '#1e293b' }}>{row.val}</div>
                </div>
              </div>
            ))}
          </div>

          <div style={{ marginTop: 32, paddingTop: 24, borderTop: '1px solid #f1f5f9' }}>
            <img src="/logo.jpeg" alt="CUBAG" style={{ height: 40, margin: '0 auto 12px', borderRadius: 8 }} />
            <p style={{ fontSize: '0.7rem', color: '#94a3b8', lineHeight: 1.5 }}>
              Official verification for Customs Brokers Association of Ghana.<br/>
              © {new Date().getFullYear()} CUBAG Secretariat.
            </p>
          </div>
        </div>

        <div style={{ marginTop: 24, textAlign: 'center' }}>
           <a href="https://cubag.org.gh" style={{ fontSize: '0.85rem', color: '#64748b', textDecoration: 'none', fontWeight: 600 }}>Visit Official Website</a>
        </div>
      </div>
    </div>
  )
}
