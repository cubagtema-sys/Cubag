import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

export default function AdminFees() {
  const [loading, setLoading] = useState(false)
  const [success, setSuccess] = useState(false)
  
  const [fees, setFees] = useState({
    renewalFee: '1500.00',
    registrationFee: '500.00',
    monthlyDues: '100.00',
    latePenaltyFee: '50.00',
    otherFee: '0.00'
  })

  useEffect(() => {
    fetch(`${import.meta.env.VITE_API_URL}/settings/cubag_fees`)
      .then(res => res.json())
      .then(data => {
        if (data && data.renewalFee) setFees(data)
      })
      .catch(e => console.error(e))
  }, [])

  const handleChange = (e) => {
    setFees({ ...fees, [e.target.name]: e.target.value })
  }

  const handleSave = async (e) => {
    e.preventDefault()
    setLoading(true)
    setSuccess(false)
    
    try {
      await fetch(`${import.meta.env.VITE_API_URL}/settings/cubag_fees`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(fees)
      })
      setSuccess(true)
      setTimeout(() => setSuccess(false), 3000)
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  return (
    <AppLayout title="Fee Management" hideSearch>
      <div style={{ maxWidth: 700, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 24 }}>
        
        <div style={{ padding: '24px', background: 'var(--bg-elevated)', borderRadius: 16 }}>
          <h2 style={{ fontSize: '1.4rem', marginBottom: 8, display: 'flex', alignItems: 'center', gap: 8 }}>
            <span className="material-symbols-outlined" style={{ color: 'var(--brand-primary)' }}>request_quote</span>
            Fee Configuration
          </h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '0.95rem', marginBottom: 24 }}>
            Manage all standard platform fees including renewals, registrations, and monthly dues.
          </p>

          {success && (
            <div style={{ padding: 12, background: 'rgba(16, 185, 129, 0.1)', color: 'var(--brand-success)', borderRadius: 8, marginBottom: 24, border: '1px solid rgba(16, 185, 129, 0.2)', display: 'flex', alignItems: 'center', gap: 8 }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>check_circle</span>
              Fees updated successfully!
            </div>
          )}

          <form onSubmit={handleSave} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
            
            <div style={{ width: '100%', maxWidth: 400, marginBottom: 32 }}>
              <h3 style={{ fontSize: '1.2rem', marginBottom: 16, paddingBottom: 8, color: 'var(--brand-primary)', borderBottom: '2px solid rgba(240,130,50,0.1)', display: 'inline-block' }}>Platform Fees</h3>
              
              <div style={{ display: 'flex', flexDirection: 'column', gap: 16, alignItems: 'center' }}>
                <div className="form-group" style={{ width: '100%', alignItems: 'center' }}>
                  <label style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-secondary)' }}>Annual License Renewal Fee (GHS)</label>
                  <input 
                    type="number" 
                    name="renewalFee"
                    value={fees.renewalFee}
                    onChange={handleChange}
                    style={{ width: '100%', padding: 12, border: '2px solid #e2e8f0', borderRadius: 8, background: '#fff', fontSize: '1.2rem', fontWeight: 800, textAlign: 'center', color: 'var(--text-primary)' }} 
                  />
                </div>

                <div className="form-group" style={{ width: '100%', alignItems: 'center' }}>
                  <label style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-secondary)' }}>New Member Registration Fee (GHS)</label>
                  <input 
                    type="number" 
                    name="registrationFee"
                    value={fees.registrationFee}
                    onChange={handleChange}
                    style={{ width: '100%', padding: 12, border: '2px solid #e2e8f0', borderRadius: 8, background: '#fff', fontSize: '1.2rem', fontWeight: 800, textAlign: 'center', color: 'var(--text-primary)' }} 
                  />
                </div>

                <div className="form-group" style={{ width: '100%', alignItems: 'center' }}>
                  <label style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-secondary)' }}>Monthly Member Dues (GHS)</label>
                  <input 
                    type="number" 
                    name="monthlyDues"
                    value={fees.monthlyDues}
                    onChange={handleChange}
                    style={{ width: '100%', padding: 12, border: '2px solid #e2e8f0', borderRadius: 8, background: '#fff', fontSize: '1.2rem', fontWeight: 800, textAlign: 'center', color: 'var(--text-primary)' }} 
                  />
                </div>

                <div className="form-group" style={{ width: '100%', alignItems: 'center' }}>
                  <label style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-secondary)' }}>Late Penalty Fee (GHS)</label>
                  <input 
                    type="number" 
                    name="latePenaltyFee"
                    value={fees.latePenaltyFee}
                    onChange={handleChange}
                    style={{ width: '100%', padding: 12, border: '2px solid #e2e8f0', borderRadius: 8, background: '#fff', fontSize: '1.2rem', fontWeight: 800, textAlign: 'center', color: 'var(--text-primary)' }} 
                  />
                </div>

                <div className="form-group" style={{ width: '100%', alignItems: 'center' }}>
                  <label style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-secondary)' }}>Default Other/Misc Fee (GHS)</label>
                  <input 
                    type="number" 
                    name="otherFee"
                    value={fees.otherFee}
                    onChange={handleChange}
                    style={{ width: '100%', padding: 12, border: '2px solid #e2e8f0', borderRadius: 8, background: '#fff', fontSize: '1.2rem', fontWeight: 800, textAlign: 'center', color: 'var(--text-primary)' }} 
                  />
                </div>
              </div>
            </div>

            <button type="submit" className="btn btn-primary btn-lg" style={{ width: '100%', maxWidth: 400, height: 54, borderRadius: 27 }} disabled={loading}>
              {loading ? 'Saving Fees...' : 'Save Fees'}
            </button>
          </form>
        </div>
      </div>
    </AppLayout>
  )
}
