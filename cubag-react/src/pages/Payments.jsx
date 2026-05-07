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
        const paymentId = result.payment_id
        if (method === 'momo' && paymentId) {
          setSuccessMsg('📱 Prompt sent! Approve on your phone...')
          const poll = setInterval(async () => {
            try {
              const sr = await fetch(`${import.meta.env.VITE_API_URL}/payments/status/${paymentId}`, {
                headers: { 'Authorization': `Bearer ${localStorage.getItem('cubag_token')}` }
              })
              const sd = await sr.json()
              if (sd.status === 'paid') {
                clearInterval(poll)
                setSuccessMsg('✅ Payment Received Successfully!')
                setAmount(''); setReason(''); setPayStep(1)
                setMomoDetails({ network: 'MTN', phone: '' })
                setTimeout(() => setSuccessMsg(''), 5000)
                setLoading(false)
              }
            } catch { /* silent */ }
          }, 3000)
          setTimeout(() => {
            clearInterval(poll)
            setLoading(false)
            setSuccessMsg('⏱️ Payment prompt expired. Please try again.')
            setTimeout(() => setSuccessMsg(''), 6000)
          }, 180000)
        } else {
          setSuccessMsg('✅ ' + (result.message || 'Payment submitted!'))
          setAmount(''); setReason(''); setPayStep(1)
          setBankDetails({ transactionId: '' })
          setTimeout(() => setSuccessMsg(''), 5000)
          setLoading(false)
        }
      } else {
        alert(result.message || 'Failed to submit payment.')
        setLoading(false)
      }
    } catch (err) {
      console.error(err)
      alert('Network error. Please check your connection.')
      setLoading(false)
    }
  }

  const STEPS = [
    { n: 1, label: 'What & Amount' },
    { n: 2, label: 'Payment Method' },
    { n: 3, label: 'Review & Pay' }
  ]
  const bank = paymentSettings.bankAccounts[selectedBank] || {}

  return (
    <AppLayout title="Payments & Dues">
      <div style={{ maxWidth: 900, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 24 }}>

        {/* Balance Banner */}
        <div className="welcome-banner" style={{ background: 'var(--gradient-brand)', marginBottom: 0 }}>
          <div className="welcome-copy">
            <h2 style={{ fontSize: '1.2rem', marginBottom: 8 }}>Outstanding Balance</h2>
            <div style={{ fontSize: '2.5rem', fontWeight: 800, color: '#fff', marginBottom: 8, fontFamily: 'var(--font-display)' }}>
              GH₵ {parseFloat(balance.total_pending || 0).toFixed(2)}
            </div>
            <p style={{ margin: 0 }}>{parseFloat(balance.total_pending || 0) > 0 ? 'You have pending payments. Please settle soon.' : 'All caught up! No pending invoices.'}</p>
          </div>
          <div className="welcome-action">
            <button className="btn btn-white" onClick={() => setPayStep(1)}>Pay Ahead</button>
          </div>
        </div>

        {/* Payment Card */}
        <div className="feed-card" style={{ maxWidth: 600, margin: '0 auto', width: '100%' }}>

          {/* Step Progress */}
          <div style={{ padding: '20px 24px 0', display: 'flex', alignItems: 'center' }}>
            {STEPS.map((s, idx) => (
              <div key={s.n} style={{ display: 'flex', alignItems: 'center', flex: idx < 2 ? 1 : 'none' }}>
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
                  <div style={{ width: 32, height: 32, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: '0.85rem', transition: 'all 0.3s', background: payStep >= s.n ? 'var(--brand-primary)' : 'var(--border-subtle)', color: payStep >= s.n ? '#fff' : 'var(--text-muted)' }}>
                    {payStep > s.n ? <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>check</span> : s.n}
                  </div>
                  <span style={{ fontSize: '0.7rem', fontWeight: 600, whiteSpace: 'nowrap', color: payStep === s.n ? 'var(--brand-primary)' : 'var(--text-muted)' }}>{s.label}</span>
                </div>
                {idx < 2 && <div style={{ flex: 1, height: 2, margin: '0 8px', marginBottom: 20, transition: 'all 0.3s', background: payStep > s.n ? 'var(--brand-primary)' : 'var(--border-subtle)' }} />}
              </div>
            ))}
          </div>

          <div className="card-body">

            {/* Step 1 */}
            {payStep === 1 && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
                <CustomSelect label="Payment For" value={reason} onChange={handleReasonChange} options={REASON_OPTIONS} icon="payments" />
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-secondary)', marginBottom: 8 }}>Amount (GH₵)</label>
                  <input type="number" placeholder="Enter amount" value={amount} onChange={e => setAmount(e.target.value)} disabled={isAmountFixed}
                    style={{ width: '100%', padding: '12px 16px', borderRadius: 'var(--radius-md)', border: '1px solid var(--border-subtle)', background: isAmountFixed ? 'rgba(0,0,0,0.05)' : 'var(--bg-base)', color: isAmountFixed ? 'var(--text-muted)' : 'var(--text-primary)', outline: 'none', boxSizing: 'border-box' }} />
                </div>
                <button className="btn btn-primary btn-lg" disabled={!reason || !amount} onClick={() => setPayStep(2)} style={{ justifyContent: 'center', opacity: (!reason || !amount) ? 0.5 : 1 }}>
                  Continue <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>arrow_forward</span>
                </button>
              </div>
            )}

            {/* Step 2 */}
            {payStep === 2 && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-secondary)', marginBottom: 12 }}>Select Payment Method</label>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                    {[{ id: 'momo', icon: 'smartphone', label: 'Mobile Money' }, { id: 'bank', icon: 'account_balance', label: 'Bank Transfer' }].map(m => (
                      <div key={m.id} onClick={() => setMethod(m.id)} style={{ padding: '20px 16px', border: `2px solid ${method === m.id ? 'var(--brand-primary)' : 'var(--border-subtle)'}`, borderRadius: 'var(--radius-md)', cursor: 'pointer', textAlign: 'center', transition: 'all 0.2s', background: method === m.id ? 'rgba(240,130,50,0.05)' : 'transparent' }}>
                        <span className="material-symbols-outlined" style={{ fontSize: '2rem', color: method === m.id ? 'var(--brand-primary)' : 'var(--text-muted)', display: 'block', marginBottom: 8 }}>{m.icon}</span>
                        <div style={{ fontSize: '0.9rem', fontWeight: 600, color: 'var(--text-primary)' }}>{m.label}</div>
                      </div>
                    ))}
                  </div>
                </div>

                {method === 'momo' && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                    <CustomSelect label="Your Network" options={[{ value: 'MTN', label: 'MTN Mobile Money' }, { value: 'Vodafone', label: 'Vodafone Cash' }, { value: 'AirtelTigo', label: 'AirtelTigo Money' }]} value={momoDetails.network} onChange={val => setMomoDetails({ ...momoDetails, network: val })} />
                    <div>
                      <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-secondary)', marginBottom: 8 }}>Your MoMo Number</label>
                      <input type="tel" placeholder="e.g. 0244123456" value={momoDetails.phone} onChange={e => setMomoDetails({ ...momoDetails, phone: e.target.value })} style={{ width: '100%', padding: '12px 16px', borderRadius: 'var(--radius-md)', border: '1px solid var(--border-subtle)', outline: 'none', boxSizing: 'border-box' }} />
                    </div>
                  </div>
                )}

                {method === 'bank' && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                    <div style={{ fontSize: '0.85rem', background: 'var(--bg-base)', padding: 16, borderRadius: 'var(--radius-md)', border: '1px solid var(--border-subtle)', lineHeight: 1.8 }}>
                      <div style={{ fontWeight: 700, color: 'var(--brand-primary)', marginBottom: 8 }}>CUBAG Bank Account Details</div>
                      <div><strong>Bank:</strong> {bank.bankName}</div>
                      <div><strong>Account Name:</strong> {bank.accountName}</div>
                      <div><strong>Account No.:</strong> <span style={{ fontWeight: 800, color: 'var(--brand-primary)' }}>{bank.accountNumber}</span></div>
                      <div><strong>Branch:</strong> {bank.branch}</div>
                    </div>
                    <div>
                      <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-secondary)', marginBottom: 8 }}>Your Transaction Reference / ID</label>
                      <input type="text" placeholder="e.g. TRN-10023491..." value={bankDetails.transactionId} onChange={e => setBankDetails({ ...bankDetails, transactionId: e.target.value })} style={{ width: '100%', padding: '12px 16px', borderRadius: 'var(--radius-md)', border: '1px solid var(--border-subtle)', outline: 'none', boxSizing: 'border-box' }} />
                    </div>
                  </div>
                )}

                <div style={{ display: 'flex', gap: 12 }}>
                  <button className="btn btn-outline" onClick={() => setPayStep(1)} style={{ flex: 1, justifyContent: 'center' }}>
                    <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>arrow_back</span> Back
                  </button>
                  <button
                    className="btn btn-primary"
                    disabled={(method === 'momo' && !momoDetails.phone) || (method === 'bank' && !bankDetails.transactionId)}
                    onClick={() => {
                      if (method === 'momo') {
                        const ghPhone = /^0[235][0-9]{8}$/
                        if (!ghPhone.test(momoDetails.phone)) {
                          alert('Please enter a valid Ghana mobile number (e.g. 0244123456)')
                          return
                        }
                      }
                      setPayStep(3)
                    }}
                    style={{ flex: 2, justifyContent: 'center', opacity: ((method === 'momo' && !momoDetails.phone) || (method === 'bank' && !bankDetails.transactionId)) ? 0.5 : 1 }}
                  >
                    Review Payment <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>arrow_forward</span>
                  </button>
                </div>
              </div>
            )}

            {/* Step 3 */}
            {payStep === 3 && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
                <div style={{ background: 'var(--bg-base)', borderRadius: 'var(--radius-md)', border: '1px solid var(--border-subtle)', overflow: 'hidden' }}>
                  <div style={{ padding: '12px 16px', background: 'var(--gradient-brand)', color: '#fff', fontWeight: 700, fontSize: '0.9rem' }}>Payment Summary</div>
                  <div style={{ padding: 16, display: 'flex', flexDirection: 'column', fontSize: '0.9rem' }}>
                    {[
                      { label: 'Payment For', value: REASON_OPTIONS.find(r => r.value === reason)?.label || reason },
                      { label: 'Amount', value: `GH₵ ${parseFloat(amount || 0).toFixed(2)}`, highlight: true },
                      { label: 'Method', value: method === 'momo' ? `Mobile Money (${momoDetails.network})` : 'Bank Transfer' },
                      method === 'momo' ? { label: 'MoMo Number', value: momoDetails.phone } : { label: 'Transaction Ref', value: bankDetails.transactionId }
                    ].map((row, i, arr) => (
                      <div key={row.label} style={{ display: 'flex', justifyContent: 'space-between', padding: '12px 0', borderBottom: i < arr.length - 1 ? '1px solid var(--border-subtle)' : 'none' }}>
                        <span style={{ color: 'var(--text-muted)', fontWeight: 500 }}>{row.label}</span>
                        <span style={{ fontWeight: row.highlight ? 800 : 600, color: row.highlight ? 'var(--brand-primary)' : 'var(--text-primary)', fontSize: row.highlight ? '1.05rem' : 'inherit' }}>{row.value}</span>
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
                    {loading ? 'Processing...' : method === 'momo' ? 'Send Prompt' : 'Confirm Payment'}
                  </button>
                </div>
              </div>
            )}

          </div>
        </div>

      </div>
    </AppLayout>
  )
}
