import { useState, useEffect, useRef } from 'react'
import { Link } from 'react-router-dom'
import AppLayout from '../components/AppLayout'
import jsPDF from 'jspdf'
import html2canvas from 'html2canvas'

const API_URL = import.meta.env.VITE_API_URL

export default function LicenseRenewal() {
  const [history, setHistory] = useState([])
  const [historyLoading, setHistoryLoading] = useState(false)
  const [memberInfo, setMemberInfo] = useState(null)
  const [viewCert, setViewCert] = useState(null)
  const [generating, setGenerating] = useState(null) // ID of record being generated
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

  useEffect(() => { fetchHistory() }, [])

  const generatePDF = async (action = 'download', rec) => {
    setGenerating(rec.id || rec.payment_ref)
    setViewCert(rec)
    await new Promise(r => setTimeout(r, 600))
    try {
      const el = certRef.current
      // Optimized for A4 size with proper scaling
      const canvas = await html2canvas(el, { 
        scale: 3, // Higher scale for better quality
        useCORS: true, 
        backgroundColor: '#ffffff',
        logging: false,
        windowWidth: el.scrollWidth,
        windowHeight: el.scrollHeight
      })
      const imgData = canvas.toDataURL('image/png')
      
      // A4 dimensions in mm: 210 x 297
      const pdf = new jsPDF({ 
        orientation: 'portrait', 
        unit: 'mm', 
        format: 'a4',
        compress: true
      })
      
      const pdfW = pdf.internal.pageSize.getWidth() // 210mm
      const pdfH = pdf.internal.pageSize.getHeight() // 297mm
      
      // Calculate image dimensions to fit perfectly within A4
      const imgW = pdfW
      const imgH = (canvas.height * pdfW) / canvas.width
      
      // Center vertically if needed
      const yOffset = imgH < pdfH ? (pdfH - imgH) / 2 : 0
      
      pdf.addImage(imgData, 'PNG', 0, yOffset, imgW, imgH)
      
      const u = memberInfo || rec
      const filename = `CUBAG_License_${(u.company || 'Company').replace(/\s+/g, '_')}_${new Date().getFullYear()}.pdf`
      
      if (action === 'download') {
        pdf.save(filename)
        setViewCert(null)
      } else {
        const blob = pdf.output('blob')
        window.open(URL.createObjectURL(blob), '_blank')
        setViewCert(null)
      }
    } catch (e) { 
      console.error(e)
    } finally { 
      setGenerating(null)
    }
  }

  const user = memberInfo || {}
  const yr = new Date().getFullYear()

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
                  <div style={{ fontWeight: 800, fontSize: '1rem', marginBottom: 4 }}>License / Membership Record</div>
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
                    <div style={{ fontSize: '0.88rem', fontWeight: 600 }}>{val || '—'}</div>
                  </div>
                ))}
              </div>

              {rec.approved ? (
                <div style={{ display: 'flex', gap: 10 }}>
                  <button className="btn btn-outline" style={{ flex: 1, justifyContent: 'center', display: 'flex', alignItems: 'center', gap: 8 }}
                    onClick={() => generatePDF('view', rec)} disabled={generating === (rec.id || rec.payment_ref)}>
                    <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>visibility</span>
                    {generating === (rec.id || rec.payment_ref) ? 'Generating...' : 'View Certificate'}
                  </button>
                  <button className="btn btn-primary" style={{ flex: 1, justifyContent: 'center', display: 'flex', alignItems: 'center', gap: 8 }}
                    onClick={() => generatePDF('download', rec)} disabled={generating === (rec.id || rec.payment_ref)}>
                    <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>download</span>
                    {generating === (rec.id || rec.payment_ref) ? 'Generating...' : 'Download Certificate'}
                  </button>
                </div>
              ) : (
                <div style={{ textAlign: 'center', padding: 10, background: 'rgba(245,158,11,0.08)', borderRadius: 10, fontSize: '0.85rem', color: '#f59e0b' }}>
                  <span className="material-symbols-outlined" style={{ verticalAlign: 'middle', fontSize: '1rem', marginRight: 4 }}>schedule</span>
                  Awaiting admin approval. Certificate available once approved.
                </div>
              )}
            </div>
          ))}
        </div>

        <div style={{ marginTop: 24, textAlign: 'center' }}>
          <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Need help? <Link to="/engagement" style={{ color: 'var(--brand-primary)', textDecoration: 'none', fontWeight: 600 }}>Contact Support</Link></p>
        </div>
      </div>

      {/* ═══════════════════════════════════════════════════════════════════
          HIDDEN CERTIFICATE DOM — Optimized for A4 PDF output
         ═══════════════════════════════════════════════════════════════════ */}
      {viewCert && (
        <div style={{ position: 'fixed', top: '-9999px', left: '-9999px', zIndex: -1 }}>
          <div ref={certRef} style={{
            width: '210mm',  // Standard A4 width
            minHeight: '297mm', // Standard A4 height
            background: '#ffffff', 
            fontFamily: "'Times New Roman', Georgia, serif",
            padding: 0, 
            boxSizing: 'border-box', 
            position: 'relative', 
            color: '#111',
            overflow: 'visible',
            pageBreakAfter: 'avoid',
            pageBreakInside: 'avoid'
          }}>

            {/* ── Decorative borders with proper spacing ───────────────────────────────────────── */}
            <div style={{ position: 'absolute', inset: '8mm', border: '3px solid #f08232', zIndex: 0 }} />
            <div style={{ position: 'absolute', inset: '11mm', border: '1.5px solid #333', zIndex: 0 }} />
            <div style={{ position: 'absolute', inset: '14mm', border: '0.5px solid #f08232', zIndex: 0 }} />

            {/* ── Diagonal watermark ───────────────────────────────────────── */}
            <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 0, pointerEvents: 'none' }}>
              <span style={{ fontSize: '80px', fontWeight: 900, color: '#f08232', opacity: 0.05, transform: 'rotate(-38deg)', letterSpacing: -6 }}>CUBAG</span>
            </div>

            {/* ── Corner ornaments ──────────────────────────────────────────── */}
            {[
              { top: '8mm', left: '8mm', transform: 'none' },
              { top: '8mm', right: '8mm', transform: 'scaleX(-1)' },
              { bottom: '8mm', left: '8mm', transform: 'scaleY(-1)' },
              { bottom: '8mm', right: '8mm', transform: 'scale(-1)' }
            ].map((style, i) => (
              <div key={i} style={{ 
                position: 'absolute', 
                ...style, 
                width: '30px', 
                height: '30px', 
                borderTop: '2px solid #333', 
                borderLeft: '2px solid #333', 
                zIndex: 1 
              }} />
            ))}

            <div style={{ 
              position: 'relative', 
              zIndex: 2, 
              padding: '24mm 22mm', 
              minHeight: '297mm',
              boxSizing: 'border-box', 
              display: 'flex', 
              flexDirection: 'column',
              justifyContent: 'space-between'
            }}>

              {/* ══ HEADER — CUBAG logo left, Ghana emblem right ════════════ */}
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '4mm' }}>
                  {/* Left — CUBAG Logo + Name */}
                  <div style={{ display: 'flex', alignItems: 'center', gap: '5mm' }}>
                    <img src="/logo.jpeg" alt="CUBAG" crossOrigin="anonymous"
                      style={{ width: '45px', height: '45px', borderRadius: '6px', objectFit: 'cover', border: '1.5px solid #f08232' }} />
                    <div>
                      <div style={{ fontSize: '11px', fontWeight: 800, color: '#f08232', letterSpacing: 0.5, lineHeight: 1.2 }}>CUBAG</div>
                      <div style={{ fontSize: '7px', color: '#555', letterSpacing: 0.3, lineHeight: 1.2, maxWidth: '130px' }}>
                        Customs Brokers &amp; Agents<br/>Association of Ghana
                      </div>
                    </div>
                  </div>

                  {/* Right — Ghana Coat of Arms */}
                  <div style={{ textAlign: 'center' }}>
                    <img src="/ghana.jpg" alt="Ghana Coat of Arms" crossOrigin="anonymous"
                      style={{ width: '50px', height: '50px', objectFit: 'contain' }} />
                    <div style={{ fontSize: '6px', color: '#444', fontWeight: 700, letterSpacing: 1, textTransform: 'uppercase', marginTop: '2px' }}>
                      Republic of Ghana
                    </div>
                  </div>
                </div>

                {/* ══ Green & Gold bands ══════════════════════════════════════ */}
                <div style={{ background: '#f08232', padding: '3px 0', textAlign: 'center', marginBottom: '2px' }}>
                  <div style={{ color: '#fff', fontSize: '7px', letterSpacing: 2, fontWeight: 700, textTransform: 'uppercase' }}>
                    Customs Brokers &amp; Agents Association of Ghana
                  </div>
                </div>
                <div style={{ background: '#333', height: '1.5px', marginBottom: '1px' }} />
                <div style={{ background: '#f08232', height: '1px', marginBottom: '6mm' }} />

                {/* ══ Accreditation line ══════════════════════════════════════ */}
                <div style={{ textAlign: 'center', fontSize: '6px', color: '#777', letterSpacing: 1, marginBottom: '8mm', textTransform: 'uppercase' }}>
                  Accredited by the Ghana Revenue Authority (GRA) &bull; Licensed under Customs Act 2015 (Act 891)
                </div>

                {/* ══ CERTIFICATE OF title ════════════════════════════════════ */}
                <div style={{ textAlign: 'center', marginBottom: '5mm' }}>
                  <div style={{ fontSize: '8px', letterSpacing: 4, color: '#888', textTransform: 'uppercase', marginBottom: '1mm' }}>Certificate of</div>
                  <div style={{ fontSize: '24px', fontWeight: 700, color: '#f08232', letterSpacing: 1, lineHeight: 1.2 }}>
                    Active Membership
                  </div>
                  <div style={{ width: '60px', height: '1.5px', background: '#333', margin: '5mm auto 3mm' }} />
                  <div style={{ fontSize: '8px', color: '#111', fontWeight: 700, letterSpacing: 2, textTransform: 'uppercase' }}>
                    &amp; Licensed Customs Broker
                  </div>
                </div>

                {/* ══ "This is to certify…" ═══════════════════════════════════ */}
                <div style={{ textAlign: 'center', fontSize: '9px', color: '#555', margin: '6mm 0 4mm', fontStyle: 'italic' }}>
                  This is to certify that
                </div>

                {/* ══ Company name ═════════════════════════════════════════════ */}
                <div style={{ textAlign: 'center', marginBottom: '3mm' }}>
                  <div style={{
                    fontSize: '20px', fontWeight: 700, color: '#111',
                    borderBottom: '1.5px solid #f08232', display: 'inline-block',
                    paddingBottom: '2mm', minWidth: '220px', letterSpacing: 0.5
                  }}>
                    {user.company || viewCert.company || 'Company Name'}
                  </div>
                </div>
                <div style={{ textAlign: 'center', fontSize: '9px', color: '#555', marginBottom: '6mm', fontStyle: 'italic' }}>
                  represented by <strong style={{ fontStyle: 'normal', color: '#222' }}>{user.name || viewCert.name || 'Member Name'}</strong>
                </div>

                {/* ══ Body paragraph ══════════════════════════════════════════ */}
                <div style={{ textAlign: 'center', fontSize: '9px', color: '#444', lineHeight: 1.6, marginBottom: '8mm', maxWidth: '450px', margin: '0 auto 8mm', padding: '0 5px' }}>
                  is hereby recognised as an <strong>Active Member and Licensed Customs Broker</strong> of the
                  Customs Brokers &amp; Agents Association of Ghana (CUBAG), duly authorised to operate as a
                  customs clearing agent within the jurisdiction of Ghana, in accordance with the
                  Customs Act, 2015 (Act 891) and all applicable GRA regulations.
                </div>

                {/* ══ Details table ═══════════════════════════════════════════ */}
                <div style={{
                  background: '#fafafa', border: '0.5px solid #eee', borderRadius: '3px',
                  padding: '8px 12px', marginBottom: '8mm',
                  display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '5px 15px'
                }}>
                  {[
                    ['License Number', user.license_number || `CUBAG-${yr}-${String(user.id || '001').padStart(4, '0')}`],
                    ['Member Type', user.member_type || viewCert.member_type || '—'],
                    ['Port of Operation', user.port_of_operation || viewCert.port_of_operation || '—'],
                    ['Valid Period', `January ${yr} – December ${yr}`],
                  ].map(([label, val]) => (
                    <div key={label}>
                      <div style={{ fontSize: '6px', color: '#f08232', fontWeight: 800, textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: '1px' }}>{label}</div>
                      <div style={{ fontSize: '9px', fontWeight: 600, color: '#111' }}>{val}</div>
                    </div>
                  ))}
                </div>
              </div>

              {/* ══ Signatures & Stamps ═════════════════════════════════════ */}
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: '6mm', padding: '0 5px' }}>

                  {/* Signature left — Executive Secretary */}
                  <div style={{ textAlign: 'center', width: '120px' }}>
                    <div style={{ fontSize: '13px', fontFamily: "'Brush Script MT', cursive", color: '#333', marginBottom: '1px' }}>E. Kwame</div>
                    <div style={{ borderTop: '0.5px solid #222', paddingTop: '2mm' }}>
                      <div style={{ fontSize: '8px', fontWeight: 700 }}>Executive Secretary</div>
                      <div style={{ fontSize: '6px', color: '#777', fontStyle: 'italic' }}>CUBAG Secretariat</div>
                    </div>
                  </div>

                  {/* Centre stamps - Scaled down for A4 */}
                  <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '2mm' }}>
                    {/* CUBAG Official Stamp */}
                    <svg viewBox="0 0 200 200" width="60" height="60" style={{ opacity: 0.85 }}>
                      <circle cx="100" cy="100" r="92" fill="none" stroke="#f08232" strokeWidth="4" strokeDasharray="8 3"/>
                      <circle cx="100" cy="100" r="80" fill="none" stroke="#f08232" strokeWidth="1.5"/>
                      <text textAnchor="middle" x="100" y="48" fontSize="10" fontWeight="800" fill="#f08232" fontFamily="serif" letterSpacing="2">✦ CUBAG ✦</text>
                      <text textAnchor="middle" x="100" y="100" fontSize="14" fontWeight="900" fill="#f08232" fontFamily="serif">OFFICIAL</text>
                      <text textAnchor="middle" x="100" y="118" fontSize="8" fontWeight="600" fill="#f08232" fontFamily="serif">SEAL</text>
                      <text textAnchor="middle" x="100" y="165" fontSize="9" fontWeight="700" fill="#f08232" fontFamily="serif" letterSpacing="1">GHANA</text>
                    </svg>
                  </div>

                  {/* Signature right — President */}
                  <div style={{ textAlign: 'center', width: '120px' }}>
                    <div style={{ fontSize: '13px', fontFamily: "'Brush Script MT', cursive", color: '#333', marginBottom: '1px' }}>A. Mensah</div>
                    <div style={{ borderTop: '0.5px solid #222', paddingTop: '2mm' }}>
                      <div style={{ fontSize: '8px', fontWeight: 700 }}>National President</div>
                      <div style={{ fontSize: '6px', color: '#777', fontStyle: 'italic' }}>CUBAG National Executive</div>
                    </div>
                  </div>
                </div>

                {/* ══ Issue date ══════════════════════════════════════════════ */}
                <div style={{ textAlign: 'center', fontSize: '7px', color: '#999', marginBottom: '5mm', letterSpacing: 0.5 }}>
                  Issued on <strong style={{ color: '#222' }}>{new Date().toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' })}</strong>
                  &nbsp;&nbsp;&bull;&nbsp;&nbsp;
                  Certificate No. <strong style={{ color: '#222' }}>CUBAG/{yr}/{String(user.id || '001').padStart(4, '0')}</strong>
                </div>

                {/* ══ Footer band ═════════════════════════════════════════════ */}
                <div style={{ background: '#f08232', padding: '3px 0', textAlign: 'center' }}>
                  <div style={{ color: '#fff', fontSize: '6px', letterSpacing: 1.5, fontWeight: 600 }}>
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
