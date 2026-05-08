import { useState, useEffect, useCallback } from 'react'
import AppLayout from '../components/AppLayout'
import CustomSelect from '../components/CustomSelect'
import useAutoRefresh from '../hooks/useAutoRefresh'
import { showToast } from '../utils/toast'

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
  const [serverRef, setServerRef] = useState('')
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
  const [psStatus, setPsStatus] = useState('') // Paystack current status
  const [pollInterval, setPollInterval] = useState(null)
  const [showSuccess, setShowSuccess] = useState(false)
  const [confirmedAmount, setConfirmedAmount] = useState('')

  const stopPolling = useCallback(() => {
    if (pollInterval) {
      clearInterval(pollInterval)
      setPollInterval(null)
    }
  }, [pollInterval])

  useEffect(() => {
    return () => stopPolling()
  }, [stopPolling])

  const fetchSummary = useCallback(async () => {
    const token = localStorage.getItem('cubag_token')
    if (!token) return
    const authHeader = { 'Authorization': `Bearer ${token}` }
    try {
      const [feesRes, payRes] = await Promise.all([
        fetch(`${import.meta.env.VITE_API_URL}/settings/cubag_fees`),
        fetch(`${import.meta.env.VITE_API_URL}/settings/cubag_payment_settings_v2`)
      ])

      if (feesRes.ok) {
        const feesData = await feesRes.json()
        if (feesData && feesData.renewalFee) setPlatformFees(feesData)
      }

      if (payRes.ok) {
        const payData = await payRes.json()
        if (payData && payData.momoAccounts) setPaymentSettings(payData)
      }
    } catch (e) {
      console.error("Payment Data Sync Error:", e)
    }
  }, [])

  const startPolling = useCallback((ref) => {
    stopPolling()
    const id = setInterval(async () => {
      try {
        const res = await fetch(`${import.meta.env.VITE_API_URL}/payments/verify/${ref}`)
        const data = await res.json()
        if (data.status === 'success') {
          stopPolling()
          setConfirmedAmount(amount)
          setPaystackCode('')
          setPayStep(1)
          setAmount('')
          setReason('')
          setPsStatus('')
          setShowSuccess(true)
          fetchSummary()
        } else if (data.status === 'failed') {
          stopPolling()
          alert('Payment failed or declined.')
          setPayStep(1)
        }
      } catch (e) {}
    }, 4000)
    setPollInterval(id)
  }, [stopPolling, fetchSummary])

  useAutoRefresh(fetchSummary, 60000)

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
        if (method === 'momo' && result.paystack_ref) {
          showToast('Payment request sent. Please check your phone.', 'success')
          setPaymentId(result.payment_id)
          setServerRef(result.paystack_ref)
          setPsStatus(result.status)

          if (result.status === 'send_otp') {
            setPayStep(4) // Move to OTP entry
          } else {
            setPayStep(4)
            startPolling(result.paystack_ref)
          }
        } else {
          showToast('✅ Payment information submitted.', 'success')
          setAmount(''); setReason(''); setPayStep(1)
          setBankDetails({ transactionId: '' })
          fetchSummary()
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
      const payload = {
        payment_id: paymentId,
        paystack_ref: serverRef,
        code: paystackCode
      }
      console.log("[DEBUG] Verifying code with payload:", payload)

      const res = await fetch(`${import.meta.env.VITE_API_URL}/payments/verify-code`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('cubag_token')}`
        },
        body: JSON.stringify(payload)
      })
      const result = await res.json()
      if (res.ok) {
        if (result.status === 'success') {
          setConfirmedAmount(amount)
          setPaystackCode('')
          setPayStep(1)
          setAmount('')
          setReason('')
          setPsStatus('')
          setShowSuccess(true)
          fetchSummary()
        } else {
          setPsStatus(result.status)
          startPolling(serverRef)
        }
      } else {
        const errorMsg = result.message || 'Verification failed.'
        alert(`Error: ${errorMsg}`)
      }
    } catch (e) {
      alert('Connection error.')
    } finally {
      setIsVerifying(false)
    }
  }

  const STEPS = [
    { n: 1, label: 'Type' },
    { n: 2, label: 'Method' },
    { n: 3, label: 'Review' },
    { n: 4, label: 'Verify' }
  ]
  const bank = paymentSettings.bankAccounts[selectedBank] || {}

  return (
    <AppLayout title="Payments">
      <div style={{ maxWidth: 650, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 20, paddingBottom: 80 }}>

        {/* Page Header - Clean & High */}
        <div style={{ padding: '8px 0' }}>
          <h2 style={{ fontSize: '1.6rem', fontWeight: 900, color: 'var(--text-primary)', margin: 0 }}>Payments & Dues</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginTop: 4 }}>Complete the steps below to settle your fees.</p>
        </div>

        {/* 4-Step Payment Card - Moved to the Top */}
        <div className="feed-card" style={{ borderRadius: 20, border: '1.5px solid var(--border-subtle)', boxShadow: 'var(--shadow-lg)', overflow: 'hidden' }}>

          {/* Progress Indicator */}
          <div style={{ padding: '24px 24px 20px', background: 'var(--bg-elevated)', borderBottom: '1px solid var(--border-subtle)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            {STEPS.map((s, idx) => (
              <div key={s.n} style={{ display: 'flex', alignItems: 'center', flex: idx < STEPS.length - 1 ? 1 : 'none' }}>
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
                  <div style={{
                    width: 32, height: 32, borderRadius: '50%',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontWeight: 800, fontSize: '0.8rem', transition: 'all 0.3s',
                    background: payStep >= s.n ? 'var(--brand-primary)' : 'var(--bg-base)',
                    color: payStep >= s.n ? '#fff' : 'var(--text-muted)',
                    border: payStep >= s.n ? 'none' : '2px solid var(--border-subtle)'
                  }}>
                    {payStep > s.n ? <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>check</span> : s.n}
                  </div>
                  <span style={{ fontSize: '0.6rem', fontWeight: 800, textTransform: 'uppercase', color: payStep === s.n ? 'var(--brand-primary)' : 'var(--text-muted)', letterSpacing: '0.02em' }}>{s.label}</span>
                </div>
                {idx < STEPS.length - 1 && (
                  <div style={{
                    flex: 1, height: 2, margin: '0 10px', marginBottom: 18,
                    transition: 'all 0.3s',
                    background: payStep > s.n ? 'var(--brand-primary)' : 'var(--border-subtle)'
                  }} />
                )}
              </div>
            ))}
          </div>

          <div className="card-body" style={{ padding: '24px 28px 32px' }}>
            {/* Step 1: Type Selection */}
            {payStep === 1 && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
                <CustomSelect label="Select Payment Category" value={reason} onChange={handleReasonChange} options={REASON_OPTIONS} icon="payments" />

                <div>
                  <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 700, color: 'var(--text-secondary)', marginBottom: 8, textTransform: 'uppercase', letterSpacing: '0.03em' }}>Amount to Pay</label>
                  <div style={{ position: 'relative' }}>
                    <span style={{ position: 'absolute', left: 16, top: '50%', transform: 'translateY(-50%)', fontWeight: 900, color: 'var(--brand-primary)', fontSize: '1.1rem' }}>₵</span>
                    <input type="number" placeholder="0.00" value={amount} onChange={e => setAmount(e.target.value)} disabled={isAmountFixed}
                      style={{ width: '100%', padding: '14px 16px 14px 40px', borderRadius: 12, border: '2px solid var(--border-default)', background: isAmountFixed ? 'rgba(0,0,0,0.02)' : 'var(--bg-base)', color: 'var(--text-primary)', outline: 'none', fontSize: '1.4rem', fontWeight: 900, fontFamily: 'monospace' }} />
                  </div>
                  {isAmountFixed && <p style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontWeight: 600, marginTop: 8, display: 'flex', alignItems: 'center', gap: 5 }}><span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>lock</span> Standard fee applies for this category.</p>}
                </div>

                <button className="btn btn-primary btn-lg" disabled={!reason || !amount} onClick={() => setPayStep(2)} style={{ justifyContent: 'center', height: 56, fontSize: '1rem', borderRadius: 14, boxShadow: '0 8px 20px rgba(240,130,50,0.2)' }}>
                  Continue to Methods <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>arrow_forward</span>
                </button>
              </div>
            )}

            {/* Step 2: Method Selection */}
            {payStep === 2 && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 700, color: 'var(--text-secondary)', marginBottom: 12, textTransform: 'uppercase' }}>Preferred Method</label>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
                    {[{ id: 'momo', icon: 'smartphone', label: 'Mobile Money' }, { id: 'bank', icon: 'account_balance', label: 'Bank Transfer' }].map(m => (
                      <div key={m.id} onClick={() => setMethod(m.id)} style={{ padding: '20px 12px', border: `2.5px solid ${method === m.id ? 'var(--brand-primary)' : 'var(--border-subtle)'}`, borderRadius: 16, cursor: 'pointer', textAlign: 'center', background: method === m.id ? 'rgba(240,130,50,0.05)' : 'var(--bg-base)', transition: 'all 0.2s' }}>
                        <span className="material-symbols-outlined" style={{ fontSize: '2rem', color: method === m.id ? 'var(--brand-primary)' : 'var(--text-muted)', display: 'block', marginBottom: 8 }}>{m.icon}</span>
                        <div style={{ fontSize: '0.85rem', fontWeight: 800, color: method === m.id ? 'var(--brand-primary)' : 'var(--text-primary)' }}>{m.label}</div>
                      </div>
                    ))}
                  </div>
                </div>

                {method === 'momo' && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
                    <CustomSelect label="Mobile Network" options={[{ value: 'MTN', label: 'MTN MoMo' }, { value: 'Vodafone', label: 'Telecel (Vodafone)' }, { value: 'AirtelTigo', label: 'AT (AirtelTigo)' }]} value={momoDetails.network} onChange={val => setMomoDetails({ ...momoDetails, network: val })} />
                    <div>
                      <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)', marginBottom: 6 }}>MoMo Phone Number</label>
                      <input type="tel" placeholder="0244..." value={momoDetails.phone} onChange={e => setMomoDetails({ ...momoDetails, phone: e.target.value })} style={{ width: '100%', padding: '12px 14px', borderRadius: 10, border: '1.5px solid var(--border-default)', outline: 'none', fontSize: '1rem', fontWeight: 600 }} />
                    </div>
                  </div>
                )}

                {method === 'bank' && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
                    <div style={{ fontSize: '0.8rem', background: 'var(--bg-base)', padding: 16, borderRadius: 12, border: '1px solid var(--border-subtle)', lineHeight: 1.6 }}>
                      <div style={{ fontWeight: 800, color: 'var(--brand-primary)', marginBottom: 6, textTransform: 'uppercase', fontSize: '0.7rem' }}>CUBAG Official Bank Account</div>
                      <div style={{ display: 'flex', justifyContent: 'space-between' }}><span>Bank:</span> <strong>{bank.bankName}</strong></div>
                      <div style={{ display: 'flex', justifyContent: 'space-between' }}><span>A/C Number:</span> <strong style={{ fontSize: '1rem', color: 'var(--text-primary)' }}>{bank.accountNumber}</strong></div>
                      <div style={{ display: 'flex', justifyContent: 'space-between' }}><span>Branch:</span> <strong>{bank.branch}</strong></div>
                    </div>
                    <div>
                      <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)', marginBottom: 6 }}>Transaction ID / Ref</label>
                      <input type="text" placeholder="Enter Reference" value={bankDetails.transactionId} onChange={e => setBankDetails({ ...bankDetails, transactionId: e.target.value })} style={{ width: '100%', padding: '12px 14px', borderRadius: 10, border: '1.5px solid var(--border-default)', outline: 'none', fontSize: '1rem', fontWeight: 600 }} />
                    </div>
                  </div>
                )}

                <div style={{ display: 'flex', gap: 12, marginTop: 10 }}>
                  <button className="btn btn-outline" onClick={() => setPayStep(1)} style={{ flex: 1, height: 52, borderRadius: 12 }}>Back</button>
                  <button
                    className="btn btn-primary"
                    disabled={(method === 'momo' && !momoDetails.phone) || (method === 'bank' && !bankDetails.transactionId)}
                    onClick={() => {
                      if (method === 'momo') {
                        const ghPhone = /^0[235][0-9]{8}$/
                        if (!ghPhone.test(momoDetails.phone)) {
                          alert('Please enter a valid Ghana phone number.')
                          return
                        }
                      }
                      setPayStep(3)
                    }}
                    style={{ flex: 2, height: 52, borderRadius: 12, fontSize: '0.9rem', fontWeight: 800 }}
                  >
                    Review Summary
                  </button>
                </div>
              </div>
            )}

            {/* Step 3: Review */}
            {payStep === 3 && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
                <div style={{ background: 'var(--bg-base)', borderRadius: 16, border: '1.5px solid var(--border-subtle)', overflow: 'hidden' }}>
                  <div style={{ padding: '12px 16px', background: 'var(--gradient-brand)', color: '#fff', fontWeight: 800, fontSize: '0.75rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Order Summary</div>
                  <div style={{ padding: '8px 16px 16px', display: 'flex', flexDirection: 'column' }}>
                    {[
                      { label: 'Category', value: REASON_OPTIONS.find(r => r.value === reason)?.label || reason },
                      { label: 'Payment Method', value: method === 'momo' ? `Mobile Money (${momoDetails.network})` : 'Bank Transfer' },
                      { label: 'Total Payable', value: `GH₵ ${parseFloat(amount || 0).toFixed(2)}`, highlight: true }
                    ].map((row, i, arr) => (
                      <div key={row.label} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '14px 0', borderBottom: i < arr.length - 1 ? '1px solid var(--border-subtle)' : 'none' }}>
                        <span style={{ color: 'var(--text-muted)', fontSize: '0.85rem', fontWeight: 600 }}>{row.label}</span>
                        <span style={{ fontWeight: row.highlight ? 900 : 700, color: row.highlight ? 'var(--brand-primary)' : 'var(--text-primary)', fontSize: row.highlight ? '1.1rem' : '0.9rem' }}>{row.value}</span>
                      </div>
                    ))}
                  </div>
                </div>

                <div style={{ display: 'flex', gap: 12 }}>
                  <button className="btn btn-outline" onClick={() => setPayStep(2)} disabled={loading} style={{ flex: 1, height: 52, borderRadius: 12 }}>
                    <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>arrow_back</span>
                  </button>
                  <button className="btn btn-primary" onClick={handlePayment} disabled={loading} style={{ flex: 3, height: 52, justifyContent: 'center', fontSize: '1rem', fontWeight: 900, borderRadius: 12, opacity: loading ? 0.6 : 1 }}>
                    {loading ? 'Processing...' : method === 'momo' ? 'Initiate Payment' : 'Confirm Payment'}
                  </button>
                </div>
              </div>
            )}

            {/* Step 4: Verification */}
            {payStep === 4 && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
                <div style={{ textAlign: 'center' }}>
                  <div style={{ width: 56, height: 56, background: 'rgba(240,130,50,0.1)', color: 'var(--brand-primary)', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px' }}>
                    <span className="material-symbols-outlined" style={{ fontSize: '1.8rem' }}>{psStatus === 'send_otp' ? 'sms' : 'timer'}</span>
                  </div>
                  <h3 style={{ fontSize: '1.2rem', fontWeight: 900, marginBottom: 6 }}>
                    {psStatus === 'send_otp' ? 'Verify OTP' : 'Action Required'}
                  </h3>
                  <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', lineHeight: 1.5 }}>
                    {psStatus === 'send_otp'
                      ? <>We've sent a code to <strong>{momoDetails.phone}</strong>.<br/>Enter it below to authorize the charge.</>
                      : <>Please check your phone (<strong>{momoDetails.phone}</strong>) and approve the MoMo prompt to finish.</>
                    }
                  </p>
                </div>

                {psStatus === 'send_otp' ? (
                  <>
                    <input
                      type="text"
                      required
                      placeholder="Enter 6-digit code"
                      value={paystackCode}
                      onChange={e => setPaystackCode(e.target.value)}
                      style={{ width: '100%', padding: 16, border: '2.5px solid var(--text-primary)', borderRadius: 14, background: '#fff', fontSize: '1.4rem', fontWeight: 900, textAlign: 'center', letterSpacing: '8px', outline: 'none' }}
                    />

                    <button className="btn btn-primary btn-lg" onClick={handleVerifyCode} disabled={isVerifying || !paystackCode.trim()} style={{ width: '100%', height: 56, fontSize: '1rem', fontWeight: 900, borderRadius: 14 }}>
                      {isVerifying ? 'Verifying...' : 'Confirm Payment'}
                    </button>
                  </>
                ) : (
                  <div style={{ textAlign: 'center', padding: '24px 0', background: 'var(--bg-base)', borderRadius: 16, border: '1.5px dashed var(--border-default)' }}>
                    <div className="spinner" style={{ margin: '0 auto 16px', width: 32, height: 32 }} />
                    <p style={{ fontSize: '0.75rem', color: 'var(--brand-primary)', fontWeight: 800, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Waiting for PIN Approval...</p>
                  </div>
                )}

                <button className="btn btn-ghost btn-sm" onClick={() => { stopPolling(); setPayStep(2); }} style={{ width: '100%', color: 'var(--text-muted)' }}>Cancel & Change Method</button>
              </div>
            )}
          </div>
        </div>

        {/* Footer Security Note */}
        <div style={{ textAlign: 'center', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, opacity: 0.6 }}>
          <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>verified</span>
          <span style={{ fontSize: '0.7rem', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.03em' }}>Secured by Paystack PCI-DSS Compliance</span>
        </div>

      </div>

      {/* ═══ Premium Success Overlay ═══ */}
      {showSuccess && (
        <div style={{
          position: 'fixed', inset: 0, zIndex: 99999,
          background: 'rgba(0,0,0,0.75)',
          backdropFilter: 'blur(8px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          animation: 'fadeIn 0.3s ease'
        }}>
          <div style={{
            background: 'var(--bg-surface)',
            borderRadius: 28,
            padding: '48px 32px 36px',
            width: '90%',
            maxWidth: 380,
            textAlign: 'center',
            position: 'relative',
            overflow: 'hidden',
            animation: 'fadeInUp 0.4s cubic-bezier(0.34, 1.56, 0.64, 1)',
            boxShadow: '0 25px 60px rgba(0,0,0,0.3)'
          }}>
            {/* Decorative glow */}
            <div style={{ position: 'absolute', top: -60, left: '50%', transform: 'translateX(-50%)', width: 200, height: 200, background: 'radial-gradient(circle, rgba(16,185,129,0.25) 0%, transparent 70%)', pointerEvents: 'none' }} />

            {/* Animated check circle */}
            <div style={{
              width: 90, height: 90,
              borderRadius: '50%',
              background: 'linear-gradient(135deg, #10b981, #059669)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              margin: '0 auto 24px',
              boxShadow: '0 8px 32px rgba(16,185,129,0.4)',
              animation: 'successPop 0.5s cubic-bezier(0.34, 1.56, 0.64, 1) 0.15s both'
            }}>
              <span className="material-symbols-outlined" style={{ fontSize: '3rem', color: '#fff', fontWeight: 700 }}>check</span>
            </div>

            <h2 style={{ fontSize: '1.5rem', fontWeight: 900, color: 'var(--text-primary)', marginBottom: 6, letterSpacing: '-0.02em' }}>Payment Confirmed!</h2>
            <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginBottom: 24, lineHeight: 1.5 }}>
              Your transaction has been successfully processed and recorded.
            </p>

            {confirmedAmount && (
              <div style={{
                background: 'rgba(16,185,129,0.08)',
                border: '1.5px solid rgba(16,185,129,0.2)',
                borderRadius: 16,
                padding: '16px 20px',
                marginBottom: 28
              }}>
                <div style={{ fontSize: '0.65rem', color: '#10b981', fontWeight: 800, textTransform: 'uppercase', letterSpacing: '0.1em', marginBottom: 4 }}>Amount Paid</div>
                <div style={{ fontSize: '1.8rem', fontWeight: 900, color: '#059669', fontFamily: 'var(--font-display)' }}>
                  GH₵ {parseFloat(confirmedAmount || 0).toFixed(2)}
                </div>
              </div>
            )}

            <button
              className="btn btn-primary btn-lg"
              onClick={() => setShowSuccess(false)}
              style={{
                width: '100%', height: 52, fontSize: '1rem', fontWeight: 800,
                borderRadius: 14, background: 'linear-gradient(135deg, #10b981, #059669)',
                border: 'none', color: '#fff'
              }}
            >
              <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>done_all</span>
              Done
            </button>

            <p style={{ fontSize: '0.7rem', color: 'var(--text-muted)', marginTop: 16 }}>A receipt has been sent to your email</p>
          </div>
        </div>
      )}

      <style>{`
        @keyframes successPop {
          0% { transform: scale(0); opacity: 0; }
          60% { transform: scale(1.15); }
          100% { transform: scale(1); opacity: 1; }
        }
        @keyframes fadeIn {
          from { opacity: 0; }
          to { opacity: 1; }
        }
      `}</style>
    </AppLayout>
  )
}
