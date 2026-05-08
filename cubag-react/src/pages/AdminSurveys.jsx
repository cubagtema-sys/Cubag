import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'
import CustomSelect from '../components/CustomSelect'
import useAutoRefresh from '../hooks/useAutoRefresh'

const API_URL = import.meta.env.VITE_API_URL
const EMPTY_OPTION = { name: '', photo: '' }
const EMPTY_FORM = { title: '', description: '', type: 'Survey', method: 'Multiple Choice', deadline: '', cover_image: '', options: [EMPTY_OPTION] }

export default function AdminSurveys() {
  const [surveys, setSurveys] = useState([])
  const [loading, setLoading] = useState(true)
  const [activeTab, setActiveTab] = useState('active') // active | history | create
  const [form, setForm] = useState(EMPTY_FORM)
  const [submitting, setSubmitting] = useState(false)
  const [viewingResults, setViewingResults] = useState(null)
  const [resultsData, setResultsData] = useState(null)

  const token = localStorage.getItem('cubag_token')

  const fetchSurveys = async () => {
    setLoading(true)
    try {
      const res = await fetch(`${API_URL}/surveys/admin/all`, {
        headers: { Authorization: `Bearer ${token}` }
      })
      if (res.ok) {
        const data = await res.json()
        setSurveys(data)
      }
    } catch {}
    finally { setLoading(false) }
  }

  useAutoRefresh(fetchSurveys, 30000)

  const handlePhotoUpload = (index, e) => {
    const file = e.target.files[0]
    if (!file) return
    const reader = new FileReader()
    reader.onload = (event) => {
      const newOptions = [...form.options]
      newOptions[index].photo = event.target.result
      setForm({ ...form, options: newOptions })
    }
    reader.readAsDataURL(file)
  }

  const handleCoverUpload = (e) => {
    const file = e.target.files[0]
    if (!file) return
    const reader = new FileReader()
    reader.onload = (event) => setForm({ ...form, cover_image: event.target.result })
    reader.readAsDataURL(file)
  }

  const handleCreate = async (e) => {
    e.preventDefault()
    setSubmitting(true)
    try {
      await fetch(`${API_URL}/surveys`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify(form)
      })
      setForm(EMPTY_FORM)
      setActiveTab('active')
      fetchSurveys()
    } catch {}
    finally { setSubmitting(false) }
  }

  const handleDelete = async (id) => {
    if (!window.confirm('Are you sure you want to delete this poll? All responses will be lost.')) return
    try {
      await fetch(`${API_URL}/surveys/${id}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` }
      })
      fetchSurveys()
    } catch {}
  }

  const viewResults = async (survey) => {
    setViewingResults(survey)
    setResultsData(null)
    try {
      const res = await fetch(`${API_URL}/surveys/${survey.id}/participation`, {
        headers: { Authorization: `Bearer ${token}` }
      })
      if (res.ok) setResultsData(await res.json())
    } catch {}
  }

  const todayStr = new Date().toISOString().split('T')[0]
  const activeSurveys = surveys.filter(s => s.active && (!s.deadline || s.deadline >= todayStr))
  const pastSurveys = surveys.filter(s => !s.active || (s.deadline && s.deadline < todayStr))

  return (
    <AppLayout title="Surveys & Elections">
      <div style={{ maxWidth: 860, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 24 }}>

        <div>
          <h2 style={{ margin: 0, fontSize: '1.4rem' }}>Surveys & Elections</h2>
          <p style={{ margin: '4px 0 0', color: 'var(--text-muted)', fontSize: '0.88rem' }}>
            Create polls, manage association elections, and view member responses.
          </p>
        </div>

        <div style={{ display: 'flex', gap: 4, background: 'var(--bg-surface)', borderRadius: 12, padding: 4, flexWrap: 'wrap' }}>
          {[
            { id: 'active', label: `Active (${activeSurveys.length})`, icon: 'how_to_vote' },
            { id: 'history', label: `History (${pastSurveys.length})`, icon: 'history' },
            { id: 'create', label: 'New Poll', icon: 'add_circle' },
          ].map(t => (
            <button key={t.id} onClick={() => { setActiveTab(t.id); setViewingResults(null); }} style={{
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

        {activeTab === 'create' ? (
          <div className="card">
            <h3 style={{ margin: '0 0 20px' }}>Create New Poll / Election</h3>
            <form onSubmit={handleCreate} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
              <div className="form-row">
                <div className="form-group">
                  <label>Title</label>
                  <input required value={form.title} onChange={e => setForm({ ...form, title: e.target.value })} placeholder="e.g. 2026 Presidential Election" />
                </div>
                <div className="form-group" style={{ zIndex: 10 }}>
                  <label>Type & Method</label>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                    <CustomSelect 
                      value={form.type} 
                      onChange={val => setForm({ ...form, type: val })}
                      options={[
                        { value: 'Survey', label: 'Survey' },
                        { value: 'Election', label: 'Election' },
                      ]}
                    />
                    <CustomSelect 
                      value={form.method} 
                      onChange={val => {
                        if (val === 'Yes/No') {
                          setForm({ ...form, method: val, options: [{ name: 'Yes' }, { name: 'No' }] })
                        } else if (val === 'Star Rating') {
                          setForm({ ...form, method: val, options: [] })
                        } else {
                          setForm({ ...form, method: val, options: [EMPTY_OPTION] })
                        }
                      }}
                      options={[
                        { value: 'Multiple Choice', label: 'Multiple Choice' },
                        { value: 'Yes/No', label: 'Yes / No' },
                        { value: 'Star Rating', label: 'Star Rating' },
                      ]}
                    />
                  </div>
                </div>
              </div>
              <div className="form-group">
                <label>Cover Photo</label>
                <div style={{ display: 'flex', gap: 16, alignItems: 'center' }}>
                  <div style={{ width: 100, height: 100, borderRadius: 12, background: 'var(--bg-surface)', border: '2px dashed var(--border-default)', display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden', position: 'relative' }}>
                    {form.cover_image ? (
                      <img src={form.cover_image} alt="Cover" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                    ) : (
                      <span className="material-symbols-outlined" style={{ fontSize: '2rem', color: 'var(--text-muted)' }}>image</span>
                    )}
                    <input type="file" accept="image/*" onChange={handleCoverUpload} style={{ position: 'absolute', inset: 0, opacity: 0, cursor: 'pointer' }} />
                  </div>
                  <div style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>
                    Upload a main photo to represent this poll or election.<br />Click the box to upload.
                  </div>
                </div>
              </div>

              <div className="form-group">
                <label>Description</label>
                <textarea required rows="3" value={form.description} onChange={e => setForm({ ...form, description: e.target.value })} placeholder="Instructions for the voters..." style={{ resize: 'vertical', borderRadius: 'var(--radius-md)', border: '1.5px solid var(--border-default)', padding: '10px 14px', fontFamily: 'inherit', fontSize: '0.9rem', width: '100%', boxSizing: 'border-box' }} />
              </div>
              <div className="form-group">
                <label>Deadline / Expiry Date</label>
                <input required type="date" value={form.deadline} onChange={e => setForm({ ...form, deadline: e.target.value })} />
              </div>

              {form.method === 'Multiple Choice' && (
                <div style={{ marginTop: 12 }}>
                  <label style={{ fontSize: '0.9rem', fontWeight: 700, display: 'flex', justifyContent: 'space-between', marginBottom: 12 }}>
                    <span>Options / Candidates</span>
                    <button type="button" className="btn btn-ghost btn-sm" onClick={() => setForm({ ...form, options: [...form.options, { ...EMPTY_OPTION }] })}>
                      <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>add</span> Add Option
                    </button>
                  </label>
                  
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                    {form.options.map((opt, i) => (
                      <div key={i} style={{ display: 'flex', gap: 12, alignItems: 'center', background: 'var(--bg-surface)', padding: 12, borderRadius: 12, border: '1px solid var(--border-subtle)' }}>
                        <div style={{ width: 60, height: 60, borderRadius: 8, background: 'var(--bg-base)', border: '1px solid var(--border-default)', display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden', flexShrink: 0, position: 'relative' }}>
                          {opt.photo ? (
                            <img src={opt.photo} alt="Candidate" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                          ) : (
                            <span className="material-symbols-outlined" style={{ color: 'var(--text-muted)' }}>person</span>
                          )}
                          <input type="file" accept="image/*" onChange={(e) => handlePhotoUpload(i, e)} style={{ position: 'absolute', inset: 0, opacity: 0, cursor: 'pointer' }} />
                        </div>
                        <input required style={{ flex: 1 }} placeholder="Option or Candidate Name..." value={opt.name} onChange={e => {
                          const newOpts = [...form.options];
                          newOpts[i].name = e.target.value;
                          setForm({ ...form, options: newOpts });
                        }} />
                        {form.options.length > 1 && (
                          <button type="button" className="btn btn-ghost btn-sm" style={{ color: 'var(--brand-danger)' }} onClick={() => {
                            setForm({ ...form, options: form.options.filter((_, idx) => idx !== i) })
                          }}>
                            <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>delete</span>
                          </button>
                        )}
                      </div>
                    ))}
                  </div>
                </div>
              )}

              <button type="submit" className="btn btn-primary" disabled={submitting} style={{ marginTop: 12, width: '100%' }}>
                {submitting ? 'Creating...' : 'Publish Poll'}
              </button>
            </form>
          </div>
        ) : viewingResults ? (
          <div className="card">
            <button className="btn btn-ghost btn-sm" onClick={() => setViewingResults(null)} style={{ marginBottom: 16 }}>
              <span className="material-symbols-outlined">arrow_back</span> Back to list
            </button>
            <h3 style={{ margin: '0 0 4px' }}>Results: {viewingResults.title}</h3>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem', marginBottom: 20 }}>{viewingResults.type} &bull; Deadline: {viewingResults.deadline}</p>
            
            {!resultsData ? (
              <div style={{ textAlign: 'center', padding: 40, color: 'var(--text-muted)' }}>Loading results...</div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 24 }}>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: 12 }}>
                  <div style={{ background: 'var(--bg-surface)', padding: 16, borderRadius: 12 }}>
                    <div style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase' }}>Responses</div>
                    <div style={{ fontSize: '1.8rem', fontWeight: 800, color: 'var(--brand-primary)' }}>{resultsData.responded.length} <span style={{ fontSize: '1rem', color: 'var(--text-secondary)' }}>/ {resultsData.total}</span></div>
                  </div>
                  <div style={{ background: 'var(--bg-surface)', padding: 16, borderRadius: 12 }}>
                    <div style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase' }}>Participation Rate</div>
                    <div style={{ fontSize: '1.8rem', fontWeight: 800, color: '#10b981' }}>{resultsData.response_rate}%</div>
                  </div>
                  {(!viewingResults.options || viewingResults.options === '[]') && (
                    <div style={{ background: 'var(--bg-surface)', padding: 16, borderRadius: 12 }}>
                      <div style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase' }}>Average Rating</div>
                      <div style={{ fontSize: '1.8rem', fontWeight: 800, color: '#f59e0b', display: 'flex', alignItems: 'center', gap: 6 }}>
                        {resultsData.average_stars} <span className="material-symbols-outlined" style={{ fontSize: '1.5rem', color: '#f59e0b', fontVariationSettings: "'FILL' 1" }}>star</span>
                      </div>
                    </div>
                  )}
                </div>

                {(!(!viewingResults.options || viewingResults.options === '[]')) && resultsData.tallies && Object.keys(resultsData.tallies).length > 0 && (
                  <div>
                    <h4 style={{ margin: '0 0 12px' }}>Voting Results</h4>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                      {Object.entries(resultsData.tallies).sort((a, b) => b[1] - a[1]).map(([optionName, count]) => (
                        <div key={optionName} style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                          <div style={{ flex: 1, fontWeight: 600 }}>{optionName}</div>
                          <div style={{ flex: 2, background: 'var(--bg-base)', height: 12, borderRadius: 6, overflow: 'hidden' }}>
                            <div style={{ width: `${(count / resultsData.responded.length) * 100}%`, height: '100%', background: 'var(--brand-primary)' }}></div>
                          </div>
                          <div style={{ width: 40, textAlign: 'right', fontWeight: 800 }}>{count}</div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                <div>
                  <h4 style={{ margin: '0 0 12px' }}>Respondents</h4>
                  {resultsData.responded.length === 0 ? (
                    <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>No responses yet.</p>
                  ) : (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                      {resultsData.responded.map(r => (
                        <div key={r.id} style={{ padding: '12px 16px', background: 'var(--bg-surface)', borderRadius: 8, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                          <div>
                            <div style={{ fontWeight: 600 }}>{r.name}</div>
                            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{r.company}</div>
                          </div>
                          <div style={{ fontSize: '0.75rem', color: 'var(--brand-primary)', fontWeight: 600 }}>{r.vote ? `Voted: ${r.vote}` : 'Responded'}</div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            )}
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            {loading ? (
              <div style={{ textAlign: 'center', padding: 40, color: 'var(--text-muted)' }}>Loading...</div>
            ) : (activeTab === 'active' ? activeSurveys : pastSurveys).length === 0 ? (
              <div className="card" style={{ textAlign: 'center', padding: '60px 20px', color: 'var(--text-muted)' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '3rem', marginBottom: 12 }}>how_to_vote</span>
                <p>No {activeTab} polls found.</p>
              </div>
            ) : (activeTab === 'active' ? activeSurveys : pastSurveys).map(s => (
              <div key={s.id} className="feed-card" style={{ padding: 20 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 12 }}>
                  <div>
                    <span style={{ fontSize: '0.7rem', fontWeight: 800, color: s.type === 'Election' ? '#8b5cf6' : 'var(--brand-primary)', textTransform: 'uppercase', padding: '4px 10px', background: s.type === 'Election' ? 'rgba(139,92,246,0.1)' : 'rgba(240,130,50,0.1)', borderRadius: 20 }}>
                      {s.type}
                    </span>
                    <h3 style={{ margin: '8px 0 4px' }}>{s.title}</h3>
                    <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)' }}>Deadline: {s.deadline || 'No deadline'}</div>
                  </div>
                  <div style={{ display: 'flex', gap: 8 }}>
                    <button className="btn btn-outline btn-sm" onClick={() => viewResults(s)}>View Results</button>
                    <button className="btn btn-ghost btn-sm" style={{ color: 'var(--brand-danger)' }} onClick={() => handleDelete(s.id)}>
                      <span className="material-symbols-outlined">delete</span>
                    </button>
                  </div>
                </div>
                <p style={{ margin: 0, fontSize: '0.85rem', color: 'var(--text-muted)', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>{s.description}</p>
              </div>
            ))}
          </div>
        )}
      </div>
    </AppLayout>
  )
}
