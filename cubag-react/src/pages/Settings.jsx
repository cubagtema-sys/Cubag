import { useState } from 'react'
import AppLayout from '../components/AppLayout'

export default function Settings() {
  const [isChangingPassword, setIsChangingPassword] = useState(false)
  const [passwords, setPasswords] = useState({ current: '', next: '', confirm: '' })
  const [message, setMessage] = useState('')

  const handlePasswordChange = (e) => {
    e.preventDefault()
    if (passwords.next !== passwords.confirm) {
      setMessage('Passwords do not match!')
      return
    }
    // Simulate API call
    setMessage('Password updated successfully!')
    setTimeout(() => {
      setIsChangingPassword(false)
      setMessage('')
      setPasswords({ current: '', next: '', confirm: '' })
    }, 2000)
  }

  return (
    <AppLayout title="Settings">
      <div style={{ maxWidth: 700, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>
        
        {/* Page Title for Content */}
        <div style={{ marginBottom: 4 }}>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Settings</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Configure your account preferences and security.</p>
        </div>

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
              
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '16px 20px', cursor: 'pointer' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                  <span className="material-symbols-outlined" style={{ color: 'var(--text-secondary)' }}>notifications_active</span>
                  <span style={{ fontWeight: 600, color: 'var(--text-primary)' }}>Push Notifications</span>
                </div>
                <input type="checkbox" defaultChecked style={{ width: 20, height: 20 }} />
              </div>
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
                  <input 
                    type="password" 
                    required
                    value={passwords.current}
                    onChange={e => setPasswords({...passwords, current: e.target.value})}
                    style={{ width: '100%', padding: '10px', border: '1px solid var(--border-subtle)', borderRadius: '4px' }} 
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', marginBottom: 6 }}>New Password</label>
                  <input 
                    type="password" 
                    required
                    value={passwords.next}
                    onChange={e => setPasswords({...passwords, next: e.target.value})}
                    style={{ width: '100%', padding: '10px', border: '1px solid var(--border-subtle)', borderRadius: '4px' }} 
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', marginBottom: 6 }}>Confirm New Password</label>
                  <input 
                    type="password" 
                    required
                    value={passwords.confirm}
                    onChange={e => setPasswords({...passwords, confirm: e.target.value})}
                    style={{ width: '100%', padding: '10px', border: '1px solid var(--border-subtle)', borderRadius: '4px' }} 
                  />
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
