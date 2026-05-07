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
    <div className="auth-layout" style={{ justifyContent: 'center', alignItems: 'center', background: '#f8fafc', minHeight: '100vh', display: 'flex' }}>
      <div className="auth-container" style={{ maxWidth: 460, textAlign: 'center', padding: '40px 30px', background: '#fff', borderRadius: 24, boxShadow: '0 10px 40px rgba(0,0,0,0.05)' }}>
        
        <div style={{ marginBottom: 24 }}>
          {status === 'verifying' && (
            <div style={{ width: 80, height: 80, margin: '0 auto', border: '4px solid #f3f4f6', borderTopColor: 'var(--brand-primary)', borderRadius: '50%', animation: 'spin 1s linear infinite' }}></div>
          )}
          {status === 'success' && (
            <span className="material-symbols-outlined" style={{ fontSize: '5rem', color: 'var(--brand-success)' }}>check_circle</span>
          )}
          {status === 'error' && (
            <span className="material-symbols-outlined" style={{ fontSize: '5rem', color: 'var(--brand-danger)' }}>error</span>
          )}
        </div>

        <h1 style={{ fontSize: '1.5rem', marginBottom: 12 }}>Email Verification</h1>
        <p style={{ color: 'var(--text-secondary)', marginBottom: 32, lineHeight: 1.5 }}>
          {message}
        </p>

        {status !== 'verifying' && (
          <button className="btn btn-primary btn-lg btn-full" onClick={() => navigate('/login')}>
            Continue to Login
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
