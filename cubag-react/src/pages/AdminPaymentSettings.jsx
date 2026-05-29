import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

export default function AdminPaymentSettings() {
  const [loading, setLoading] = useState(false)
  const [success, setSuccess] = useState(false)
  
  const [settings, setSettings] = useState({
    bankAccounts: [{ bankName: '', accountName: '', accountNumber: '', branch: '' }]
  })

  useEffect(() => {
    fetch(`${import.meta.env.VITE_API_URL}/settings/cubag_payment_settings_v2`)
      .then(res => res.json())
      .then(data => {
        if (data && data.bankAccounts) setSettings(data)
      })
      .catch(e => console.error(e))
  }, [])

  const handleBankChange = (index, field, value) => {
    const newBanks = [...settings.bankAccounts]
    newBanks[index][field] = value
    setSettings({ ...settings, bankAccounts: newBanks })
  }

  const addBank = () => {
    setSettings({ ...settings, bankAccounts: [...settings.bankAccounts, { bankName: '', accountName: '', accountNumber: '', branch: '' }] })
  }

  const removeBank = (index) => {
    const newBanks = settings.bankAccounts.filter((_, i) => i !== index)
    setSettings({ ...settings, bankAccounts: newBanks })
  }

  const handleSave = async (e) => {
    e.preventDefault()
    setLoading(true)
    setSuccess(false)
    
    try {
      await fetch(`${import.meta.env.VITE_API_URL}/settings/cubag_payment_settings_v2`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(settings)
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
    <AppLayout title="Regulations">
      <div style={{ maxWidth: 700, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>
        
        {/* Page Title for Content */}
        <div style={{ marginBottom: 4 }}>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Collection Settings</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Manage MoMo and Bank details for renewals.</p>
        </div>

        <div style={{ padding: '20px 16px', background: 'var(--bg-elevated)', borderRadius: 12 }}>
          {success && (
            <div style={{ padding: 10, background: '#10b981', color: '#fff', borderRadius: 8, marginBottom: 20, display: 'flex', alignItems: 'center', gap: 8, fontSize: '0.85rem', fontWeight: 600 }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>check_circle</span>
              Settings updated!
            </div>
          )}

          <form onSubmit={handleSave} style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
            
            {/* Bank Details Section */}
            <div style={{ width: '100%' }}>
              <h3 style={{ fontSize: '1rem', marginBottom: 12, color: '#3b82f6', fontWeight: 800, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Bank Details</h3>
              
              <div style={{ display: 'flex', flexDirection: 'column', gap: 12, width: '100%' }}>
                {settings.bankAccounts.map((bank, index) => (
                  <div key={index} style={{ padding: '14px', background: 'var(--bg-base)', border: '1px solid var(--border-default)', borderRadius: '12px', position: 'relative', display: 'flex', flexDirection: 'column', gap: 10 }}>
                    {settings.bankAccounts.length > 1 && (
                      <button type="button" onClick={() => removeBank(index)} style={{ position: 'absolute', top: 10, right: 10, background: 'transparent', border: 'none', color: '#ef4444', cursor: 'pointer' }}>
                        <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>close</span>
                      </button>
                    )}
                    <div className="form-group">
                      <label style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)', marginBottom: 2 }}>Bank</label>
                      <input type="text" value={bank.bankName} onChange={(e) => handleBankChange(index, 'bankName', e.target.value)} style={{ padding: 8, fontSize: '0.9rem' }} required />
                    </div>
                    <div className="form-group">
                      <label style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)', marginBottom: 2 }}>A/C Name</label>
                      <input type="text" value={bank.accountName} onChange={(e) => handleBankChange(index, 'accountName', e.target.value)} style={{ padding: 8, fontSize: '0.9rem' }} required />
                    </div>
                    <div className="form-group">
                      <label style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)', marginBottom: 2 }}>A/C Number</label>
                      <input type="text" value={bank.accountNumber} onChange={(e) => handleBankChange(index, 'accountNumber', e.target.value)} style={{ padding: 10, fontSize: '1rem', fontWeight: 800, color: 'var(--brand-primary)', textAlign: 'center' }} required />
                    </div>
                  </div>
                ))}
              </div>

              <button type="button" onClick={addBank} className="btn btn-outline btn-sm" style={{ marginTop: 12, width: '100%', height: 40, fontSize: '0.75rem' }}>
                + Add Bank
              </button>
            </div>

            <button type="submit" className="btn btn-primary btn-lg" style={{ width: '100%', height: 50, borderRadius: 25, fontSize: '0.95rem' }} disabled={loading}>
              {loading ? 'Saving...' : 'Save Settings'}
            </button>
          </form>
        </div>
      </div>
    </AppLayout>
  )
}
