import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout.jsx'
import CustomSelect from '../components/CustomSelect.jsx'
import useAutoRefresh from '../hooks/useAutoRefresh'

const API_URL = import.meta.env.VITE_API_URL
const AUTH = () => ({
  'Content-Type': 'application/json',
  'Authorization': `Bearer ${localStorage.getItem('cubag_token')}`
})

export default function AdminTasks() {
  const [tasks, setTasks] = useState([])
  const [members, setMembers] = useState([])
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [dueDate, setDueDate] = useState('')
  const [memberId, setMemberId] = useState('')
  const [message, setMessage] = useState('')
  const [activeTab, setActiveTab] = useState('create')
  const [selectedAssignment, setSelectedAssignment] = useState(null)
  const [verifyingId, setVerifyingId] = useState(null)
  const [verifyNotes, setVerifyNotes] = useState({})
  const [viewFile, setViewFile] = useState(null) // { url, type, name }
  const [historyPage, setHistoryPage] = useState(1)
  const [submissionsPage, setSubmissionsPage] = useState(1)

  const PAGE_SIZE = 8

  const fetchData = async () => {
    try {
      const [memRes, taskRes] = await Promise.all([
        fetch(`${API_URL}/members`, { headers: AUTH() }),
        fetch(`${API_URL}/tasks/admin/all`, { headers: AUTH() })
      ])
      if (memRes.ok) setMembers(await memRes.json())
      if (taskRes.ok) setTasks(await taskRes.json())
    } catch (e) { console.error(e) }
  }

  useAutoRefresh(fetchData, 30000)

  const handleSubmit = async (e) => {
    e.preventDefault()
    try {
      const res = await fetch(`${API_URL}/tasks/admin/create`, {
        method: 'POST',
        headers: AUTH(),
        body: JSON.stringify({ title, description, due_date: dueDate, member_id: memberId })
      })
      if (res.ok) {
        setMessage('Task successfully assigned.')
        setTitle(''); setDescription(''); setDueDate(''); setMemberId('')
        fetchData()
        setTimeout(() => setMessage(''), 3000)
      } else {
        setMessage('Failed to assign task.')
      }
    } catch (e) { setMessage('Network error.') }
  }

  const handleVerify = async (submissionId) => {
    try {
      const res = await fetch(`${API_URL}/tasks/admin/${submissionId}/verify`, {
        method: 'PATCH',
        headers: AUTH(),
        body: JSON.stringify({ admin_notes: verifyNotes[submissionId] || '' })
      })
      if (res.ok) { fetchData(); setVerifyingId(null) }
    } catch (e) { console.error(e) }
  }

  const fileIcon = (type = '') => {
    if (type.includes('image')) return 'image'
    if (type.includes('pdf')) return 'picture_as_pdf'
    if (type.includes('video')) return 'videocam'
    if (type.includes('word') || type.includes('doc')) return 'description'
    return 'attach_file'
  }

  const triggerDownload = async (url, filename) => {
    try {
      const res = await fetch(url)
      const blob = await res.blob()
      const link = document.createElement('a')
      link.href = URL.createObjectURL(blob)
      link.download = filename
      document.body.appendChild(link)
      link.click()
      link.remove()
      URL.revokeObjectURL(link.href)
    } catch (e) {
      console.error('Download failed', e)
    }
  }

  // Group tasks by title+due_date for history view
  const groupedTasks = {}
  tasks.forEach(task => {
    const key = `${task.title}|${task.due_date}`
    if (!groupedTasks[key]) {
      groupedTasks[key] = { title: task.title, description: task.description, due_date: task.due_date, total: 0, completed: 0, members: [] }
    }
    groupedTasks[key].total += 1
    if (task.done) groupedTasks[key].completed += 1
    groupedTasks[key].members.push(task)
  })
  const assignmentGroups = Object.values(groupedTasks).sort((a, b) => new Date(b.due_date) - new Date(a.due_date))

  const submissions = tasks.filter(t => t.submission_id)
  const pendingVerify = submissions.filter(t => !t.admin_verified).length

  const paginatedHistory = assignmentGroups.slice((historyPage - 1) * PAGE_SIZE, historyPage * PAGE_SIZE)
  const totalHistoryPages = Math.ceil(assignmentGroups.length / PAGE_SIZE)

  const paginatedSubmissions = submissions.slice((submissionsPage - 1) * PAGE_SIZE, submissionsPage * PAGE_SIZE)
  const totalSubmissionsPages = Math.ceil(submissions.length / PAGE_SIZE)

  return (
    <AppLayout title="Compliance Control">
      <div style={{ maxWidth: 1000, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16 }}>

        {/* Page Title removed as it is now in the header */}

        {/* Tab bar */}
        <div style={{ display: 'flex', gap: 3, background: 'var(--bg-surface)', borderRadius: 10, padding: 3, flexWrap: 'wrap' }}>
          {[
            { id: 'create', label: 'Assign', icon: 'assignment_add' },
            { id: 'history', label: 'History', icon: 'history' },
            { id: 'submissions', label: 'Submissions', icon: 'inbox', badge: pendingVerify }
          ].map(t => (
            <button key={t.id} onClick={() => { setActiveTab(t.id); setSelectedAssignment(null) }} style={{
              flex: 1, minWidth: 90, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
              padding: '8px 10px', borderRadius: 8, border: 'none', cursor: 'pointer',
              fontWeight: 700, fontSize: '0.75rem',
              background: activeTab === t.id ? 'var(--brand-primary)' : 'transparent',
              color: activeTab === t.id ? '#fff' : 'var(--text-secondary)',
              transition: 'all 0.2s'
            }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>{t.icon}</span>
              {t.label}
              {t.badge > 0 && <span style={{ marginLeft: 4, background: '#ef4444', borderRadius: 12, padding: '1px 6px', fontSize: '0.6rem', color: '#fff' }}>{t.badge}</span>}
            </button>
          ))}
        </div>

        {/* ── CREATE TAB ─────────────────────────────────────────────────────── */}
        {activeTab === 'create' && (
          <div className="feed-card" style={{ maxWidth: 600, margin: '0 auto', width: '100%', borderRadius: 12 }}>
            <div className="card-header" style={{ padding: '12px 16px' }}><span className="card-title">New Assignment</span></div>
            <div className="card-body" style={{ padding: '16px' }}>
              {message && (
                <div style={{ padding: '10px 14px', background: message.includes('success') ? '#10b981' : '#ef4444', color: '#fff', borderRadius: 8, marginBottom: 16, fontSize: '0.8rem', fontWeight: 600 }}>
                  {message}
                </div>
              )}
              <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700, marginBottom: 4 }}>Assign To</label>
                  <CustomSelect
                    options={[
                      { value: '', label: 'Select a member...' },
                      { value: 'all', label: 'All Active Members' },
                      ...members.map(m => ({ value: m.id.toString(), label: `${m.name}` }))
                    ]}
                    value={memberId.toString()}
                    onChange={setMemberId}
                  />
                </div>
                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700, marginBottom: 4 }}>Task Title</label>
                  <input type="text" required value={title} onChange={e => setTitle(e.target.value)} placeholder="Title..." style={{ padding: '10px 12px', fontSize: '0.9rem' }} />
                </div>
                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700, marginBottom: 4 }}>Due Date</label>
                  <input type="date" required value={dueDate} onChange={e => setDueDate(e.target.value)} style={{ padding: '10px 12px', fontSize: '0.9rem' }} />
                </div>
                <div className="form-group">
                  <label style={{ fontSize: '0.8rem', fontWeight: 700, marginBottom: 4 }}>Instructions</label>
                  <textarea required value={description} onChange={e => setDescription(e.target.value)} rows="4" placeholder="Task details..." style={{ padding: '10px 12px', fontSize: '0.9rem', borderRadius: 8, border: '1.5px solid var(--border-default)', outline: 'none' }} />
                </div>
                <button type="submit" className="btn btn-primary btn-full" style={{ height: 48, fontSize: '0.9rem' }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>send</span> Assign Now
                </button>
              </form>
            </div>
          </div>
        )}

        {/* ── SUBMISSIONS TAB ────────────────────────────────────────────────── */}
        {activeTab === 'submissions' && (
          <div className="card">
            <div style={{ marginBottom: 20 }}>
              <h3 style={{ margin: 0 }}>Member Submissions</h3>
              <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginTop: 4 }}>Review evidence submitted by members and mark tasks as verified.</p>
            </div>
            {submissions.length === 0 ? (
              <div style={{ textAlign: 'center', padding: 48, color: 'var(--text-muted)' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '2.5rem', display: 'block', marginBottom: 8 }}>inbox</span>
                No submissions yet.
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                {paginatedSubmissions.map((task, i) => (
                  <div key={i} style={{ border: '1px solid var(--border-subtle)', borderRadius: 12, overflow: 'hidden' }}>

                    {/* Header */}
                    <div style={{ padding: '14px 20px', background: task.admin_verified ? 'rgba(16,185,129,0.06)' : 'rgba(59,130,246,0.04)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 10 }}>
                      <div>
                        <div style={{ fontWeight: 700, fontSize: '0.95rem' }}>{task.title}</div>
                        <div style={{ fontSize: '0.8rem', color: 'var(--brand-primary)', display: 'flex', alignItems: 'center', gap: 4, marginTop: 4 }}>
                          <span className="material-symbols-outlined" style={{ fontSize: '0.9rem' }}>person</span>
                          {task.member_name}
                          <span style={{ color: 'var(--text-muted)', marginLeft: 6 }}>
                            · Submitted {task.submitted_at ? new Date(task.submitted_at).toLocaleDateString() : ''}
                          </span>
                        </div>
                      </div>
                      {task.admin_verified ? (
                        <span style={{ display: 'flex', alignItems: 'center', gap: 6, background: 'rgba(16,185,129,0.1)', color: '#10b981', borderRadius: 20, padding: '4px 14px', fontSize: '0.8rem', fontWeight: 800 }}>
                          <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>verified</span> Verified
                        </span>
                      ) : (
                        <button className="btn btn-primary btn-sm"
                          onClick={() => setVerifyingId(verifyingId === task.submission_id ? null : task.submission_id)}>
                          <span className="material-symbols-outlined" style={{ fontSize: '1rem', marginRight: 4 }}>check_circle</span>
                          Mark Verified
                        </button>
                      )}
                    </div>

                    {/* Completion note */}
                    {task.completion_note && (
                      <div style={{ padding: '12px 20px', borderBottom: '1px solid var(--border-subtle)', background: 'var(--bg-base)' }}>
                        <div style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-muted)', marginBottom: 6 }}>MEMBER NOTE</div>
                        <p style={{ margin: 0, fontSize: '0.9rem', color: 'var(--text-secondary)', lineHeight: 1.6 }}>{task.completion_note}</p>
                      </div>
                    )}

                    {/* Files */}
                    {task.files && task.files.length > 0 && (
                      <div style={{ padding: '12px 20px', borderBottom: '1px solid var(--border-subtle)' }}>
                        <div style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-muted)', marginBottom: 8 }}>ATTACHMENTS ({task.files.length})</div>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                          {task.files.map((f, fi) => {
                            const fileUrl = `${API_URL}/tasks/uploads/${f.filename}`
                            const isViewable = f.file_type?.startsWith('image') || f.file_type?.includes('pdf')
                            return (
                              <div key={fi} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 12px', background: 'var(--bg-elevated)', borderRadius: 8, border: '1px solid var(--border-subtle)' }}>
                                <span className="material-symbols-outlined" style={{ fontSize: '1.2rem', color: 'var(--brand-primary)', flexShrink: 0 }}>{fileIcon(f.file_type)}</span>
                                <div style={{ flex: 1, minWidth: 0 }}>
                                  <div style={{ fontSize: '0.85rem', fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{f.original_name}</div>
                                  <div style={{ fontSize: '0.72rem', color: 'var(--text-muted)' }}>{f.file_type}</div>
                                </div>
                                <div style={{ display: 'flex', gap: 6, flexShrink: 0 }}>
                                  {isViewable && (
                                    <button onClick={() => setViewFile({ url: fileUrl, type: f.file_type, name: f.original_name })}
                                      style={{ display: 'flex', alignItems: 'center', gap: 4, padding: '5px 10px', border: '1px solid var(--border-subtle)', borderRadius: 6, background: 'var(--bg-base)', cursor: 'pointer', fontSize: '0.8rem', fontWeight: 600, color: 'var(--brand-primary)' }}>
                                      <span className="material-symbols-outlined" style={{ fontSize: '0.95rem' }}>visibility</span> View
                                    </button>
                                  )}
                                  <button onClick={() => triggerDownload(fileUrl, f.original_name)}
                                    style={{ display: 'flex', alignItems: 'center', gap: 4, padding: '5px 10px', border: '1px solid var(--border-subtle)', borderRadius: 6, background: 'var(--bg-base)', cursor: 'pointer', fontSize: '0.8rem', fontWeight: 600, color: 'var(--text-secondary)' }}>
                                    <span className="material-symbols-outlined" style={{ fontSize: '0.95rem' }}>download</span> Download
                                  </button>
                                </div>
                              </div>
                            )
                          })}
                        </div>
                      </div>
                    )}

                    {/* Verify panel */}
                    {verifyingId === task.submission_id && (
                      <div style={{ padding: '16px 20px', background: 'rgba(16,185,129,0.04)', borderTop: '1px solid rgba(16,185,129,0.15)' }}>
                        <label style={{ fontWeight: 700, fontSize: '0.85rem', display: 'block', marginBottom: 8 }}>Admin Notes (optional)</label>
                        <textarea rows={2} placeholder="Any notes for the member..."
                          value={verifyNotes[task.submission_id] || ''}
                          onChange={e => setVerifyNotes(prev => ({ ...prev, [task.submission_id]: e.target.value }))}
                          style={{ width: '100%', padding: 10, border: '1px solid var(--border-subtle)', borderRadius: 8, background: 'var(--bg-base)', fontFamily: 'inherit', boxSizing: 'border-box', marginBottom: 12 }}
                        />
                        <div style={{ display: 'flex', gap: 10 }}>
                          <button className="btn btn-primary" onClick={() => handleVerify(task.submission_id)}>
                            <span className="material-symbols-outlined" style={{ fontSize: '1rem', marginRight: 4 }}>verified</span>Confirm Verified
                          </button>
                          <button className="btn btn-ghost" onClick={() => setVerifyingId(null)}>Cancel</button>
                        </div>
                      </div>
                    )}
                  </div>
                ))}

                {/* Submissions Pagination Controls */}
                {totalSubmissionsPages > 1 && (
                  <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 8, padding: '12px 0' }}>
                    <button
                      onClick={() => setSubmissionsPage(p => Math.max(1, p - 1))}
                      disabled={submissionsPage === 1}
                      style={{ padding: '6px 14px', borderRadius: 8, border: '1px solid var(--border-subtle)', background: 'var(--bg-card)', color: submissionsPage === 1 ? 'var(--text-muted)' : 'var(--text-primary)', cursor: submissionsPage === 1 ? 'default' : 'pointer', fontWeight: 600, opacity: submissionsPage === 1 ? 0.5 : 1 }}
                    >← Prev</button>
                    {Array.from({ length: totalSubmissionsPages }, (_, i) => i + 1).map(n => (
                      <button key={n} onClick={() => setSubmissionsPage(n)} style={{ width: 34, height: 34, borderRadius: 8, border: 'none', background: submissionsPage === n ? 'var(--brand-primary)' : 'var(--bg-card)', color: submissionsPage === n ? '#fff' : 'var(--text-secondary)', fontWeight: 700, cursor: 'pointer' }}>{n}</button>
                    ))}
                    <button
                      onClick={() => setSubmissionsPage(p => Math.min(totalSubmissionsPages, p + 1))}
                      disabled={submissionsPage === totalSubmissionsPages}
                      style={{ padding: '6px 14px', borderRadius: 8, border: '1px solid var(--border-subtle)', background: 'var(--bg-card)', color: submissionsPage === totalSubmissionsPages ? 'var(--text-muted)' : 'var(--text-primary)', cursor: submissionsPage === totalSubmissionsPages ? 'default' : 'pointer', fontWeight: 600, opacity: submissionsPage === totalSubmissionsPages ? 0.5 : 1 }}
                    >Next →</button>
                  </div>
                )}
              </div>
            )}
          </div>
        )}

        {/* ── HISTORY TAB ────────────────────────────────────────────────────── */}
        {activeTab === 'history' && (
          selectedAssignment ? (
            <div className="card">
              <button className="btn btn-ghost btn-sm" style={{ marginBottom: 16, display: 'flex', alignItems: 'center', gap: 8 }} onClick={() => setSelectedAssignment(null)}>
                <span className="material-symbols-outlined">arrow_back</span> Back to Assignments
              </button>
              <div style={{ marginBottom: 24 }}>
                <h3 style={{ margin: 0 }}>{selectedAssignment.title}</h3>
                <p style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', marginTop: 4 }}>Due: {new Date(selectedAssignment.due_date).toLocaleDateString()}</p>
                <div style={{ marginTop: 12, padding: 12, background: 'var(--bg-elevated)', borderRadius: 8, fontSize: '0.9rem', color: 'var(--text-secondary)' }}>
                  {selectedAssignment.description}
                </div>
              </div>
              <h4 style={{ marginBottom: 12 }}>Member Status ({selectedAssignment.completed}/{selectedAssignment.total} Completed)</h4>
              <table style={{ width: '100%', textAlign: 'left', borderCollapse: 'collapse' }}>
                <thead>
                  <tr style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                    <th style={{ padding: 12, color: 'var(--text-muted)', fontSize: '0.85rem' }}>Member</th>
                    <th style={{ padding: 12, color: 'var(--text-muted)', fontSize: '0.85rem' }}>Status</th>
                    <th style={{ padding: 12, color: 'var(--text-muted)', fontSize: '0.85rem' }}>Verified</th>
                  </tr>
                </thead>
                <tbody>
                  {selectedAssignment.members.map((m, i) => (
                    <tr key={i} style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                      <td style={{ padding: 12, fontWeight: 600 }}>{m.member_name}</td>
                      <td style={{ padding: 12 }}>
                        <span className={`badge ${m.done ? 'badge-success' : 'badge-warning'}`}>{m.done ? 'Submitted' : 'Pending'}</span>
                      </td>
                      <td style={{ padding: 12, fontSize: '0.85rem' }}>
                        {m.admin_verified
                          ? <span style={{ color: '#10b981', fontWeight: 700 }}>✅ Verified</span>
                          : m.submission_id
                            ? <span style={{ color: '#f59e0b' }}>⏳ Awaiting review</span>
                            : <span style={{ color: 'var(--text-muted)' }}>—</span>}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="card">
              <h3 style={{ marginBottom: 16 }}>Assignment History</h3>
              <div className="responsive-table-wrapper">
                <table className="responsive-table" style={{ width: '100%', textAlign: 'left', borderCollapse: 'collapse' }}>
                  <thead>
                    <tr style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                      <th style={{ padding: 12, color: 'var(--text-muted)', fontSize: '0.85rem' }}>Assignment</th>
                      <th style={{ padding: 12, color: 'var(--text-muted)', fontSize: '0.85rem' }}>Due Date</th>
                      <th style={{ padding: 12, color: 'var(--text-muted)', fontSize: '0.85rem' }}>Rate</th>
                      <th style={{ padding: 12, color: 'var(--text-muted)', fontSize: '0.85rem' }}>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {paginatedHistory.map((group, i) => {
                      const isOverdue = new Date(group.due_date) < new Date() && group.completed < group.total
                      return (
                        <tr key={i} style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                          <td style={{ padding: 12 }}>
                            <div style={{ fontWeight: 600 }}>{group.title}</div>
                            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{(group.description || '').substring(0, 50)}...</div>
                          </td>
                          <td style={{ padding: 12, color: isOverdue ? 'var(--brand-danger)' : 'var(--text-secondary)', fontWeight: isOverdue ? 700 : 400 }}>
                            {new Date(group.due_date).toLocaleDateString()}
                          </td>
                          <td style={{ padding: 12 }}>
                            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                              <div style={{ width: 80, height: 6, background: 'var(--border-subtle)', borderRadius: 3, overflow: 'hidden' }}>
                                <div style={{ width: `${(group.completed / group.total) * 100}%`, height: '100%', background: group.completed === group.total ? 'var(--brand-success)' : 'var(--brand-primary)' }} />
                              </div>
                              <span style={{ fontSize: '0.8rem', fontWeight: 600 }}>{group.completed}/{group.total}</span>
                            </div>
                          </td>
                          <td style={{ padding: 12 }}>
                            <button className="btn btn-outline btn-sm" onClick={() => setSelectedAssignment(group)}>View</button>
                          </td>
                        </tr>
                      )
                    })}
                    {assignmentGroups.length === 0 && (
                      <tr><td colSpan="4" style={{ padding: 24, textAlign: 'center', color: 'var(--text-muted)' }}>No assignments found.</td></tr>
                    )}
                  </tbody>
                </table>
              </div>

              {/* History Pagination Controls */}
              {totalHistoryPages > 1 && (
                <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 8, padding: '12px 0', marginTop: 12 }}>
                  <button
                    onClick={() => setHistoryPage(p => Math.max(1, p - 1))}
                    disabled={historyPage === 1}
                    style={{ padding: '6px 14px', borderRadius: 8, border: '1px solid var(--border-subtle)', background: 'var(--bg-card)', color: historyPage === 1 ? 'var(--text-muted)' : 'var(--text-primary)', cursor: historyPage === 1 ? 'default' : 'pointer', fontWeight: 600, opacity: historyPage === 1 ? 0.5 : 1 }}
                  >← Prev</button>
                  {Array.from({ length: totalHistoryPages }, (_, i) => i + 1).map(n => (
                    <button key={n} onClick={() => setHistoryPage(n)} style={{ width: 34, height: 34, borderRadius: 8, border: 'none', background: historyPage === n ? 'var(--brand-primary)' : 'var(--bg-card)', color: historyPage === n ? '#fff' : 'var(--text-secondary)', fontWeight: 700, cursor: 'pointer' }}>{n}</button>
                  ))}
                  <button
                    onClick={() => setHistoryPage(p => Math.min(totalHistoryPages, p + 1))}
                    disabled={historyPage === totalHistoryPages}
                    style={{ padding: '6px 14px', borderRadius: 8, border: '1px solid var(--border-subtle)', background: 'var(--bg-card)', color: historyPage === totalHistoryPages ? 'var(--text-muted)' : 'var(--text-primary)', cursor: historyPage === totalHistoryPages ? 'default' : 'pointer', fontWeight: 600, opacity: historyPage === totalHistoryPages ? 0.5 : 1 }}
                  >Next →</button>
                </div>
              )}
            </div>
          )
        )}

      </div>

      {/* ── File Viewer Lightbox ─────────────────────────────────────────── */}
      {viewFile && (
        <div onClick={() => setViewFile(null)}
          style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.85)', zIndex: 2000, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16 }}>
          <div onClick={e => e.stopPropagation()}
            style={{ background: 'var(--bg-card)', borderRadius: 16, maxWidth: '90vw', maxHeight: '90vh', overflow: 'hidden', display: 'flex', flexDirection: 'column', boxShadow: '0 32px 80px rgba(0,0,0,0.6)', width: '100%' }}>
            {/* Header */}
            <div style={{ padding: '14px 20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--border-subtle)' }}>
              <div style={{ fontWeight: 700, fontSize: '0.9rem', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{viewFile.name}</div>
              <div style={{ display: 'flex', gap: 10, flexShrink: 0 }}>
                <button onClick={() => triggerDownload(viewFile.url, viewFile.name)}
                  style={{ display: 'flex', alignItems: 'center', gap: 4, padding: '6px 12px', background: 'var(--brand-primary)', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontSize: '0.85rem', fontWeight: 600 }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>download</span> Download
                </button>
                <button onClick={() => setViewFile(null)}
                  style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)', display: 'flex', alignItems: 'center' }}>
                  <span className="material-symbols-outlined">close</span>
                </button>
              </div>
            </div>
            {/* Content */}
            <div style={{ flex: 1, overflow: 'auto', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 16, background: '#111', minHeight: 300 }}>
              {viewFile.type?.startsWith('image') ? (
                <img src={viewFile.url} alt={viewFile.name} style={{ maxWidth: '100%', maxHeight: '75vh', objectFit: 'contain', borderRadius: 8 }} />
              ) : viewFile.type?.includes('pdf') ? (
                <iframe src={viewFile.url} title={viewFile.name} style={{ width: '100%', height: '75vh', border: 'none', borderRadius: 8 }} />
              ) : null}
            </div>
          </div>
        </div>
      )}
    </AppLayout>
  )
}