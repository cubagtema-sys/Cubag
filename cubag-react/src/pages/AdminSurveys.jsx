import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

const API_URL = import.meta.env.VITE_API_URL

const TYPE_COLORS = {
  survey:   { bg: 'rgba(59,130,246,0.1)',  color: '#3b82f6',  label: 'Survey' },
  election: { bg: 'rgba(139,92,246,0.1)',  color: '#8b5cf6',  label: 'Election' },
  poll:     { bg: 'rgba(240,130,50,0.1)',  color: '#f08232',  label: 'Poll' },
}

export default function AdminSurveys() {
  const [surveys, setSurveys] = useState([])
  const [loading, setLoading] = useState(true)
  const [tab, setTab] = useState('history')         // 'history' | 'create' | 'participation'
  const [submitting, setSubmitting] = useState(false)
  const [form, setForm] = useState({ title: '', description: '', deadline: '', type: 'survey', options: ['', ''] })

  // Participation state
  const [selectedSurvey, setSelectedSurvey] = useState(null)
  const [participation, setParticipation] = useState(null)
  const [participationLoading, setParticipationLoading] = useState(false)
  const [participationTab, setParticipationTab] = useState('responded') // 'responded' | 'pending'

  const token = localStorage.getItem('cubag_token')

  const fetchSurveys = async () => {
    setLoading(true)
    try {
      const res = await fetch(`${API_URL}/surveys`, {
        headers: { Authorization: `Bearer ${token}` }
      })
      const data = await res.json()
      setSurveys(Array.isArray(data) ? data : [])
    } catch {
      setSurveys([])
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchSurveys() }, [])

  const fetchParticipation = async (survey) => {
    setSelectedSurvey(survey)
    setParticipation(null)
    setParticipationLoading(true)
    setTab('participation')
    try {
      const res = await fetch(`${API_URL}/surveys/${survey.id}/participation`, {
        headers: { Authorization: `Bearer ${token}` }
      })
      const data = await res.json()
      setParticipation(data)
    } catch {
      setParticipation({ responded: [], not_responded: [], total: 0, response_rate: 0 })
    } finally {
      setParticipationLoading(false)
    }
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
      setForm({ title: '', description: '', deadline: '', type: 'survey', options: ['', ''] })
      setTab('history')
      fetchSurveys()
    } catch {
    } finally {
      setSubmitting(false)
    }
  }

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this survey? All responses will also be removed.')) return
    try {
      await fetch(`${API_URL}/surveys/${id}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` }
      })
      if (selectedSurvey?.id === id) { setSelectedSurvey(null); setParticipation(null) }
      fetchSurveys()
    } catch {}
  }

  const addOption = () => setForm(f => ({ ...f, options: [...f.options, ''] }))
  const updateOption = (i, val) => setForm(f => ({ ...f, options: f.options.map((o, idx) => idx === i ? val : o) }))
  const removeOption = (i) => setForm(f => ({ ...f, options: f.options.filter((_, idx) => idx !== i) }))

  const TABS = [
    { id: 'history',       label: `All Surveys (${surveys.length})`, icon: 'history' },
    { id: 'create',        label: 'New Survey',                      icon: 'add_circle' },
    { id: 'participation', label: 'Participation',                    icon: 'bar_chart' },
  ]

  const MemberRow = ({ m, done }) => (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px', background: 'var(--bg-base)', borderRadius: 10, border: `1px solid ${done ? 'rgba(16,185,129,0.2)' : 'var(--border-subtle)'}` }}>
      <div style={{ width: 38, height: 38, borderRadius: '50%', background: done ? 'rgba(16,185,129,0.12)' : 'var(--bg-surface)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: '0.9rem', color: done ? '#10b981' : 'var(--text-muted)', flexShrink: 0 }}>
        {(m.name || 'M').split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2)}
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontWeight: 700, fontSize: '0.88rem', color: 'var(--text-primary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{m.name}</div>
        <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{m.company || m.email}</div>
      </div>
      <span style={{ padding: '3px 10px', borderRadius: 20, fontSize: '0.7rem', fontWeight: 800, background: done ? 'rgba(16,185,129,0.1)' : 'rgba(100,116,139,0.1)', color: done ? '#10b981' : '#64748b', flexShrink: 0 }}>
        {done ? (m.submitted_at ? new Date(m.submitted_at).toLocaleDateString() : 'Responded') : 'Pending'}
      </span>
    </div>
  )

  return (
    <AppLayout title="Surveys & Elections">
      <div style={{ maxWidth: 860, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 24 }}>

        {/* Header */}
        <div>
          <h2 style={{ margin: 0, fontSize: '1.4rem' }}>Surveys & Elections</h2>
          <p style={{ margin: '4px 0 0', color: 'var(--text-muted)', fontSize: '0.88rem' }}>
            Create and manage member surveys, elections, and polls.
          </p>
        </div>

        {/* Tab Bar */}
        <div style={{ display: 'flex', gap: 4, background: 'var(--bg-surface)', borderRadius: 12, padding: 4, flexWrap: 'wrap' }}>
          {TABS.map(t => (
            <button key={t.id} onClick={() => setTab(t.id)} style={{
              flex: 1, minWidth: 100, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
              padding: '10px 12px', borderRadius: 9, border: 'none', cursor: 'pointer',
              fontWeight: 700, fontSize: '0.83rem',
              background: tab === t.id ? (t.id === 'create' ? 'var(--brand-primary)' : '#fff') : 'transparent',
              color: tab === t.id ? (t.id === 'create' ? '#fff' : 'var(--brand-primary)') : 'var(--text-secondary)',
              boxShadow: tab === t.id && t.id !== 'create' ? '0 2px 8px rgba(0,0,0,0.08)' : 'none',
              transition: 'all 0.2s'
            }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>{t.icon}</span>
              {t.label}
            </button>
          ))}
        </div>

        {/* ── HISTORY TAB ── */}
        {tab === 'history' && (
          <div className="card">
            <h3 style={{ marginBottom: 16 }}>All Surveys & Elections</h3>
            {loading ? (
              <div style={{ textAlign: 'center', padding: 40, color: 'var(--text-muted)' }}>Loading...</div>
            ) : surveys.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '40px 20px' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '3rem', color: 'var(--text-muted)', display: 'block', marginBottom: 12 }}>how_to_vote</span>
                <p style={{ color: 'var(--text-muted)', marginBottom: 16 }}>No surveys yet.</p>
                <button className="btn btn-primary" onClick={() => setTab('create')}>Create One</button>
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
                {surveys.map(sv => {
                  const style = TYPE_COLORS[sv.type] || TYPE_COLORS.survey
                  return (
                    <div key={sv.id} style={{ padding: '16px', background: 'var(--bg-base)', borderRadius: 12, border: '1px solid var(--border-subtle)', display: 'flex', flexDirection: 'column', gap: 10 }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: 10 }}>
                        <div style={{ flex: 1, minWidth: 0 }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap', marginBottom: 4 }}>
                            <span style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '0.95rem' }}>{sv.title}</span>
                            <span style={{ padding: '2px 10px', borderRadius: 20, background: style.bg, color: style.color, fontSize: '0.7rem', fontWeight: 800, textTransform: 'uppercase' }}>{style.label}</span>
                          </div>
                          {sv.description && <div style={{ fontSize: '0.83rem', color: 'var(--text-secondary)', marginBottom: 4 }}>{sv.description}</div>}
                          {sv.deadline && (
                            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: 4 }}>
                              <span className="material-symbols-outlined" style={{ fontSize: '0.9rem' }}>event</span>
                              Deadline: {sv.deadline}
                            </div>
                          )}
                        </div>
                        <div style={{ display: 'flex', gap: 8, flexShrink: 0, flexWrap: 'wrap' }}>
                          <button className="btn btn-sm btn-outline" onClick={() => fetchParticipation(sv)}
                            style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                            <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>bar_chart</span> Participation
                          </button>
                          <button className="btn btn-sm btn-danger" onClick={() => handleDelete(sv.id)}>Delete</button>
                        </div>
                      </div>

                      {/* Options chips */}
                      {sv.options && sv.options.length > 0 && (
                        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                          {(typeof sv.options === 'string' ? JSON.parse(sv.options) : sv.options).filter(Boolean).map((opt, i) => (
                            <span key={i} style={{ padding: '3px 10px', background: 'var(--bg-surface)', border: '1px solid var(--border-subtle)', borderRadius: 20, fontSize: '0.75rem', color: 'var(--text-secondary)' }}>
                              {opt}
                            </span>
                          ))}
                        </div>
                      )}
                    </div>
                  )
                })}
              </div>
            )}
          </div>
        )}

        {/* ── CREATE TAB ── */}
        {tab === 'create' && (
          <div className="card">
            <h3 style={{ marginBottom: 20 }}>Create Survey / Election</h3>
            <form onSubmit={handleCreate} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>

              <div className="form-group">
                <label>Title</label>
                <input required value={form.title}
                  onChange={e => setForm({ ...form, title: e.target.value })}
                  placeholder="e.g. Board Elections 2025" />
              </div>

              <div className="form-group">
                <label>Type</label>
                <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
                  {['survey', 'election', 'poll'].map(t => (
                    <button key={t} type="button" onClick={() => setForm({ ...form, type: t })}
                      style={{
                        padding: '8px 18px', borderRadius: 20, border: '2px solid', fontWeight: 700, cursor: 'pointer', textTransform: 'capitalize', fontSize: '0.88rem',
                        borderColor: form.type === t ? TYPE_COLORS[t].color : 'var(--border-default)',
                        background: form.type === t ? TYPE_COLORS[t].bg : 'transparent',
                        color: form.type === t ? TYPE_COLORS[t].color : 'var(--text-secondary)',
                      }}>{t}</button>
                  ))}
                </div>
              </div>

              <div className="form-group">
                <label>Description</label>
                <textarea rows="3" value={form.description}
                  onChange={e => setForm({ ...form, description: e.target.value })}
                  placeholder="Provide context for members..."
                  style={{ resize: 'vertical', borderRadius: 'var(--radius-md)', border: '1.5px solid var(--border-default)', padding: '10px 14px', fontFamily: 'inherit', fontSize: '0.9rem', width: '100%', boxSizing: 'border-box' }}
                />
              </div>

              <div className="form-group">
                <label>Deadline <span style={{ fontWeight: 400, color: 'var(--text-muted)', fontSize: '0.8rem' }}>(optional)</span></label>
                <input type="date" value={form.deadline} onChange={e => setForm({ ...form, deadline: e.target.value })} />
              </div>

              <div className="form-group">
                <label>Options / Candidates</label>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                  {form.options.map((opt, i) => (
                    <div key={i} style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                      <input value={opt} onChange={e => updateOption(i, e.target.value)}
                        placeholder={`Option ${i + 1}`} style={{ flex: 1 }} />
                      {form.options.length > 2 && (
                        <button type="button" onClick={() => removeOption(i)} className="btn btn-ghost btn-sm"
                          style={{ color: '#ef4444', padding: '6px' }}>
                          <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>remove_circle</span>
                        </button>
                      )}
                    </div>
                  ))}
                  <button type="button" onClick={addOption} className="btn btn-outline btn-sm"
                    style={{ alignSelf: 'flex-start', display: 'flex', alignItems: 'center', gap: 6 }}>
                    <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>add</span> Add Option
                  </button>
                </div>
              </div>

              <button type="submit" className="btn btn-primary" disabled={submitting} style={{ width: '100%' }}>
                {submitting ? 'Publishing...' : 'Publish Survey'}
              </button>
            </form>
          </div>
        )}

        {/* ── PARTICIPATION TAB ── */}
        {tab === 'participation' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            {!selectedSurvey ? (
              <div className="card" style={{ textAlign: 'center', padding: '48px 24px' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '3rem', color: 'var(--text-muted)', display: 'block', marginBottom: 12 }}>bar_chart</span>
                <h3 style={{ marginBottom: 8 }}>Select a Survey</h3>
                <p style={{ color: 'var(--text-secondary)', marginBottom: 20 }}>Go to the History tab and click "Participation" on any survey to view member responses.</p>
                <button className="btn btn-primary" onClick={() => setTab('history')}>View Surveys</button>
              </div>
            ) : (
              <>
                {/* Survey Info Header */}
                <div className="card" style={{ padding: '16px 20px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: 12 }}>
                    <div>
                      <div style={{ fontSize: '0.72rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 700, marginBottom: 4 }}>Viewing Participation For</div>
                      <div style={{ fontWeight: 800, fontSize: '1.05rem', color: 'var(--text-primary)' }}>{selectedSurvey.title}</div>
                    </div>
                    <button className="btn btn-ghost btn-sm" onClick={() => { setSelectedSurvey(null); setParticipation(null) }}>
                      <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>close</span> Clear
                    </button>
                  </div>

                  {/* Progress bar */}
                  {participation && (
                    <div style={{ marginTop: 16 }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.78rem', color: 'var(--text-muted)', marginBottom: 6 }}>
                        <span>{participation.responded.length} responded</span>
                        <span>{participation.response_rate}% response rate</span>
                      </div>
                      <div style={{ height: 8, background: 'var(--bg-base)', borderRadius: 4, overflow: 'hidden' }}>
                        <div style={{ height: '100%', width: `${participation.response_rate}%`, background: 'var(--brand-primary)', borderRadius: 4, transition: 'width 0.6s ease' }} />
                      </div>
                      <div style={{ display: 'flex', gap: 16, marginTop: 10, flexWrap: 'wrap' }}>
                        {[
                          { label: 'Total Members', val: participation.total,                         color: '#3b82f6' },
                          { label: 'Responded',     val: participation.responded.length,              color: '#10b981' },
                          { label: 'Pending',       val: participation.not_responded.length,          color: '#f59e0b' },
                        ].map(k => (
                          <div key={k.label} style={{ textAlign: 'center', flex: 1, minWidth: 80 }}>
                            <div style={{ fontSize: '1.4rem', fontWeight: 800, color: k.color }}>{k.val}</div>
                            <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase' }}>{k.label}</div>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </div>

                {/* Sub-tabs */}
                <div style={{ display: 'flex', gap: 4, background: 'var(--bg-surface)', borderRadius: 10, padding: 4 }}>
                  {[
                    { id: 'responded', label: `Responded (${participation?.responded?.length ?? '…'})`, icon: 'check_circle' },
                    { id: 'pending',   label: `Pending (${participation?.not_responded?.length ?? '…'})`, icon: 'schedule' },
                  ].map(t => (
                    <button key={t.id} onClick={() => setParticipationTab(t.id)} style={{
                      flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
                      padding: '9px 12px', borderRadius: 8, border: 'none', cursor: 'pointer', fontWeight: 700, fontSize: '0.82rem',
                      background: participationTab === t.id ? '#fff' : 'transparent',
                      color: participationTab === t.id ? (t.id === 'responded' ? '#10b981' : '#f59e0b') : 'var(--text-secondary)',
                      boxShadow: participationTab === t.id ? '0 2px 8px rgba(0,0,0,0.08)' : 'none',
                      transition: 'all 0.2s'
                    }}>
                      <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>{t.icon}</span>
                      {t.label}
                    </button>
                  ))}
                </div>

                {/* Member list */}
                {participationLoading ? (
                  <div style={{ textAlign: 'center', padding: 40, color: 'var(--text-muted)' }}>
                    <div className="spinner" style={{ margin: '0 auto 12px' }} />
                    Loading participation data...
                  </div>
                ) : (
                  <div className="card" style={{ padding: '12px' }}>
                    {participationTab === 'responded' && (
                      participation?.responded?.length === 0 ? (
                        <div style={{ textAlign: 'center', padding: '32px 16px', color: 'var(--text-muted)' }}>
                          <span className="material-symbols-outlined" style={{ fontSize: '2.5rem', display: 'block', marginBottom: 8 }}>how_to_vote</span>
                          No responses yet.
                        </div>
                      ) : (
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                          {participation?.responded?.map(m => <MemberRow key={m.id} m={m} done={true} />)}
                        </div>
                      )
                    )}
                    {participationTab === 'pending' && (
                      participation?.not_responded?.length === 0 ? (
                        <div style={{ textAlign: 'center', padding: '32px 16px', color: '#10b981' }}>
                          <span className="material-symbols-outlined" style={{ fontSize: '2.5rem', display: 'block', marginBottom: 8 }}>verified</span>
                          All members have responded!
                        </div>
                      ) : (
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                          {participation?.not_responded?.map(m => <MemberRow key={m.id} m={m} done={false} />)}
                        </div>
                      )
                    )}
                  </div>
                )}
              </>
            )}
          </div>
        )}

      </div>
    </AppLayout>
  )
}
