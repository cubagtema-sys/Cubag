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
      <div style={{ background: 'var(--brand-primary)', padding: '32px 16px', position: 'relative', overflow: 'hidden' }}>
        <div style={{ position: 'absolute', top: -50, right: -50, width: 200, height: 200, background: '#fff', opacity: 0.1, borderRadius: '50%' }}></div>
        <div style={{ maxWidth: 900, margin: '0 auto', position: 'relative', zIndex: 1 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
            <Link to="/" style={{ display: 'inline-flex', alignItems: 'center', gap: 6, color: '#fff', textDecoration: 'none', fontWeight: 600, fontSize: '0.9rem' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>arrow_back</span>
              Back
            </Link>
            <div style={{ display: 'flex', gap: 8 }}>
              <Link to="/login" style={{ color: '#fff', textDecoration: 'none', fontWeight: 700, padding: '6px 12px', border: '1px solid rgba(255,255,255,0.3)', borderRadius: 8, fontSize: '0.85rem' }}>Login</Link>
            </div>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: 16, flexWrap: 'wrap' }}>
            <img src="/logo.jpeg" alt="CUBAG" style={{ width: 60, height: 60, borderRadius: 16, boxShadow: '0 8px 24px rgba(0,0,0,0.15)' }} />
            <div>
              <h1 style={{ fontSize: 'clamp(1.5rem, 5vw, 2.2rem)', fontWeight: 900, color: '#fff', marginBottom: 4 }}>Public Portal</h1>
              <p style={{ color: 'rgba(255,255,255,0.9)', fontSize: '0.9rem', maxWidth: 600, lineHeight: 1.4 }}>
                Verified logistics directory & licensed customs brokers.
              </p>
            </div>
          </div>
        </div>
      </div>

      <div style={{ maxWidth: 900, margin: '-24px auto 0', padding: '0 20px 60px', position: 'relative', zIndex: 10 }}>
        
        {/* App Download Banner */}
        <div style={{ background: '#fff', padding: '16px', borderRadius: 16, boxShadow: '0 10px 40px rgba(0,0,0,0.05)', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 12, marginBottom: 32 }}>
          <div style={{ display: 'flex', gap: 12, alignItems: 'center', minWidth: '240px', flex: '1' }}>
            <div style={{ width: 44, height: 44, background: 'rgba(240,130,50,0.1)', color: 'var(--brand-primary)', borderRadius: 12, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1.5rem' }}>install_mobile</span>
            </div>
            <div>
              <h3 style={{ fontSize: '1rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: 2 }}>Get Mobile App</h3>
              <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Best experience on iOS & Android.</p>
            </div>
          </div>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', width: '100%', justifyContent: 'center' }}>
            <button className="btn btn-outline" style={{ background: '#000', color: '#fff', border: 'none', display: 'flex', gap: 6, padding: '8px 16px', flex: '1', minWidth: '120px', justifyContent: 'center', fontSize: '0.8rem' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>shop</span> Google Play
            </button>
            <button className="btn btn-outline" style={{ background: '#000', color: '#fff', border: 'none', display: 'flex', gap: 6, padding: '8px 16px', flex: '1', minWidth: '120px', justifyContent: 'center', fontSize: '0.8rem' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>apple</span> App Store
            </button>
          </div>
        </div>

        {/* CUBAG Contact Info */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 12, marginBottom: 32 }}>
          <div style={{ background: '#fff', padding: '16px', borderRadius: 12, border: '1px solid var(--border-subtle)', display: 'flex', gap: 12, alignItems: 'center' }}>
            <span className="material-symbols-outlined" style={{ color: '#10b981', fontSize: '1.4rem' }}>call</span>
            <div>
              <div style={{ fontWeight: 800, color: 'var(--text-primary)', fontSize: '0.8rem' }}>Call</div>
              <a href="tel:+233302123456" style={{ color: 'var(--text-muted)', textDecoration: 'none', fontSize: '0.8rem' }}>+233 302 123 456</a>
            </div>
          </div>
          <div style={{ background: '#fff', padding: '16px', borderRadius: 12, border: '1px solid var(--border-subtle)', display: 'flex', gap: 12, alignItems: 'center' }}>
            <span className="material-symbols-outlined" style={{ color: '#3b82f6', fontSize: '1.4rem' }}>mail</span>
            <div>
              <div style={{ fontWeight: 800, color: 'var(--text-primary)', fontSize: '0.8rem' }}>Email</div>
              <a href="mailto:info@cubag.org.gh" style={{ color: 'var(--text-muted)', textDecoration: 'none', fontSize: '0.8rem', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: 'block', maxWidth: '140px' }}>info@cubag.org.gh</a>
            </div>
          </div>
          <div style={{ background: '#fff', padding: '16px', borderRadius: 12, border: '1px solid var(--border-subtle)', display: 'flex', gap: 12, alignItems: 'center' }}>
            <span className="material-symbols-outlined" style={{ color: '#f59e0b', fontSize: '1.4rem' }}>location_on</span>
            <div>
              <div style={{ fontWeight: 800, color: 'var(--text-primary)', fontSize: '0.8rem' }}>Office</div>
              <div style={{ color: 'var(--text-muted)', fontSize: '0.8rem' }}>Tema, Ghana</div>
            </div>
          </div>
        </div>

        {/* Directory Search */}
        <div style={{ marginBottom: 20 }}>
          <h2 style={{ fontSize: '1.2rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: 12 }}>Logistics Directory</h2>
          <div style={{ position: 'relative' }}>
            <span className="material-symbols-outlined" style={{ position: 'absolute', left: 14, top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)', fontSize: '1.1rem' }}>search</span>
            <input 
              type="text" 
              placeholder="Search companies..." autoComplete="off"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              style={{ width: '100%', padding: '10px 12px 10px 40px', borderRadius: 10, border: '1.5px solid var(--border-default)', fontSize: '0.9rem', outline: 'none' }}
            />
          </div>
        </div>

        {/* Company List */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {filteredCompanies.map(company => (
            <div key={company.id} style={{ background: '#fff', padding: '16px', borderRadius: 12, border: '1px solid var(--border-subtle)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 12 }}>
              <div style={{ minWidth: 0, flex: 1 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
                  <h3 style={{ fontSize: '0.95rem', fontWeight: 800, color: 'var(--text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{company.name}</h3>
                  <span style={{ padding: '2px 8px', background: 'rgba(16,185,129,0.1)', color: '#10b981', borderRadius: 20, fontSize: '0.6rem', fontWeight: 700, flexShrink: 0 }}>VERIFIED</span>
                </div>
                <div style={{ display: 'flex', gap: 10, color: 'var(--text-muted)', fontSize: '0.75rem', marginBottom: 6 }}>
                   <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{company.type}</span>
                   <span>•</span>
                   <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{company.location}</span>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 4, color: '#f59e0b', fontSize: '0.8rem', fontWeight: 700 }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '0.9rem', fontVariationSettings: "'FILL' 1" }}>star</span> {company.rating}/5.0
                </div>
              </div>
              
              <div style={{ display: 'flex', gap: 8, width: '100%', borderTop: '1px solid var(--border-subtle)', paddingTop: 12, marginTop: 4 }}>
                <a href={`tel:${company.phone}`} className="btn btn-outline btn-sm" style={{ flex: 1, justifyContent: 'center', height: 36, fontSize: '0.75rem' }}>Call</a>
                <a href={`mailto:${company.email}`} className="btn btn-primary btn-sm" style={{ flex: 1, justifyContent: 'center', height: 36, fontSize: '0.75rem' }}>Email</a>
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
