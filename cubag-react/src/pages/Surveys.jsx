import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

const API_URL = import.meta.env.VITE_API_URL

export default function Surveys() {
  const [surveys, setSurveys] = useState([])
  const [loading, setLoading] = useState(true)
  const [activeTab, setActiveTab] = useState('active') // active | history
  const [answering, setAnswering] = useState(null)
  const [submitting, setSubmitting] = useState(false)
  
  // Single choice answer for elections/polls
  const [selectedOption, setSelectedOption] = useState('')

  const token = localStorage.getItem('cubag_token')

  const fetchSurveys = async () => {
    setLoading(true)
    try {
      const res = await fetch(`${API_URL}/surveys`, {
        headers: { Authorization: `Bearer ${token}` }
      })
      if (res.ok) setSurveys(await res.json())
    } catch {}
    finally { setLoading(false) }
  }

  useEffect(() => { fetchSurveys() }, [])

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!selectedOption) return alert('Please select an option.')
    
    setSubmitting(true)
    try {
      await fetch(`${API_URL}/surveys/${answering.id}/respond`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ answers: { vote: selectedOption } })
      })
      setAnswering(null)
      fetchSurveys() // Optional: refresh if we want to show it as completed
      alert('Your response has been submitted successfully!')
    } catch {}
    finally { setSubmitting(false) }
  }

  const todayStr = new Date().toISOString().split('T')[0]
  // In a full implementation, we'd filter out surveys the user already answered
  const activeSurveys = surveys.filter(s => s.active && (!s.deadline || s.deadline >= todayStr))
  const pastSurveys = surveys.filter(s => !s.active || (s.deadline && s.deadline < todayStr))

  return (
    <AppLayout title="Surveys & Elections">
      <div style={{ maxWidth: 860, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 24 }}>

        <div>
          <h2 style={{ margin: 0, fontSize: '1.4rem' }}>Surveys & Elections</h2>
          <p style={{ margin: '4px 0 0', color: 'var(--text-muted)', fontSize: '0.88rem' }}>
            Participate in association polls, surveys, and executive elections.
          </p>
        </div>

        {answering ? (
          <div className="card" style={{ padding: 32 }}>
            <button className="btn btn-ghost btn-sm" onClick={() => setAnswering(null)} style={{ marginBottom: 16 }}>
              <span className="material-symbols-outlined">arrow_back</span> Back
            </button>
            {answering.cover_image && (
              <div style={{ width: '100%', height: 200, borderRadius: 12, overflow: 'hidden', marginBottom: 24 }}>
                <img src={answering.cover_image} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
              </div>
            )}
            <span style={{ fontSize: '0.7rem', fontWeight: 800, color: answering.type === 'Election' ? '#8b5cf6' : 'var(--brand-primary)', textTransform: 'uppercase', padding: '4px 10px', background: answering.type === 'Election' ? 'rgba(139,92,246,0.1)' : 'rgba(240,130,50,0.1)', borderRadius: 20, display: 'inline-block', marginBottom: 12 }}>
              {answering.type}
            </span>
            <h2 style={{ margin: '0 0 8px' }}>{answering.title}</h2>
            <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem', marginBottom: 24 }}>{answering.description}</p>

            <form onSubmit={handleSubmit}>
              {(() => {
                const parsedOptions = JSON.parse(answering.options || '[]');
                const isStarRating = parsedOptions.length === 0;
                const isYesNo = parsedOptions.length === 2 && parsedOptions[0].name === 'Yes' && parsedOptions[1].name === 'No';

                if (isStarRating) {
                  return (
                    <div style={{ textAlign: 'center', margin: '40px 0' }}>
                      <h4 style={{ marginBottom: 20 }}>Rate your experience:</h4>
                      <div style={{ display: 'flex', justifyContent: 'center', gap: 8 }}>
                        {[1, 2, 3, 4, 5].map(star => (
                          <button
                            key={star}
                            type="button"
                            onClick={() => setSelectedOption(star)}
                            style={{
                              background: 'none', border: 'none', cursor: 'pointer', padding: 0,
                              transition: 'transform 0.1s'
                            }}
                            onMouseEnter={e => e.currentTarget.style.transform = 'scale(1.2)'}
                            onMouseLeave={e => e.currentTarget.style.transform = 'scale(1)'}
                          >
                            <span className="material-symbols-outlined" style={{
                              fontSize: '3rem',
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
                    <h4 style={{ marginBottom: 16 }}>Select your choice:</h4>
                    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: 16, marginBottom: 24 }}>
                      {parsedOptions.map((opt, i) => (
                        <label key={i} style={{
                          display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12, padding: 20,
                          border: selectedOption === opt.name ? '2px solid var(--brand-primary)' : '2px solid var(--border-subtle)',
                          borderRadius: 12, cursor: 'pointer', background: selectedOption === opt.name ? 'rgba(240,130,50,0.05)' : 'var(--bg-base)',
                          transition: 'all 0.2s', textAlign: 'center'
                        }}>
                          {!isYesNo && (
                            <div style={{ width: 80, height: 80, borderRadius: '50%', background: 'var(--bg-surface)', border: '1px solid var(--border-default)', display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden' }}>
                              {opt.photo ? (
                                <img src={opt.photo} alt={opt.name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                              ) : (
                                <span className="material-symbols-outlined" style={{ fontSize: '2rem', color: 'var(--text-muted)' }}>person</span>
                              )}
                            </div>
                          )}
                          <div>
                            <div style={{ fontWeight: 700, fontSize: '1.05rem', color: 'var(--text-primary)' }}>{opt.name}</div>
                          </div>
                          <input type="radio" name="vote" value={opt.name} checked={selectedOption === opt.name} onChange={() => setSelectedOption(opt.name)} style={{ width: 18, height: 18, accentColor: 'var(--brand-primary)' }} />
                        </label>
                      ))}
                    </div>
                  </>
                );
              })()}

              <button type="submit" className="btn btn-primary btn-lg" disabled={submitting || !selectedOption} style={{ width: '100%' }}>
                {submitting ? 'Submitting...' : 'Submit Vote / Response'}
              </button>
            </form>
          </div>
        ) : (
          <>
            <div style={{ display: 'flex', gap: 4, background: 'var(--bg-surface)', borderRadius: 12, padding: 4, flexWrap: 'wrap' }}>
              {[
                { id: 'active', label: `Active (${activeSurveys.length})`, icon: 'how_to_vote' },
                { id: 'history', label: `Past Polls (${pastSurveys.length})`, icon: 'history' },
              ].map(t => (
                <button key={t.id} onClick={() => setActiveTab(t.id)} style={{
                  flex: 1, padding: '10px 16px', border: 'none', borderRadius: 8,
                  background: activeTab === t.id ? 'var(--bg-base)' : 'transparent',
                  color: activeTab === t.id ? 'var(--text-primary)' : 'var(--text-secondary)',
                  fontWeight: activeTab === t.id ? 700 : 500, cursor: 'pointer',
                  display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
                  boxShadow: activeTab === t.id ? 'var(--shadow-sm)' : 'none', minWidth: 120
                }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>{t.icon}</span>
                  {t.label}
                </button>
              ))}
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
              {loading ? (
                <div style={{ textAlign: 'center', padding: 40, color: 'var(--text-muted)' }}>Loading...</div>
              ) : (activeTab === 'active' ? activeSurveys : pastSurveys).length === 0 ? (
                <div className="card" style={{ textAlign: 'center', padding: '60px 20px', color: 'var(--text-muted)' }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '3rem', marginBottom: 12 }}>ballot</span>
                  <p>There are currently no active surveys or association elections requiring your vote.</p>
                </div>
              ) : (activeTab === 'active' ? activeSurveys : pastSurveys).map(s => (
                <div key={s.id} className="feed-card" style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 16 }}>
                  <div style={{ display: 'flex', gap: 20 }}>
                    {s.cover_image && (
                      <img src={s.cover_image} alt="" style={{ width: 100, height: 100, objectFit: 'cover', borderRadius: 12, flexShrink: 0 }} />
                    )}
                    <div>
                      <span style={{ fontSize: '0.7rem', fontWeight: 800, color: s.type === 'Election' ? '#8b5cf6' : 'var(--brand-primary)', textTransform: 'uppercase', padding: '4px 10px', background: s.type === 'Election' ? 'rgba(139,92,246,0.1)' : 'rgba(240,130,50,0.1)', borderRadius: 20 }}>
                        {s.type}
                      </span>
                      <h3 style={{ margin: '8px 0 6px', fontSize: '1.2rem' }}>{s.title}</h3>
                      <p style={{ margin: 0, fontSize: '0.9rem', color: 'var(--text-secondary)' }}>{s.description}</p>
                    </div>
                  </div>
                  
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid var(--border-subtle)', paddingTop: 16 }}>
                    <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                      Deadline: <strong>{s.deadline || 'No deadline'}</strong>
                    </div>
                    {activeTab === 'active' ? (
                      <button className="btn btn-primary" onClick={() => { setAnswering(s); setSelectedOption(''); }}>
                        Participate
                      </button>
                    ) : (
                      <span style={{ fontSize: '0.8rem', fontWeight: 700, color: 'var(--text-muted)' }}>Closed</span>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </>
        )}
      </div>
    </AppLayout>
  )
}
