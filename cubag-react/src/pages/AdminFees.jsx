import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'
import CustomSelect from '../components/CustomSelect'

const API = import.meta.env.VITE_API_URL

const FEE_ICONS = {
  'License Renewal': 'badge',
  'Registration':    'app_registration',
  'Monthly Dues':    'calendar_month',
  'Late Penalty':    'schedule',
  'Other / Misc':    'attach_money',
}
const iconForLabel = (label) =>
  FEE_ICONS[label] || 'payments'

const PRESET_TYPES = [
  'License Renewal', 'Registration', 'Monthly Dues', 'Late Penalty', 'Other / Misc'
]

const DEFAULT_FEES = [
  { id: Date.now() + 1, label: 'License Renewal', amount: '1500.00' },
  { id: Date.now() + 2, label: 'Registration',    amount: '500.00'  },
  { id: Date.now() + 3, label: 'Monthly Dues',    amount: '100.00'  },
  { id: Date.now() + 4, label: 'Late Penalty',    amount: '50.00'   },
]

export default function AdminFees() {
  const [fees, setFees]       = useState(DEFAULT_FEES)
  const [loading, setLoading] = useState(false)
  const [success, setSuccess] = useState(false)
  const [error, setError]     = useState('')

  // For adding a new fee type
  const [addMode, setAddMode]         = useState(false)
  const [newLabel, setNewLabel]       = useState('')
  const [newAmount, setNewAmount]     = useState('')
  const [customLabel, setCustomLabel] = useState('')
  const [useCustom, setUseCustom]     = useState(false)

  useEffect(() => {
    fetch(`${API}/settings/cubag_fees_v2`)
      .then(res => res.json())
      .then(data => {
        if (Array.isArray(data) && data.length > 0) {
          setFees(data)
        }
      })
      .catch(e => console.error(e))
  }, [])

  const updateAmount = (id, val) =>
    setFees(prev => prev.map(f => f.id === id ? { ...f, amount: val } : f))

  const removeFee = (id) =>
    setFees(prev => prev.filter(f => f.id !== id))

  const addFee = () => {
    const label = useCustom ? customLabel.trim() : newLabel
    if (!label || !newAmount) return setError('Please fill in both label and amount.')
    if (fees.some(f => f.label.toLowerCase() === label.toLowerCase())) {
      return setError('A fee with this label already exists.')
    }
    setFees(prev => [...prev, { id: Date.now(), label, amount: newAmount }])
    setNewLabel(''); setNewAmount(''); setCustomLabel(''); setAddMode(false); setError('')
  }

  const handleSave = async (e) => {
    e.preventDefault()
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

  const LABEL_OPTIONS = PRESET_TYPES.map(t => ({ value: t, label: t, icon: iconForLabel(t) }))
    .concat([{ value: '__custom__', label: 'Custom type...', icon: 'add_circle' }])

  return (
    <AppLayout title="Fees">
      <div style={{ maxWidth: 720, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 20 }}>

        <div>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Fee Configuration</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Set and manage all platform fee types and their amounts.</p>
        </div>

        {/* ── Feedback ── */}
        {success && (
          <div style={{ padding: '10px 16px', background: 'rgba(16,185,129,0.1)', color: '#10b981', borderRadius: 12, fontSize: '0.85rem', fontWeight: 700, border: '1px solid rgba(16,185,129,0.2)', display: 'flex', alignItems: 'center', gap: 8 }}>
            <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>check_circle</span>
            Fee configuration saved successfully!
          </div>
        )}
        {error && (
          <div style={{ padding: '10px 16px', background: 'rgba(239,68,68,0.08)', color: '#ef4444', borderRadius: 12, fontSize: '0.85rem', fontWeight: 700, border: '1px solid rgba(239,68,68,0.15)', display: 'flex', alignItems: 'center', gap: 8 }}>
            <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>error</span>
            {error}
          </div>
        )}

        <form onSubmit={handleSave} style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>

          {/* ── Fee Cards ── */}
          {fees.map((fee, idx) => (
            <div key={fee.id} className="feed-card" style={{ padding: '14px 16px', borderRadius: 14, display: 'flex', alignItems: 'center', gap: 14 }}>
              {/* Icon */}
              <div style={{ width: 40, height: 40, borderRadius: 12, background: 'rgba(240,130,50,0.1)', color: 'var(--brand-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>{iconForLabel(fee.label)}</span>
              </div>

              {/* Label + amount */}
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: '0.72rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.04em', marginBottom: 4 }}>
                  {fee.label}
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span style={{ fontSize: '0.9rem', fontWeight: 700, color: 'var(--text-secondary)' }}>GH₵</span>
                  <input
                    type="number"
                    min="0"
                    step="0.01"
                    value={fee.amount}
                    onChange={e => updateAmount(fee.id, e.target.value)}
                    style={{
                      flex: 1, padding: '8px 12px',
                      border: '2px solid var(--border-default)',
                      borderRadius: 10, background: 'var(--bg-base)',
                      fontSize: '1.05rem', fontWeight: 900,
                      color: 'var(--brand-primary)', outline: 'none',
                      textAlign: 'right', maxWidth: 160
                    }}
                  />
                </div>
              </div>

              {/* Remove (only for non-core fees) */}
              {!['License Renewal', 'Registration', 'Monthly Dues'].includes(fee.label) && (
                <button
                  type="button"
                  onClick={() => removeFee(fee.id)}
                  style={{ width: 32, height: 32, borderRadius: 8, border: '1px solid rgba(239,68,68,0.25)', background: 'rgba(239,68,68,0.06)', color: '#ef4444', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}
                  title="Remove fee type"
                >
                  <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>remove</span>
                </button>
              )}
            </div>
          ))}

          {/* ── Add New Fee ── */}
          {addMode ? (
            <div className="feed-card" style={{ padding: '16px', borderRadius: 14, border: '2px dashed var(--brand-primary)', background: 'rgba(240,130,50,0.03)' }}>
              <h4 style={{ margin: '0 0 14px', fontSize: '0.85rem', fontWeight: 800, color: 'var(--text-primary)', display: 'flex', alignItems: 'center', gap: 6 }}>
                <span className="material-symbols-outlined" style={{ fontSize: '1rem', color: 'var(--brand-primary)' }}>add_circle</span>
                New Fee Type
              </h4>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                {/* Label selector */}
                <div className="form-group">
                  <label style={{ fontSize: '0.72rem', fontWeight: 700, color: 'var(--text-secondary)', display: 'block', marginBottom: 4 }}>Fee Type</label>
                  <CustomSelect
                    value={useCustom ? '__custom__' : (newLabel || LABEL_OPTIONS[0].value)}
                    onChange={val => {
                      if (val === '__custom__') { setUseCustom(true); setNewLabel('') }
                      else { setUseCustom(false); setNewLabel(val) }
                    }}
                    options={LABEL_OPTIONS}
                    icon="label"
                  />
                </div>

                {useCustom && (
                  <div className="form-group">
                    <label style={{ fontSize: '0.72rem', fontWeight: 700, color: 'var(--text-secondary)', display: 'block', marginBottom: 4 }}>Custom Label</label>
                    <input
                      type="text" value={customLabel}
                      onChange={e => setCustomLabel(e.target.value)}
                      placeholder="e.g. Conference Fee"
                      style={{ width: '100%', padding: '10px 12px', border: '1.5px solid var(--border-default)', borderRadius: 10, fontSize: '0.9rem', boxSizing: 'border-box' }}
                    />
                  </div>
                )}

                <div className="form-group">
                  <label style={{ fontSize: '0.72rem', fontWeight: 700, color: 'var(--text-secondary)', display: 'block', marginBottom: 4 }}>Amount (GH₵)</label>
                  <input
                    type="number" min="0" step="0.01" value={newAmount}
                    onChange={e => setNewAmount(e.target.value)}
                    placeholder="0.00"
                    style={{ width: '100%', padding: '10px 12px', border: '1.5px solid var(--border-default)', borderRadius: 10, fontSize: '0.95rem', fontWeight: 800, boxSizing: 'border-box' }}
                  />
                </div>

                <div style={{ display: 'flex', gap: 10 }}>
                  <button type="button" className="btn btn-primary" style={{ flex: 2, height: 42, justifyContent: 'center', fontSize: '0.85rem' }} onClick={addFee}>
                    <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>add</span>
                    Add Fee
                  </button>
                  <button type="button" className="btn btn-ghost" style={{ flex: 1, height: 42, justifyContent: 'center', fontSize: '0.85rem' }} onClick={() => { setAddMode(false); setError('') }}>
                    Cancel
                  </button>
                </div>
              </div>
            </div>
          ) : (
            <button
              type="button"
              onClick={() => { setAddMode(true); setNewLabel(LABEL_OPTIONS[0].value); setUseCustom(false) }}
              style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, padding: '12px', borderRadius: 14, border: '2px dashed var(--border-default)', background: 'transparent', color: 'var(--text-muted)', cursor: 'pointer', fontSize: '0.85rem', fontWeight: 700, transition: 'all 0.2s' }}
              onMouseEnter={e => { e.currentTarget.style.borderColor = 'var(--brand-primary)'; e.currentTarget.style.color = 'var(--brand-primary)' }}
              onMouseLeave={e => { e.currentTarget.style.borderColor = 'var(--border-default)'; e.currentTarget.style.color = 'var(--text-muted)' }}
            >
              <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>add_circle</span>
              Add New Fee Type
            </button>
          )}

          {/* ── Summary & Save ── */}
          <div style={{ background: 'var(--bg-surface)', borderRadius: 14, padding: '14px 16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10 }}>
            <div>
              <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.04em' }}>Total Fee Types</div>
              <div style={{ fontSize: '1.2rem', fontWeight: 900, color: 'var(--text-primary)' }}>{fees.length}</div>
            </div>
            <div style={{ textAlign: 'right' }}>
              <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.04em' }}>Highest Fee</div>
              <div style={{ fontSize: '1.1rem', fontWeight: 900, color: 'var(--brand-primary)' }}>
                GH₵ {Math.max(...fees.map(f => parseFloat(f.amount) || 0)).toLocaleString('en-GH', { minimumFractionDigits: 2 })}
              </div>
            </div>
          </div>

          <button type="submit" className="btn btn-primary btn-lg" style={{ width: '100%', height: 50, borderRadius: 25, fontSize: '0.95rem', justifyContent: 'center' }} disabled={loading}>
            <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>save</span>
            {loading ? 'Saving...' : 'Save All Fee Settings'}
          </button>
        </form>

      </div>
    </AppLayout>
  )
}
