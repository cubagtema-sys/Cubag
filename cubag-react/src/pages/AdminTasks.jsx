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
  const [activeTab, setActiveTab] = useState('create') // 'create' or 'history'

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

        <div style={{ display: 'flex', gap: '16px', marginBottom: '24px' }}>
          <button 
            className={`btn ${activeTab === 'create' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => { setActiveTab('create'); setSelectedAssignment(null); }}
          >
            Assign Task
          </button>
          <button 
            className={`btn ${activeTab === 'history' ? 'btn-primary' : 'btn-outline'}`}
            onClick={() => { setActiveTab('history'); setSelectedAssignment(null); }}
          >
            Assignment History
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
        )}
      </div>
    </AppLayout>
  )
}
