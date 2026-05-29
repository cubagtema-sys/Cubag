import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import AppLayout from '../components/AppLayout'

export default function Settings() {
  const navigate = useNavigate()
  const [isChangingPassword, setIsChangingPassword] = useState(false)
  const [passwords, setPasswords] = useState({ current: '', next: '', confirm: '' })
  const [showPasswords, setShowPasswords] = useState({ current: false, next: false, confirm: false })
  const [message, setMessage] = useState('')

  const handlePasswordChange = async (e) => {
    e.preventDefault()
    if (passwords.next !== passwords.confirm) {
      setMessage('Passwords do not match!')
      return
    }

    try {
      const baseUrl = import.meta.env.VITE_API_URL.endsWith('/')
        ? import.meta.env.VITE_API_URL.slice(0, -1)
        : import.meta.env.VITE_API_URL;

      const res = await fetch(`${baseUrl}/auth/change-password`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('cubag_token')}`
        },
        body: JSON.stringify({
          current_password: passwords.current,
          new_password: passwords.next
        })
      })
      const data = await res.json()
      if (res.ok) {
        setMessage('✅ Password updated successfully!')
        setTimeout(() => {
          setIsChangingPassword(false)
          setMessage('')
          setPasswords({ current: '', next: '', confirm: '' })
        }, 2000)
      } else {
        setMessage(`❌ ${data.message || 'Update failed'}`)
      }
    } catch (err) {
      setMessage('❌ Connection error. Try again.')
    }
  }

  return (
    <AppLayout title="Account Settings">
      <div style={{ maxWidth: 700, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>
        
        {/* Page Title removed as it is now in the header */}

        {!isChangingPassword ? (
          <div className="feed-card">
            <div className="card-header">
              <span className="card-title">Settings & Security</span>
            </div>
            <div className="card-body" style={{ padding: 0 }}>
              <div 
                onClick={() => setIsChangingPassword(true)}
                style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '16px 20px', borderBottom: '1px solid var(--border-subtle)', cursor: 'pointer' }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <span className="material-symbols-outlined" style={{ color: 'var(--text-secondary)' }}>lock</span>
                  <span style={{ fontWeight: 600, color: 'var(--text-primary)' }}>Change Password</span>
                </div>
                <span className="material-symbols-outlined" style={{ color: 'var(--text-muted)' }}>chevron_right</span>
              </div>
              
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '16px 20px', borderBottom: '1px solid var(--border-subtle)', cursor: 'pointer' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <span className="material-symbols-outlined" style={{ color: 'var(--text-secondary)' }}>notifications_active</span>
                  <span style={{ fontWeight: 600, color: 'var(--text-primary)' }}>Push Notifications</span>
                </div>
                <input type="checkbox" defaultChecked style={{ width: 20, height: 20 }} />
              </div>

              {/* Contact Support */}
              <div style={{ padding: '12px 20px 4px', borderBottom: '1px solid var(--border-subtle)' }}>
                <span style={{ fontSize: '0.7rem', fontWeight: 800, textTransform: 'uppercase', letterSpacing: '0.06em', color: 'var(--text-muted)' }}>Contact &amp; Support</span>
              </div>

              {[
                { icon: 'call',  color: 'var(--brand-primary)', bg: 'rgba(240,130,50,0.1)', label: 'Call Support', value: '+233 (0) 302 123 456', href: 'tel:+233302123456' },
                { icon: 'mail',  color: '#3b82f6',              bg: 'rgba(59,130,246,0.1)',  label: 'Email Us',    value: 'support@cubag.org.gh',  href: 'mailto:support@cubag.org.gh' },
                { icon: 'forum', color: '#10b981',              bg: 'rgba(16,185,129,0.1)',  label: 'Support Center',   value: 'Help desk & messages',   to: '/engagement' },
              ].map((c, i, arr) => (
                <div key={c.label}
                  onClick={() => c.to ? navigate(c.to) : (window.location.href = c.href)}
                  style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '14px 20px', cursor: 'pointer', borderBottom: i < arr.length - 1 ? '1px solid var(--border-subtle)' : 'none' }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                    <div style={{ width: 34, height: 34, borderRadius: 9, background: c.bg, color: c.color, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                      <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>{c.icon}</span>
                    </div>
                    <div>
                      <div style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '0.85rem' }}>{c.label}</div>
                      <div style={{ fontSize: '0.72rem', color: 'var(--text-muted)' }}>{c.value}</div>
                    </div>
                  </div>
                  <span className="material-symbols-outlined" style={{ color: 'var(--text-muted)', fontSize: '1.1rem' }}>chevron_right</span>
                </div>
              ))}
            </div>
          </div>
        ) : (
          <div className="feed-card">
            <div className="card-header" style={{ justifyContent: 'flex-start' }}>
              <span className="card-title">Change Password</span>
            </div>
            <div className="card-body">
              <form onSubmit={handlePasswordChange} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', marginBottom: 6 }}>Current Password</label>
                  <div style={{ position: 'relative' }}>
                    <input
                      type={showPasswords.current ? "text" : "password"}
                      required
                      value={passwords.current}
                      onChange={e => setPasswords({...passwords, current: e.target.value})}
                      style={{ width: '100%', padding: '10px 40px 10px 10px', border: '1px solid var(--border-subtle)', borderRadius: '4px', background: 'var(--bg-input)', color: 'var(--text-primary)' }}
                    />
                    <span
                      className="material-symbols-outlined"
                      onClick={() => setShowPasswords({...showPasswords, current: !showPasswords.current})}
                      style={{ position: 'absolute', right: 10, top: '50%', transform: 'translateY(-50%)', cursor: 'pointer', color: 'var(--text-muted)', fontSize: '1.2rem', userSelect: 'none' }}
                    >
                      {showPasswords.current ? 'visibility' : 'visibility_off'}
                    </span>
                  </div>
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', marginBottom: 6 }}>New Password</label>
                  <div style={{ position: 'relative' }}>
                    <input
                      type={showPasswords.next ? "text" : "password"}
                      required
                      value={passwords.next}
                      onChange={e => setPasswords({...passwords, next: e.target.value})}
                      style={{ width: '100%', padding: '10px 40px 10px 10px', border: '1px solid var(--border-subtle)', borderRadius: '4px', background: 'var(--bg-input)', color: 'var(--text-primary)' }}
                    />
                    <span
                      className="material-symbols-outlined"
                      onClick={() => setShowPasswords({...showPasswords, next: !showPasswords.next})}
                      style={{ position: 'absolute', right: 10, top: '50%', transform: 'translateY(-50%)', cursor: 'pointer', color: 'var(--text-muted)', fontSize: '1.2rem', userSelect: 'none' }}
                    >
                      {showPasswords.next ? 'visibility' : 'visibility_off'}
                    </span>
                  </div>
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', marginBottom: 6 }}>Confirm New Password</label>
                  <div style={{ position: 'relative' }}>
                    <input
                      type={showPasswords.confirm ? "text" : "password"}
                      required
                      value={passwords.confirm}
                      onChange={e => setPasswords({...passwords, confirm: e.target.value})}
                      style={{ width: '100%', padding: '10px 40px 10px 10px', border: '1px solid var(--border-subtle)', borderRadius: '4px', background: 'var(--bg-input)', color: 'var(--text-primary)' }}
                    />
                    <span
                      className="material-symbols-outlined"
                      onClick={() => setShowPasswords({...showPasswords, confirm: !showPasswords.confirm})}
                      style={{ position: 'absolute', right: 10, top: '50%', transform: 'translateY(-50%)', cursor: 'pointer', color: 'var(--text-muted)', fontSize: '1.2rem', userSelect: 'none' }}
                    >
                      {showPasswords.confirm ? 'visibility' : 'visibility_off'}
                    </span>
                  </div>
                </div>
                
                {message && <div style={{ color: message.includes('success') ? 'var(--brand-success)' : 'var(--brand-danger)', fontSize: '0.9rem' }}>{message}</div>}

                <div style={{ display: 'flex', gap: 12, marginTop: 8 }}>
                  <button type="submit" className="btn btn-primary" style={{ flex: 1 }}>Update Password</button>
                  <button type="button" className="btn btn-outline" style={{ flex: 1 }} onClick={() => setIsChangingPassword(false)}>Cancel</button>
                </div>
              </form>
            </div>
          </div>
        )}

      </div>
    </AppLayout>
  )
}
