import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

const API = import.meta.env.VITE_API_URL

export default function AdminFees() {
  const [fees, setFees]       = useState([])
  const [loading, setLoading] = useState(false)
  const [success, setSuccess] = useState(false)
  const [error, setError]     = useState('')

  useEffect(() => {
    fetch(`${API}/settings/cubag_fees_v2`)
      .then(res => res.json())
      .then(data => {
        if (Array.isArray(data)) {
          setFees(data)
        }
      })
      .catch(e => console.error(e))
  }, [])

  const updateFee = (id, field, val) =>
    setFees(prev => prev.map(f => f.id === id ? { ...f, [field]: val } : f))

  const removeFee = (id) =>
    setFees(prev => prev.filter(f => f.id !== id))

  const addFee = () => {
    setFees(prev => [...prev, { id: Date.now(), label: '', amount: '0.00' }])
  }

  const handleSave = async (e) => {
    e.preventDefault()
    // Validate
    if (fees.some(f => !f.label.trim())) {
      return setError('All fees must have a name.')
    }

    setLoading(true); setSuccess(false); setError('')
    try {
      const res = await fetch(`${API}/settings/cubag_fees_v2`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(fees)
      })
      if (res.ok) {
        setSuccess(true)
        setTimeout(() => setSuccess(false), 3000)
      } else {
        setError('Failed to save. Please try again.')
      }
    } catch (err) {
      setError('Network error.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <AppLayout title="Platform Fees">
      <div style={{ maxWidth: 720, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 20 }}>

        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Fee Configuration</h2>
            <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Define custom payment categories and amounts.</p>
          </div>
          <button type="button" onClick={addFee} className="btn btn-primary btn-sm">
            <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>add</span> Add Fee
          </button>
        </div>

        {success && (
          <div style={{ padding: '10px 16px', background: 'rgba(16,185,129,0.1)', color: '#10b981', borderRadius: 12, fontSize: '0.85rem', fontWeight: 700, border: '1px solid rgba(16,185,129,0.2)', display: 'flex', alignItems: 'center', gap: 8 }}>
            <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>check_circle</span>
            Fee configuration saved!
          </div>
        )}
        {error && (
          <div style={{ padding: '10px 16px', background: 'rgba(239,68,68,0.08)', color: '#ef4444', borderRadius: 12, fontSize: '0.85rem', fontWeight: 700, border: '1px solid rgba(239,68,68,0.15)', display: 'flex', alignItems: 'center', gap: 8 }}>
            <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>error</span>
            {error}
          </div>
        )}

        <form onSubmit={handleSave} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          {fees.length === 0 && !loading && (
            <div style={{ textAlign: 'center', padding: '40px 20px', background: 'var(--bg-base)', borderRadius: 16, border: '2px dashed var(--border-subtle)', color: 'var(--text-muted)' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '3rem', marginBottom: 12, opacity: 0.5 }}>payments</span>
              <p style={{ fontWeight: 600 }}>No fees configured yet. Click "Add Fee" to start.</p>
            </div>
          )}

          {fees.map((fee) => (
            <div key={fee.id} className="feed-card" style={{ padding: '16px', borderRadius: 16, display: 'flex', flexWrap: 'wrap', gap: 16, alignItems: 'flex-end', position: 'relative' }}>
              <button
                type="button"
                onClick={() => removeFee(fee.id)}
                style={{ position: 'absolute', top: 12, right: 12, background: 'none', border: 'none', color: '#ef4444', cursor: 'pointer' }}
              >
                <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>delete</span>
              </button>

              <div style={{ flex: '2 1 200px' }}>
                <label style={{ display: 'block', fontSize: '0.72rem', fontWeight: 700, color: 'var(--text-secondary)', marginBottom: 6, textTransform: 'uppercase' }}>Fee Name</label>
                <input
                  type="text"
                  value={fee.label}
                  onChange={e => updateFee(fee.id, 'label', e.target.value)}
                  placeholder="e.g. Annual Subscription"
                  style={{ width: '100%', padding: '12px', borderRadius: 10, border: '1.5px solid var(--border-default)', background: 'var(--bg-base)', color: 'var(--text-primary)', fontWeight: 600 }}
                />
              </div>

              <div style={{ flex: '1 1 120px' }}>
                <label style={{ display: 'block', fontSize: '0.72rem', fontWeight: 700, color: 'var(--text-secondary)', marginBottom: 6, textTransform: 'uppercase' }}>Amount (GH₵)</label>
                <input
                  type="number"
                  step="0.01"
                  value={fee.amount}
                  onChange={e => updateFee(fee.id, 'amount', e.target.value)}
                  style={{ width: '100%', padding: '12px', borderRadius: 10, border: '1.5px solid var(--border-default)', background: 'var(--bg-base)', color: 'var(--brand-primary)', fontWeight: 800, textAlign: 'right' }}
                />
              </div>
            </div>
          ))}

          {fees.length > 0 && (
            <button type="submit" className="btn btn-primary btn-lg" style={{ width: '100%', height: 52, borderRadius: 26, fontSize: '1rem', fontWeight: 800, marginTop: 10 }} disabled={loading}>
              {loading ? 'Saving Changes...' : 'Save All Fees'}
            </button>
          )}
        </form>
      </div>
    </AppLayout>
  )
}
