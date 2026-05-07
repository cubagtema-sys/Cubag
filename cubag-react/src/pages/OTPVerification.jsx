import { useState, useRef, useEffect } from 'react'
import { useNavigate, useLocation, Link } from 'react-router-dom'

export default function OTPVerification() {
  const [otp, setOtp] = useState(['', '', '', '', '', ''])
  const [isVerifying, setIsVerifying] = useState(false)
  const [isResending, setIsResending] = useState(false)
  const [error, setError] = useState('')
  const [countdown, setCountdown] = useState(60)
  const [canResend, setCanResend] = useState(false)
  const inputs = useRef([])
  const navigate = useNavigate()
  const location = useLocation()
  const email = location.state?.email || 'your email'

  useEffect(() => {
    if (countdown > 0) {
      const timer = setTimeout(() => setCountdown(c => c - 1), 1000)
      return () => clearTimeout(timer)
    } else {
      setCanResend(true)
    }
  }, [countdown])

  const handleChange = (val, idx) => {
    if (!/^\d?$/.test(val)) return
    const newOtp = [...otp]
    newOtp[idx] = val
    setOtp(newOtp)
    if (val && idx < 5) inputs.current[idx + 1]?.focus()
  }

  const handleKeyDown = (e, idx) => {
    if (e.key === 'Backspace' && !otp[idx] && idx > 0) {
      inputs.current[idx - 1]?.focus()
    }
  }

  const handlePaste = (e) => {
    const paste = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, 6)
    if (paste.length === 6) {
      setOtp(paste.split(''))
      inputs.current[5]?.focus()
    }
  }

  const handleVerify = async () => {
    const code = otp.join('')
    if (code.length < 6) {
      setError('Please enter all 6 digits')
      return
    }
    setIsVerifying(true)
    setError('')
    try {
      const res = await fetch(`${import.meta.env.VITE_API_URL}/auth/verify-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, otp: code })
      })
      if (res.ok) {
        navigate('/dashboard')
      } else {
        const data = await res.json()
        setError(data.message || 'Invalid or expired code')
      }
    } catch {
      setError('Connection error. Please try again.')
    } finally {
      setIsVerifying(false)
    }
  }

  const handleResend = async () => {
    setIsResending(true)
    setError('')
    try {
      await fetch(`${import.meta.env.VITE_API_URL}/auth/resend-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email })
      })
    } catch {}
    setIsResending(false)
    setCountdown(60)
    setCanResend(false)
    setOtp(['', '', '', '', '', ''])
    inputs.current[0]?.focus()
  }

  return (
    <div className="auth-layout">
      <div className="auth-sidebar">
        <div className="auth-sidebar-bg"></div>
        <div className="auth-sidebar-orb"></div>
        <div className="auth-sidebar-content">
          <Link to="/register" style={{ display: 'inline-block', marginBottom: 60 }}>
            <span className="material-symbols-outlined" style={{ fontSize: '2rem', color: '#fff' }}>arrow_back</span>
          </Link>
          <h2>Email Verification</h2>
          <p style={{ marginTop: 16 }}>We've sent a 6-digit one-time code to your registered email. Enter it to verify your identity and activate your account.</p>
          <div style={{ marginTop: 48, display: 'flex', gap: 16, alignItems: 'center' }}>
            <div style={{ width: 44, height: 44, borderRadius: 12, background: 'rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <span className="material-symbols-outlined">shield_lock</span>
            </div>
            <span style={{ fontWeight: 600 }}>Your data is encrypted and secure</span>
          </div>
        </div>
      </div>

      <div className="auth-main" style={{ background: '#f8fafc' }}>
        <div className="auth-container">
          <div className="auth-header">
            <img src="/logo.jpeg" alt="CUBAG Logo" className="auth-logo" />
            <h1 className="auth-title">Verify Your Email</h1>
            <p className="auth-subtitle">Code sent to <strong>{email}</strong></p>
          </div>

          <div className="auth-form" style={{ padding: '40px' }}>
            {error && (
              <div style={{ padding: '10px 14px', background: 'rgba(239,68,68,0.08)', color: '#ef4444', borderRadius: 8, fontSize: '0.85rem', marginBottom: 24, border: '1px solid rgba(239,68,68,0.2)' }}>{error}</div>
            )}

            {/* OTP Inputs */}
            <div style={{ display: 'flex', gap: 12, justifyContent: 'center', marginBottom: 32 }} onPaste={handlePaste}>
              {otp.map((digit, idx) => (
                <input
                  key={idx}
                  ref={el => inputs.current[idx] = el}
                  type="text"
                  inputMode="numeric"
                  maxLength={1}
                  value={digit}
                  onChange={e => handleChange(e.target.value, idx)}
                  onKeyDown={e => handleKeyDown(e, idx)}
                  style={{
                    width: 56, height: 64, textAlign: 'center',
                    fontSize: '1.8rem', fontWeight: 800,
                    border: digit ? '2px solid var(--brand-primary)' : '2px solid #000',
                    borderRadius: 12, background: '#fff', color: '#000',
                    outline: 'none', transition: 'border-color 0.2s'
                  }}
                />
              ))}
            </div>

            <button
              onClick={handleVerify}
              disabled={isVerifying}
              className="btn btn-primary btn-lg btn-full"
              style={{ height: 54, marginBottom: 20 }}
            >
              {isVerifying ? 'Verifying...' : 'Verify & Activate Account'}
            </button>

            <div style={{ textAlign: 'center', fontSize: '0.9rem', color: 'var(--text-secondary)' }}>
              {canResend ? (
                <button onClick={handleResend} disabled={isResending} style={{ background: 'none', border: 'none', color: 'var(--brand-primary)', fontWeight: 700, cursor: 'pointer', fontSize: '0.9rem' }}>
                  {isResending ? 'Sending...' : 'Resend Code'}
                </button>
              ) : (
                <span>Resend code in <strong style={{ color: 'var(--brand-primary)' }}>{countdown}s</strong></span>
              )}
            </div>
          </div>

          <div className="auth-footer" style={{ textAlign: 'center' }}>
            Wrong email? <Link to="/register" style={{ color: 'var(--brand-primary)', fontWeight: 700 }}>Go Back</Link>
          </div>
        </div>
      </div>
    </div>
  )
}
