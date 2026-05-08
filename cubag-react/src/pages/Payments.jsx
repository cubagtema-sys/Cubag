import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'
import CustomSelect from '../components/CustomSelect'

const REASON_OPTIONS = [
  { value: '', label: '— Select payment type —', icon: 'payments', disabled: true },
  { value: 'Dues', label: 'Association Dues' },
  { value: 'Renewal', label: 'License Renewal' },
  { value: 'Penalty', label: 'Late Penalty Fee' },
  { value: 'Other', label: 'Other / Miscellaneous' }
]

export default function Payments() {
  const [payStep, setPayStep] = useState(1)
  const [amount, setAmount] = useState('')
  const [reason, setReason] = useState('')
  const [method, setMethod] = useState('momo')
  const [paystackCode, setPaystackCode] = useState('')
  const [paymentId, setPaymentId] = useState(null)
  const [paystackRef, setPaystackRef] = useState('')
  const [isVerifying, setIsVerifying] = useState(false)
  const [platformFees, setPlatformFees] = useState({ renewalFee: '1500.00', monthlyDues: '100.00', latePenaltyFee: '50.00', otherFee: '0.00' })
  const [paymentSettings, setPaymentSettings] = useState({
    momoAccounts: [{ network: 'MTN', number: '0244000000' }],
    bankAccounts: [{ bankName: 'GCB Bank', accountName: 'CUBAG National Account', accountNumber: '1011130023456', branch: 'Tema Main' }]
  })
  const [momoDetails, setMomoDetails] = useState({ network: 'MTN', phone: '' })
  const [bankDetails, setBankDetails] = useState({ transactionId: '' })
  const [selectedBank] = useState(0)
  const [loading, setLoading] = useState(false)
  const [successMsg, setSuccessMsg] = useState('')
  const [balance, setBalance] = useState({ total_pending: 0 })

  useEffect(() => {
    const token = localStorage.getItem('cubag_token')
    const authHeader = { 'Authorization': `Bearer ${token}` }
    Promise.all([
      fetch(`${import.meta.env.VITE_API_URL}/settings/cubag_fees`),
      fetch(`${import.meta.env.VITE_API_URL}/settings/cubag_payment_settings_v2`),
      fetch(`${import.meta.env.VITE_API_URL}/payments/summary`, { headers: authHeader })
    ])
      .then(responses => Promise.all(responses.map(r => r.json())))
      .then(([feesData, payData, summaryData]) => {
        if (feesData && feesData.renewalFee) setPlatformFees(feesData)
        if (payData && payData.momoAccounts) setPaymentSettings(payData)
        if (summaryData && summaryData.total_pending !== undefined) setBalance(summaryData)
      })
      .catch(e => console.error(e))
  }, []) // eslint-disable-line

  const handleReasonChange = (val) => {
    setReason(val)
    if (val === 'Dues')         setAmount(platformFees.monthlyDues    || '100.00')
    else if (val === 'Renewal') setAmount(platformFees.renewalFee     || '1500.00')
    else if (val === 'Penalty') setAmount(platformFees.latePenaltyFee || '50.00')
    else if (val === 'Other')   setAmount(platformFees.otherFee       || '0.00')
    else setAmount('')
  }

  const isAmountFixed = reason === 'Dues' || reason === 'Renewal'

  const handlePayment = async () => {
    setLoading(true)
    try {
      const paymentRef = method === 'momo' ? `MOMO-${momoDetails.phone}` : bankDetails.transactionId
      const desc = reason === 'Dues' ? 'Association Dues'
                 : reason === 'Renewal' ? 'License Renewal'
                 : reason === 'Penalty' ? 'Late Penalty Fee'
                 : 'Other / Miscellaneous'

      const res = await fetch(`${import.meta.env.VITE_API_URL}/payments`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('cubag_token')}`
        },
        body: JSON.stringify({
          amount: parseFloat(amount),
          description: desc,
          payment_ref: paymentRef,
          method,
          network: momoDetails.network,
          phone: momoDetails.phone,
          bank_tx_id: bankDetails.transactionId
        })
      })

      const result = await res.json()

      if (res.ok) {
        if (method === 'momo' && result.payment_id) {
          setPaymentId(result.payment_id)
          setPaystackRef(result.paystack_ref || '')
          setPayStep(4) // OTP Code Verification
        } else {
          setSuccessMsg('✅ ' + (result.message || 'Payment submitted!'))
          setAmount(''); setReason(''); setPayStep(1)
          setBankDetails({ transactionId: '' })
          setTimeout(() => setSuccessMsg(''), 5000)
        }
      } else {
        alert(result.message || 'Failed to submit payment.')
      }
    } catch (err) {
      console.error(err)
      alert('Network error.')
    } finally {
      setLoading(false)
    }
  }

  const handleVerifyCode = async () => {
    if (!paystackCode.trim()) return
    setIsVerifying(true)
    try {
      const res = await fetch(`${import.meta.env.VITE_API_URL}/payments/verify-code`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('cubag_token')}`
        },
        body: JSON.stringify({ payment_id: paymentId, code: paystackCode, paystack_ref: paystackRef })
      })
      const result = await res.json()
      if (res.ok) {
        setSuccessMsg('✅ ' + (result.message || 'Payment verified!'))
        setAmount(''); setReason(''); setPaystackCode(''); setPaystackRef(''); setPayStep(1)
        setTimeout(() => setSuccessMsg(''), 5000)
      } else {
        alert(result.message || 'Verification failed.')
      }
    } catch (e) {
      alert('Connection error during verification.')
    } finally {
      setIsVerifying(false)
    }
  }

  const STEPS = [
    { n: 1, label: 'What' },
    { n: 2, label: 'Method' },
    { n: 3, label: 'Review' },
    { n: 4, label: 'Verify' }
  ]
  const bank = paymentSettings.bankAccounts[selectedBank] || {}

  return (
    <AppLayout title="Payments">
      <div style={{ maxWidth: 900, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 12 }}>

        {/* Page Title for Content */}
        <div style={{ marginBottom: 2 }}>
          <h2 style={{ fontSize: '1.2rem', fontWeight: 800, color: 'var(--text-primary)' }}>Payments & Dues</h2>
          <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Settle your fees and track your balance.</p>
        </div>

        {/* Balance Banner */}
        <div className="welcome-banner" style={{ background: 'var(--gradient-brand)', marginBottom: 0, padding: '16px 20px', borderRadius: 12 }}>
          <div className="welcome-copy">
            <h2 style={{ fontSize: '1rem', marginBottom: 2 }}>Balance</h2>
            <div style={{ fontSize: '1.6rem', fontWeight: 800, color: '#fff', fontFamily: 'var(--font-display)' }}>
              GH₵ {parseFloat(balance.total_pending || 0).toFixed(2)}
            </div>
          </div>
          <div className="welcome-action">
            <button className="btn btn-white btn-sm" onClick={() => setPayStep(1)} style={{ fontSize: '0.75rem', padding: '6px 12px' }}>Pay Now</button>
          </div>
        </div>

        {/* Payment Card */}
        <div className="feed-card" style={{ maxWidth: 600, margin: '0 auto', width: '100%', borderRadius: 12 }}>

          {/* Step Progress */}
          <div style={{ padding: '16px 16px 0', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            {STEPS.map((s, idx) => (
              <div key={s.n} style={{ display: 'flex', alignItems: 'center', flex: idx < 2 ? 1 : 'none' }}>
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2 }}>
                  <div style={{ width: 28, height: 28, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: '0.75rem', transition: 'all 0.3s', background: payStep >= s.n ? 'var(--brand-primary)' : 'var(--border-subtle)', color: payStep >= s.n ? '#fff' : 'var(--text-muted)' }}>
                    {payStep > s.n ? <span className="material-symbols-outlined" style={{ fontSize: '0.9rem' }}>check</span> : s.n}
                  </div>
                  <span style={{ fontSize: '0.6rem', fontWeight: 600, color: payStep === s.n ? 'var(--brand-primary)' : 'var(--text-muted)' }}>{s.label.split(' ')[0]}</span>
                </div>
                {idx < 2 && <div style={{ flex: 1, height: 2, margin: '0 4px', marginBottom: 14, transition: 'all 0.3s', background: payStep > s.n ? 'var(--brand-primary)' : 'var(--border-subtle)' }} />}
              </div>
            ))}
          </div>

          <div className="card-body">

            {/* Step 1 */}
            {payStep === 1 && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                <CustomSelect label="Payment Type" value={reason} onChange={handleReasonChange} options={REASON_OPTIONS} icon="payments" />
                <div>
                  <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, color: 'var(--text-secondary)', marginBottom: 6 }}>Amount (GH₵)</label>
                  <input type="number" placeholder="0.00" value={amount} onChange={e => setAmount(e.target.value)} disabled={isAmountFixed}
                    style={{ width: '100%', padding: '10px 14px', borderRadius: 8, border: '1px solid var(--border-subtle)', background: isAmountFixed ? 'rgba(0,0,0,0.03)' : 'var(--bg-base)', color: isAmountFixed ? 'var(--text-muted)' : 'var(--text-primary)', outline: 'none', fontSize: '0.95rem' }} />
                </div>
                <button className="btn btn-primary btn-lg" disabled={!reason || !amount} onClick={() => setPayStep(2)} style={{ justifyContent: 'center', height: 48, fontSize: '0.9rem' }}>
                  Next <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>arrow_forward</span>
                </button>
              </div>
            )}

            {/* Step 2 */}
            {payStep === 2 && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, color: 'var(--text-secondary)', marginBottom: 10 }}>Select Method</label>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
                    {[{ id: 'momo', icon: 'smartphone', label: 'MoMo' }, { id: 'bank', icon: 'account_balance', label: 'Bank' }].map(m => (
                      <div key={m.id} onClick={() => setMethod(m.id)} style={{ padding: '14px 10px', border: `2px solid ${method === m.id ? 'var(--brand-primary)' : 'var(--border-subtle)'}`, borderRadius: 10, cursor: 'pointer', textAlign: 'center', background: method === m.id ? 'rgba(240,130,50,0.05)' : 'transparent' }}>
                        <span className="material-symbols-outlined" style={{ fontSize: '1.5rem', color: method === m.id ? 'var(--brand-primary)' : 'var(--text-muted)', display: 'block', marginBottom: 4 }}>{m.icon}</span>
                        <div style={{ fontSize: '0.8rem', fontWeight: 600 }}>{m.label}</div>
                      </div>
                    ))}
                  </div>
                </div>

                {method === 'momo' && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                    <CustomSelect label="Network" options={[{ value: 'MTN', label: 'MTN MoMo' }, { value: 'Vodafone', label: 'Vodafone' }, { value: 'AirtelTigo', label: 'AirtelTigo' }]} value={momoDetails.network} onChange={val => setMomoDetails({ ...momoDetails, network: val })} />
                    <div>
                      <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, color: 'var(--text-secondary)', marginBottom: 6 }}>Number</label>
                      <input type="tel" placeholder="0244..." value={momoDetails.phone} onChange={e => setMomoDetails({ ...momoDetails, phone: e.target.value })} style={{ width: '100%', padding: '10px 14px', borderRadius: 8, border: '1px solid var(--border-subtle)', outline: 'none', fontSize: '0.95rem' }} />
                    </div>
                  </div>
                )}

                {method === 'bank' && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                    <div style={{ fontSize: '0.75rem', background: 'var(--bg-base)', padding: 12, borderRadius: 8, border: '1px solid var(--border-subtle)', lineHeight: 1.6 }}>
                      <div style={{ fontWeight: 700, color: 'var(--brand-primary)', marginBottom: 4 }}>CUBAG Bank Details</div>
                      <div>Bank: {bank.bankName}</div>
                      <div>A/C: <span style={{ fontWeight: 800 }}>{bank.accountNumber}</span></div>
                    </div>
                    <div>
                      <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, color: 'var(--text-secondary)', marginBottom: 6 }}>Tx ID / Ref</label>
                      <input type="text" placeholder="Transaction ID" value={bankDetails.transactionId} onChange={e => setBankDetails({ ...bankDetails, transactionId: e.target.value })} style={{ width: '100%', padding: '10px 14px', borderRadius: 8, border: '1px solid var(--border-subtle)', outline: 'none', fontSize: '0.95rem' }} />
                    </div>
                  </div>
                )}

                <div style={{ display: 'flex', gap: 10 }}>
                  <button className="btn btn-outline" onClick={() => setPayStep(1)} style={{ flex: 1, height: 48, fontSize: '0.85rem' }}>Back</button>
                  <button
                    className="btn btn-primary"
                    disabled={(method === 'momo' && !momoDetails.phone) || (method === 'bank' && !bankDetails.transactionId)}
                    onClick={() => {
                      if (method === 'momo') {
                        const ghPhone = /^0[235][0-9]{8}$/
                        if (!ghPhone.test(momoDetails.phone)) {
                          alert('Invalid Ghana number')
                          return
                        }
                      }
                      setPayStep(3)
                    }}
                    style={{ flex: 2, height: 48, fontSize: '0.85rem' }}
                  >
                    Review
                  </button>
                </div>
              </div>
            )}

            {/* Step 3 */}
            {payStep === 3 && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                <div style={{ background: 'var(--bg-base)', borderRadius: 10, border: '1px solid var(--border-subtle)', overflow: 'hidden' }}>
                  <div style={{ padding: '10px 14px', background: 'var(--gradient-brand)', color: '#fff', fontWeight: 700, fontSize: '0.85rem' }}>Summary</div>
                  <div style={{ padding: 12, display: 'flex', flexDirection: 'column', fontSize: '0.8rem' }}>
                    {[
                      { label: 'Type', value: REASON_OPTIONS.find(r => r.value === reason)?.label.split(' ')[0] || reason },
                      { label: 'Amount', value: `GH₵ ${parseFloat(amount || 0).toFixed(2)}`, highlight: true },
                      { label: 'Method', value: method === 'momo' ? `MoMo` : 'Bank' }
                    ].map((row, i, arr) => (
                      <div key={row.label} style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0', borderBottom: i < arr.length - 1 ? '1px solid var(--border-subtle)' : 'none' }}>
                        <span style={{ color: 'var(--text-muted)', fontWeight: 500 }}>{row.label}</span>
                        <span style={{ fontWeight: row.highlight ? 800 : 600, color: row.highlight ? 'var(--brand-primary)' : 'var(--text-primary)' }}>{row.value}</span>
                      </div>
                    ))}
                  </div>
                </div>

                {successMsg && (
                  <div style={{ padding: '14px', background: 'rgba(16,185,129,0.1)', color: '#10b981', borderRadius: 'var(--radius-md)', textAlign: 'center', fontWeight: 700, fontSize: '1rem' }}>
                    {successMsg}
                  </div>
                )}

                <div style={{ display: 'flex', gap: 12 }}>
                  <button className="btn btn-outline" onClick={() => setPayStep(2)} disabled={loading} style={{ flex: 1, justifyContent: 'center' }}>
                    <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>arrow_back</span> Back
                  </button>
                  <button className="btn btn-primary btn-lg" onClick={handlePayment} disabled={loading} style={{ flex: 2, justifyContent: 'center', opacity: loading ? 0.6 : 1 }}>
                    {loading ? 'Processing...' : method === 'momo' ? 'Send Code' : 'Confirm'}
                  </button>
                </div>
              </div>
            )}

            {/* Step 4: Verification Code */}
            {payStep === 4 && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                <div style={{ textAlign: 'center', marginBottom: 8 }}>
                  <div style={{ width: 44, height: 44, background: 'rgba(240,130,50,0.1)', color: 'var(--brand-primary)', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 12px' }}>
                    <span className="material-symbols-outlined" style={{ fontSize: '1.4rem' }}>smartphone</span>
                  </div>
                  <h3 style={{ fontSize: '1.1rem', marginBottom: 4 }}>Enter Approval Code</h3>
                  <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Paystack has sent a code to <strong>{momoDetails.phone}</strong>. Enter it below to confirm your payment.</p>
                </div>

                <div className="form-group">
                  <label style={{ fontSize: '0.75rem', fontWeight: 800, marginBottom: 4, display: 'block', textAlign: 'center' }}>Verification Code</label>
                  <input
                    type="text"
                    required
                    placeholder="— — — — — —"
                    value={paystackCode}
                    onChange={e => setPaystackCode(e.target.value)}
                    style={{ width: '100%', padding: 12, border: '2.5px solid #000', borderRadius: 10, background: '#fff', fontSize: '1.2rem', fontWeight: 800, textAlign: 'center', letterSpacing: '4px' }}
                  />
                </div>

                <button className="btn btn-primary btn-lg" onClick={handleVerifyCode} disabled={isVerifying || !paystackCode.trim()} style={{ width: '100%', height: 48, fontSize: '0.95rem' }}>
                  {isVerifying ? 'Verifying...' : 'Done / Confirm'}
                </button>
                <button className="btn btn-ghost btn-sm" onClick={() => setPayStep(3)} style={{ width: '100%' }}>Back to Review</button>
              </div>
            )}

          </div>
        </div>

      </div>
    </AppLayout>
  )
}
