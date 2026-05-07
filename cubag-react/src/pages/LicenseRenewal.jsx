import { useState, useEffect } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import AppLayout from '../components/AppLayout'
import CustomSelect from '../components/CustomSelect'

const API_URL = import.meta.env.VITE_API_URL

export default function LicenseRenewal() {
  const [step, setStep] = useState(1)
  const [loading, setLoading] = useState(false)
  const [success, setSuccess] = useState(false)
  const [paymentMethod, setPaymentMethod] = useState('momo')
  const [momoDetails, setMomoDetails] = useState({ network: 'MTN', phone: '' })
  const [bankDetails, setBankDetails] = useState({ transactionId: '' })
  const navigate = useNavigate()
  const [history, setHistory] = useState([])
  const [historyLoading, setHistoryLoading] = useState(false)
  const [memberInfo, setMemberInfo] = useState(null)

  const fetchHistory = async () => {
    setHistoryLoading(true)
    try {
      const res = await fetch(`${API_URL}/members/license-history`, {
        headers: { Authorization: `Bearer ${localStorage.getItem('cubag_token')}` }
      })
      const data = await res.json()
      setHistory(data.history || [])
      setMemberInfo(data.member || null)
    } catch {}
    finally { setHistoryLoading(false) }
  }

  const [settingsLoading, setSettingsLoading] = useState(true)
  const [platformFees, setPlatformFees] = useState({ renewalFee: '1500.00' })
  const [platformSettings, setPlatformSettings] = useState({
    momoAccounts: [{ network: 'MTN', number: '0244000000' }],
    bankAccounts: [{ bankName: 'GCB Bank', accountName: 'CUBAG National Account', accountNumber: '1011130023456', branch: 'Tema Main' }]
  })

  const fetchSettings = async () => {
    try {
      const [feesRes, settingsRes] = await Promise.all([
        fetch(`${API_URL}/settings/cubag_fees`),
        fetch(`${API_URL}/settings/cubag_payment_settings_v2`)
      ])
      if (feesRes.ok) {
        const f = await feesRes.json()
        if (f.renewalFee) setPlatformFees(f)
      }
      if (settingsRes.ok) {
        const s = await settingsRes.json()
        if (s.momoAccounts) setPlatformSettings(s)
      }
    } catch (e) {
      console.error('Failed to load settings', e)
    } finally {
      setSettingsLoading(false)
    }
  }

  useEffect(() => { 
    fetchHistory()
    fetchSettings()
  }, [])

  const user = JSON.parse(localStorage.getItem('cubag_user') || '{}')
  
  const renewalFee = platformFees.renewalFee
  const momoAccounts = platformSettings.momoAccounts
  const bankAccounts = platformSettings.bankAccounts

  const [selectedMomo, setSelectedMomo] = useState(0)
  const [selectedBank, setSelectedBank] = useState(0)

  const handlePaymentNext = () => {
    // Simulate moving past payment gateway or picking option
    setStep(3)
  }

  const handleSubmit = async () => {
    setLoading(true)
    try {
      const paymentRef = paymentMethod === 'momo' ? `MOMO-${momoDetails.phone}` : bankDetails.transactionId
      const res = await fetch(`${API_URL}/members/renew`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('cubag_token')}`
        },
        body: JSON.stringify({ payment_ref: paymentRef })
      })

      if (res.ok) {
        setSuccess(true)
        setStep(4)
      } else {
        alert('Failed to submit application. Try again.')
      }
    } catch (e) {
      console.error(e)
    } finally {
      setLoading(false)
    }
  }

  return (
    <AppLayout title="Receipts & Licenses" hideSearch>
      <div style={{ maxWidth: 800, margin: '0 auto' }}>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          {historyLoading ? (
            <div style={{ textAlign: 'center', padding: 40, color: 'var(--text-muted)' }}>Loading history...</div>
          ) : history.length === 0 ? (
            <div className="feed-card" style={{ textAlign: 'center', padding: '48px 24px' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '3rem', color: 'var(--text-muted)', display: 'block', marginBottom: 12 }}>history</span>
              <h3 style={{ marginBottom: 8 }}>No Records Found</h3>
              <p style={{ color: 'var(--text-secondary)', marginBottom: 20 }}>You don't have any receipts or license certificates yet.</p>
              <Link to="/payments" className="btn btn-primary">Make a Payment</Link>
            </div>
          ) : history.map((rec, i) => (
            <div key={i} className="feed-card" style={{ padding: '20px 24px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: 12, marginBottom: 16 }}>
                  <div>
                    <div style={{ fontWeight: 800, fontSize: '1rem', color: 'var(--text-primary)', marginBottom: 4 }}>License / Membership Record</div>
                    {rec.payment_ref && rec.payment_ref !== 'N/A' && (
                      <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Ref: <span style={{ fontFamily: 'monospace' }}>{rec.payment_ref}</span></div>
                    )}
                  </div>
                  <span style={{
                    padding: '4px 14px', borderRadius: 20, fontSize: '0.75rem', fontWeight: 800,
                    background: rec.approved ? 'rgba(16,185,129,0.1)' : rec.status === 'suspended' ? 'rgba(239,68,68,0.1)' : 'rgba(245,158,11,0.1)',
                    color: rec.approved ? '#10b981' : rec.status === 'suspended' ? '#ef4444' : '#f59e0b'
                  }}>
                    {rec.approved ? 'Approved & Active' : rec.status === 'suspended' ? 'Suspended' : 'Pending Approval'}
                  </span>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 16 }}>
                  {[['Company', rec.company], ['Member Type', rec.member_type], ['Port', rec.port_of_operation], ['Submitted', rec.submitted_at?.split('T')[0]]].map(([label, val]) => (
                    <div key={label} style={{ padding: '10px 12px', background: 'var(--bg-base)', borderRadius: 10 }}>
                      <div style={{ fontSize: '0.68rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, marginBottom: 2 }}>{label}</div>
                      <div style={{ fontSize: '0.88rem', fontWeight: 600, color: 'var(--text-primary)' }}>{val || '—'}</div>
                    </div>
                  ))}
                </div>

                {rec.approved && (
                  <button
                    className="btn btn-primary"
                    style={{ width: '100%', justifyContent: 'center', display: 'flex', alignItems: 'center', gap: 8 }}
                    onClick={() => {
                      const user = memberInfo || rec
                      const content = `CUBAG LICENSE CERTIFICATE\n${'='.repeat(40)}\nMember: ${user.name}\nCompany: ${user.company}\nMember Type: ${user.member_type}\nLicense No.: ${user.license_number || 'N/A'}\nPort: ${user.port_of_operation}\nEmail: ${user.email}\nPayment Ref: ${rec.payment_ref}\nStatus: APPROVED\nIssued: ${new Date().toLocaleDateString()}\n${'='.repeat(40)}\nThis certificate confirms active membership in the\nCustoms Brokers & Agents Association of Ghana (CUBAG).`
                      const blob = new Blob([content], { type: 'text/plain' })
                      const url = URL.createObjectURL(blob)
                      const a = document.createElement('a')
                      a.href = url
                      a.download = `CUBAG_License_${user.name?.replace(/\s+/g, '_')}.txt`
                      a.click()
                      URL.revokeObjectURL(url)
                    }}
                  >
                    <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>download</span>
                    Download License Certificate
                  </button>
                )}

                {!rec.approved && (
                  <div style={{ textAlign: 'center', padding: '10px', background: 'rgba(245,158,11,0.08)', borderRadius: 10, fontSize: '0.85rem', color: '#f59e0b' }}>
                    <span className="material-symbols-outlined" style={{ verticalAlign: 'middle', fontSize: '1rem', marginRight: 4 }}>schedule</span>
                    Awaiting admin approval. Download will be available once approved.
                  </div>
                )}
              </div>
            ))}
          </div>

        <div style={{ marginTop: 24, textAlign: 'center' }}>
          <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Need help? <Link to="/engagement" style={{ color: 'var(--brand-primary)', textDecoration: 'none', fontWeight: 600 }}>Contact Support</Link></p>
        </div>

      </div>
    </AppLayout>
  )
}
