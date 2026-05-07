import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout.jsx'
import CustomSelect from '../components/CustomSelect.jsx'

export default function AdminTasks() {
  const [tasks, setTasks] = useState([])
  const [members, setMembers] = useState([])
  
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [dueDate, setDueDate] = useState('')
  const [memberId, setMemberId] = useState('')
  
  const [message, setMessage] = useState('')
  const [activeTab, setActiveTab] = useState('create') // 'create' | 'history' | 'submissions'
  const [verifyingId, setVerifyingId] = useState(null)
  const [verifyNotes, setVerifyNotes] = useState({})

  const fetchData = async () => {
    try {
      // Fetch members for dropdown
      const memRes = await fetch(`${import.meta.env.VITE_API_URL}/members`)
      if (memRes.ok) {
        setMembers(await memRes.json())
      }
      
      // Fetch tasks
      const taskRes = await fetch(`${import.meta.env.VITE_API_URL}/tasks/admin/all`)
      if (taskRes.ok) {
        setTasks(await taskRes.json())
      }
    } catch (e) {
      console.error(e)
    }
  }

  useEffect(() => {
    fetchData()
  }, [])

  const handleSubmit = async (e) => {
    e.preventDefault()
    try {
      const res = await fetch(`${import.meta.env.VITE_API_URL}/tasks/admin/create`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('cubag_token')}`
        },
        body: JSON.stringify({ title, description, due_date: dueDate, member_id: memberId })
      })

      if (res.ok) {
        setMessage('Task successfully assigned.')
        setTitle('')
        setDescription('')
        setDueDate('')
        setMemberId('')
        fetchData()
        setTimeout(() => setMessage(''), 3000)
      } else {
        setMessage('Failed to assign task.')
      }
    } catch (e) {
      setMessage('Network error.')
    }
  }

  const handleVerify = async (submissionId) => {
    try {
      const res = await fetch(`${import.meta.env.VITE_API_URL}/tasks/admin/${submissionId}/verify`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('cubag_token')}`
        },
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

  const groupedTasks = {}
  tasks.forEach(task => {
    const key = `${task.title}|${task.due_date}`
    if (!groupedTasks[key]) {
      groupedTasks[key] = {
        title: task.title,
        description: task.description,
        due_date: task.due_date,
        total: 0,
        completed: 0,
        members: []
      }
    }
    groupedTasks[key].total += 1
    if (task.done) groupedTasks[key].completed += 1
    groupedTasks[key].members.push(task)
  })

  const assignmentGroups = Object.values(groupedTasks).sort((a, b) => new Date(b.due_date) - new Date(a.due_date))
  const [selectedAssignment, setSelectedAssignment] = useState(null)

  return (
    <AppLayout title="Compliance & Tasks">
      <div style={{ maxWidth: 1000, margin: '0 auto', padding: '24px 16px', display: 'flex', flexDirection: 'column', gap: 24 }}>
        <div>
          <h2 style={{ fontSize: '1.5rem', marginBottom: 8, display: 'flex', alignItems: 'center', gap: 8 }}>
            <span className="material-symbols-outlined" style={{ color: 'var(--brand-primary)' }}>assignment_add</span>
            Task Assignment & Tracking
          </h2>
          <p style={{ color: 'var(--text-secondary)', fontSize: '0.95rem' }}>Assign compliance duties and monitor task completion status across all members.</p>
        </div>

        <div style={{ display: 'flex', gap: '12px', marginBottom: '24px', flexWrap: 'wrap' }}>
          <button className={`btn ${activeTab === 'create' ? 'btn-primary' : 'btn-outline'}`} onClick={() => { setActiveTab('create'); setSelectedAssignment(null) }}>Assign Task</button>
          <button className={`btn ${activeTab === 'history' ? 'btn-primary' : 'btn-outline'}`} onClick={() => { setActiveTab('history'); setSelectedAssignment(null) }}>Assignment History</button>
          <button className={`btn ${activeTab === 'submissions' ? 'btn-primary' : 'btn-outline'}`} onClick={() => { setActiveTab('submissions'); setSelectedAssignment(null) }} style={{ position: 'relative' }}>
            Member Submissions
            {tasks.filter(t => t.submission_id && !t.admin_verified).length > 0 && (
              <span style={{ marginLeft: 8, background: '#ef4444', borderRadius: 12, padding: '1px 8px', fontSize: '0.75rem', fontWeight: 800, color: '#fff' }}>
                {tasks.filter(t => t.submission_id && !t.admin_verified).length}
              </span>
            )}
          </button>
        </div>

        {activeTab === 'create' ? (
          <div className="card" style={{ maxWidth: '600px', margin: '0 auto' }}>
            <h3 style={{ marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <span className="material-symbols-outlined">assignment_add</span>
              New Assignment
            </h3>
            {message && (
              <div style={{ padding: '12px', background: message.includes('success') ? 'var(--brand-success)' : 'var(--brand-danger)', color: '#fff', borderRadius: 'var(--radius-md)', marginBottom: '16px', fontSize: '0.9rem' }}>
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
              <div className="form-group" style={{ marginTop: '16px' }}>
                <label>Task Title</label>
                <input type="text" required value={title} onChange={e => setTitle(e.target.value)} placeholder="e.g. Submit Q3 Compliance Form" />
              </div>
              <div className="form-group">
                <label>Due Date</label>
                <input type="date" required value={dueDate} onChange={e => setDueDate(e.target.value)} />
              </div>
              <div className="form-group">
                <label>Instructions</label>
                <textarea required value={description} onChange={e => setDescription(e.target.value)} rows="4" placeholder="Detailed instructions for the task..."></textarea>
              </div>
              <button type="submit" className="btn btn-primary btn-full" style={{ marginTop: '16px' }}>
                <span className="material-symbols-outlined">send</span> Assign Task
              </button>
            </form>
          </div>
        ) : selectedAssignment ? (
          <div className="card">
            <button className="btn btn-ghost btn-sm" style={{ marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }} onClick={() => setSelectedAssignment(null)}>
              <span className="material-symbols-outlined">arrow_back</span> Back to Assignments
            </button>
            <div style={{ marginBottom: '24px' }}>
              <h3 style={{ margin: 0, color: 'var(--text-primary)' }}>{selectedAssignment.title}</h3>
              <p style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', marginTop: '4px' }}>Due: {new Date(selectedAssignment.due_date).toLocaleDateString()}</p>
              <div style={{ marginTop: '12px', padding: '12px', background: 'var(--bg-elevated)', borderRadius: '8px', fontSize: '0.9rem', color: 'var(--text-secondary)' }}>
                {selectedAssignment.description}
              </div>
            </div>
            
            <h4 style={{ marginBottom: '12px' }}>Member Status ({selectedAssignment.completed}/{selectedAssignment.total} Completed)</h4>
            <div className="responsive-table-wrapper">
              <table className="responsive-table" style={{ width: '100%', textAlign: 'left', borderCollapse: 'collapse' }}>
                <thead>
                  <tr style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Member Name</th>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {selectedAssignment.members.map((m, i) => (
                    <tr key={i} style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                      <td data-label="Member Name" style={{ padding: '12px', fontSize: '0.9rem', fontWeight: 600 }}>{m.member_name}</td>
                      <td data-label="Status" style={{ padding: '12px' }}>
                        <span className={`badge ${m.done ? 'badge-success' : 'badge-warning'}`}>
                          {m.done ? 'Completed' : 'Pending'}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        ) : (
          <div className="card">
            <h3 style={{ marginBottom: '16px' }}>Assignment History</h3>
            <div className="responsive-table-wrapper">
              <table className="responsive-table" style={{ width: '100%', textAlign: 'left', borderCollapse: 'collapse' }}>
                <thead>
                  <tr style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Assignment</th>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Due Date</th>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Completion Rate</th>
                    <th style={{ padding: '12px', color: 'var(--text-muted)', fontSize: '0.85rem' }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {assignmentGroups.map((group, i) => {
                    const isOverdue = new Date(group.due_date) < new Date() && group.completed < group.total
                    return (
                      <tr key={i} style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                        <td data-label="Assignment" style={{ padding: '12px', fontSize: '0.9rem' }}>
                          <div style={{ fontWeight: 600 }}>{group.title}</div>
                          <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{group.description.substring(0, 50)}...</div>
                        </td>
                        <td data-label="Due Date" style={{ padding: '12px', fontSize: '0.9rem' }}>
                          <span style={{ color: isOverdue ? 'var(--brand-danger)' : 'var(--text-secondary)', fontWeight: isOverdue ? 700 : 400 }}>
                            {new Date(group.due_date).toLocaleDateString()}
                          </span>
                        </td>
                        <td data-label="Completion Rate" style={{ padding: '12px' }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', justifyContent: 'flex-end' }}>
                            <div style={{ width: '100px', height: '6px', background: 'var(--border-subtle)', borderRadius: '3px', overflow: 'hidden' }}>
                              <div style={{ width: `${(group.completed / group.total) * 100}%`, height: '100%', background: group.completed === group.total ? 'var(--brand-success)' : 'var(--brand-primary)' }}></div>
                            </div>
                            <span style={{ fontSize: '0.8rem', fontWeight: 600 }}>{group.completed}/{group.total}</span>
                          </div>
                        </td>
                        <td data-label="Actions" style={{ padding: '12px' }}>
                          <button className="btn btn-outline btn-sm" onClick={() => setSelectedAssignment(group)}>View Status</button>
                        </td>
                      </tr>
                    )
                  })}
                  {assignmentGroups.length === 0 && (
                    <tr>
                      <td colSpan="4" style={{ padding: '24px', textAlign: 'center', color: 'var(--text-muted)' }}>No assignments found.</td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        ) : activeTab === 'submissions' ? (
          <div className="card">
            <div style={{ marginBottom: 20 }}>
              <h3 style={{ margin: 0 }}>Member Submissions</h3>
              <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginTop: 4 }}>Review evidence submitted by members and mark tasks as verified.</p>
            </div>
            {tasks.filter(t => t.submission_id).length === 0 ? (
              <div style={{ textAlign: 'center', padding: '48px', color: 'var(--text-muted)' }}>
                <span className="material-symbols-outlined" style={{ fontSize: '2.5rem', display: 'block', marginBottom: 8 }}>inbox</span>
                No submissions yet.
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                {tasks.filter(t => t.submission_id).map((task, i) => (
                  <div key={i} style={{ border: '1px solid var(--border-subtle)', borderRadius: 12, overflow: 'hidden' }}>
                    {/* Header */}
                    <div style={{ padding: '14px 20px', background: task.admin_verified ? 'rgba(16,185,129,0.06)' : 'rgba(59,130,246,0.04)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 10 }}>
                      <div>
                        <div style={{ fontWeight: 700, fontSize: '0.95rem' }}>{task.title}</div>
                        <div style={{ fontSize: '0.8rem', color: 'var(--brand-primary)', display: 'flex', alignItems: 'center', gap: 4, marginTop: 4 }}>
                          <span className="material-symbols-outlined" style={{ fontSize: '0.9rem' }}>person</span>
                          {task.member_name}
                          <span style={{ color: 'var(--text-muted)', marginLeft: 6 }}>· Submitted {task.submitted_at ? new Date(task.submitted_at).toLocaleDateString() : ''}</span>
                        </div>
                      </div>
                      {task.admin_verified ? (
                        <span style={{ display: 'flex', alignItems: 'center', gap: 6, background: 'rgba(16,185,129,0.1)', color: '#10b981', borderRadius: 20, padding: '4px 14px', fontSize: '0.8rem', fontWeight: 800 }}>
                          <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>verified</span> Verified
                        </span>
                      ) : (
                        <button className="btn btn-primary btn-sm" onClick={() => setVerifyingId(verifyingId === task.submission_id ? null : task.submission_id)}>
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

                    {/* Attached files */}
                    {task.files && task.files.length > 0 && (
                      <div style={{ padding: '12px 20px', borderBottom: '1px solid var(--border-subtle)' }}>
                        <div style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-muted)', marginBottom: 8 }}>ATTACHMENTS ({task.files.length})</div>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                          {task.files.map((f, fi) => (
                            <a key={fi} href={`${import.meta.env.VITE_API_URL}/tasks/uploads/${f.filename}`}
                              target="_blank" rel="noreferrer"
                              style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 12px', background: 'var(--bg-elevated)', borderRadius: 8, border: '1px solid var(--border-subtle)', textDecoration: 'none', color: 'var(--text-primary)' }}>
                              <span className="material-symbols-outlined" style={{ fontSize: '1.2rem', color: 'var(--brand-primary)' }}>{fileIcon(f.file_type)}</span>
                              <div style={{ flex: 1, minWidth: 0 }}>
                                <div style={{ fontSize: '0.85rem', fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{f.original_name}</div>
                                <div style={{ fontSize: '0.72rem', color: 'var(--text-muted)' }}>{f.file_type}</div>
                              </div>
                              <span className="material-symbols-outlined" style={{ fontSize: '1rem', color: 'var(--text-muted)' }}>download</span>
                            </a>
                          ))}
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
        