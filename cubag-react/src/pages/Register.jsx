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
  const [showPassword, setShowPassword] = useState(false)
  const [showConfirmPassword, setShowConfirmPassword] = useState(false)
  const [error, setError] = useState('')

  const navigate = useNavigate()

  const memberOptions = [
    { value: 'Individual Broker', label: 'Individual Broker', icon: 'person' },
    { value: 'Corporate Agency', label: 'Corporate Agency', icon: 'business' },
    { value: 'Associate Member', label: 'Associate Member', icon: 'groups' }
  ]

  const portOptions = [
    { value: 'Tema Port', label: 'Tema Port', icon: 'directions_boat' },
    { value: 'Takoradi Port', label: 'Takoradi Port', icon: 'sailing' },
    { value: 'KIA Air Cargo', label: 'KIA Air Cargo', icon: 'flight' },
    { value: 'Elubo Border', label: 'Elubo Border', icon: 'local_shipping' },
    { value: 'Aflao Border', label: 'Aflao Border', icon: 'border_outer' }
  ]

  const validateStep1 = () => {
    if (!formData.name.trim() || !formData.email.trim() || !formData.phone.trim()) {
      setError('Please provide your identity details to continue.')
      return false
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
      setError('Please enter a valid email address.')
      return false
    }
    setError('')
    return true
  }

  const goToStep2 = () => { if (validateStep1()) setStep(2) }

  const goToStep3 = async () => {
    if (!formData.company.trim()) {
      setError('Please enter your agency or company name.')
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
        setError(data.error || data.message || 'Failed to send verification code.')
      }
    } catch (e) {
      setError('Network error. Please try again.')
    } finally {
      setIsLoading(false)
    }
  }

  const handleVerifyOTP = async (e) => {
    e.preventDefault()
    if (!otp || otp.length !== 6) {
      setError('Enter the 6-digit code sent to your email.')
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
        setError(data.error || data.message || 'Invalid or expired code.')
      }
    } catch (e) {
      setError('Connection error. Try again.')
    } finally {
      setIsLoading(false)
    }
  }

  const handleRegister = async (e) => {
    e.preventDefault()
    if (!formData.password || formData.password !== formData.confirmPassword) {
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

  const STEPS = [
    { n: 1, label: 'Identity', icon: 'person' },
    { n: 2, label: 'Professional', icon: 'badge' },
    { n: 3, label: 'Verify', icon: 'mark_email_read' },
    { n: 4, label: 'Security', icon: 'lock' }
  ]

  return (
    <div className="auth-layout">
      {/* Visual Sidebar */}
      <div className="auth-sidebar">
        <div className="auth-sidebar-bg"></div>
        <div className="auth-sidebar-orb"></div>
        <div className="auth-sidebar-content">
          <Link to="/" style={{ display: 'inline-block', marginBottom: 40 }}>
            <span className="material-symbols-outlined" style={{ fontSize: '2rem', color: '#fff' }}>arrow_back</span>
          </Link>
          <h2 style={{ fontSize: '2.5rem', fontWeight: 800, lineHeight: 1.1 }}>Join the Elite Network</h2>
          <p style={{ marginTop: 16, fontSize: '1rem', opacity: 0.9 }}>Connect to the Enterprise Mobility Platform for Ghana's Customs Brokers.</p>
          
          <div style={{ marginTop: 40, display: 'flex', flexDirection: 'column', gap: 20 }}>
            <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
              <div style={{ width: 40, height: 40, borderRadius: 10, background: 'rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>verified_user</span>
              </div>
              <span style={{ fontWeight: 600, fontSize: '0.9rem' }}>Official Credentials</span>
            </div>
            <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
              <div style={{ width: 40, height: 40, borderRadius: 10, background: 'rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>monitoring</span>
              </div>
              <span style={{ fontWeight: 600, fontSize: '0.9rem' }}>Real-time Intelligence</span>
            </div>
          </div>
        </div>
      </div>

      <div className="auth-main">
        <div className="auth-container" style={{ maxWidth: 500 }}>

          <div className="auth-header">
            <Link to="/">
              <img src="/logo.jpeg" alt="CUBAG Logo" className="auth-logo"
                onError={(e) => { e.target.style.display = 'none' }} />
            </Link>
            <h1 className="auth-title" style={{ fontSize: '1.8rem' }}>
              {step === 1 ? 'Join CUBAG' : (step === 2 ? 'Professional Profile' : (step === 3 ? 'Verify Identity' : 'Secure Account'))}
            </h1>
            <p className="auth-subtitle">
              {step === 1 ? 'Start by providing your basic contact information.' :
               step === 2 ? 'Tell us about your agency or brokerage.' :
               step === 3 ? `Enter the code sent to ${formData.email}` :
               'Choose a strong password for your new account.'}
            </p>
          </div>

          {/* Progress Tracker */}
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 32, position: 'relative', padding: '0 10px' }}>
            <div style={{ position: 'absolute', top: 18, left: 20, right: 20, height: 2, background: 'var(--border-subtle)', zIndex: 1 }}>
              <div style={{ width: `${((step - 1) / (STEPS.length - 1)) * 100}%`, height: '100%', background: 'var(--brand-primary)', transition: 'width 0.4s ease' }}></div>
            </div>
            {STEPS.map(s => (
              <div key={s.n} style={{ position: 'relative', zIndex: 2, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
                <div style={{
                  width: 38, height: 38, borderRadius: '50%',
                  background: step >= s.n ? 'var(--brand-primary)' : 'var(--bg-card)',
                  color: step >= s.n ? '#fff' : 'var(--text-muted)',
                  border: `2px solid ${step >= s.n ? 'var(--brand-primary)' : 'var(--border-subtle)'}`,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  transition: 'all 0.3s ease', fontSize: '1rem'
                }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>{s.icon}</span>
                </div>
                <span style={{ fontSize: '0.65rem', fontWeight: 800, textTransform: 'uppercase', color: step >= s.n ? 'var(--brand-primary)' : 'var(--text-muted)' }}>{s.label}</span>
              </div>
            ))}
          </div>

          <form className="auth-form" onSubmit={e => e.preventDefault()} style={{ boxShadow: 'var(--shadow-md)' }}>
            {error && (
              <div style={{ padding: '12px 16px', background: 'rgba(239,68,68,0.08)', color: '#ef4444', borderRadius: 10, fontSize: '0.85rem', marginBottom: 20, border: '1px solid rgba(239,68,68,0.2)', fontWeight: 600 }}>
                {error}
              </div>
            )}

            {/* Step 1: Identity */}
            {step === 1 && (
              <div className="animate-fadeInUp" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                <div className="form-group">
                  <label>Full Name</label>
                  <input type="text" value={formData.name} placeholder="e.g. John Mensah" onChange={e => setFormData({...formData, name: e.target.value})} />
                </div>
                <div className="form-group">
                  <label>Email Address</label>
                  <input type="email" value={formData.email} placeholder="e.g. john@agency.com" onChange={e => setFormData({...formData, email: e.target.value})} />
                </div>
                <div className="form-group">
                  <label>Phone Number</label>
                  <input
                    type="tel"
                    value={formData.phone}
                    placeholder="e.g. 024 5678 901"
                    onChange={e => {
                      // Remove all non-digits
                      const val = e.target.value.replace(/\D/g, '');
                      // Format: XXX XXXX XXX
                      let formatted = val;
                      if (val.length > 3 && val.length <= 7) {
                        formatted = `${val.slice(0, 3)} ${val.slice(3)}`;
                      } else if (val.length > 7) {
                        formatted = `${val.slice(0, 3)} ${val.slice(3, 7)} ${val.slice(7, 10)}`;
                      }
                      setFormData({...formData, phone: formatted});
                    }}
                  />
                </div>
                <div className="form-group">
                  <CustomSelect label="Membership Type" options={memberOptions} value={formData.memberType} onChange={v => setFormData({...formData, memberType: v})} icon="groups" />
                </div>
                <button type="button" onClick={goToStep2} className="btn btn-primary btn-lg btn-full" style={{ marginTop: 8 }}>Next Step</button>
              </div>
            )}

            {/* Step 2: Professional */}
            {step === 2 && (
              <div className="animate-fadeInUp" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                <div className="form-group">
                  <label>Agency or Company Name</label>
                  <input type="text" value={formData.company} placeholder="e.g. Global Logistics Ltd" onChange={e => setFormData({...formData, company: e.target.value})} />
                </div>

                <div style={{ padding: '12px', background: 'rgba(240,130,50,0.05)', borderRadius: 10, border: '1px dashed var(--brand-primary)', marginBottom: 4 }}>
                  <p style={{ fontSize: '0.75rem', color: 'var(--brand-primary)', fontWeight: 700, margin: 0 }}>Note for New Applicants:</p>
                  <p style={{ fontSize: '0.7rem', color: 'var(--text-muted)', margin: '4px 0 0' }}>If you don't have these yet, leave them blank. CUBAG will assign them upon approval.</p>
                </div>

                <div className="form-group">
                  <label>License # <span style={{ fontWeight: 400, opacity: 0.6 }}>(Optional)</span></label>
                  <input type="text" value={formData.licenseNumber} placeholder="LIC/..." onChange={e => setFormData({...formData, licenseNumber: e.target.value})} />
                </div>
                <div className="form-group">
                  <label>Agency Code <span style={{ fontWeight: 400, opacity: 0.6 }}>(Optional)</span></label>
                  <input type="text" value={formData.agencyCode} placeholder="CUB-..." onChange={e => setFormData({...formData, agencyCode: e.target.value})} />
                </div>

                <div className="form-group">
                  <CustomSelect label="Primary Port of Operation" options={portOptions} value={formData.portOfOperation} onChange={v => setFormData({...formData, portOfOperation: v})} icon="anchor" />
                </div>

                <div style={{ display: 'flex', gap: 12, marginTop: 8, flexWrap: 'wrap' }}>
                  <button type="button" onClick={() => setStep(1)} className="btn btn-outline" style={{ flex: 1, minWidth: '100px' }}>Back</button>
                  <button type="button" onClick={goToStep3} disabled={isLoading} className="btn btn-primary" style={{ flex: 2, minWidth: '160px' }}>
                    {isLoading ? 'Sending Code...' : 'Verify Email'}
                  </button>
                </div>
              </div>
            )}

            {/* Step 3: OTP */}
            {step === 3 && (
              <div className="animate-fadeInUp" style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
                <div style={{ textAlign: 'center' }}>
                  <div style={{ width: 60, height: 60, background: 'rgba(240,130,50,0.1)', color: 'var(--brand-primary)', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px' }}>
                    <span className="material-symbols-outlined" style={{ fontSize: '2rem' }}>mark_email_read</span>
                  </div>
                  <p style={{ fontSize: '0.9rem', color: 'var(--text-secondary)', marginBottom: 20 }}>Check your inbox for a 6-digit verification code.</p>
                </div>

                <div className="form-group">
                  <input
                    type="text" 
                    required 
                    placeholder="0 0 0 0 0 0"
                    maxLength={6}
                    value={otp}
                    style={{ border: '2.5px solid #000', background: '#fff', color: '#000', padding: 14, fontSize: '1.6rem', letterSpacing: '0.4em', textAlign: 'center', borderRadius: 14, fontWeight: 800 }}
                    onChange={e => setOtp(e.target.value.replace(/\D/g, ''))} 
                  />
                </div>
                
                <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
                  <button type="button" onClick={() => setStep(2)} className="btn btn-outline" style={{ flex: 1, minWidth: '100px' }}>Back</button>
                  <button type="button" disabled={isLoading} onClick={handleVerifyOTP} className="btn btn-primary" style={{ flex: 2, minWidth: '160px' }}>
                    {isLoading ? 'Verifying...' : 'Verify Code'}
                  </button>
                </div>
              </div>
            )}

            {/* Step 4: Password */}
            {step === 4 && (
              <div className="animate-fadeInUp" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                <div className="form-group">
                  <label>Create Password</label>
                  <div style={{ position: 'relative' }}>
                    <input
                      type={showPassword ? 'text' : 'password'}
                      required
                      placeholder="At least 8 characters"
                      style={{ paddingRight: '44px' }}
                      onChange={e => setFormData({...formData, password: e.target.value})}
                    />
                    <button type="button" onClick={() => setShowPassword(!showPassword)} style={{ position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)', background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)' }}>
                      <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>{showPassword ? 'visibility_off' : 'visibility'}</span>
                    </button>
                  </div>
                </div>

                <div className="form-group">
                  <label>Confirm Password</label>
                  <div style={{ position: 'relative' }}>
                    <input
                      type={showConfirmPassword ? 'text' : 'password'}
                      required
                      placeholder="Repeat password"
                      style={{ paddingRight: '44px' }}
                      onChange={e => setFormData({...formData, confirmPassword: e.target.value})}
                    />
                    <button type="button" onClick={() => setShowConfirmPassword(!showConfirmPassword)} style={{ position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)', background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)' }}>
                      <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>{showConfirmPassword ? 'visibility_off' : 'visibility'}</span>
                    </button>
                  </div>
                </div>

                <div style={{ display: 'flex', gap: 12, marginTop: 8 }}>
                  <button type="button" disabled={isLoading} onClick={handleRegister} className="btn btn-primary btn-full btn-lg">
                    {isLoading ? 'Creating Account...' : 'Complete Registration'}
                  </button>
                </div>
              </div>
            )}

          </form>

          <div className="auth-footer" style={{ marginTop: 32 }}>
            Already have an account? <Link to="/login" style={{ color: 'var(--brand-primary)', fontWeight: 800 }}>Sign In</Link>
          </div>
        </div>
      </div>
    </div>
  )
}
