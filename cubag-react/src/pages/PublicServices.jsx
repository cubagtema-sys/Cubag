import { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import CustomSelect from '../components/CustomSelect'

const API_URL = import.meta.env.VITE_API_URL

export default function PublicServices() {
  const [searchTerm, setSearchTerm] = useState('')
  const [categoryFilter, setCategoryFilter] = useState('All')
  const [materials, setMaterials] = useState([])
  const [loading, setLoading] = useState(true)

  const CATEGORY_OPTIONS = [
    { value: 'All',    label: 'All Categories',      icon: 'filter_list' },
    { value: 'Policy', label: 'Policy Documents',    icon: 'description' },
    { value: 'Forms',  label: 'Official Forms',      icon: 'edit_document' },
    { value: 'Guides', label: 'Instructional Guides',icon: 'menu_book' },
    { value: 'Images', label: 'Association Images',  icon: 'image' }
  ]

  useEffect(() => {
    async function fetchMaterials() {
      try {
        const res = await fetch(`${API_URL}/public-materials/public`)
        if (res.ok) {
          setMaterials(await res.json())
        } else {
          setMaterials([
            { id: 1, title: 'CUBAG Membership Policy 2026', category: 'Policy', file_type: 'pdf',  file_url: '#', created_at: '2026-01-10' },
            { id: 2, title: 'License Renewal Form',          category: 'Forms',  file_type: 'xlsx', file_url: '#', created_at: '2026-02-15' },
            { id: 3, title: 'Export Documentation Guide',    category: 'Guides', file_type: 'pdf',  file_url: '#', created_at: '2026-03-01' },
            { id: 4, title: 'Customs Act 2015 Extract',      category: 'Policy', file_type: 'pdf',  file_url: '#', created_at: '2026-01-20' },
            { id: 5, title: 'Standard Operating Procedures', category: 'Guides', file_type: 'docx', file_url: '#', created_at: '2026-02-25' }
          ])
        }
      } catch (e) {
        console.error('Error fetching materials', e)
      } finally {
        setLoading(false)
      }
    }
    fetchMaterials()
  }, [])

  const filteredMaterials = materials.filter(m => {
    const q = searchTerm.toLowerCase()
    const matchSearch = m.title?.toLowerCase().includes(q) || m.category?.toLowerCase().includes(q)
    const matchCat = categoryFilter === 'All' || m.category === categoryFilter
    return matchSearch && matchCat
  })

  const getFileIcon = (type) => {
    if (type === 'pdf')                      return 'picture_as_pdf'
    if (['jpg','png','jpeg'].includes(type)) return 'image'
    if (['xls','xlsx'].includes(type))       return 'table_chart'
    if (['doc','docx'].includes(type))       return 'description'
    return 'file_present'
  }

  const FILE_COLORS = {
    pdf: '#ef4444', xlsx: '#22c55e', xls: '#22c55e',
    docx: '#3b82f6', doc: '#3b82f6', jpg: '#f59e0b',
    png: '#f59e0b', jpeg: '#f59e0b'
  }
  const fileColor = (type) => FILE_COLORS[type] || 'var(--brand-primary)'

  return (
    <div style={{
      minHeight: '100vh',
      background: 'var(--bg-base)',
      overflowX: 'hidden',
      fontFamily: 'var(--font-base, Inter, sans-serif)'
    }}>

      {/* ── Header ── */}
      <div style={{
        background: 'linear-gradient(135deg, #f08232 0%, #e06920 100%)',
        padding: 'calc(env(safe-area-inset-top, 0px) + 20px) 16px 48px',
        position: 'relative',
        overflow: 'hidden'
      }}>
        {/* Decorative orbs */}
        <div style={{ position:'absolute', top:-60, right:-60, width:180, height:180, background:'#fff', opacity:0.08, borderRadius:'50%', pointerEvents:'none' }} />
        <div style={{ position:'absolute', bottom:-40, left:-40, width:130, height:130, background:'#fff', opacity:0.06, borderRadius:'50%', pointerEvents:'none' }} />

        <div style={{ maxWidth: 720, margin: '0 auto', position: 'relative', zIndex: 1 }}>
          {/* Login link */}
          <div style={{ display:'flex', justifyContent:'flex-end', marginBottom: 20 }}>
            <Link to="/login" style={{
              color:'#fff', textDecoration:'none', fontWeight:800,
              padding:'7px 16px', border:'1.5px solid rgba(255,255,255,0.45)',
              borderRadius:20, fontSize:'0.78rem', letterSpacing:'0.04em',
              textTransform:'uppercase', backdropFilter:'blur(4px)'
            }}>Login</Link>
          </div>

          {/* Branding row */}
          <div style={{ display:'flex', alignItems:'center', gap:14, flexWrap:'nowrap' }}>
            <img
              src="/logo.jpeg" alt="CUBAG"
              style={{ width:52, height:52, borderRadius:14, boxShadow:'0 4px 16px rgba(0,0,0,0.25)', flexShrink:0, objectFit:'cover' }}
            />
            <div style={{ minWidth:0 }}>
              <h1 style={{ fontSize:'clamp(1.2rem,5vw,1.6rem)', fontWeight:900, color:'#fff', margin:0, lineHeight:1.15, letterSpacing:'-0.01em' }}>
                Public Library
              </h1>
              <p style={{ color:'rgba(255,255,255,0.85)', fontSize:'clamp(0.72rem,2.5vw,0.82rem)', margin:'4px 0 0', lineHeight:1.4 }}>
                Official documents & guidelines for logistics professionals.
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* ── Content card lifted over header ── */}
      <div style={{ maxWidth:720, margin:'-24px auto 0', padding:'0 12px 60px', position:'relative', zIndex:10, boxSizing:'border-box' }}>

        {/* Search */}
        <div style={{ background:'var(--bg-card, #fff)', borderRadius:14, boxShadow:'0 4px 20px rgba(0,0,0,0.10)', border:'1px solid var(--border-subtle)', padding:'10px 12px', marginBottom:12 }}>
          <div style={{ position:'relative' }}>
            <span className="material-symbols-outlined" style={{ position:'absolute', left:12, top:'50%', transform:'translateY(-50%)', color:'var(--text-muted)', fontSize:'1.15rem', lineHeight:1 }}>search</span>
            <input
              type="text"
              placeholder="Search documents..."
              autoComplete="off"
              value={searchTerm}
              onChange={e => setSearchTerm(e.target.value)}
              style={{
                width:'100%', boxSizing:'border-box',
                padding:'10px 10px 10px 40px',
                borderRadius:10, border:'1px solid var(--border-default)',
                fontSize:'0.9rem', outline:'none',
                background:'var(--bg-base)', color:'var(--text-primary)'
              }}
            />
          </div>
        </div>

        {/* Category filter */}
        <div style={{ marginBottom:16 }}>
          <CustomSelect
            value={categoryFilter}
            onChange={setCategoryFilter}
            options={CATEGORY_OPTIONS}
            icon="filter_list"
          />
        </div>

        {/* Document cards */}
        <div style={{ display:'flex', flexDirection:'column', gap:10 }}>
          {loading ? (
            <div style={{ textAlign:'center', padding:'48px 20px', color:'var(--text-muted)', fontSize:'0.82rem', fontWeight:600 }}>
              <span className="material-symbols-outlined" style={{ display:'block', fontSize:'2.2rem', marginBottom:10, opacity:0.5 }}>autorenew</span>
              Syncing library...
            </div>
          ) : filteredMaterials.map(m => {
            const color = fileColor(m.file_type)
            return (
              <div
                key={m.id}
                className="feed-card"
                style={{
                  padding:'12px', borderRadius:14,
                  display:'flex', alignItems:'center', gap:12,
                  width:'100%', boxSizing:'border-box',
                  overflow:'hidden'
                }}
              >
                {/* File type icon */}
                <div style={{
                  width:44, height:44, borderRadius:12,
                  background:`${color}18`,
                  border:`1.5px solid ${color}30`,
                  color, display:'flex', alignItems:'center',
                  justifyContent:'center', flexShrink:0
                }}>
                  <span className="material-symbols-outlined" style={{ fontSize:'1.45rem', lineHeight:1 }}>{getFileIcon(m.file_type)}</span>
                </div>

                {/* Text */}
                <div style={{ minWidth:0, flex:1, overflow:'hidden' }}>
                  <h3 style={{
                    fontSize:'clamp(0.78rem,2.8vw,0.88rem)', fontWeight:800,
                    color:'var(--text-primary)', margin:0, lineHeight:1.35,
                    display:'-webkit-box', WebkitLineClamp:2,
                    WebkitBoxOrient:'vertical', overflow:'hidden',
                    wordBreak:'break-word'
                  }}>
                    {m.title}
                  </h3>
                  <div style={{ display:'flex', gap:6, marginTop:4, flexWrap:'wrap', alignItems:'center' }}>
                    <span style={{
                      fontSize:'0.66rem', fontWeight:800, color,
                      textTransform:'uppercase', letterSpacing:'0.04em',
                      background:`${color}18`, padding:'2px 8px', borderRadius:20
                    }}>{m.category}</span>
                    <span style={{ fontSize:'0.66rem', color:'var(--text-muted)', fontWeight:500 }}>
                      {new Date(m.created_at).toLocaleDateString()}
                    </span>
                  </div>
                </div>

                {/* Download */}
                <a
                  href={m.file_url}
                  download={m.title}
                  style={{
                    display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', gap:2,
                    flexShrink:0, padding:'8px 10px', borderRadius:10,
                    background:'rgba(240,130,50,0.09)', textDecoration:'none', color:'var(--brand-primary)',
                    fontSize:'0.6rem', fontWeight:800, textTransform:'uppercase', letterSpacing:'0.03em',
                    minWidth:54, textAlign:'center'
                  }}
                >
                  <span className="material-symbols-outlined" style={{ fontSize:'1.2rem', lineHeight:1 }}>download</span>
                  Get
                </a>
              </div>
            )
          })}

          {!loading && filteredMaterials.length === 0 && (
            <div className="card" style={{ textAlign:'center', padding:'40px 20px', borderRadius:14 }}>
              <span className="material-symbols-outlined" style={{ display:'block', fontSize:'2.5rem', marginBottom:12, opacity:0.4 }}>search_off</span>
              <p style={{ color:'var(--text-muted)', fontSize:'0.82rem', fontWeight:600 }}>No documents found.</p>
            </div>
          )}
        </div>

        {/* Help CTA */}
        <div style={{
          marginTop:28,
          padding:'24px 16px',
          background:'linear-gradient(135deg, #f08232 0%, #e06920 100%)',
          borderRadius:20,
          textAlign:'center',
          color:'#fff',
          boxShadow:'0 6px 24px rgba(240,130,50,0.35)',
          width:'100%',
          boxSizing:'border-box',
          overflow:'hidden',
          position:'relative'
        }}>
          <div style={{ position:'absolute', top:-30, right:-30, width:120, height:120, background:'#fff', opacity:0.08, borderRadius:'50%', pointerEvents:'none' }} />
          <div style={{ position:'relative', zIndex:1 }}>
            <span className="material-symbols-outlined" style={{ fontSize:'2rem', display:'block', marginBottom:8, opacity:0.9 }}>support_agent</span>
            <h3 style={{ fontSize:'clamp(1rem,4vw,1.2rem)', fontWeight:900, margin:'0 0 8px', color:'#fff' }}>Need Assistance?</h3>
            <p style={{ fontSize:'clamp(0.78rem,2.5vw,0.85rem)', color:'rgba(255,255,255,0.9)', margin:'0 auto 18px', lineHeight:1.5, maxWidth:260 }}>
              Our secretariat can assist you with membership and licensing requirements.
            </p>
            <a
              href="mailto:info@cubag.org.gh"
              className="btn btn-white"
              style={{ display:'inline-flex', alignItems:'center', gap:6, width:'auto', padding:'0 24px', height:44, fontSize:'0.85rem', fontWeight:800, borderRadius:22 }}
            >
              <span className="material-symbols-outlined" style={{ fontSize:'1rem' }}>mail</span>
              Email Us
            </a>
          </div>
        </div>

      </div>
    </div>
  )
}
