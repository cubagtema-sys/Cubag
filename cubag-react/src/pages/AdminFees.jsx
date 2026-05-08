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
    <AppLayout title="Fees">
      <div style={{ maxWidth: 700, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>
        
        {/* Page Title for Content */}
        <div style={{ marginBottom: 4 }}>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Fee Configuration</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Manage renewal, registration, and monthly dues.</p>
        </div>

        <div style={{ padding: '20px 16px', background: 'var(--bg-elevated)', borderRadius: 12 }}>
          <h2 style={{ fontSize: '1.1rem', marginBottom: 6, display: 'flex', alignItems: 'center', gap: 8 }}>
            <span className="material-symbols-outlined" style={{ color: 'var(--brand-primary)', fontSize: '1.2rem' }}>request_quote</span>
            Platform Fees
          </h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '0.85rem', marginBottom: 20 }}>
            Configure the default amounts for member payments.
          </p>

          {success && (
            <div style={{ padding: 10, background: 'rgba(16, 185, 129, 0.1)', color: 'var(--brand-success)', borderRadius: 8, marginBottom: 20, border: '1px solid rgba(16, 185, 129, 0.2)', display: 'flex', alignItems: 'center', gap: 8, fontSize: '0.85rem', fontWeight: 600 }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>check_circle</span>
              Fees updated!
            </div>
          )}

          <form onSubmit={handleSave} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            
            <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
              {[
                { name: 'renewalFee', label: 'License Renewal' },
                { name: 'registrationFee', label: 'Registration' },
                { name: 'monthlyDues', label: 'Monthly Dues' },
                { name: 'latePenaltyFee', label: 'Late Penalty' },
                { name: 'otherFee', label: 'Other/Misc' }
              ].map(f => (
                <div key={f.name} className="form-group">
                  <label style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)', marginBottom: 4 }}>{f.label} (GHS)</label>
                  <input 
                    type="number" 
                    name={f.name}
                    value={fees[f.name]}
                    onChange={handleChange}
                    style={{ width: '100%', padding: 10, border: '2.5px solid #e2e8f0', borderRadius: 8, background: '#fff', fontSize: '1rem', fontWeight: 800, textAlign: 'center', color: 'var(--text-primary)' }}
                  />
                </div>
              ))}
            </div>

            <button type="submit" className="btn btn-primary btn-lg" style={{ width: '100%', height: 48, borderRadius: 24, fontSize: '0.95rem', marginTop: 10 }} disabled={loading}>
              {loading ? 'Saving...' : 'Save Configuration'}
            </button>
          </form>
        </div>
      </div>
    </AppLayout>
  )
}
