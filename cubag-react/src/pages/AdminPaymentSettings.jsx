import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

export default function AdminPaymentSettings() {
  const [loading, setLoading] = useState(false)
  const [success, setSuccess] = useState(false)
  
  const [settings, setSettings] = useState({
    momoAccounts: [{ network: 'MTN', number: '0244000000' }],
    bankAccounts: [{ bankName: 'GCB Bank', accountName: 'CUBAG National Account', accountNumber: '1011130023456', branch: 'Tema Main' }]
  })

  useEffect(() => {
    fetch(`${import.meta.env.VITE_API_URL}/settings/cubag_payment_settings_v2`)
      .then(res => res.json())
      .then(data => {
        if (data && data.momoAccounts) setSettings(data)
      })
      .catch(e => console.error(e))
  }, [])

  const handleMomoChange = (index, field, value) => {
    const newMomo = [...settings.momoAccounts]
    newMomo[index][field] = value
    setSettings({ ...settings, momoAccounts: newMomo })
  }

  const addMomo = () => {
    setSettings({ ...settings, momoAccounts: [...settings.momoAccounts, { network: 'MTN', number: '' }] })
  }

  const removeMomo = (index) => {
    const newMomo = settings.momoAccounts.filter((_, i) => i !== index)
    setSettings({ ...settings, momoAccounts: newMomo })
  }

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
    <AppLayout title="Payment Settings (Admin)" hideSearch>
      <div style={{ maxWidth: 700, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 24 }}>
        
        <div style={{ padding: '24px', background: 'var(--bg-elevated)', borderRadius: 16 }}>
          <h2 style={{ fontSize: '1.4rem', marginBottom: 8, display: 'flex', alignItems: 'center', gap: 8 }}>
            <span className="material-symbols-outlined" style={{ color: 'var(--brand-primary)' }}>admin_panel_settings</span>
            Payment Regulations
          </h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '0.95rem', marginBottom: 24 }}>
            Configure the fees, mobile money integrations, and bank details displayed to members during the license renewal and dues payment processes.
          </p>

          {success && (
            <div style={{ padding: 12, background: 'rgba(16, 185, 129, 0.1)', color: 'var(--brand-success)', borderRadius: 8, marginBottom: 24, border: '1px solid rgba(16, 185, 129, 0.2)', display: 'flex', alignItems: 'center', gap: 8 }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>check_circle</span>
              Payment settings updated successfully!
            </div>
          )}

          <form onSubmit={handleSave} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
            
            {/* Mobile Money Settings */}
            <div style={{ width: '100%', maxWidth: 400, marginBottom: 32 }}>
              <h3 style={{ fontSize: '1.2rem', marginBottom: 16, paddingBottom: 8, color: '#10b981', borderBottom: '2px solid rgba(16,185,129,0.1)', display: 'inline-block' }}>Mobile Money Accounts</h3>
              
              <div style={{ display: 'flex', flexDirection: 'column', gap: 24, width: '100%' }}>
                {settings.momoAccounts.map((momo, index) => (
                  <div key={index} style={{ padding: '16px', background: 'var(--bg-base)', border: '1px solid var(--border-default)', borderRadius: '12px', position: 'relative' }}>
                    {settings.momoAccounts.length > 1 && (
                      <button type="button" onClick={() => removeMomo(index)} style={{ position: 'absolute', top: 8, right: 8, background: 'transparent', border: 'none', color: 'var(--brand-danger)', cursor: 'pointer' }}>
                        <span className="material-symbols-outlined">close</span>
                      </button>
                    )}
                    <div className="form-group" style={{ alignItems: 'center', marginBottom: 12 }}>
                      <label style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-secondary)' }}>Provider</label>
                      <select 
                        value={momo.network}
                        onChange={(e) => handleMomoChange(index, 'network', e.target.value)}
                        style={{ width: '100%', padding: 12, border: '2px solid #e2e8f0', borderRadius: 8, background: '#fff', textAlign: 'center', fontWeight: 600 }}
                      >
                        <option value="MTN">MTN Mobile Money</option>
                        <option value="Vodafone">Vodafone Cash</option>
                        <option value="AirtelTigo">AirtelTigo Money</option>
                      </select>
                    </div>
                    <div className="form-group" style={{ alignItems: 'center', margin: 0 }}>
                      <label style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-secondary)' }}>Collection Number</label>
                      <input 
                        type="text" 
                        value={momo.number}
                        onChange={(e) => handleMomoChange(index, 'number', e.target.value)}
                        style={{ width: '100%', padding: 12, border: '2px solid #e2e8f0', borderRadius: 8, background: '#fff', textAlign: 'center', fontWeight: 600, letterSpacing: '2px' }} 
                        required
                      />
                    </div>
                  </div>
                ))}
              </div>
              
              <button type="button" onClick={addMomo} className="btn btn-outline btn-sm" style={{ marginTop: 16, width: '100%' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>add</span> Add MoMo Account
              </button>
            </div>

            {/* Bank Settings */}
            <div style={{ width: '100%', maxWidth: 400, marginBottom: 40 }}>
              <h3 style={{ fontSize: '1.2rem', marginBottom: 16, paddingBottom: 8, color: '#3b82f6', borderBottom: '2px solid rgba(59,130,246,0.1)', display: 'inline-block' }}>Bank Transfer Details</h3>
              
              <div style={{ display: 'flex', flexDirection: 'column', gap: 24, width: '100%' }}>
                {settings.bankAccounts.map((bank, index) => (
                  <div key={index} style={{ padding: '16px', background: 'var(--bg-base)', border: '1px solid var(--border-default)', borderRadius: '12px', position: 'relative' }}>
                    {settings.bankAccounts.length > 1 && (
                      <button type="button" onClick={() => removeBank(index)} style={{ position: 'absolute', top: 8, right: 8, background: 'transparent', border: 'none', color: 'var(--brand-danger)', cursor: 'pointer' }}>
                        <span className="material-symbols-outlined">close</span>
                      </button>
                    )}
                    <div className="form-group" style={{ alignItems: 'center', marginBottom: 12 }}>
                      <label style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-secondary)' }}>Bank Name</label>
                      <input 
                        type="text" 
                        value={bank.bankName}
                        onChange={(e) => handleBankChange(index, 'bankName', e.target.value)}
                        style={{ width: '100%', padding: 12, border: '2px solid #e2e8f0', borderRadius: 8, background: '#fff', textAlign: 'center', fontWeight: 600 }} 
                        required
                      />
                    </div>
                    <div className="form-group" style={{ alignItems: 'center', marginBottom: 12 }}>
                      <label style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-secondary)' }}>Account Name</label>
                      <input 
                        type="text" 
                        value={bank.accountName}
                        onChange={(e) => handleBankChange(index, 'accountName', e.target.value)}
                        style={{ width: '100%', padding: 12, border: '2px solid #e2e8f0', borderRadius: 8, background: '#fff', textAlign: 'center', fontWeight: 600 }} 
                        required
                      />
                    </div>
                    <div className="form-group" style={{ alignItems: 'center', marginBottom: 12 }}>
                      <label style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-secondary)' }}>Account Number</label>
                      <input 
                        type="text" 
                        value={bank.accountNumber}
                        onChange={(e) => handleBankChange(index, 'accountNumber', e.target.value)}
                        style={{ width: '100%', padding: 12, border: '2px solid #e2e8f0', borderRadius: 8, background: '#fff', fontSize: '1.1rem', color: 'var(--brand-primary)', fontWeight: 800, textAlign: 'center', letterSpacing: '2px' }} 
                        required
                      />
                    </div>
                    <div className="form-group" style={{ alignItems: 'center', margin: 0 }}>
                      <label style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-secondary)' }}>Branch</label>
                      <input 
                        type="text" 
                        value={bank.branch}
                        onChange={(e) => handleBankChange(index, 'branch', e.target.value)}
                        style={{ width: '100%', padding: 12, border: '2px solid #e2e8f0', borderRadius: 8, background: '#fff', textAlign: 'center', fontWeight: 600 }} 
                        required
                      />
                    </div>
                  </div>
                ))}
              </div>

              <button type="button" onClick={addBank} className="btn btn-outline btn-sm" style={{ marginTop: 16, width: '100%' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>add</span> Add Bank Account
              </button>
            </div>

            <button type="submit" className="btn btn-primary btn-lg" style={{ width: '100%', maxWidth: 400, height: 54, borderRadius: 27 }} disabled={loading}>
              {loading ? 'Saving Settings...' : 'Save Payment Settings'}
            </button>
          </form>
        </div>
      </div>
    </AppLayout>
  )
}
