import { useState, useEffect } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { NativeBiometric } from '@capgo/capacitor-native-biometric'

export default function Login() {
  const [memberId, setMemberId] = useState('')
  const [password, setPassword] = useState('')
  const [rememberMe, setRememberMe] = useState(false)
  const [showPassword, setShowPassword] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [biometricAvailable, setBiometricAvailable] = useState(false)
  const navigate = useNavigate()

  useEffect(() => {
    const savedId = localStorage.getItem('cubag_remember_id')
    const savedPass = localStorage.getItem('cubag_remember_pass')
    if (savedId) {
      setMemberId(savedId)
      setRememberMe(true)
    }
    if (savedPass) {
      setPassword(savedPass)
    }

    // Check if biometric is available
    async function checkBiometrics() {
      try {
        const result = await NativeBiometric.isAvailable()
        if (result.isAvailable) setBiometricAvailable(true)
      } catch (e) {
        console.log("Biometrics not available", e)
      }
    }
    checkBiometrics()
  }, [])

  const handleLogin = async (e) => {
    if (e) e.preventDefault()
    setLoading(true)
    setError('')

    try {
      const res = await fetch(`${import.meta.env.VITE_API_URL}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: memberId, password })
      })

      const data = await res.json()

      if (res.ok) {
        if (rememberMe) {
          localStorage.setItem('cubag_remember_id', memberId)
          localStorage.setItem('cubag_remember_pass', password)
        } else {
          localStorage.removeItem('cubag_remember_id')
          localStorage.removeItem('cubag_remember_pass')
        }

        localStorage.setItem('cubag_token', data.token)
        localStorage.setItem('cubag_user', JSON.stringify(data.user))
        // Redirect based on role — admin → /admin, everyone else → /dashboard
        navigate(data.user?.role === 'admin' ? '/admin' : '/dashboard')
      } else {
        setError(data.error || data.message || 'Login failed. Please check credentials.')
      }
    } catch (err) {
      setError('Connection error. Please try again later.')
    } finally {
      setLoading(false)
    }
  }

  const handleBiometricLogin = async () => {
    try {
      // 1. Verify Identity
      await NativeBiometric.verifyIdentity({
        reason: "Sign in to CUBAG",
        title: "Biometric Login",
        subtitle: "Use your fingerprint or face to sign in",
        description: "Verify your identity to proceed"
      })

      // 2. Retrieve Credentials
      const creds = await NativeBiometric.getCredentials({
        server: "cubag.org.gh"
      })

      if (creds && creds.username && creds.password) {
        // Perform login with retrieved credentials
        setLoading(true)
        const res = await fetch(`${import.meta.env.VITE_API_URL}/auth/login`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ email: creds.username, password: creds.password })
        })
        const data = await res.json()
        if (res.ok) {
          localStorage.setItem('cubag_token', data.token)
          localStorage.setItem('cubag_user', JSON.stringify(data.user))
          navigate(data.user?.role === 'admin' ? '/admin' : '/dashboard')
        } else {
          setError("Biometric login failed. Please use your password.")
        }
      }
    } catch (e) {
      console.log("Biometric Auth Failed", e)
      // Usually means user cancelled or no credentials stored
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="auth-layout">
      {/* Sidebar */}
      <div className="auth-sidebar">
        <div className="auth-sidebar-bg"></div>
        <div className="auth-sidebar-orb"></div>
        <div className="auth-sidebar-content">
          <Link to="/" style={{ display: 'inline-block', marginBottom: 60 }}>
            <span className="material-symbols-outlined" style={{ fontSize: '2rem', color: '#fff' }}>arrow_back</span>
          </Link>
          <h2>Welcome Back</h2>
          <p>Sign in to access the Enterprise Mobility Platform. Manage compliance, networking, and real-time logistics data.</p>
        </div>
      </div>

      {/* Main content */}
      <div className="auth-main">
        <div className="auth-container">
          <div className="auth-header">
            <Link to="/">
              <img src="/logo.jpeg" alt="CUBAG Logo" className="auth-logo"
                onError={(e) => { e.target.style.display = 'none' }} />
            </Link>
            <h1 className="auth-title">Member Login</h1>
            <p className="auth-subtitle">Enter your credentials to continue</p>
          </div>

          <form className="auth-form" onSubmit={handleLogin} name="loginform">
            {error && (
              <div style={{ padding: '12px', background: 'rgba(239,68,68,0.1)', color: 'var(--brand-danger)', borderRadius: 'var(--radius-md)', marginBottom: '20px', fontSize: '0.88rem' }}>
                {error}
              </div>
            )}
            
            <div className="form-group">
              <label htmlFor="memberId">Member ID or Email</label>
              <input
                type="text"
                id="memberId"
                name="username"
                autoComplete="username"
                placeholder="e.g. CUBAG-2024-0421"
                value={memberId}
                onChange={e => setMemberId(e.target.value)}
                required
              />
            </div>
            
            <div className="form-group">
              <div className="form-group-flex">
                <label htmlFor="password">Password</label>
                <Link to="/forgot-password" style={{ fontSize: '0.8rem', fontWeight: 600 }}>Forgot?</Link>
              </div>
              <div style={{ position: 'relative' }}>
                <input
                  type={showPassword ? 'text' : 'password'}
                  id="password"
                  name="password"
                  autoComplete="current-password"
                  placeholder="••••••••"
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  required
                  style={{ paddingRight: '44px', width: '100%', boxSizing: 'border-box' }}
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(v => !v)}
                  style={{ position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)', background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', padding: 0 }}
                  tabIndex={-1}
                  aria-label={showPassword ? 'Hide password' : 'Show password'}
                >
                  <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>
                    {showPassword ? 'visibility_off' : 'visibility'}
                  </span>
                </button>
              </div>
            </div>
            
            <div className="form-group-flex" style={{ margin: '20px 0', justifyContent: 'flex-start', gap: '8px' }}>
              <input
                type="checkbox"
                id="remember"
                style={{ width: 'auto' }}
                checked={rememberMe}
                onChange={e => setRememberMe(e.target.checked)}
              />
              <label htmlFor="remember" style={{ fontSize: '0.85rem', cursor: 'pointer' }}>Remember me</label>
            </div>
            
            <div style={{ display: 'flex', gap: 12 }}>
              <button type="submit" className="btn btn-primary btn-lg" disabled={loading} style={{ flex: 1, justifyContent: 'center' }}>
                {loading ? 'Authenticating...' : 'Sign In'}
              </button>

              {biometricAvailable && (
                <button
                  type="button"
                  className="btn btn-outline"
                  onClick={handleBiometricLogin}
                  style={{ width: 48, height: 48, padding: 0, justifyContent: 'center', borderRadius: 12 }}
                  title="Login with Biometrics"
                >
                  <span className="material-symbols-outlined" style={{ fontSize: '1.6rem' }}>fingerprint</span>
                </button>
              )}
            </div>
          </form>

          <div className="auth-footer">
            Don't have an account? <Link to="/register">Join CUBAG</Link>
          </div>
        </div>
      </div>
    </div>
  )
}
