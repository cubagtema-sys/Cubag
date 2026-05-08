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

  const fetchData = async () => {
    try {
      const [memRes, taskRes] = await Promise.all([
        fetch(`${API_URL}/members`),
        fetch(`${API_URL}/tasks/admin/all`)
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

  return (
    <AppLayout title="Compliance & Tasks">
      <div style={{ maxWidth: 1000, margin: '0 auto', padding: '24px 16px', display: 'flex', flexDirection: 'column', gap: 24 }}>

        <div>
          <h2 style={{ fontSize: '1.5rem', marginBottom: 8, display: 'flex', alignItems: 'center', gap: 8 }}>
            <span className="material-symbols-outlined" style={{ color: 'var(--brand-primary)' }}>assignment_add</span>
            Task Assignment & Tracking
          </h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '0.95rem' }}>Assign compliance duties and monitor task completion across all members.</p>
        </div>

        {/* Tab bar */}
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
          <button className={`btn ${activeTab === 'create' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => { setActiveTab('create'); setSelectedAssignment(null) }}>
            Assign Task
          </button>
          <button className={`btn ${activeTab === 'history' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => { setActiveTab('history'); setSelectedAssignment(null) }}>
            Assignment History
          </button>
          <button className={`btn ${activeTab === 'submissions' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => { setActiveTab('submissions'); setSelectedAssignment(null) }}>
            Member Submissions
            {pendingVerify > 0 && (
              <span style={{ marginLeft: 8, background: '#ef4444', borderRadius: 12, padding: '1px 8px', fontSize: '0.75rem', fontWeight: 800, color: '#fff' }}>
                {pendingVerify}
              </span>
            )}
          </button>
        </div>

        {/* ── CREATE TAB ─────────────────────────────────────────────────────── */}
        {activeTab === 'create' && (
          <div className="card" style={{ maxWidth: 600, margin: '0 auto' }}>
            <h3 style={{ marginBottom: 16, display: 'flex', alignItems: 'center', gap: 8 }}>
              <span className="material-symbols-outlined">assignment_add</span>
              New Assignment
            </h3>
            {message && (
              <div style={{ padding: 12, background: message.includes('success') ? 'var(--brand-success)' : 'var(--brand-danger)', color: '#fff', borderRadius: 8, marginBottom: 16, fontSize: '0.9rem' }}>
                {message}
              </div>
            )}
            <form onSubmit={handleSubmit}>
              <div className="form-group" style={{ zIndex: 10 }}>
                <CustomSelect
                  label="Assign To"
                  options={[
                    { value: '', label: 'Select a member...' },
                    { value: 'all', label: 'All Active Members (Broadcast)' },
                    ...members.map(m => ({ value: m.id.toString(), label: `${m.name} (${m.company})` }))
                  ]}
                  value={memberId.toString()}
                  onChange={setMemberId}
                />
              </div>
              <div className="form-group" style={{ marginTop: 16 }}>
                <label>Task Title</label>
                <input type="text" required value={title} onChange={e => setTitle(e.target.value)} placeholder="e.g. Submit Q3 Compliance Form" />
              </div>
              <div className="form-group">
                <label>Due Date</label>
                <input type="date" required value={dueDate} onChange={e => setDueDate(e.target.value)} />
              </div>
              <div className="form-group">
                <label>Instructions</label>
                <textarea required value={description} onChange={e => setDescription(e.target.value)} rows="4" placeholder="Detailed instructions for the task..." />
              </div>
              <button type="submit" className="btn btn-primary btn-full" style={{ marginTop: 16 }}>
                <span className="material-symbols-outlined">send</span> Assign Task
              </button>
            </form>
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
                {submissions.map((task, i) => (
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
                    {assignmentGroups.map((group, i) => {
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