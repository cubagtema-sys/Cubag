import { useState, useEffect, useRef } from 'react'
import AppLayout from '../components/AppLayout'
import useAutoRefresh from '../hooks/useAutoRefresh'

const API_URL = import.meta.env.VITE_API_URL
const AUTH = () => ({ 'Authorization': `Bearer ${localStorage.getItem('cubag_token')}` })

export default function Tasks() {
  const [tasks, setTasks] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [modal, setModal] = useState(null)       // task being submitted
  const [note, setNote] = useState('')
  const [files, setFiles] = useState([])
  const [submitting, setSubmitting] = useState(false)
  const [submitDone, setSubmitDone] = useState(false)
  const fileRef = useRef()

  const fetchTasks = async () => {
    try {
      setLoading(true)
      const res = await fetch(`${API_URL}/tasks`, { headers: AUTH() })
      if (!res.ok) throw new Error('Failed to fetch tasks')
      setTasks(await res.json())
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  useAutoRefresh(fetchTasks, 30000)

  const openModal = (task) => {
    setModal(task)
    setNote('')
    setFiles([])
    setSubmitDone(false)
  }
  const closeModal = () => { setModal(null); setFiles([]) }

  const handleFileChange = (e) => {
    const selected = Array.from(e.target.files)
    setFiles(prev => [...prev, ...selected])
  }

  const removeFile = (idx) => setFiles(prev => prev.filter((_, i) => i !== idx))

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!modal) return
    setSubmitting(true)
    const fd = new FormData()
    fd.append('note', note)
    files.forEach(f => fd.append('files', f))
    try {
      const res = await fetch(`${API_URL}/tasks/${modal.id}/submit`, {
        method: 'POST',
        headers: AUTH(),
        body: fd
      })
      if (res.ok) {
        setSubmitDone(true)
        fetchTasks()
        setTimeout(closeModal, 2000)
      }
    } catch (err) {
      console.error(err)
    } finally {
      setSubmitting(false)
    }
  }

  const fileIcon = (type = '') => {
    if (type.startsWith('image')) return 'image'
    if (type.includes('pdf')) return 'picture_as_pdf'
    if (type.includes('video')) return 'videocam'
    if (type.includes('word') || type.includes('doc')) return 'description'
    return 'attach_file'
  }

  const formatSize = (bytes) => bytes < 1024 * 1024
    ? `${(bytes / 1024).toFixed(1)} KB`
    : `${(bytes / 1024 / 1024).toFixed(1)} MB`

  return (
    <AppLayout title="Tasks & Compliance">
      <div style={{ maxWidth: 800, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 24 }}>

        {/* Banner */}
        <div className="feed-card" style={{ background: 'var(--gradient-brand)', color: '#fff', border: 'none' }}>
          <div className="card-body" style={{ display: 'flex', alignItems: 'center', gap: 20, padding: '24px' }}>
            <div style={{ width: 60, height: 60, borderRadius: '50%', background: 'rgba(255,255,255,0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '2rem', animation: loading ? 'spin 1s linear infinite' : 'none' }}>
                {loading ? 'sync' : tasks.filter(t => !t.done).length > 0 ? 'assignment_late' : 'verified_user'}
              </span>
            </div>
            <div>
              <h2 style={{ fontSize: '1.25rem', marginBottom: 4 }}>Compliance Status</h2>
              <p style={{ opacity: 0.9, fontSize: '0.9rem' }}>
                {tasks.length > 0
                  ? `${tasks.filter(t => !t.done).length} pending · ${tasks.filter(t => t.admin_verified).length} verified by admin`
                  : 'Checking your compliance records...'}
              </p>
            </div>
          </div>
        </div>

        {loading ? (
          <div style={{ minHeight: 300, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', background: 'var(--bg-card)', borderRadius: 'var(--radius-xl)', border: '1px solid var(--border-subtle)' }}>
            <div className="spinner" style={{ marginBottom: 16 }} />
            <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', fontWeight: 600, letterSpacing: '0.05em' }}>SYNCING COMPLIANCE RECORDS</div>
          </div>
        ) : error ? (
          <div className="feed-card" style={{ border: '1px solid var(--brand-danger)', background: 'rgba(239,68,68,0.05)' }}>
            <div className="card-body" style={{ textAlign: 'center', padding: '48px 20px' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '3rem', color: 'var(--brand-danger)', marginBottom: 16 }}>cloud_off</span>
              <h3 style={{ marginBottom: 8 }}>Connection Failed</h3>
              <button className="btn btn-primary" style={{ background: 'var(--brand-danger)' }} onClick={() => window.location.reload()}>Retry</button>
            </div>
          </div>
        ) : tasks.length === 0 ? (
          <div className="feed-card">
            <div className="card-body" style={{ textAlign: 'center', padding: '60px 20px' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '2.5rem', color: 'var(--text-muted)' }}>inventory_2</span>
              <h3 style={{ marginTop: 16 }}>All caught up!</h3>
              <p style={{ color: 'var(--text-secondary)' }}>No pending compliance tasks at this time.</p>
            </div>
          </div>
        ) : (
          <div className="feed-card">
            <div className="card-header"><span className="card-title">Compliance Requirements</span></div>
            <div className="card-body" style={{ padding: 0 }}>
              {tasks.map(task => {
                const submitted = !!task.submission_id
                const verified = task.admin_verified
                return (
                  <div key={task.id} style={{ padding: '20px', borderBottom: '1px solid var(--border-subtle)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12 }}>
                    <div style={{ display: 'flex', gap: 16, alignItems: 'center', flex: 1, minWidth: 0 }}>
                      <div style={{ width: 44, height: 44, borderRadius: 12, flexShrink: 0,
                        background: verified ? 'rgba(16,185,129,0.1)' : submitted ? 'rgba(59,130,246,0.1)' : 'rgba(240,130,50,0.1)',
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        color: verified ? '#10b981' : submitted ? '#3b82f6' : 'var(--brand-primary)'
                      }}>
                        <span className="material-symbols-outlined">{verified ? 'verified' : submitted ? 'hourglass_top' : 'description'}</span>
                      </div>
                      <div style={{ minWidth: 0 }}>
                        <div style={{ fontWeight: 600, color: 'var(--text-primary)' }}>{task.title}</div>
                        <div style={{ fontSize: '0.8rem', marginTop: 2,
                          color: verified ? '#10b981' : submitted ? '#3b82f6' : task.urgent ? 'var(--brand-danger)' : 'var(--text-muted)'
                        }}>
                          {verified ? '✅ Verified by admin' : submitted ? '⏳ Awaiting admin review' : task.due_date ? `Due: ${task.due_date}` : 'No due date'}
                        </div>
                        {task.description && <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', marginTop: 2 }}>{task.description}</div>}
                      </div>
                    </div>
                    {!submitted && (
                      <button className="btn btn-primary btn-sm" onClick={() => openModal(task)} style={{ flexShrink: 0 }}>
                        <span className="material-symbols-outlined" style={{ fontSize: '1rem', marginRight: 4 }}>upload</span>
                        Submit
                      </button>
                    )}
                  </div>
                )
              })}
            </div>
          </div>
        )}
      </div>

      {/* ── Submission Modal ─────────────────────────────────────────────────── */}
      {modal && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.55)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16 }}>
          <div style={{ background: 'var(--bg-card)', borderRadius: 20, width: '100%', maxWidth: 560, maxHeight: '90vh', overflowY: 'auto', padding: 32, position: 'relative', boxShadow: '0 24px 64px rgba(0,0,0,0.4)' }}>
            <button onClick={closeModal} style={{ position: 'absolute', top: 16, right: 16, background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)' }}>
              <span className="material-symbols-outlined">close</span>
            </button>

            {submitDone ? (
              <div style={{ textAlign: 'center', padding: '32px 0' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '4rem', color: '#10b981' }}>check_circle</span>
                <h3 style={{ marginTop: 16 }}>Submitted!</h3>
                <p style={{ color: 'var(--text-secondary)' }}>Your evidence has been sent for admin review.</p>
              </div>
            ) : (
              <>
                <div style={{ marginBottom: 24 }}>
                  <h3 style={{ margin: 0, fontSize: '1.2rem' }}>Submit Task Evidence</h3>
                  <p style={{ margin: '6px 0 0', fontSize: '0.88rem', color: 'var(--text-secondary)' }}>{modal.title}</p>
                </div>

                <form onSubmit={handleSubmit}>
                  {/* Completion note */}
                  <div className="form-group" style={{ marginBottom: 20 }}>
                    <label style={{ fontWeight: 700, fontSize: '0.85rem' }}>Completion Notes</label>
                    <textarea
                      rows={4}
                      value={note}
                      onChange={e => setNote(e.target.value)}
                      placeholder="Describe what you did to complete this task..."
                      style={{ width: '100%', padding: 12, border: '2px solid var(--border-subtle)', borderRadius: 10, background: 'var(--bg-base)', color: 'var(--text-primary)', resize: 'vertical', fontFamily: 'inherit', boxSizing: 'border-box' }}
                    />
                  </div>

                  {/* File upload */}
                  <div className="form-group" style={{ marginBottom: 20 }}>
                    <label style={{ fontWeight: 700, fontSize: '0.85rem' }}>Attachments <span style={{ fontWeight: 400, color: 'var(--text-muted)' }}>(images, PDF, Word, video)</span></label>
                    <input ref={fileRef} type="file" multiple accept="image/*,.pdf,.doc,.docx,.xls,.xlsx,.mp4,.mov,.avi,.txt" onChange={handleFileChange} style={{ display: 'none' }} />
                    <div
                      onClick={() => fileRef.current.click()}
                      style={{ border: '2px dashed var(--border-subtle)', borderRadius: 12, padding: '28px 16px', textAlign: 'center', cursor: 'pointer', background: 'var(--bg-base)', transition: 'border-color 0.2s' }}
                      onMouseOver={e => e.currentTarget.style.borderColor = 'var(--brand-primary)'}
                      onMouseOut={e => e.currentTarget.style.borderColor = 'var(--border-subtle)'}
                    >
                      <span className="material-symbols-outlined" style={{ fontSize: '2rem', color: 'var(--text-muted)', display: 'block', marginBottom: 8 }}>cloud_upload</span>
                      <div style={{ fontSize: '0.88rem', color: 'var(--text-secondary)' }}>Click to attach files</div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: 4 }}>Images · PDF · Word · Video</div>
                    </div>

                    {/* File list */}
                    {files.length > 0 && (
                      <div style={{ marginTop: 12, display: 'flex', flexDirection: 'column', gap: 8 }}>
                        {files.map((f, i) => (
                          <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 12px', background: 'var(--bg-elevated)', borderRadius: 8, border: '1px solid var(--border-subtle)' }}>
                            <span className="material-symbols-outlined" style={{ fontSize: '1.2rem', color: 'var(--brand-primary)' }}>{fileIcon(f.type)}</span>
                            <div style={{ flex: 1, minWidth: 0 }}>
                              <div style={{ fontSize: '0.85rem', fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{f.name}</div>
                              <div style={{ fontSize: '0.72rem', color: 'var(--text-muted)' }}>{formatSize(f.size)}</div>
                            </div>
                            <button type="button" onClick={() => removeFile(i)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)' }}>
                              <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>close</span>
                            </button>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>

                  <button type="submit" className="btn btn-primary btn-lg" style={{ width: '100%' }} disabled={submitting}>
                    {submitting ? 'Submitting...' : 'Submit for Admin Review'}
                  </button>
                </form>
              </>
            )}
          </div>
        </div>
      )}
    </AppLayout>
  )
}
