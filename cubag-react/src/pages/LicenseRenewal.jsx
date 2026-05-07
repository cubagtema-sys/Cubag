import { useState, useEffect, useRef } from 'react'
import { Link } from 'react-router-dom'
import AppLayout from '../components/AppLayout'
import jsPDF from 'jspdf'
import html2canvas from 'html2canvas'

const API_URL = import.meta.env.VITE_API_URL

/* ─── Ghana Coat of Arms SVG (simplified official emblem) ─────────────────── */
const GhanaEmblem = () => (
  <svg viewBox="0 0 120 120" width="64" height="64" xmlns="http://www.w3.org/2000/svg">
    <circle cx="60" cy="60" r="58" fill="#006B3F" stroke="#FCD116" strokeWidth="3"/>
    <circle cx="60" cy="60" r="48" fill="none" stroke="#FCD116" strokeWidth="1.5"/>
    {/* Shield */}
    <path d="M60,25 L85,35 L85,65 Q85,85 60,95 Q35,85 35,65 L35,35 Z" fill="#fff" stroke="#CE1126" strokeWidth="1.5"/>
    {/* Quadrants */}
    <line x1="60" y1="25" x2="60" y2="95" stroke="#CE1126" strokeWidth="1.2"/>
    <line x1="35" y1="60" x2="85" y2="60" stroke="#CE1126" strokeWidth="1.2"/>
    {/* Top-left: Castle */}
    <rect x="41" y="32" width="12" height="10" fill="#CE1126"/>
    <rect x="43" y="30" width="3" height="3" fill="#CE1126"/>
    <rect x="48" y="30" width="3" height="3" fill="#CE1126"/>
    {/* Top-right: Sword */}
    <line x1="72" y1="30" x2="72" y2="48" stroke="#FCD116" strokeWidth="3"/>
    <path d="M70,30 L74,30 L72,26 Z" fill="#FCD116"/>
    {/* Bottom-left: Cocoa */}
    <circle cx="47" cy="72" r="6" fill="#006B3F"/>
    <ellipse cx="47" cy="72" rx="4" ry="7" fill="#228B22"/>
    {/* Bottom-right: Black Star */}
    <polygon points="72,64 73.5,69 78.5,69 74.5,72 76,77 72,74 68,77 69.5,72 65.5,69 70.5,69" fill="#FCD116"/>
    {/* Bottom text */}
    <text x="60" y="112" textAnchor="middle" fontSize="7" fill="#FCD116" fontWeight="bold" fontFamily="serif">GHANA</text>
  </svg>
)

/* ─── Circular Stamp ───────────────────────────────────────────────────────── */
const Stamp = ({ text = 'CERTIFIED', color = '#006B3F', size = 110 }) => (
  <svg viewBox="0 0 200 200" width={size} height={size}>
    <circle cx="100" cy="100" r="94" fill="none" stroke={color} strokeWidth="5" strokeDasharray="6 3" opacity="0.85"/>
    <circle cx="100" cy="100" r="80" fill="none" stroke={color} strokeWidth="2" opacity="0.6"/>
    <circle cx="100" cy="100" r="50" fill="rgba(0,107,63,0.07)" stroke={color} strokeWidth="2" opacity="0.5"/>
    <text fontSize="15" fontWeight="800" fill={color} fontFamily="serif" opacity="0.9">
      <textPath href="#circleTop" startOffset="15%">{text}</textPath>
    </text>
    <defs>
      <path id="circleTop" d="M 100,100 m -75,0 a 75,75 0 1,1 150,0 a 75,75 0 1,1 -150,0"/>
    </defs>
    <text x="100" y="108" textAnchor="middle" fontSize="11" fill={color} fontWeight="700" fontFamily="serif" opacity="0.85">
      CUSTOMS BROKERS
    </text>
    <text x="100" y="122" textAnchor="middle" fontSize="10" fill={color} fontWeight="600" fontFamily="serif" opacity="0.75">
      GHANA 🇬🇭
    </text>
  </svg>
)

export default function LicenseRenewal() {
  const [history, setHistory] = useState([])
  const [historyLoading, setHistoryLoading] = useState(false)
  const [memberInfo, setMemberInfo] = useState(null)
  const [platformFees, setPlatformFees] = useState({ renewalFee: '1500.00' })
  const [platformSettings, setPlatformSettings] = useState({
    momoAccounts: [{ network: 'MTN', number: '0244000000' }],
    bankAccounts: [{ bankName: 'GCB Bank', accountName: 'CUBAG National Account', accountNumber: '1011130023456', branch: 'Tema Main' }]
  })
  const [viewCert, setViewCert] = useState(null)   // record being viewed
  const [generating, setGenerating] = useState(false)
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

  const fetchSettings = async () => {
    try {
      const [feesRes, settingsRes] = await Promise.all([
        fetch(`${API_URL}/settings/cubag_fees`),
        fetch(`${API_URL}/settings/cubag_payment_settings_v2`)
      ])
      if (feesRes.ok) { const f = await feesRes.json(); if (f.renewalFee) setPlatformFees(f) }
      if (settingsRes.ok) { const s = await settingsRes.json(); if (s.momoAccounts) setPlatformSettings(s) }
    } catch {}
  }

  useEffect(() => { fetchHistory(); fetchSettings() }, [])

  /* ── Generate PDF from the hidden cert DOM ────────────────────────────── */
  const generatePDF = async (action = 'download', rec) => {
    setGenerating(true)
    setViewCert(rec)

    // wait for DOM render
    await new Promise(r => setTimeout(r, 400))

    try {
      const el = certRef.current
      const canvas = await html2canvas(el, { scale: 2, useCORS: true, backgroundColor: '#fff' })
      const imgData = canvas.toDataURL('image/png')
      const pdf = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' })
      const pdfW = pdf.internal.pageSize.getWidth()
      const pdfH = (canvas.height * pdfW) / canvas.width
      pdf.addImage(imgData, 'PNG', 0, 0, pdfW, pdfH)

      const user = memberInfo || rec
      const filename = `CUBAG_License_${(user.name || 'Member').replace(/\s+/g, '_')}_${new Date().getFullYear()}.pdf`

      if (action === 'download') {
        pdf.save(filename)
        setViewCert(null)
      } else {
        // View in new tab
        const pdfBlob = pdf.output('blob')
        const url = URL.createObjectURL(pdfBlob)
        window.open(url, '_blank')
        setViewCert(null)
      }
    } catch (e) {
      console.error(e)
    } finally {
      setGenerating(false)
    }
  }

  const user = memberInfo || {}
  const certYear = new Date().getFullYear()

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

              {rec.approved ? (
                <div style={{ display: 'flex', gap: 10 }}>
                  <button className="btn btn-outline" style={{ flex: 1, justifyContent: 'center', display: 'flex', alignItems: 'center', gap: 8 }}
                    onClick={() => generatePDF('view', rec)} disabled={generating}>
                    <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>visibility</span>
                    {generating ? 'Generating...' : 'View Certificate'}
                  </button>
                  <button className="btn btn-primary" style={{ flex: 1, justifyContent: 'center', display: 'flex', alignItems: 'center', gap: 8 }}
                    onClick={() => generatePDF('download', rec)} disabled={generating}>
                    <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>download</span>
                    {generating ? 'Generating...' : 'Download Certificate'}
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

      {/* ── Hidden Certificate DOM (rendered off-screen for html2canvas) ────── */}
      {viewCert && (
        <div style={{ position: 'fixed', top: '-9999px', left: '-9999px', zIndex: -1 }}>
          <div ref={certRef} style={{
            width: 794, minHeight: 1123, background: '#fff', fontFamily: 'Georgia, serif',
            padding: '48px 60px', boxSizing: 'border-box', position: 'relative', color: '#1a1a1a'
          }}>

            {/* Watermark */}
            <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', opacity: 0.04, pointerEvents: 'none', zIndex: 0 }}>
              <span style={{ fontSize: 160, fontWeight: 900, color: '#006B3F', transform: 'rotate(-35deg)', letterSpacing: -8, fontFamily: 'Georgia, serif' }}>CUBAG</span>
            </div>

            {/* Border frame */}
            <div style={{ position: 'absolute', inset: 16, border: '4px solid #006B3F', borderRadius: 4, zIndex: 0 }} />
            <div style={{ position: 'absolute', inset: 22, border: '1.5px solid #FCD116', borderRadius: 2, zIndex: 0 }} />

            <div style={{ position: 'relative', zIndex: 1 }}>

              {/* Header row: Ghana emblem | CUBAG logo | Ghana emblem */}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
                <GhanaEmblem />
                <div style={{ textAlign: 'center', flex: 1 }}>
                  <img src="/logo.jpeg" alt="CUBAG" crossOrigin="anonymous"
                    style={{ height: 72, width: 72, borderRadius: 12, objectFit: 'cover', marginBottom: 8, border: '2px solid #006B3F' }} />
                  <div style={{ fontSize: 13, color: '#006B3F', fontWeight: 700, letterSpacing: 2, textTransform: 'uppercase' }}>
                    Republic of Ghana
                  </div>
                  <div style={{ fontSize: 10, color: '#666', letterSpacing: 1, marginTop: 2 }}>
                    Ministry of Finance & Economic Planning
                  </div>
                </div>
                <GhanaEmblem />
              </div>

              {/* Title band */}
              <div style={{ background: '#006B3F', padding: '10px 0', textAlign: 'center', marginBottom: 6 }}>
                <div style={{ color: '#FCD116', fontSize: 11, letterSpacing: 4, fontWeight: 700, textTransform: 'uppercase' }}>
                  Customs Brokers & Agents Association of Ghana
                </div>
              </div>
              <div style={{ background: '#FCD116', padding: '6px 0', textAlign: 'center', marginBottom: 28 }}>
                <div style={{ color: '#006B3F', fontSize: 9, letterSpacing: 3, fontWeight: 700, textTransform: 'uppercase' }}>
                  CUBAG — Accredited by the Ghana Revenue Authority (GRA) • Reg. No. GH-CB-2024
                </div>
              </div>

              {/* Certificate title */}
              <div style={{ textAlign: 'center', marginBottom: 28 }}>
                <div style={{ fontSize: 11, letterSpacing: 6, color: '#888', textTransform: 'uppercase', marginBottom: 6 }}>Certificate of</div>
                <div style={{ fontSize: 32, fontWeight: 700, color: '#006B3F', letterSpacing: 1, lineHeight: 1.1 }}>
                  Active Membership
                </div>
                <div style={{ fontSize: 10, color: '#CE1126', fontWeight: 700, letterSpacing: 3, marginTop: 6, textTransform: 'uppercase' }}>
                  & Licensed Customs Broker
                </div>
              </div>

              {/* Body text */}
              <div style={{ textAlign: 'center', fontSize: 12, color: '#444', lineHeight: 1.9, marginBottom: 28 }}>
                <span style={{ fontStyle: 'italic' }}>This is to certify that</span>
              </div>

              {/* Member name */}
              <div style={{ textAlign: 'center', marginBottom: 8 }}>
                <div style={{ fontSize: 28, fontWeight: 700, color: '#1a1a1a', borderBottom: '2px solid #006B3F', display: 'inline-block', paddingBottom: 4, minWidth: 300 }}>
                  {user.name || viewCert.name || 'Member Name'}
                </div>
              </div>
              <div style={{ textAlign: 'center', fontSize: 12, color: '#555', marginBottom: 24, fontStyle: 'italic' }}>
                representing <strong style={{ fontStyle: 'normal' }}>{user.company || viewCert.company || 'Company Name'}</strong>
              </div>

              {/* Description */}
              <div style={{ textAlign: 'center', fontSize: 12, color: '#444', lineHeight: 1.9, marginBottom: 28, maxWidth: 560, margin: '0 auto 28px' }}>
                is hereby recognised as an <strong>Active Member and Licensed Customs Broker</strong> of the
                Customs Brokers & Agents Association of Ghana (CUBAG), duly authorised to operate as a
                customs clearing agent within the jurisdiction of Ghana, in accordance with the
                Customs Act 2015 (Act 891) and GRA regulations.
              </div>

              {/* Details grid */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 32, background: '#f8faf8', borderRadius: 8, padding: '16px 20px', border: '1px solid #d0e8d0' }}>
                {[
                  ['License Number', user.license_number || `CUBAG-${certYear}-${String(user.id || '001').padStart(4,'0')}`],
                  ['Member Type', user.member_type || viewCert.member_type || '—'],
                  ['Port of Operation', user.port_of_operation || viewCert.port_of_operation || '—'],
                  ['Email Address', user.email || '—'],
                  ['Payment Reference', viewCert.payment_ref || '—'],
                  ['Valid Period', `January ${certYear} – December ${certYear}`],
                ].map(([label, val]) => (
                  <div key={label}>
                    <div style={{ fontSize: 9, color: '#006B3F', fontWeight: 700, textTransform: 'uppercase', letterSpacing: 1, marginBottom: 2 }}>{label}</div>
                    <div style={{ fontSize: 12, fontWeight: 600, color: '#1a1a1a' }}>{val}</div>
                  </div>
                ))}
              </div>

              {/* Signature & Stamp row */}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginTop: 8, marginBottom: 24 }}>
                {/* Signature 1 */}
                <div style={{ textAlign: 'center', minWidth: 160 }}>
                  <div style={{ borderTop: '1.5px solid #333', paddingTop: 6, width: 160 }}>
                    <div style={{ fontSize: 11, fontWeight: 700, color: '#1a1a1a' }}>Executive Secretary</div>
                    <div style={{ fontSize: 10, color: '#666', fontStyle: 'italic' }}>CUBAG Secretariat</div>
                  </div>
                </div>

                {/* Stamps centre */}
                <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                  <Stamp text="✦ CUBAG OFFICIAL ✦" color="#006B3F" size={100} />
                  <Stamp text="✦ GRA APPROVED ✦" color="#CE1126" size={90} />
                </div>

                {/* Signature 2 */}
                <div style={{ textAlign: 'center', minWidth: 160 }}>
                  <div style={{ borderTop: '1.5px solid #333', paddingTop: 6, width: 160 }}>
                    <div style={{ fontSize: 11, fontWeight: 700, color: '#1a1a1a' }}>President</div>
                    <div style={{ fontSize: 10, color: '#666', fontStyle: 'italic' }}>CUBAG National</div>
                  </div>
                </div>
              </div>

              {/* Issue date */}
              <div style={{ textAlign: 'center', fontSize: 11, color: '#888', marginBottom: 20 }}>
                Issued on <strong style={{ color: '#1a1a1a' }}>{new Date().toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' })}</strong>
              </div>

              {/* Footer band */}
              <div style={{ background: '#006B3F', padding: '8px 0', textAlign: 'center', marginTop: 8 }}>
                <div style={{ color: '#FCD116', fontSize: 9, letterSpacing: 2, fontWeight: 700 }}>
                  FREEDOM AND JUSTICE • GHANA • P.O. Box TEMA • www.cubag.gh
                </div>
              </div>

            </div>
          </div>
        </div>
      )}
    </AppLayout>
  )
}
