import { useState } from 'react'
import { Link } from 'react-router-dom'

export default function ForgotPassword() {
  const [email, setEmail] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const [isSent, setIsSent] = useState(false)
  const [error, setError] = useState('')

  const handleReset = async (e) => {
    e.preventDefault()
    setIsLoading(true)
    setError('')

    try {
      const res = await fetch(`${import.meta.env.VITE_API_URL}/auth/forgot-password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email })
      })
      
      if (res.ok) {
        setIsSent(true)
      } else {
        setError('We couldn’t find an account with that email.')
      }
    } catch (err) {
      setError('Connection error. Please try again later.')
    } finally {
      setIsLoading(false)
    }
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
          <h1 style={{ fontSize: 'clamp(1.5rem, 5vw, 1.8rem)', marginTop: 20 }}>Reset Password</h1>
          <p style={{ opacity: 0.8, fontSize: '0.88rem', maxWidth: 300, margin: '10px auto 0' }}>
            Enter your email and we'll send you instructions to reset your password.
          </p>
        </div>

        {isSent ? (
          <div style={{ textAlign: 'center', background: 'rgba(255,255,255,0.05)', padding: '40px 20px', borderRadius: 16, border: '1px solid rgba(255,255,255,0.1)' }}>
            <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="var(--brand-primary)" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" style={{ display: 'block', margin: '0 auto 20px' }}>
              <path d="M22 10.5V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v12c0 1.1.9 2 2 2h12.5"/>
              <path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/>
              <path d="M20 14L22 16L17 21L15 19"/>
            </svg>
            <h3 style={{ marginBottom: 12 }}>Check your Inbox</h3>
            <p style={{ fontSize: '0.9rem', opacity: 0.8, marginBottom: 32 }}>
              If an account exists for <b>{email}</b>, you will receive a reset link shortly.
            </p>
            <Link to="/login" className="btn btn-primary btn-full">Back to Login</Link>
          </div>
        ) : (
          <form onSubmit={handleReset} style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
            {error && (
              <div style={{ background: 'rgba(239, 68, 68, 0.1)', color: '#ef4444', padding: '12px', borderRadius: 8, fontSize: '0.85rem', textAlign: 'center' }}>
                {error}
              </div>
            )}

            <div className="form-group">
              <label style={{ fontSize: '0.82rem', marginBottom: 6, display: 'block', fontWeight: 600 }}>Recovery Email</label>
              <input 
                type="email" 
                required 
                placeholder="broker@example.com"
                value={email}
                onChange={e => setEmail(e.target.value)}
              />
            </div>

            <button type="submit" disabled={isLoading} className="btn btn-primary btn-lg btn-full" style={{ marginTop: 8 }}>
              {isLoading ? 'Processing...' : 'Send Reset Link'}
            </button>

            <div style={{ textAlign: 'center', marginTop: 24, fontSize: '0.9rem' }}>
              Remember your password? <Link to="/login" style={{ color: 'var(--brand-primary)', fontWeight: 600 }}>Sign In</Link>
            </div>
          </form>
        )}
      </div>
    </div>
  )
}
