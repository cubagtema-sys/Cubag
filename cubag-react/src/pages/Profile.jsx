import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import AppLayout from '../components/AppLayout'
import { showToast } from '../utils/toast'
import { mapUser, getStoredUser, saveUser } from '../utils/user'

const API_URL = import.meta.env.VITE_API_URL

function formatDate(str) {
  if (!str) return '—'
  try {
    const d = new Date(str)
    if (isNaN(d.getTime())) return '—'
    return d.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })
  } catch (e) {
    return '—'
  }
}

export default function Profile() {
  const [user, setUser]               = useState({})
  const navigate = useNavigate()

  useEffect(() => {
    const fetchUser = async () => {
      const token = localStorage.getItem('cubag_token')
      if (!token) { navigate('/login'); return }
      try {
        const res = await fetch(`${API_URL}/auth/me`, {
          headers: { 'Authorization': `Bearer ${token}` }
        })
        if (res.ok) {
          const data = await res.json()
          const mappedUser = mapUser(data, getStoredUser() || {})
          setUser(mappedUser)
          saveUser(mappedUser)
        } else {
          localStorage.removeItem('cubag_token')
          navigate('/login')
        }
      } catch (e) {
        console.error(e)
        const userData = JSON.parse(localStorage.getItem('cubag_user') || '{}')
        if (userData.name) setUser(userData)
      }
    }
    fetchUser()
  }, [navigate])


  const handlePhotoUpload = async (e) => {
    const file = e.target.files[0]
    if (!file) return

    // Show optimistic preview immediately
    const previewUrl = URL.createObjectURL(file)
    const previousPhoto = user.photo
    setUser(prev => ({ ...prev, photo: previewUrl }))

    // Upload to backend → Supabase Storage
    const formData = new FormData()
    formData.append('photo', file)

    try {
      const token = localStorage.getItem('cubag_token')
      const res = await fetch(`${API_URL}/auth/upload-photo`, {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` },
        body: formData
      })
      const result = await res.json()
      if (res.ok && result.photo_url) {
        const updatedUser = mapUser({ profile_photo: result.photo_url }, user)
        setUser(updatedUser)
        saveUser(updatedUser)
        showToast('Profile photo updated!', 'success')
        setShowIdCard(true)
      } else {
        showToast(result.message || 'Photo upload failed', 'error')
        setUser(prev => ({ ...prev, photo: previousPhoto }))
      }
    } catch (err) {
      console.error(err)
      showToast('Connection error uploading photo', 'error')
      setUser(prev => ({ ...prev, photo: previousPhoto }))
    } finally {
      URL.revokeObjectURL(previewUrl)
    }
  }



  const initials = user.name ? user.name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2) : '...'

  const [showIdCard, setShowIdCard] = useState(false)
  
  // Generate unique member ID based on last name + id
  const lastName = user.name ? user.name.split(' ').pop().toUpperCase() : ''
  const uniqueMemberId = user.id ? `CUBAG-${lastName}-00${user.id || user.memberId}` : '...'

  // Standard public URL for verification
  const verifyUrl = user.id ? `${window.location.origin}/verify/${user.id || user.memberId}` : ''
  const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${encodeURIComponent(verifyUrl)}`
  
  const handleViewIdCard = () => {
    if (!user.photo) {
      showToast("Please upload a selfie profile photo first to generate your Digital Identity Card.", "warning")
      document.getElementById('profile-upload-input').click()
      return
    }
    setShowIdCard(true)
  }

  return (
    <AppLayout title="My Profile">
      <div style={{ maxWidth: 700, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>
        
        {/* Page Title removed as it is now in the header */}

        {/* Profile Header Card */}
        <div className="feed-card" style={{ overflow: 'visible' }}>
          <div style={{ height: 100, background: 'var(--gradient-brand)', borderRadius: 'var(--radius-lg) var(--radius-lg) 0 0' }}></div>
          <div className="card-body" style={{ padding: '0 16px 16px', textAlign: 'center', marginTop: -40 }}>
            
            <label style={{ cursor: 'pointer', display: 'block', width: 80, height: 80, margin: '0 auto 12px', position: 'relative' }}>
              <input id="profile-upload-input" type="file" accept="image/*" capture="user" style={{ display: 'none' }} onChange={handlePhotoUpload} />
              <div style={{ width: '100%', height: '100%', borderRadius: '50%', background: 'var(--bg-surface)', border: '3px solid var(--bg-surface)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '2rem', fontWeight: 800, color: 'var(--brand-primary)', boxShadow: 'var(--shadow-md)', overflow: 'hidden' }}>
                {user.photo ? (
                  <img src={user.photo} alt="Profile" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                ) : (
                  initials
                )}
              </div>
              <div style={{ position: 'absolute', bottom: 0, right: 0, background: 'var(--brand-primary)', color: '#fff', width: 28, height: 28, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: 'var(--shadow-sm)' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '0.9rem' }}>photo_camera</span>
              </div>
            </label>
            
            <h2 style={{ fontSize: '1.25rem', color: 'var(--text-primary)', marginBottom: 2 }}>{user.name}</h2>
            <p style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', marginBottom: 10 }}>{user.role}</p>
            
            <div style={{ display: 'flex', gap: 10, justifyContent: 'center', flexWrap: 'wrap' }}>
              <span className="badge badge-success" style={{ padding: '4px 10px', fontSize: '0.75rem' }}>{user.status ? user.status.charAt(0).toUpperCase() + user.status.slice(1) : ''} Member</span>
              <button className="btn btn-ghost btn-sm" onClick={handleViewIdCard} style={{ display: 'flex', alignItems: 'center', gap: 4, padding: '4px 10px', fontSize: '0.75rem' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>badge</span> ID Card
              </button>
            </div>
          </div>
        </div>

        {/* Digital ID Card Modal */}
        {showIdCard && (
          <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.9)', zIndex: 9999, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 20 }}>
            <div style={{ position: 'relative', width: '100%', maxWidth: 360, animation: 'fadeInUp 0.3s cubic-bezier(0.34, 1.56, 0.64, 1)' }}>

              {/* Modern Close Button - Positioned clearly inside the modal area or floating above */}
              <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 12 }}>
                <button
                  onClick={() => setShowIdCard(false)}
                  style={{
                    background: 'rgba(255,255,255,0.2)', border: '1.5px solid #fff', color: '#fff',
                    width: 36, height: 36, borderRadius: '50%', display: 'flex',
                    alignItems: 'center', justifyContent: 'center', cursor: 'pointer'
                  }}
                >
                  <span className="material-symbols-outlined" style={{ fontSize: '1.4rem' }}>close</span>
                </button>
              </div>
              
              <div style={{ 
                background: '#ffffff', 
                borderRadius: 24, 
                padding: '24px',
                color: '#0f172a', 
                boxShadow: '0 25px 50px -12px rgba(0,0,0,0.5)',
                border: '1px solid #e2e8f0',
                overflow: 'hidden',
                position: 'relative'
              }}>
                {/* ID Card Decoration */}
                <div style={{ position: 'absolute', top: -50, right: -50, width: 200, height: 200, background: 'var(--brand-primary)', filter: 'blur(80px)', opacity: 0.1 }}></div>
                <div style={{ position: 'absolute', bottom: -50, left: -50, width: 150, height: 150, background: 'rgba(59, 130, 246, 0.5)', filter: 'blur(80px)', opacity: 0.1 }}></div>
                
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 30 }}>
                  <img src="/logo.jpeg" alt="CUBAG" style={{ height: 40, width: 40, borderRadius: 8, boxShadow: '0 2px 8px rgba(0,0,0,0.1)' }} />
                  <div style={{ textAlign: 'right' }}>
                    <div style={{ fontSize: '0.9rem', fontWeight: 800, letterSpacing: '0.1em', color: '#0f172a' }}>CUBAG</div>
                    <div style={{ fontSize: '0.6rem', color: 'var(--brand-primary)', fontWeight: 700, textTransform: 'uppercase' }}>Digital Identity</div>
                  </div>
                </div>

                <div style={{ display: 'flex', gap: 20, marginBottom: 30 }}>
                  <div style={{ width: 90, height: 90, borderRadius: 16, border: '3px solid var(--brand-primary)', padding: 2, background: '#fff', overflow: 'hidden', flexShrink: 0, boxShadow: '0 4px 12px rgba(0,0,0,0.08)' }}>
                    {user.photo ? (
                      <img src={user.photo} alt="Member" style={{ width: '100%', height: '100%', objectFit: 'cover', borderRadius: 12 }} />
                    ) : (
                      <div style={{ width: '100%', height: '100%', background: '#f1f5f9', borderRadius: 12, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '2rem', fontWeight: 700, color: '#94a3b8' }}>{initials}</div>
                    )}
                  </div>
                  <div>
                    <div style={{ fontSize: '1.2rem', fontWeight: 800, marginBottom: 4, color: '#0f172a' }}>{user.name}</div>
                    <div style={{ fontSize: '0.75rem', color: '#64748b', marginBottom: 8, fontWeight: 600 }}>{user.role}</div>
                    <div style={{ background: 'rgba(240,130,50,0.1)', border: '1px solid rgba(240,130,50,0.2)', color: 'var(--brand-primary)', padding: '4px 10px', borderRadius: 20, fontSize: '0.7rem', fontWeight: 700, display: 'inline-block' }}>{user.status ? user.status.charAt(0).toUpperCase() + user.status.slice(1) : ''}</div>
                  </div>
                </div>

                <div style={{ background: '#f8fafc', border: '1px solid #e2e8f0', borderRadius: 16, padding: 16, marginBottom: 24 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 12 }}>
                    <span style={{ fontSize: '0.65rem', color: '#64748b', textTransform: 'uppercase', fontWeight: 700 }}>Member ID</span>
                    <span style={{ fontSize: '0.85rem', fontWeight: 800, color: '#0f172a' }}>{uniqueMemberId}</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ fontSize: '0.65rem', color: '#64748b', textTransform: 'uppercase', fontWeight: 700 }}>License Expires</span>
                    <span style={{ fontSize: '0.85rem', fontWeight: 800, color: user.licenseExpiry && new Date(user.licenseExpiry) < new Date() ? '#ef4444' : '#0f172a' }}>
                      {user.licenseExpiry ? formatDate(user.licenseExpiry) : 'Not set'}
                    </span>
                  </div>
                </div>

                <div style={{ textAlign: 'center' }}>
                  <div style={{ background: '#fff', padding: 12, borderRadius: 16, display: 'inline-block', border: '1px solid #e2e8f0', boxShadow: '0 4px 6px -1px rgba(0,0,0,0.05)' }}>
                    <img src={qrUrl} alt="QR Code" style={{ width: 140, height: 140 }} />
                  </div>
                  <p style={{ fontSize: '0.65rem', color: '#64748b', marginTop: 12, fontWeight: 600 }}>Scan for verification at CUBAG checkpoints</p>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* License Details Card */}
        <div className="feed-card">
          <div className="card-header">
            <span className="card-title">Professional Details</span>
          </div>
          <div className="card-body" style={{ padding: 0 }}>
            <div style={{ display: 'flex', flexDirection: 'column' }}>
              <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--border-subtle)' }}>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: 4 }}>Member ID</div>
                <div style={{ fontSize: '1rem', color: 'var(--text-primary)', fontWeight: 600 }}>{uniqueMemberId}</div>
              </div>
              <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--border-subtle)' }}>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: 4 }}>Organization</div>
                <div style={{ fontSize: '1rem', color: 'var(--text-primary)', fontWeight: 600 }}>{user.company || 'Independent'}</div>
              </div>
              <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--border-subtle)' }}>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: 4 }}>Email Address</div>
                <div style={{ fontSize: '1rem', color: 'var(--text-primary)', fontWeight: 600, wordBreak: 'break-all' }}>{user.email}</div>
              </div>
              <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--border-subtle)' }}>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: 4 }}>Phone Number</div>
                <div style={{ fontSize: '1rem', color: 'var(--text-primary)', fontWeight: 600 }}>{user.phone || 'Not provided'}</div>
              </div>

              {/* License Number + Expiry */}
              <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--border-subtle)', background: user.status === 'active' ? 'rgba(240,130,50,0.05)' : 'rgba(239,68,68,0.05)' }}>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: 8 }}>License</div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 8 }}>
                  <div>
                    <div style={{ fontSize: '1rem', color: user.status === 'active' ? 'var(--text-primary)' : 'var(--brand-danger)', fontWeight: 700 }}>
                      {user.id ? (user.licenseNumber || (user.status === 'active' ? 'N/A' : 'PAYMENT REQUIRED')) : '...'}
                    </div>
                    {user.id && user.licenseExpiry && (() => {
                      const exp      = new Date(user.licenseExpiry)
                      const daysLeft = Math.ceil((exp - new Date()) / 86400000)
                      return (
                        <div style={{ fontSize: '0.75rem', marginTop: 3, color: daysLeft < 0 ? '#ef4444' : daysLeft <= 30 ? '#f59e0b' : 'var(--text-muted)', fontWeight: 600 }}>
                          {daysLeft < 0
                            ? `Expired ${formatDate(user.licenseExpiry)}`
                            : daysLeft <= 30
                            ? `Expires in ${daysLeft} day${daysLeft !== 1 ? 's' : ''} — ${formatDate(user.licenseExpiry)}`
                            : `Valid until ${formatDate(user.licenseExpiry)}`
                          }
                        </div>
                      )
                    })()}
                  </div>
                  <button className="btn btn-outline btn-sm" onClick={() => navigate('/payments')} style={{ whiteSpace: 'nowrap', fontSize: '0.75rem' }}>
                    {user.status === 'active' ? 'Renew' : 'Pay to Activate'}
                  </button>
                </div>
              </div>

              {/* License History button */}
              <div style={{ padding: '12px 20px' }}>
                <button
                  onClick={() => navigate('/license-renewal')}
                  style={{ width: '100%', padding: '9px', borderRadius: 8, border: '1px solid var(--border-subtle)', background: 'transparent', color: 'var(--text-muted)', fontSize: '0.78rem', fontWeight: 700, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6 }}
                >
                  <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>history</span>
                  View License History
                </button>
              </div>
            </div>
          </div>
        </div>

      </div>
    </AppLayout>
  )
}
