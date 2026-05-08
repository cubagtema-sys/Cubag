import { useState, useRef } from 'react'
import AppLayout from '../components/AppLayout'
import useAutoRefresh from '../hooks/useAutoRefresh'

const API_URL = import.meta.env.VITE_API_URL

export default function Surveys() {
  const [surveys, setSurveys] = useState([])
  const [loading, setLoading] = useState(true)
  const [activeTab, setActiveTab] = useState('active') // active | history
  const [answering, setAnswering] = useState(null)
  const [submitting, setSubmitting] = useState(false)
  
  // Single choice answer for elections/polls
  const [selectedOption, setSelectedOption] = useState('')

  const [toast, setToast] = useState(null) // { message: '', type: 'success' | 'error' }

  const token = localStorage.getItem('cubag_token')
  const firstLoad = useRef(true)

  const showToast = (message, type = 'success') => {
    setToast({ message, type })
    setTimeout(() => setToast(null), 3000)
  }

  const fetchSurveys = async () => {
    if (firstLoad.current) setLoading(true)
    try {
      const res = await fetch(`${API_URL}/surveys`, {
        headers: { Authorization: `Bearer ${token}` }
      })
      if (res.ok) setSurveys(await res.json())
    } catch {}
    finally {
      setLoading(false)
      firstLoad.current = false
    }
  }

  useAutoRefresh(fetchSurveys, 30000)

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!selectedOption) return showToast('Please select an option.', 'error')
    
    setSubmitting(true)
    try {
      await fetch(`${API_URL}/surveys/${answering.id}/respond`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ answers: { vote: selectedOption } })
      })
      setAnswering(null)
      fetchSurveys() // Optional: refresh if we want to show it as completed
      showToast('Your response has been submitted successfully!', 'success')
    } catch {
      showToast('An error occurred while submitting.', 'error')
    }
    finally { setSubmitting(false) }
  }

  const todayStr = new Date().toISOString().split('T')[0]
  // In a full implementation, we'd filter out surveys the user already answered
  const activeSurveys = surveys.filter(s => s.active && (!s.deadline || s.deadline >= todayStr))
  const pastSurveys = surveys.filter(s => !s.active || (s.deadline && s.deadline < todayStr))

  return (
    <AppLayout title="Surveys">
      <div style={{ maxWidth: 860, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>

        <div style={{ marginBottom: 4 }}>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Surveys & Elections</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Participate in association polls and elections.</p>
        </div>

        {answering ? (
          <div className="feed-card" style={{ padding: '24px 20px', borderRadius: 12 }}>
            <button className="btn btn-ghost btn-sm" onClick={() => setAnswering(null)} style={{ marginBottom: 12, padding: '4px 8px', fontSize: '0.75rem' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>arrow_back</span> Back
            </button>
            {answering.cover_image && (
              <div style={{ width: '100%', height: 160, borderRadius: 10, overflow: 'hidden', marginBottom: 20 }}>
                <img src={answering.cover_image} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
              </div>
            )}
            <span style={{ fontSize: '0.65rem', fontWeight: 800, color: answering.type === 'Election' ? '#8b5cf6' : 'var(--brand-primary)', textTransform: 'uppercase', padding: '3px 8px', background: answering.type === 'Election' ? 'rgba(139,92,246,0.1)' : 'rgba(240,130,50,0.1)', borderRadius: 20, display: 'inline-block', marginBottom: 10 }}>
              {answering.type}
            </span>
            <h2 style={{ fontSize: '1.2rem', margin: '0 0 6px' }}>{answering.title}</h2>
            <p style={{ color: 'var(--text-secondary)', fontSize: '0.85rem', marginBottom: 20 }}>{answering.description}</p>

            <form onSubmit={handleSubmit}>
              {(() => {
                const parsedOptions = JSON.parse(answering.options || '[]');
                const isStarRating = parsedOptions.length === 0;
                const isYesNo = parsedOptions.length === 2 && parsedOptions[0].name === 'Yes' && parsedOptions[1].name === 'No';

                if (isStarRating) {
                  return (
                    <div style={{ textAlign: 'center', margin: '24px 0' }}>
                      <h4 style={{ marginBottom: 16, fontSize: '0.9rem' }}>Rate experience:</h4>
                      <div style={{ display: 'flex', justifyContent: 'center', gap: 4 }}>
                        {[1, 2, 3, 4, 5].map(star => (
                          <button
                            key={star}
                            type="button"
                            onClick={() => setSelectedOption(star)}
                            style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 0 }}
                          >
                            <span className="material-symbols-outlined" style={{
                              fontSize: '2.5rem',
                              color: selectedOption >= star ? '#f59e0b' : 'var(--border-default)',
                              fontVariationSettings: selectedOption >= star ? "'FILL' 1" : "'FILL' 0"
                            }}>
                              star
                            </span>
                          </button>
                        ))}
                      </div>
                    </div>
                  );
                }

                return (
                  <>
                    <h4 style={{ marginBottom: 12, fontSize: '0.9rem' }}>Select choice:</h4>
                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(140px, 1fr))', gap: 12, marginBottom: 20 }}>
                      {parsedOptions.map((opt, i) => (
                        <label key={i} style={{
                          display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10, padding: 16,
                          border: selectedOption === opt.name ? '2.5px solid var(--brand-primary)' : '1px solid var(--border-subtle)',
                          borderRadius: 12, cursor: 'pointer', background: selectedOption === opt.name ? 'rgba(240,130,50,0.05)' : 'var(--bg-base)',
                          transition: 'all 0.2s', textAlign: 'center'
                        }}>
                          {!isYesNo && (
                            <div style={{ width: 60, height: 60, borderRadius: '50%', background: 'var(--bg-surface)', border: '1px solid var(--border-default)', display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden' }}>
                              {opt.photo ? (
                                <img src={opt.photo} alt={opt.name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                              ) : (
                                <span className="material-symbols-outlined" style={{ fontSize: '1.5rem', color: 'var(--text-muted)' }}>person</span>
                              )}
                            </div>
                          )}
                          <div style={{ fontWeight: 700, fontSize: '0.9rem', color: 'var(--text-primary)' }}>{opt.name}</div>
                          <input type="radio" name="vote" value={opt.name} checked={selectedOption === opt.name} onChange={() => setSelectedOption(opt.name)} style={{ width: 16, height: 18, accentColor: 'var(--brand-primary)' }} />
                        </label>
                      ))}
                    </div>
                  </>
                );
              })()}

              <button type="submit" className="btn btn-primary btn-lg" disabled={submitting || !selectedOption} style={{ width: '100%', height: 48, fontSize: '0.9rem' }}>
                {submitting ? 'Submitting...' : 'Submit Response'}
              </button>
            </form>
          </div>
        ) : (
          <>
            <div style={{ display: 'flex', gap: 4, background: 'var(--bg-surface)', borderRadius: 10, padding: 3, flexWrap: 'wrap' }}>
              {[
                { id: 'active', label: `Active (${activeSurveys.length})`, icon: 'how_to_vote' },
                { id: 'history', label: `Past (${pastSurveys.length})`, icon: 'history' },
              ].map(t => (
                <button key={t.id} onClick={() => setActiveTab(t.id)} style={{
                  flex: 1, padding: '8px 12px', border: 'none', borderRadius: 8,
                  background: activeTab === t.id ? 'var(--bg-base)' : 'transparent',
                  color: activeTab === t.id ? 'var(--text-primary)' : 'var(--text-secondary)',
                  fontWeight: activeTab === t.id ? 700 : 500, cursor: 'pointer',
                  display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
                  boxShadow: activeTab === t.id ? 'var(--shadow-sm)' : 'none', minWidth: 100, fontSize: '0.8rem'
                }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>{t.icon}</span>
                  {t.label}
                </button>
              ))}
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {loading ? (
                <div style={{ textAlign: 'center', padding: 40, color: 'var(--text-muted)', fontSize: '0.8rem' }}>Loading surveys...</div>
              ) : (activeTab === 'active' ? activeSurveys : pastSurveys).length === 0 ? (
                <div className="card" style={{ textAlign: 'center', padding: '60px 20px', color: 'var(--text-muted)', borderRadius: 12 }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '3rem', marginBottom: 12 }}>ballot</span>
                  <p style={{ fontSize: '0.85rem' }}>No surveys found.</p>
                </div>
              ) : (activeTab === 'active' ? activeSurveys : pastSurveys).map(s => (
                <div key={s.id} className="feed-card" style={{ padding: '16px 20px', display: 'flex', flexDirection: 'column', gap: 12, borderRadius: 12 }}>
                  <div style={{ display: 'flex', gap: 14 }}>
                    {s.cover_image && (
                      <img src={s.cover_image} alt="" style={{ width: 64, height: 64, objectFit: 'cover', borderRadius: 10, flexShrink: 0 }} />
                    )}
                    <div style={{ minWidth: 0 }}>
                      <span style={{ fontSize: '0.6rem', fontWeight: 800, color: s.type === 'Election' ? '#8b5cf6' : 'var(--brand-primary)', textTransform: 'uppercase', padding: '2px 8px', background: s.type === 'Election' ? 'rgba(139,92,246,0.1)' : 'rgba(240,130,50,0.1)', borderRadius: 20 }}>
                        {s.type}
                      </span>
                      <h3 style={{ margin: '6px 0 4px', fontSize: '1rem', fontWeight: 700, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{s.title}</h3>
                      <p style={{ margin: 0, fontSize: '0.8rem', color: 'var(--text-secondary)', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>{s.description}</p>
                    </div>
                  </div>
                  
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid var(--border-subtle)', paddingTop: 10 }}>
                    <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                      Deadline: <strong>{s.deadline || 'None'}</strong>
                    </div>
                    {activeTab === 'active' ? (
                      s.has_responded ? (
                        <span style={{ fontSize: '0.8rem', fontWeight: 700, color: '#10b981', display: 'flex', alignItems: 'center', gap: 4 }}>
                          <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>check_circle</span>
                          Voted
                        </span>
                      ) : (
                        <button className="btn btn-primary btn-sm" onClick={() => { setAnswering(s); setSelectedOption(''); }}>
                          Participate
                        </button>
                      )
                    ) : (
                      <span style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-muted)' }}>Closed</span>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </>
        )}
      </div>

      {toast && (
        <div style={{
          position: 'fixed', top: 32, left: '50%', transform: 'translateX(-50%)',
          background: toast.type === 'success' ? '#10b981' : 'var(--brand-danger)',
          color: 'white', padding: '12px 24px', borderRadius: 8, fontWeight: 600,
          boxShadow: '0 8px 24px rgba(0,0,0,0.2)', zIndex: 9999,
          display: 'flex', alignItems: 'center', gap: 8,
          animation: 'slideDown 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275)'
        }}>
          <span className="material-symbols-outlined">
            {toast.type === 'success' ? 'check_circle' : 'error'}
          </span>
          {toast.message}
        </div>
      )}
      <style>{`
        @keyframes slideDown {
          from { transform: translate(-50%, -100%); opacity: 0; }
          to { transform: translate(-50%, 0); opacity: 1; }
        }
      `}</style>
    </AppLayout>
  )
}
