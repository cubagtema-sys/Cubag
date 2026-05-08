import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout.jsx'

export default function AdminSettings() {
  const [user, setUser] = useState({ name: 'System Administrator', email: 'admin@cubag.org', role: 'Platform Admin' })
  const [passwordForm, setPasswordForm] = useState({ current: '', new: '', confirm: '' })
  const [message, setMessage] = useState('')

  useEffect(() => {
    try {
      const stored = localStorage.getItem('cubag_user')
      if (stored) {
        setUser(JSON.parse(stored))
      }
    } catch (e) {
      console.error(e)
    }
  }, [])

  const handlePasswordChange = (e) => {
    e.preventDefault()
    if (passwordForm.new !== passwordForm.confirm) {
      setMessage('New passwords do not match.')
      return
    }
    // Simulate password reset
    setMessage('Password successfully reset.')
    setPasswordForm({ current: '', new: '', confirm: '' })
    
    // Clear message after 3 seconds
    setTimeout(() => setMessage(''), 3000)
  }

  return (
    <AppLayout title="Settings">
      <div style={{ maxWidth: 1000, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>

        {/* Page Title for Content */}
        <div style={{ marginBottom: 4 }}>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Admin Profile</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Manage your administrative credentials and security.</p>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div className="feed-card" style={{ padding: '20px 16px', borderRadius: 12 }}>
            <h3 style={{ marginBottom: 16, display: 'flex', alignItems: 'center', gap: 8, fontSize: '1rem' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1.2rem', color: 'var(--brand-primary)' }}>person</span>
              Profile Details
            </h3>
            <div className="form-group">
              <label style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)' }}>Full Name</label>
              <input type="text" value={user.name || 'System Administrator'} readOnly disabled style={{ background: 'var(--bg-base)', border: '1px solid var(--border-subtle)', padding: 10, fontSize: '0.9rem' }} />
            </div>
            <div className="form-group">
              <label style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)' }}>Email Address</label>
              <input type="email" value={user.email || 'admin@cubag.org'} readOnly disabled style={{ background: 'var(--bg-base)', border: '1px solid var(--border-subtle)', padding: 10, fontSize: '0.9rem' }} />
            </div>
            <div className="form-group">
              <label style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)' }}>Role</label>
              <input type="text" value={user.role || 'Platform Admin'} readOnly disabled style={{ background: 'var(--bg-base)', border: '1px solid var(--border-subtle)', padding: 10, fontSize: '0.9rem' }} />
            </div>
          </div>

          <div className="feed-card" style={{ padding: '20px 16px', borderRadius: 12 }}>
            <h3 style={{ marginBottom: 16, display: 'flex', alignItems: 'center', gap: 8, fontSize: '1rem' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1.2rem', color: 'var(--brand-primary)' }}>lock_reset</span>
              Reset Password
            </h3>
            {message && (
              <div style={{ padding: '10px 14px', background: message.includes('success') ? '#10b981' : '#ef4444', color: '#fff', borderRadius: 8, marginBottom: 16, fontSize: '0.85rem', fontWeight: 600 }}>
                {message}
              </div>
            )}
            <form onSubmit={handlePasswordChange} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
              <div className="form-group">
                <label style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)' }}>Current Password</label>
                <input 
                  type="password" 
                  value={passwordForm.current} 
                  onChange={e => setPasswordForm({...passwordForm, current: e.target.value})} 
                  required 
                  style={{ padding: 10, fontSize: '0.9rem' }}
                />
              </div>
              <div className="form-group">
                <label style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)' }}>New Password</label>
                <input 
                  type="password" 
                  value={passwordForm.new} 
                  onChange={e => setPasswordForm({...passwordForm, new: e.target.value})} 
                  required 
                  style={{ padding: 10, fontSize: '0.9rem' }}
                />
              </div>
              <div className="form-group">
                <label style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)' }}>Confirm Password</label>
                <input 
                  type="password" 
                  value={passwordForm.confirm} 
                  onChange={e => setPasswordForm({...passwordForm, confirm: e.target.value})} 
                  required 
                  style={{ padding: 10, fontSize: '0.9rem' }}
                />
              </div>
              <button type="submit" className="btn btn-primary" style={{ height: 48, fontSize: '0.95rem', marginTop: 6 }}>
                Update Password
              </button>
            </form>
          </div>
        </div>
      </div>
    </AppLayout>
  )
}
