import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import CustomSelect from '../components/CustomSelect'

export default function Register() {
  const [step, setStep] = useState(1)
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    phone: '',
    company: '',
    licenseNumber: '',
    agencyCode: '',
    portOfOperation: 'Tema Port',
    memberType: 'Individual Broker',
    password: '',
    confirmPassword: ''
  })
  const [otp, setOtp] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const navigate = useNavigate()

  const memberOptions = [
    { value: 'Individual Broker', label: 'Individual', icon: 'person' },
    { value: 'Corporate Agency', label: 'Corporate', icon: 'business' },
    { value: 'Associate Member', label: 'Associate', icon: 'groups' }
  ]

  const portOptions = [
    { value: 'Tema Port', label: 'Tema', icon: 'directions_boat' },
    { value: 'Takoradi Port', label: 'Takoradi', icon: 'sailing' },
    { value: 'KIA Air Cargo', label: 'KIA', icon: 'flight' },
    { value: 'Elubo Border', label: 'Elubo', icon: 'local_shipping' },
    { value: 'Aflao Border', label: 'Aflao', icon: 'border_outer' }
  ]

  const [error, setError] = useState('')

  const goToStep2 = () => {
    if (!formData.name.trim() || !formData.email.trim() || !formData.phone.trim()) {
      setError('Please fill in all fields before continuing.')
      return
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
      setError('Please enter a valid email address.')
      return
    }
    setError('')
    setStep(2)
  }

  const goToStep3 = async () => {
    if (!formData.company.trim() || !formData.licenseNumber.trim() || !formData.agencyCode.trim()) {
      setError('Please fill in all fields before continuing.')
      return
    }
    setError('')
    setIsLoading(true)
    
    try {
      const res = await fetch(`${import.meta.env.VITE_API_URL}/auth/send-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: formData.email })
      })
      const data = await res.json()
      if (res.ok) {
        setStep(3)
      } else {
        setError(data.error || data.message || 'Failed to send OTP.')
      }
    } catch (e) {
      setError('Connection error. Please try again.')
    } finally {
      setIsLoading(false)
    }
  }

  const handleRegister = async (e) => {
    e.preventDefault()
    if (!formData.password || !formData.confirmPassword) {
      setError('Please enter and confirm your password.')
      return
    }
    if (formData.password !== formData.confirmPassword) {
      setError('Passwords do not match.')
      return
    }
    if (formData.password.length < 8) {
      setError('Password must be at least 8 characters.')
      return
    }
    setError('')
    setIsLoading(true)
    
    try {
      const res = await fetch(`${import.meta.env.VITE_API_URL}/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData)
      })
      const data = await res.json()
      if (res.ok) {
        navigate('/login')
      } else {
        setError(data.error || data.message || 'Registration failed.')
      }
    } catch (e) {
      setError('Connection error. Please try again.')
    } finally {
      setIsLoading(false)
    }
  }

  const handleVerifyOTP = async (e) => {
    e.preventDefault()
    if (!otp || otp.length !== 6) {
      setError('Please enter a valid 6-digit code.')
      return
    }
    setError('')
    setIsLoading(true)
    
    try {
      const res = await fetch(`${import.meta.env.VITE_API_URL}/auth/verify-email`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: formData.email, token: otp })
      })
      const data = await res.json()
      if (res.ok) {
        setStep(4)
      } else {
        setError(data.error || data.message || 'Verification failed. Invalid code.')
      }
    } catch (e) {
      setError('Connection error. Please try again.')
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="auth-layout">
      {/* LEFT SIDEBAR - Matching Login */}
      <div className="auth-sidebar">
        <div className="auth-sidebar-bg"></div>
        <div className="auth-sidebar-orb"></div>
        <div className="auth-sidebar-content">
          <Link to="/" style={{ display: 'inline-block', marginBottom: 60 }}>
            <span className="material-symbols-outlined" style={{ fontSize: '2rem', color: '#fff' }}>arrow_back</span>
          </Link>
          <h2 style={{ fontSize: '2.8rem', fontWeight: 800, lineHeight: 1.1 }}>Join the Elite Network</h2>
          <p style={{ marginTop: 20 }}>Official Membership Portal for the Customs Brokers Association of Ghana.</p>
          
          <div style={{ marginTop: 48, display: 'flex', flexDirection: 'column', gap: 24 }}>
            <div style={{ display: 'flex', gap: 16, alignItems: 'center' }}>
              <div style={{ width: 44, height: 44, borderRadius: 12, background: 'rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <span className="material-symbols-outlined">verified_user</span>
              </div>
              <span style={{ fontWeight: 600 }}>Verified Credentials</span>
            </div>
            <div style={{ display: 'flex', gap: 16, alignItems: 'center' }}>
              <div style={{ width: 44, height: 44, borderRadius: 12, background: 'rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <span className="material-symbols-outlined">monitoring</span>
              </div>
              <span style={{ fontWeight: 600 }}>Logistics Intelligence</span>
            </div>
          </div>
        </div>
      </div>

      {/* RIGHT SIDE - Matching Login Structure */}
      <div className="auth-main" style={{ background: '#f8fafc' }}>
        <div className="auth-container" style={{ maxWidth: 520 }}>
          <div className="auth-header" style={{ marginBottom: 20 }}>
            <img src="/logo.jpeg" alt="CUBAG Logo" className="auth-logo" />
            <h1 className="auth-title" style={{ fontSize: '1.6rem', marginBottom: 4 }}>Create Account</h1>
            <p className="auth-subtitle">Step {step} of 4: {step === 1 ? 'Personal Info' : (step === 2 ? 'Official Details' : (step === 3 ? 'Email Verification' : 'Account Security'))}</p>
          </div>

          <form className="auth-form" onSubmit={e => { e.preventDefault(); if (step === 3) handleVerifyOTP(e); else if (step === 4) handleRegister(e); }} style={{ padding: '32px', background: '#fff', border: 'none', boxShadow: '0 10px 40px rgba(0,0,0,0.05)', borderRadius: 24 }}>
            
            {/* Step 1: Personal */}
            {step === 1 && (
              <div className="animate-fadeInUp" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                {error && <div style={{ padding: '10px 14px', background: 'rgba(239,68,68,0.08)', color: '#ef4444', borderRadius: 8, fontSize: '0.82rem', border: '1px solid rgba(239,68,68,0.2)' }}>{error}</div>}
                <div className="form-group">
                  <label style={{ color: '#000', fontWeight: 800, fontSize: '0.8rem', marginBottom: 4 }}>Full Name</label>
                  <input type="text" required placeholder="John Mensah" style={{ border: '2px solid #000', background: '#fff', color: '#000', padding: 12 }} onChange={e => setFormData({...formData, name: e.target.value})} />
                </div>
                <div className="form-group">
                  <label style={{ color: '#000', fontWeight: 800, fontSize: '0.8rem', marginBottom: 4 }}>Email Address</label>
                  <input type="email" required placeholder="john@agency.com" style={{ border: '2px solid #000', background: '#fff', color: '#000', padding: 12 }} onChange={e => setFormData({...formData, email: e.target.value})} />
                </div>
                <div className="form-group">
                  <label style={{ color: '#000', fontWeight: 800, fontSize: '0.8rem', marginBottom: 4 }}>Phone Number</label>
                  <input type="tel" required placeholder="+233..." style={{ border: '2px solid #000', background: '#fff', color: '#000', padding: 12 }} onChange={e => setFormData({...formData, phone: e.target.value})} />
                </div>
                <button type="button" onClick={goToStep2} className="btn btn-primary btn-lg btn-full" style={{ height: 54, marginTop: 10 }}>Continue</button>
              </div>
            )}

            {/* Step 2: Professional */}
            {step === 2 && (
              <div className="animate-fadeInUp" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                {error && <div style={{ padding: '10px 14px', background: 'rgba(239,68,68,0.08)', color: '#ef4444', borderRadius: 8, fontSize: '0.82rem', border: '1px solid rgba(239,68,68,0.2)' }}>{error}</div>}
                <div className="form-group">
                  <label style={{ color: '#000', fontWeight: 800, fontSize: '0.8rem', marginBottom: 4 }}>Agency Name</label>
                  <input type="text" required placeholder="Global Logistics Ltd" style={{ border: '2px solid #000', background: '#fff', color: '#000', padding: 12 }} onChange={e => setFormData({...formData, company: e.target.value})} />
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                  <div className="form-group">
                    <label style={{ color: '#000', fontWeight: 800, fontSize: '0.8rem', marginBottom: 4 }}>License #</label>
                    <input type="text" required placeholder="LIC/..." style={{ border: '2px solid #000', background: '#fff', color: '#000', padding: 12 }} onChange={e => setFormData({...formData, licenseNumber: e.target.value})} />
                  </div>
                  <div className="form-group">
                    <label style={{ color: '#000', fontWeight: 800, fontSize: '0.8rem', marginBottom: 4 }}>Agency Code</label>
                    <input type="text" required placeholder="CUB-..." style={{ border: '2px solid #000', background: '#fff', color: '#000', padding: 12 }} onChange={e => setFormData({...formData, agencyCode: e.target.value})} />
                  </div>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                  <CustomSelect label="Port" options={portOptions} value={formData.portOfOperation} onChange={v => setFormData({...formData, portOfOperation: v})} />
                  <CustomSelect label="Type" options={memberOptions} value={formData.memberType} onChange={v => setFormData({...formData, memberType: v})} />
                </div>
                <div style={{ display: 'flex', gap: 12, marginTop: 10 }}>
                  <button type="button" onClick={() => setStep(1)} className="btn btn-outline" style={{ flex: 1, height: 54 }}>Back</button>
                  <button type="button" onClick={goToStep3} className="btn btn-primary" style={{ flex: 2, height: 54 }}>Next Step</button>
                </div>
              </div>
            )}

            {/* Step 3: OTP Verification */}
            {step === 3 && (
              <div className="animate-fadeInUp" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                {error && <div style={{ padding: '10px 14px', background: 'rgba(239,68,68,0.08)', color: '#ef4444', borderRadius: 8, fontSize: '0.82rem', border: '1px solid rgba(239,68,68,0.2)' }}>{error}</div>}
                
                <div style={{ textAlign: 'center', marginBottom: 16 }}>
                  <div style={{ width: 64, height: 64, background: 'rgba(240,130,50,0.1)', color: 'var(--brand-primary)', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px' }}>
                    <span className="material-symbols-outlined" style={{ fontSize: '2rem' }}>mark_email_read</span>
                  </div>
                  <h3 style={{ fontSize: '1.2rem', marginBottom: 8 }}>Verify your email</h3>
                  <p style={{ fontSize: '0.9rem', color: 'var(--text-secondary)' }}>We've sent a 6-digit code to <strong>{formData.email}</strong>.</p>
                </div>

                <div className="form-group">
                  <label style={{ color: '#000', fontWeight: 800, fontSize: '0.8rem', marginBottom: 4, textAlign: 'center', display: 'block' }}>6-Digit OTP Code</label>
                  <input 
                    type="text" 
                    required 
                    placeholder="123456" 
                    maxLength={6}
                    value={otp}
                    style={{ border: '2px solid #000', background: '#fff', color: '#000', padding: 16, fontSize: '1.5rem', letterSpacing: '0.5em', textAlign: 'center', borderRadius: 12, fontWeight: 800 }} 
                    onChange={e => setOtp(e.target.value.replace(/\D/g, ''))} 
                  />
                </div>
                
                <div style={{ display: 'flex', gap: 12, marginTop: 10 }}>
                  <button type="button" onClick={() => setStep(2)} className="btn btn-outline" style={{ flex: 1, height: 54 }}>Back</button>
                  <button type="button" disabled={isLoading} onClick={handleVerifyOTP} className="btn btn-primary" style={{ flex: 2, height: 54 }}>
                    {isLoading ? 'Verifying...' : 'Verify Code'}
                  </button>
                </div>
              </div>
            )}

            {/* Step 4: Security */}
            {step === 4 && (
              <div className="animate-fadeInUp" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                {error && <div style={{ padding: '10px 14px', background: 'rgba(239,68,68,0.08)', color: '#ef4444', borderRadius: 8, fontSize: '0.82rem', border: '1px solid rgba(239,68,68,0.2)' }}>{error}</div>}
                <div className="form-group">
                  <label style={{ color: '#000', fontWeight: 800, fontSize: '0.8rem', marginBottom: 4 }}>Password</label>
                  <input type="password" required placeholder="••••••••" style={{ border: '2px solid #000', background: '#fff', color: '#000', padding: 12 }} onChange={e => setFormData({...formData, password: e.target.value})} />
                </div>
                <div className="form-group">
                  <label style={{ color: '#000', fontWeight: 800, fontSize: '0.8rem', marginBottom: 4 }}>Confirm Password</label>
                  <input type="password" required placeholder="••••••••" style={{ border: '2px solid #000', background: '#fff', color: '#000', padding: 12 }} onChange={e => setFormData({...formData, confirmPassword: e.target.value})} />
                </div>
                <div style={{ display: 'flex', gap: 12, marginTop: 10 }}>
                  <button type="button" disabled={isLoading} onClick={handleRegister} className="btn btn-primary" style={{ flex: 2, height: 54 }}>
                    {isLoading ? 'Processing...' : 'Complete Register'}
                  </button>
                </div>
              </div>
            )}

          </form>

          <div className="auth-footer" style={{ textAlign: 'center', marginTop: 24 }}>
            Already have an account? <Link to="/login" style={{ color: 'var(--brand-primary)', fontWeight: 800 }}>Sign In here</Link>
          </div>
        </div>
      </div>
    </div>
  )
}
