import { useState } from 'react'
import { Link, useSearchParams, useNavigate } from 'react-router-dom'

export default function ResetPassword() {
  const [searchParams] = useSearchParams()
  const email = searchParams.get('email')
  const token = searchParams.get('token')
  const navigate = useNavigate()

  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState(false)

  const handleReset = async (e) => {
    e.preventDefault()
    setIsLoading(true)
    setError('')

    if (password !== confirmPassword) {
      setError('Passwords do not match.')
      setIsLoading(false)
      return
    }

    try {
      const res = await fetch(`${import.meta.env.VITE_API_URL}/auth/reset-password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, code: token, new_password: password })
      })
      
      const data = await res.json()
      
      if (res.ok) {
        setSuccess(true)
        setTimeout(() => navigate('/login'), 3000)
      } else {
        setError(data.message || 'Failed to reset password.')
      }
    } catch (err) {
      setError('Connection error. Please try again later.')
    } finally {
      setIsLoading(false)
    }
  }

  if (!email || !token) {
    return (
      <div className="welcome-screen">
        <div className="welcome-bg">
          <div className="welcome-orb orb-1"></div>
          <div className="welcome-orb orb-2"></div>
        </div>
        <div className="welcome-content" style={{ padding: '40px 24px', maxWidth: 450 }}>
          <div style={{ textAlign: 'center', background: 'rgba(239, 68, 68, 0.1)', padding: '40px 20px', borderRadius: 16, border: '1px solid rgba(239, 68, 68, 0.2)' }}>
            <span className="material-symbols-outlined" style={{ fontSize: '4rem', color: '#ef4444', marginBottom: 20 }}>error</span>
            <h3 style={{ marginBottom: 12 }}>Invalid Link</h3>
            <p style={{ fontSize: '0.9rem', opacity: 0.8, marginBottom: 32 }}>
              The password reset link is invalid or missing required parameters. Please request a new one.
            </p>
            <Link to="/forgot-password" className="btn btn-primary btn-full">Request New Link</Link>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="welcome-screen">
      <div className="welcome-bg">
        <div className="welcome-orb orb-1"></div>
        <div className="welcome-orb orb-2"></div>
      </div>

      <div className="welcome-content" style={{ padding: '24px', maxWidth: 450, width: '100%' }}>
        <div className="welcome-header" style={{ marginBottom: 32 }}>
          <img src="/logo.jpeg" alt="CUBAG" className="welcome-logo" style={{ width: 60, height: 60, borderRadius: 16 }} />
          <h1 style={{ fontSize: 'clamp(1.5rem, 5vw, 1.8rem)', marginTop: 20 }}>Set New Password</h1>
          <p style={{ opacity: 0.8, fontSize: '0.88rem', maxWidth: 300, margin: '10px auto 0' }}>
            Choose a new, secure password for your account.
          </p>
        </div>

        {success ? (
          <div style={{ textAlign: 'center', background: 'rgba(16, 185, 129, 0.1)', padding: '40px 24px', borderRadius: 20, border: '1px solid rgba(16, 185, 129, 0.2)', animation: 'fadeInUp 0.4s ease' }}>
            <div style={{ width: 80, height: 80, borderRadius: '50%', background: 'var(--brand-success)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 24px', boxShadow: '0 10px 20px rgba(16, 185, 129, 0.2)' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '3rem' }}>check_circle</span>
            </div>
            <h2 style={{ fontSize: '1.5rem', marginBottom: 12, color: 'var(--text-primary)' }}>Password Reset Completed</h2>
            <p style={{ fontSize: '0.95rem', opacity: 0.8, marginBottom: 32, color: 'var(--text-secondary)' }}>
              Your password has been updated successfully. You can now log in using your new credentials.
            </p>
            <Link to="/login" className="btn btn-primary btn-full btn-lg">Back to Login</Link>
          </div>
        ) : (
          <form onSubmit={handleReset} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            {error && (
              <div style={{ background: 'rgba(239, 68, 68, 0.1)', color: '#ef4444', padding: '12px', borderRadius: 8, fontSize: '0.82rem', textAlign: 'center' }}>
                {error}
              </div>
            )}

            <div className="form-group">
              <label style={{ fontSize: '0.82rem', marginBottom: 6, display: 'block', fontWeight: 600 }}>New Password</label>
              <input 
                type="password" 
                required 
                placeholder="Enter new password"
                value={password}
                onChange={e => setPassword(e.target.value)}
                minLength={8}
              />
            </div>

            <div className="form-group">
              <label style={{ fontSize: '0.82rem', marginBottom: 6, display: 'block', fontWeight: 600 }}>Confirm Password</label>
              <input 
                type="password" 
                required 
                placeholder="Confirm new password"
                value={confirmPassword}
                onChange={e => setConfirmPassword(e.target.value)}
                minLength={8}
              />
            </div>

            <button type="submit" disabled={isLoading} className="btn btn-primary btn-lg btn-full" style={{ marginTop: 8 }}>
              {isLoading ? 'Updating...' : 'Update Password'}
            </button>
          </form>
        )}
      </div>
    </div>
  )
}
