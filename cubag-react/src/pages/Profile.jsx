import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import AppLayout from '../components/AppLayout'
import { showToast } from '../utils/toast'
import { NativeBiometric } from '@capgo/capacitor-native-biometric'

export default function Profile() {
  const [user, setUser] = useState({})
  const [biometricEnabled, setBiometricEnabled] = useState(false)
  const [biometricAvailable, setBiometricAvailable] = useState(false)
  const [showPasswordPrompt, setShowPasswordPrompt] = useState(false)
  const [confirmPassword, setConfirmPassword] = useState('')
  const [isEnabling, setIsEnabling] = useState(false)
  const navigate = useNavigate()

  useEffect(() => {
    const fetchUser = async () => {
      const token = localStorage.getItem('cubag_token')
      if (!token) {
        navigate('/login')
        return
      }
      try {
        const res = await fetch(`${import.meta.env.VITE_API_URL}/auth/me`, {
          headers: { 'Authorization': `Bearer ${token}` }
        })
        if (res.ok) {
          const data = await res.json()
          // Map backend fields to frontend expected fields
          const existingUser = JSON.parse(localStorage.getItem('cubag_user') || '{}')
          const mappedUser = {
            name: data.name,
            email: data.email,
            phone: data.phone,
            company: data.company,
            memberId: data.id,
            role: data.member_type,
            licenseExpiry: data.license_number || 'No Active License',
            status: data.status,
            photo: existingUser.photo || null // Preserve existing local photo
          }
          setUser(mappedUser)
          localStorage.setItem('cubag_user', JSON.stringify(mappedUser))
        } else {
          // Token invalid
          localStorage.removeItem('cubag_token')
          navigate('/login')
        }
      } catch (e) {
        console.error(e)
        // Fallback to local storage if offline
        const userData = JSON.parse(localStorage.getItem('cubag_user') || '{}')
        if (userData.name) setUser(userData)
      }
    }
    fetchUser()

    // Check biometric availability and state
    async function initBiometrics() {
      try {
        const result = await NativeBiometric.isAvailable()
        if (result.isAvailable) {
          setBiometricAvailable(true)
          const enabled = localStorage.getItem('cubag_biometric_enabled') === 'true'
          setBiometricEnabled(enabled)
        }
      } catch (e) {}
    }
    initBiometrics()
  }, [navigate])

  const handleToggleBiometric = async () => {
    if (biometricEnabled) {
      // Disable
      try {
        await NativeBiometric.deleteCredentials({ server: "cubag.org.gh" })
        localStorage.setItem('cubag_biometric_enabled', 'false')
        setBiometricEnabled(false)
        showToast("Biometric login disabled.", "info")
      } catch (e) {
        showToast("Failed to disable biometrics.", "error")
      }
    } else {
      // Enable - Step 1: Show password prompt
      setShowPasswordPrompt(true)
    }
  }

  const handleConfirmBiometric = async (e) => {
    e.preventDefault()
    if (!confirmPassword) return

    setIsEnabling(true)
    try {
      // 1. Verify with Biometrics first
      await NativeBiometric.verifyIdentity({
        reason: "Confirm to enable biometric login",
        title: "Secure Setup",
        subtitle: "Verify your identity",
        description: "Verify your fingerprint or face to proceed"
      })

      // 2. Store Credentials
      await NativeBiometric.setCredentials({
        username: user.email,
        password: confirmPassword,
        server: "cubag.org.gh"
      })

      localStorage.setItem('cubag_biometric_enabled', 'true')
      setBiometricEnabled(true)
      setShowPasswordPrompt(false)
      setConfirmPassword('')
      showToast("Biometric login enabled successfully!", "success")
    } catch (e) {
      showToast("Verification failed. Please try again.", "error")
    } finally {
      setIsEnabling(false)
    }
  }

  const handlePhotoUpload = (e) => {
    const file = e.target.files[0]
    if (file) {
      const reader = new FileReader()
      reader.onloadend = () => {
        const base64String = reader.result
        const updatedUser = { ...user, photo: base64String }
        setUser(updatedUser)
        localStorage.setItem('cubag_user', JSON.stringify(updatedUser))
        
        // Auto-show ID card after successful upload
        setShowIdCard(true)
      }
      reader.readAsDataURL(file)
    }
  }



  const initials = (user.name || 'J').split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)

  const [showIdCard, setShowIdCard] = useState(false)
  
  // Generate unique member ID based on last name + id
  const lastName = user.name ? user.name.split(' ').pop().toUpperCase() : 'MEMBER'
  const uniqueMemberId = user.status === 'active' ? `CUBAG-${lastName}-00${user.memberId || '1'}` : 'VALIDATION REQUIRED'

  const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=MEMBER:${uniqueMemberId}`
  
  const handleViewIdCard = () => {
    if (user.status !== 'active') {
      showToast("Access Restricted: Please settle your dues to activate your Digital ID.", "error")
      return
    }
    if (!user.photo) {
      showToast("Please upload a selfie profile photo first to generate your Digital Identity Card.", "warning")
      document.getElementById('profile-upload-input').click()
      return
    }
    setShowIdCard(true)
  }

  return (
    <AppLayout title="Profile">
      <div style={{ maxWidth: 700, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>
        
        {/* Page Title for Content */}
        <div style={{ marginBottom: 4 }}>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>My Profile</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Manage your personal and professional information.</p>
        </div>

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
                    <span style={{ fontSize: '0.65rem', color: '#64748b', textTransform: 'uppercase', fontWeight: 700 }}>Expires</span>
                    <span style={{ fontSize: '0.85rem', fontWeight: 800, color: '#0f172a' }}>{user.licenseExpiry}</span>
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

        {/* Professional Details Card */}
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
              <div style={{ padding: '20px', background: user.status === 'active' ? 'rgba(240,130,50,0.05)' : 'rgba(239,68,68,0.05)' }}>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: 4 }}>License Number</div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 12 }}>
                  <div style={{ fontSize: '1.1rem', color: user.status === 'active' ? 'var(--text-primary)' : 'var(--brand-danger)', fontWeight: 700 }}>
                    {user.status === 'active' ? user.licenseExpiry : 'PAYMENT REQUIRED'}
                  </div>
                  <button className="btn btn-outline btn-sm" onClick={() => navigate('/license-renewal')} style={{ whiteSpace: 'nowrap' }}>
                    {user.status === 'active' ? 'Renew Now' : 'Pay to Activate'}
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Security Settings Card */}
        {biometricAvailable && (
          <div className="feed-card">
            <div className="card-header">
              <span className="card-title">Security & Preferences</span>
            </div>
            <div className="card-body" style={{ padding: '16px 20px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div>
                  <div style={{ fontSize: '0.95rem', fontWeight: 700, color: 'var(--text-primary)' }}>Biometric Login</div>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Use fingerprint or face recognition to sign in.</div>
                </div>
                <div
                  onClick={handleToggleBiometric}
                  style={{
                    width: 50, height: 26, borderRadius: 20,
                    background: biometricEnabled ? 'var(--brand-primary)' : 'var(--border-default)',
                    position: 'relative', cursor: 'pointer', transition: 'all 0.3s'
                  }}
                >
                  <div style={{
                    width: 20, height: 20, borderRadius: '50%', background: '#fff',
                    position: 'absolute', top: 3, left: biometricEnabled ? 27 : 3,
                    transition: 'all 0.3s', boxShadow: 'var(--shadow-sm)'
                  }} />
                </div>
              </div>
            </div>
          </div>
        )}

      </div>

      {/* Password Confirmation Modal for Biometrics */}
      {showPasswordPrompt && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)', zIndex: 10000, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 20 }}>
          <div style={{ background: 'var(--bg-surface)', borderRadius: 20, padding: 24, width: '100%', maxWidth: 400, animation: 'fadeInUp 0.3s' }}>
            <h3 style={{ margin: '0 0 10px', fontSize: '1.2rem' }}>Enable Biometric Login</h3>
            <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginBottom: 20 }}>Please enter your current password to securely link your biometrics to this device.</p>

            <form onSubmit={handleConfirmBiometric}>
              <div className="form-group">
                <label>Current Password</label>
                <input
                  type="password"
                  required
                  autoFocus
                  placeholder="••••••••"
                  value={confirmPassword}
                  onChange={e => setConfirmPassword(e.target.value)}
                  style={{ border: '2px solid var(--border-default)' }}
                />
              </div>

              <div style={{ display: 'flex', gap: 10, marginTop: 24 }}>
                <button type="button" className="btn btn-ghost" style={{ flex: 1 }} onClick={() => setShowPasswordPrompt(false)}>Cancel</button>
                <button type="submit" className="btn btn-primary" style={{ flex: 2 }} disabled={isEnabling}>
                  {isEnabling ? 'Verifying...' : 'Enable Now'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </AppLayout>
  )
}
