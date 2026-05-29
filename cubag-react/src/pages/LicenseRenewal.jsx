import { useState, useEffect, useRef } from 'react'
import { Link } from 'react-router-dom'
import AppLayout from '../components/AppLayout'
import jsPDF from 'jspdf'
import html2canvas from 'html2canvas'
import useAutoRefresh from '../hooks/useAutoRefresh'

const API_URL = import.meta.env.VITE_API_URL

export default function LicenseRenewal() {
  const [history, setHistory] = useState([])
  const [historyLoading, setHistoryLoading] = useState(false)
  const [memberInfo, setMemberInfo] = useState(null)
  const [viewCert, setViewCert] = useState(null)
  const [generating, setGenerating] = useState(null) // { id, action }
  const [pdfPreviewUrl, setPdfPreviewUrl] = useState(null) // Blob URL for inline viewing
  const certRef = useRef()

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

  useAutoRefresh(fetchHistory, 60000)

  const generatePDF = async (action = 'download', rec) => {
    const id = rec.id || rec.payment_ref
    setGenerating({ id, action })
    setViewCert(rec)
    await new Promise(r => setTimeout(r, 800)) // Slightly longer delay for rendering
    try {
      const el = certRef.current
      // Optimized for A4 size with proper scaling
      const canvas = await html2canvas(el, { 
        scale: 3,
        useCORS: true, 
        backgroundColor: '#ffffff',
        logging: false,
        width: 794, // 210mm at 96 DPI
        height: 1123, // 297mm at 96 DPI
        windowWidth: 794,
        windowHeight: 1123
      })
      const imgData = canvas.toDataURL('image/png')
      
      const pdf = new jsPDF({
        orientation: 'portrait', 
        unit: 'mm', 
        format: 'a4',
        compress: true
      })

      const pdfW = pdf.internal.pageSize.getWidth()
      const pdfH = pdf.internal.pageSize.getHeight()
      
      pdf.addImage(imgData, 'PNG', 0, 0, pdfW, pdfH)
      
      const u = memberInfo || rec
      const filename = `CUBAG_License_${(u.company || 'Company').replace(/\s+/g, '_')}_${new Date().getFullYear()}.pdf`
      
      if (action === 'download') {
        pdf.save(filename)
      } else {
        setPdfPreviewUrl(imgData)
      }
    } catch (e) { 
      console.error(e)
    } finally { 
      setGenerating(null)
      setViewCert(null)
    }
  }

  const user = memberInfo || JSON.parse(localStorage.getItem('cubag_user') || '{}')
  const yr = new Date().getFullYear()
  const isActive = user.status === 'active'

  return (
    <AppLayout title="Receipts & Licenses">
      {(!isActive && !historyLoading && history.length === 0) ? (
        <div style={{ maxWidth: 600, margin: '40px auto', textAlign: 'center', padding: '60px 24px', background: 'var(--bg-surface)', borderRadius: 20, border: '1px solid var(--border-subtle)' }}>
          <div style={{ width: 80, height: 80, background: 'rgba(239,68,68,0.1)', color: '#ef4444', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 20px' }}>
            <span className="material-symbols-outlined" style={{ fontSize: '3rem' }}>lock</span>
          </div>
          <h2 style={{ fontSize: '1.5rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: 12 }}>Records Restricted</h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '0.95rem', lineHeight: 1.6, marginBottom: 24 }}>
            Your official receipts and membership licenses will appear here once your annual dues are settled and approved by the secretariat.
          </p>
          <div style={{ display: 'flex', gap: 12, justifyContent: 'center' }}>
            <button className="btn btn-primary" onClick={() => (window.location.href = '/payments')} style={{ height: 48, padding: '0 24px' }}>Make Payment</button>
            <button className="btn btn-outline" onClick={() => (window.location.href = '/dashboard')} style={{ height: 48, padding: '0 24px' }}>Back to Dashboard</button>
          </div>
        </div>
      ) : (
        <div style={{ maxWidth: 800, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>

        {/* Page Title removed as it is now in the header */}

        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {historyLoading ? (
            <div style={{ textAlign: 'center', padding: 40, color: 'var(--text-muted)', fontSize: '0.8rem' }}>Loading records...</div>
          ) : history.length === 0 ? (
            <div className="feed-card" style={{ textAlign: 'center', padding: '48px 24px', borderRadius: 12 }}>
              <span className="material-symbols-outlined" style={{ fontSize: '3rem', color: 'var(--text-muted)', display: 'block', marginBottom: 12 }}>history</span>
              <h3 style={{ marginBottom: 8, fontSize: '1.1rem' }}>No Records</h3>
              <p style={{ color: 'var(--text-secondary)', fontSize: '0.85rem', marginBottom: 20 }}>You don't have any receipts yet.</p>
              <Link to="/payments" className="btn btn-primary" style={{ height: 48, fontSize: '0.9rem' }}>Make Payment</Link>
            </div>
          ) : history.map((rec, i) => (
            <div key={i} className="feed-card" style={{ padding: '20px', borderRadius: 16, border: '1.5px solid var(--border-subtle)', background: 'var(--bg-surface)', transition: 'all 0.2s ease' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10, marginBottom: 16 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <div style={{ width: 40, height: 40, borderRadius: 10, background: 'var(--gradient-brand)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <span className="material-symbols-outlined" style={{ fontSize: '1.4rem' }}>badge</span>
                  </div>
                  <div>
                    <div style={{ fontWeight: 900, fontSize: '1rem', color: 'var(--text-primary)' }}>Membership Record</div>
                  </div>
                </div>
                <span style={{
                  padding: '5px 12px', borderRadius: 8, fontSize: '0.65rem', fontWeight: 900, flexShrink: 0, textTransform: 'uppercase', letterSpacing: '0.05em',
                  background: rec.approved ? 'rgba(16,185,129,0.12)' : rec.status === 'suspended' ? 'rgba(239,68,68,0.12)' : 'rgba(245,158,11,0.12)',
                  color: rec.approved ? '#10b981' : rec.status === 'suspended' ? '#ef4444' : '#f59e0b',
                  border: `1px solid ${rec.approved ? '#10b98133' : rec.status === 'suspended' ? '#ef444433' : '#f59e0b33'}`
                }}>
                  {rec.approved ? 'Active' : rec.status === 'suspended' ? 'Suspended' : 'In Approval'}
                </span>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 16 }}>
                {[
                  { label: 'License Number', val: rec.license_number || (rec.approved ? 'Validating...' : 'Pending'), icon: 'verified' },
                  { label: 'Organization', val: rec.company, icon: 'business' },
                  { label: 'Port of Operation', val: rec.port_of_operation, icon: 'location_on' }
                ].map(({ label, val, icon }) => (
                  <div key={label} style={{ padding: '12px 14px', background: 'var(--bg-base)', borderRadius: 10, border: '1.5px solid var(--border-subtle)', display: 'flex', alignItems: 'center', gap: 12 }}>
                    <div style={{ width: 34, height: 34, borderRadius: 8, background: 'rgba(240,130,50,0.1)', color: 'var(--brand-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                      <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>{icon}</span>
                    </div>
                    <div style={{ minWidth: 0 }}>
                      <div style={{ fontSize: '0.65rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, letterSpacing: '0.02em' }}>{label}</div>
                      <div style={{ fontSize: '0.9rem', fontWeight: 800, color: 'var(--text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{val || '—'}</div>
                    </div>
                  </div>
                ))}
              </div>

              {rec.approved ? (
                <div style={{ display: 'flex', gap: 8 }}>
                  <button
                    className="btn btn-outline btn-sm"
                    style={{ flex: 1, height: 40, fontSize: '0.75rem', padding: '0 8px' }}
                    onClick={() => generatePDF('view', rec)}
                    disabled={generating && generating.id === (rec.id || rec.payment_ref)}
                  >
                    <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>
                      {generating?.id === (rec.id || rec.payment_ref) && generating?.action === 'view' ? 'sync' : 'visibility'}
                    </span>
                    {generating?.id === (rec.id || rec.payment_ref) && generating?.action === 'view' ? 'Viewing...' : 'View'}
                  </button>
                  <button
                    className="btn btn-primary btn-sm"
                    style={{ flex: 1, height: 40, fontSize: '0.75rem', padding: '0 8px' }}
                    onClick={() => generatePDF('download', rec)}
                    disabled={generating && generating.id === (rec.id || rec.payment_ref)}
                  >
                    <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>
                      {generating?.id === (rec.id || rec.payment_ref) && generating?.action === 'download' ? 'sync' : 'download'}
                    </span>
                    {generating?.id === (rec.id || rec.payment_ref) && generating?.action === 'download' ? 'Generating...' : 'Download'}
                  </button>
                </div>
              ) : (
                <div style={{ textAlign: 'center', padding: 8, background: 'rgba(245,158,11,0.08)', borderRadius: 8, fontSize: '0.75rem', color: '#f59e0b' }}>
                  Awaiting admin approval...
                </div>
              )}
            </div>
          ))}
        </div>

        <div style={{ marginTop: 24, textAlign: 'center' }}>
          <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Need help? <Link to="/engagement" style={{ color: 'var(--brand-primary)', textDecoration: 'none', fontWeight: 600 }}>Contact Support</Link></p>
        </div>
      </div>
    )}

      {/* ── Inline Viewer Modal ────────────────────────────────────────── */}
      {pdfPreviewUrl && (
        <div style={{
          position: 'fixed', inset: 0, zIndex: 9999, background: 'rgba(0,0,0,0.85)',
          display: 'flex', flexDirection: 'column', padding: '16px 16px 80px'
        }}>
          <div style={{ flex: 1, overflow: 'auto', background: '#fff', borderRadius: 12, display: 'flex', justifyContent: 'center', padding: '20px 0', boxShadow: '0 10px 40px rgba(0,0,0,0.3)' }}>
            <img 
              src={pdfPreviewUrl} 
              alt="Certificate Preview"
              style={{ width: '100%', maxWidth: '800px', height: 'auto', objectFit: 'contain', display: 'block', margin: '0 auto' }}
            />
          </div>
          
          <div style={{ position: 'fixed', bottom: 24, left: '50%', transform: 'translateX(-50%)', zIndex: 10000 }}>
            <button 
              className="btn btn-primary" 
              onClick={() => setPdfPreviewUrl(null)} 
              style={{ 
                borderRadius: 30, padding: '14px 28px', display: 'flex', alignItems: 'center', gap: 8, 
                boxShadow: '0 8px 30px rgba(0,0,0,0.4)', fontSize: '1rem', fontWeight: 800
              }}
            >
              <span className="material-symbols-outlined">close</span> Close Preview
            </button>
          </div>
        </div>
      )}

      {viewCert && (
        <div style={{ position: 'fixed', top: '-9999px', left: '-9999px', zIndex: -1 }}>
          <div ref={certRef} style={{
            width: '794px',  // 210mm at 96dpi
            height: '1123px', // 297mm at 96dpi
            background: '#ffffff', 
            fontFamily: "'Times New Roman', Georgia, serif",
            padding: 0, 
            boxSizing: 'border-box', 
            position: 'relative', 
            color: '#111',
            overflow: 'hidden'
          }}>

            {/* ── Decorative borders ── */}
            <div style={{ position: 'absolute', inset: '30px', border: '3px solid #f08232', zIndex: 0 }} />
            <div style={{ position: 'absolute', inset: '40px', border: '1.5px solid #333', zIndex: 0 }} />
            <div style={{ position: 'absolute', inset: '50px', border: '0.5px solid #f08232', zIndex: 0 }} />

            {/* ── Diagonal watermark ── */}
            <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 0, pointerEvents: 'none' }}>
              <span style={{ fontSize: '120px', fontWeight: 900, color: '#f08232', opacity: 0.03, transform: 'rotate(-35deg)', letterSpacing: -5 }}>CUBAG</span>
            </div>

            <div style={{ 
              position: 'relative', 
              zIndex: 2, 
              padding: '80px 70px',
              height: '100%',
              boxSizing: 'border-box', 
              display: 'flex', 
              flexDirection: 'column',
              justifyContent: 'space-between',
              background: 'transparent'
            }}>

              {/* ══ HEADER ═════════════════════════════════════════════════ */}
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '15px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '15px' }}>
                    <img src="/logo.jpeg" alt="CUBAG" crossOrigin="anonymous"
                      style={{ width: '60px', height: '60px', borderRadius: '8px', objectFit: 'cover', border: '2px solid #f08232' }} />
                    <div>
                      <div style={{ fontSize: '18px', fontWeight: 800, color: '#f08232', letterSpacing: 0.5, lineHeight: 1 }}>CUBAG</div>
                      <div style={{ fontSize: '10px', color: '#555', letterSpacing: 0.3, lineHeight: 1.2, maxWidth: '180px', marginTop: '4px' }}>
                        Customs Brokers &amp; Agents<br/>Association of Ghana
                      </div>
                    </div>
                  </div>

                  <div style={{ textAlign: 'center' }}>
                    <img src="/ghana.jpg" alt="Ghana Coat of Arms" crossOrigin="anonymous"
                      style={{ width: '65px', height: '65px', objectFit: 'contain' }} />
                    <div style={{ fontSize: '8px', color: '#444', fontWeight: 700, letterSpacing: 1, textTransform: 'uppercase', marginTop: '4px' }}>
                      Republic of Ghana
                    </div>
                  </div>
                </div>

                <div style={{ background: '#f08232', padding: '6px 0', textAlign: 'center', marginBottom: '4px' }}>
                  <div style={{ color: '#fff', fontSize: '9px', letterSpacing: 2, fontWeight: 700, textTransform: 'uppercase' }}>
                    Customs Brokers &amp; Agents Association of Ghana
                  </div>
                </div>
                <div style={{ background: '#333', height: '2px', marginBottom: '2px' }} />
                <div style={{ background: '#f08232', height: '1px', marginBottom: '20px' }} />

                <div style={{ textAlign: 'center', fontSize: '9px', color: '#666', letterSpacing: 1, marginBottom: '30px', textTransform: 'uppercase', fontWeight: 600 }}>
                  Accredited by the Ghana Revenue Authority (GRA) &bull; Licensed under Customs Act 2015 (Act 891)
                </div>

                <div style={{ textAlign: 'center', marginBottom: '20px' }}>
                  <div style={{ fontSize: '11px', letterSpacing: 4, color: '#888', textTransform: 'uppercase', marginBottom: '5px' }}>Certificate of</div>
                  <div style={{ fontSize: '32px', fontWeight: 700, color: '#f08232', letterSpacing: 1, lineHeight: 1 }}>
                    Active Membership
                  </div>
                  <div style={{ width: '80px', height: '2px', background: '#333', margin: '15px auto 10px' }} />
                  <div style={{ fontSize: '10px', color: '#111', fontWeight: 700, letterSpacing: 2, textTransform: 'uppercase' }}>
                    &amp; Licensed Customs Broker
                  </div>
                </div>

                <div style={{ textAlign: 'center', fontSize: '12px', color: '#555', margin: '20px 0 10px', fontStyle: 'italic' }}>
                  This is to certify that
                </div>

                <div style={{ textAlign: 'center', marginBottom: '10px' }}>
                  <div style={{
                    fontSize: '24px', fontWeight: 700, color: '#111',
                    borderBottom: '2px solid #f08232', display: 'inline-block',
                    paddingBottom: '5px', minWidth: '300px', letterSpacing: 0.5
                  }}>
                    {user.company || viewCert.company || 'Company Name'}
                  </div>
                </div>
                <div style={{ textAlign: 'center', fontSize: '12px', color: '#555', marginBottom: '25px', fontStyle: 'italic' }}>
                  represented by <strong style={{ fontStyle: 'normal', color: '#222' }}>{user.name || viewCert.name || 'Member Name'}</strong>
                </div>

                <div style={{ textAlign: 'center', fontSize: '11px', color: '#444', lineHeight: 1.7, marginBottom: '30px', maxWidth: '500px', margin: '0 auto 30px' }}>
                  is hereby recognised as an <strong>Active Member and Licensed Customs Broker</strong> of the
                  Customs Brokers &amp; Agents Association of Ghana (CUBAG), duly authorised to operate as a
                  customs clearing agent within the jurisdiction of Ghana, in accordance with the
                  Customs Act, 2015 (Act 891) and all applicable GRA regulations.
                </div>

                <div style={{
                  background: '#fcfcfc', border: '1px solid #eee', borderRadius: '4px',
                  padding: '15px 20px', marginBottom: '30px',
                  display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px 30px'
                }}>
                  {[
                    ['License Number', (user.license_number && user.status === 'active') ? user.license_number : (viewCert.approved ? (viewCert.license_number || 'VALIDATING...') : 'AWAITING PAYMENT')],
                    ['Member Type', user.member_type || viewCert.member_type || '—'],
                    ['Port of Operation', user.port_of_operation || viewCert.port_of_operation || '—'],
                    ['Valid Period', `January ${yr} – December ${yr}`],
                  ].map(([label, val]) => (
                    <div key={label}>
                      <div style={{ fontSize: '8px', color: '#f08232', fontWeight: 800, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: '2px' }}>{label}</div>
                      <div style={{ fontSize: '11px', fontWeight: 700, color: '#111' }}>{val}</div>
                    </div>
                  ))}
                </div>
              </div>

              {/* ══ FOOTER ═════════════════════════════════════════════════ */}
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: '25px' }}>
                  <div style={{ textAlign: 'center', width: '150px' }}>
                    <div style={{ fontSize: '18px', fontFamily: "'Brush Script MT', cursive", color: '#333', marginBottom: '4px' }}>E. Kwame</div>
                    <div style={{ borderTop: '1px solid #222', paddingTop: '8px' }}>
                      <div style={{ fontSize: '10px', fontWeight: 700 }}>Executive Secretary</div>
                      <div style={{ fontSize: '8px', color: '#777', fontStyle: 'italic' }}>CUBAG Secretariat</div>
                    </div>
                  </div>

                  <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                    <svg viewBox="0 0 200 200" width="80" height="80" style={{ opacity: 0.9 }}>
                      <circle cx="100" cy="100" r="92" fill="none" stroke="#f08232" strokeWidth="4" strokeDasharray="8 3"/>
                      <circle cx="100" cy="100" r="80" fill="none" stroke="#f08232" strokeWidth="1.5"/>
                      <text textAnchor="middle" x="100" y="48" fontSize="10" fontWeight="800" fill="#f08232" fontFamily="serif" letterSpacing="2">✦ CUBAG ✦</text>
                      <text textAnchor="middle" x="100" y="100" fontSize="14" fontWeight="900" fill="#f08232" fontFamily="serif">OFFICIAL</text>
                      <text textAnchor="middle" x="100" y="118" fontSize="8" fontWeight="600" fill="#f08232" fontFamily="serif">SEAL</text>
                      <text textAnchor="middle" x="100" y="165" fontSize="9" fontWeight="700" fill="#f08232" fontFamily="serif" letterSpacing="1">GHANA</text>
                    </svg>
                  </div>

                  <div style={{ textAlign: 'center', width: '150px' }}>
                    <div style={{ fontSize: '18px', fontFamily: "'Brush Script MT', cursive", color: '#333', marginBottom: '4px' }}>A. Mensah</div>
                    <div style={{ borderTop: '1px solid #222', paddingTop: '8px' }}>
                      <div style={{ fontSize: '10px', fontWeight: 700 }}>National President</div>
                      <div style={{ fontSize: '8px', color: '#777', fontStyle: 'italic' }}>CUBAG National Executive</div>
                    </div>
                  </div>
                </div>

                <div style={{ textAlign: 'center', fontSize: '9px', color: '#999', marginBottom: '15px', letterSpacing: 0.5 }}>
                  Issued on <strong style={{ color: '#222' }}>{new Date().toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' })}</strong>
                  &nbsp;&nbsp;&bull;&nbsp;&nbsp;
                  Certificate No. <strong style={{ color: '#222' }}>CUBAG/{yr}/{String(user.id || '001').padStart(4, '0')}</strong>
                </div>

                <div style={{ background: '#f08232', padding: '6px 0', textAlign: 'center' }}>
                  <div style={{ color: '#fff', fontSize: '8px', letterSpacing: 1.5, fontWeight: 600 }}>
                    FREEDOM AND JUSTICE &bull; REPUBLIC OF GHANA &bull; P.O. BOX TEMA &bull; WWW.CUBAG.GH
                  </div>
                </div>
              </div>

            </div>
          </div>
        </div>
      )}
    </AppLayout>
  )
}
