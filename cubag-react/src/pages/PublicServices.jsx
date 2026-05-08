import { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'

export default function PublicServices() {
  const [searchTerm, setSearchTerm] = useState('')
  const [companies, setCompanies] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function fetchDirectory() {
      try {
        // Will fetch from admin-managed verified list
        const res = await fetch(`${import.meta.env.VITE_API_URL}/members/public-directory`)
        if (res.ok) {
          const data = await res.json()
          setCompanies(data)
        }
      } catch (e) {
        console.error("Error fetching directory", e)
      } finally {
        setLoading(false)
      }
    }
    fetchDirectory()
  }, [])

  const filteredCompanies = companies.filter(c => 
    c.name?.toLowerCase().includes(searchTerm.toLowerCase()) || 
    c.location?.toLowerCase().includes(searchTerm.toLowerCase())
  )

  return (
    <div className="welcome-screen" style={{ overflowY: 'auto', minHeight: '100vh', background: '#f8fafc', padding: 0 }}>
      {/* Public Header */}
      <div style={{ background: 'var(--brand-primary)', padding: '40px 20px', position: 'relative', overflow: 'hidden' }}>
        <div style={{ position: 'absolute', top: -50, right: -50, width: 200, height: 200, background: '#fff', opacity: 0.1, borderRadius: '50%' }}></div>
        <div style={{ maxWidth: 900, margin: '0 auto', position: 'relative', zIndex: 1 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 40 }}>
            <Link to="/" style={{ display: 'inline-flex', alignItems: 'center', gap: 8, color: '#fff', textDecoration: 'none', fontWeight: 600 }}>
              <span className="material-symbols-outlined">arrow_back</span>
              Back
            </Link>
            <div style={{ display: 'flex', gap: 12 }}>
              <Link to="/login" style={{ color: '#fff', textDecoration: 'none', fontWeight: 700, padding: '8px 16px', border: '1px solid rgba(255,255,255,0.3)', borderRadius: 8 }}>Member Login</Link>
            </div>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: 24, flexWrap: 'wrap' }}>
            <img src="/logo.jpeg" alt="CUBAG" style={{ width: 80, height: 80, borderRadius: 20, boxShadow: '0 8px 24px rgba(0,0,0,0.15)' }} />
            <div>
              <h1 style={{ fontSize: '2.4rem', fontWeight: 900, color: '#fff', marginBottom: 8 }}>CUBAG Public Portal</h1>
              <p style={{ color: 'rgba(255,255,255,0.9)', fontSize: '1.1rem', maxWidth: 600 }}>
                Find verified logistics companies, contact licensed customs brokers, and download the official CUBAG app.
              </p>
            </div>
          </div>
        </div>
      </div>

      <div style={{ maxWidth: 900, margin: '-24px auto 0', padding: '0 20px 60px', position: 'relative', zIndex: 10 }}>
        
        {/* App Download Banner */}
        <div style={{ background: '#fff', padding: '24px', borderRadius: 20, boxShadow: '0 10px 40px rgba(0,0,0,0.08)', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 20, marginBottom: 40 }}>
          <div style={{ display: 'flex', gap: 16, alignItems: 'center' }}>
            <div style={{ width: 54, height: 54, background: 'rgba(240,130,50,0.1)', color: 'var(--brand-primary)', borderRadius: 14, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '2rem' }}>install_mobile</span>
            </div>
            <div>
              <h3 style={{ fontSize: '1.1rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: 4 }}>Get the Mobile App</h3>
              <p style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>Download the CUBAG app for the best experience on iOS and Android.</p>
            </div>
          </div>
          <div style={{ display: 'flex', gap: 12 }}>
            <button className="btn btn-outline" style={{ background: '#000', color: '#fff', border: 'none', display: 'flex', gap: 8, padding: '10px 20px' }}>
              <span className="material-symbols-outlined">shop</span> Google Play
            </button>
            <button className="btn btn-outline" style={{ background: '#000', color: '#fff', border: 'none', display: 'flex', gap: 8, padding: '10px 20px' }}>
              <span className="material-symbols-outlined">apple</span> App Store
            </button>
          </div>
        </div>

        {/* CUBAG Contact Info */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))', gap: 20, marginBottom: 48 }}>
          <div style={{ background: '#fff', padding: '24px', borderRadius: 16, border: '1px solid var(--border-subtle)', display: 'flex', gap: 16, alignItems: 'flex-start' }}>
            <span className="material-symbols-outlined" style={{ color: '#10b981', fontSize: '1.8rem' }}>call</span>
            <div>
              <div style={{ fontWeight: 800, color: 'var(--text-primary)', marginBottom: 4 }}>Call Secretariat</div>
              <a href="tel:+233302123456" style={{ color: 'var(--text-secondary)', textDecoration: 'none', fontSize: '0.9rem' }}>+233 (0) 302 123 456</a>
            </div>
          </div>
          <div style={{ background: '#fff', padding: '24px', borderRadius: 16, border: '1px solid var(--border-subtle)', display: 'flex', gap: 16, alignItems: 'flex-start' }}>
            <span className="material-symbols-outlined" style={{ color: '#3b82f6', fontSize: '1.8rem' }}>mail</span>
            <div>
              <div style={{ fontWeight: 800, color: 'var(--text-primary)', marginBottom: 4 }}>Email Secretariat</div>
              <a href="mailto:info@cubag.org.gh" style={{ color: 'var(--text-secondary)', textDecoration: 'none', fontSize: '0.9rem' }}>info@cubag.org.gh</a>
            </div>
          </div>
          <div style={{ background: '#fff', padding: '24px', borderRadius: 16, border: '1px solid var(--border-subtle)', display: 'flex', gap: 16, alignItems: 'flex-start' }}>
            <span className="material-symbols-outlined" style={{ color: '#f59e0b', fontSize: '1.8rem' }}>location_on</span>
            <div>
              <div style={{ fontWeight: 800, color: 'var(--text-primary)', marginBottom: 4 }}>Head Office</div>
              <div style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>Community 1, Tema, Ghana</div>
            </div>
          </div>
        </div>

        {/* Directory Search */}
        <div style={{ marginBottom: 32 }}>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: 16 }}>Verified Logistics Directory</h2>
          <div style={{ position: 'relative' }}>
            <span className="material-symbols-outlined" style={{ position: 'absolute', left: 16, top: 14, color: 'var(--text-muted)' }}>search</span>
            <input 
              type="text" 
              placeholder="Search companies by name or location..." autoComplete="off" 
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              style={{ width: '100%', padding: '14px 16px 14px 48px', borderRadius: 12, border: '1.5px solid var(--border-default)', fontSize: '1rem', outline: 'none' }}
            />
          </div>
        </div>

        {/* Company List */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          {filteredCompanies.map(company => (
            <div key={company.id} style={{ background: '#fff', padding: '24px', borderRadius: 16, border: '1px solid var(--border-subtle)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 20 }}>
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
                  <h3 style={{ fontSize: '1.1rem', fontWeight: 800, color: 'var(--text-primary)' }}>{company.name}</h3>
                  <span style={{ padding: '4px 10px', background: 'rgba(16,185,129,0.1)', color: '#10b981', borderRadius: 20, fontSize: '0.7rem', fontWeight: 700 }}>VERIFIED</span>
                </div>
                <div style={{ display: 'flex', gap: 16, color: 'var(--text-muted)', fontSize: '0.85rem', marginBottom: 12 }}>
                  <span style={{ display: 'flex', alignItems: 'center', gap: 4 }}><span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>work</span> {company.type}</span>
                  <span style={{ display: 'flex', alignItems: 'center', gap: 4 }}><span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>location_on</span> {company.location}</span>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 4, color: '#f59e0b', fontSize: '0.9rem', fontWeight: 700 }}>
                  <span className="material-symbols-outlined" style={{ fontVariationSettings: "'FILL' 1" }}>star</span> {company.rating}/5.0
                </div>
              </div>
              
              <div style={{ display: 'flex', gap: 12 }}>
                <a href={`tel:${company.phone}`} className="btn btn-outline" style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '10px 16px' }}>
                  <span className="material-symbols-outlined">call</span> Call
                </a>
                <a href={`mailto:${company.email}`} className="btn btn-primary" style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '10px 16px' }}>
                  <span className="material-symbols-outlined">mail</span> Email
                </a>
              </div>
            </div>
          ))}
          {filteredCompanies.length === 0 && (
            <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-muted)' }}>
              No companies found matching your search.
            </div>
          )}
        </div>
        
      </div>
    </div>
  )
}
