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
    <AppLayout title="Admin Settings">
      <div className="container section animate-fadeInUp">
        <div className="section-header">
          <h1 className="section-title">Admin Profile & Settings</h1>
          <p className="section-subtitle">Manage your platform administrator account and security credentials.</p>
        </div>

        <div className="form-row">
          <div className="card">
            <h3 style={{ marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <span className="material-symbols-outlined">person</span>
              Profile Details
            </h3>
            <div className="form-group">
              <label>Full Name</label>
              <input type="text" value={user.name || 'System Administrator'} readOnly disabled />
            </div>
            <div className="form-group">
              <label>Email Address</label>
              <input type="email" value={user.email || 'admin@cubag.org'} readOnly disabled />
            </div>
            <div className="form-group">
              <label>Role</label>
              <input type="text" value={user.role || 'Platform Admin'} readOnly disabled />
            </div>
          </div>

          <div className="card">
            <h3 style={{ marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <span className="material-symbols-outlined">lock_reset</span>
              Reset Password
            </h3>
            {message && (
              <div style={{ padding: '12px', background: message.includes('success') ? 'var(--brand-success)' : 'var(--brand-danger)', color: '#fff', borderRadius: 'var(--radius-md)', marginBottom: '16px', fontSize: '0.9rem' }}>
                {message}
              </div>
            )}
            <form onSubmit={handlePasswordChange}>
              <div className="form-group">
                <label>Current Password</label>
                <input 
                  type="password" 
                  value={passwordForm.current} 
                  onChange={e => setPasswordForm({...passwordForm, current: e.target.value})} 
                  required 
                />
              </div>
              <div className="form-group">
                <label>New Password</label>
                <input 
                  type="password" 
                  value={passwordForm.new} 
                  onChange={e => setPasswordForm({...passwordForm, new: e.target.value})} 
                  required 
                />
              </div>
              <div className="form-group">
                <label>Confirm New Password</label>
                <input 
                  type="password" 
                  value={passwordForm.confirm} 
                  onChange={e => setPasswordForm({...passwordForm, confirm: e.target.value})} 
                  required 
                />
              </div>
              <button type="submit" className="btn btn-primary btn-full" style={{ marginTop: '16px' }}>
                Update Password
              </button>
            </form>
          </div>
        </div>
      </div>
    </AppLayout>
  )
}
