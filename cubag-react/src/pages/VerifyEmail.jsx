import { useState, useEffect } from 'react'
import { Link, useSearchParams, useNavigate } from 'react-router-dom'

export default function VerifyEmail() {
  const [searchParams] = useSearchParams()
  const token = searchParams.get('token')
  const navigate = useNavigate()
  
  const [status, setStatus] = useState('verifying') // 'verifying', 'success', 'error'
  const [message, setMessage] = useState('Verifying your email address...')

  useEffect(() => {
    if (!token) {
      setStatus('error')
      setMessage('Invalid or missing verification token.')
      return
    }

    const verifyToken = async () => {
      try {
        const res = await fetch(`${import.meta.env.VITE_API_URL}/auth/verify-email`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ token })
        })
        const data = await res.json()

        if (res.ok) {
          setStatus('success')
          setMessage('Your email has been verified! You can now log in to the portal.')
        } else {
          setStatus('error')
          setMessage(data.message || 'Verification failed. The link may have expired.')
        }
      } catch (err) {
        setStatus('error')
        setMessage('Network error while verifying email. Please try again later.')
      }
    }

    verifyToken()
  }, [token])

  return (
    <div className="auth-layout" style={{ justifyContent: 'center', alignItems: 'center', background: 'var(--bg-base)', minHeight: '100vh', display: 'flex', padding: 20 }}>
      <div className="auth-container" style={{ maxWidth: 420, textAlign: 'center', padding: '32px 24px', background: 'var(--bg-card)', borderRadius: 24, boxShadow: 'var(--shadow-md)', border: '1px solid var(--border-subtle)' }}>
        
        <div style={{ marginBottom: 20 }}>
          {status === 'verifying' && (
            <div style={{ width: 60, height: 60, margin: '0 auto', border: '3.5px solid var(--border-subtle)', borderTopColor: 'var(--brand-primary)', borderRadius: '50%', animation: 'spin 1s linear infinite' }}></div>
          )}
          {status === 'success' && (
            <div style={{ width: 64, height: 64, background: 'rgba(16,185,129,0.1)', color: '#10b981', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '3rem' }}>check_circle</span>
            </div>
          )}
          {status === 'error' && (
            <div style={{ width: 64, height: 64, background: 'rgba(239,68,68,0.1)', color: '#ef4444', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '3rem' }}>error</span>
            </div>
          )}
        </div>

        <h1 style={{ fontSize: '1.4rem', fontWeight: 800, marginBottom: 8 }}>Email Verification</h1>
        <p style={{ color: 'var(--text-secondary)', marginBottom: 28, fontSize: '0.9rem', lineHeight: 1.5 }}>
          {message}
        </p>

        {status !== 'verifying' && (
          <button className="btn btn-primary btn-lg btn-full" style={{ height: 48, fontSize: '0.95rem' }} onClick={() => navigate('/login')}>
            Go to Login
          </button>
        )}
      </div>
      
      <style>{`
        @keyframes spin {
          0% { transform: rotate(0deg); }
          100% { transform: rotate(360deg); }
        }
      `}</style>
    </div>
  )
}
