import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'

const API_URL = import.meta.env.VITE_API_URL

export default function AdminIntelligence() {
  const [activeTab, setActiveTab] = useState('manual')
  
  // Manual Feeds State
  const [data, setData] = useState({ ports: [], bunkers: [], alerts: [] })
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState('')

  // Blog State
  const [blogs, setBlogs] = useState([])
  const [blogTitle, setBlogTitle] = useState('')
  const [blogContent, setBlogContent] = useState('')
  const [blogCategory, setBlogCategory] = useState('Logistics Update')
  const [blogImage, setBlogImage] = useState('')
  const [publishing, setPublishing] = useState(false)

  const token = localStorage.getItem('cubag_token')

  useEffect(() => {
    // Load intelligence
    fetch(`${API_URL}/intelligence`)
      .then(res => res.json())
      .then(d => {
        setData(d)
        setLoading(false)
      })
    // Load blogs
    fetchBlogs()
  }, [])

  const fetchBlogs = () => {
    fetch(`${API_URL}/news/blog`)
      .then(res => res.json())
      .then(b => setBlogs(b))
  }

  const handleSaveIntelligence = async () => {
    setSaving(true)
    setMessage('')
    try {
      const res = await fetch(`${API_URL}/intelligence`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(data)
      })
      if (res.ok) {
        setMessage('Successfully updated intelligence data!')
      } else {
        setMessage('Failed to update data.')
      }
    } catch (e) {
      setMessage('Error connecting to server.')
    } finally {
      setSaving(false)
    }
  }

  const handlePublishBlog = async (e) => {
    e.preventDefault()
    setPublishing(true)
    try {
      const res = await fetch(`${API_URL}/news/blog`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({
          title: blogTitle,
          content: blogContent,
          category: blogCategory,
          image_url: blogImage,
          author: 'CUBAG Secretariat'
        })
      })
      if (res.ok) {
        setBlogTitle('')
        setBlogContent('')
        setBlogImage('')
        fetchBlogs()
        setMessage('Blog post published successfully!')
      }
    } catch (e) {
      setMessage('Failed to publish post.')
    } finally {
      setPublishing(false)
      setTimeout(() => setMessage(''), 3000)
    }
  }

  const handleDeleteBlog = async (id) => {
    if(!confirm("Delete this post?")) return
    try {
      await fetch(`${API_URL}/news/blog/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      })
      fetchBlogs()
    } catch (e) {}
  }

  const updatePort = (idx, field, val) => {
    const newPorts = [...data.ports]
    newPorts[idx][field] = val
    setData({ ...data, ports: newPorts })
  }

  const updateAlert = (idx, field, val) => {
    const newAlerts = [...data.alerts]
    newAlerts[idx][field] = val
    setData({ ...data, alerts: newAlerts })
  }

  if (loading) return <AppLayout title="Intelligence">Loading...</AppLayout>

  return (
    <AppLayout title="Intelligence">
      <div style={{ maxWidth: 800, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 16, paddingBottom: 60 }}>
        
        {/* Page Title */}
        <div style={{ marginBottom: 4 }}>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Intelligence Control</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Manage port data, security alerts, and official CUBAG news.</p>
        </div>

        {/* Tab Switcher */}
        <div style={{ display: 'flex', gap: 0, background: 'var(--bg-base)', borderRadius: 12, padding: 4, border: '1.5px solid var(--border-subtle)' }}>
          {[
            { id: 'manual', label: 'Manual Feeds & Alerts', icon: 'settings_input_component' },
            { id: 'blog', label: 'Official CUBAG Blog', icon: 'newspaper' }
          ].map(t => (
            <button
              key={t.id}
              onClick={() => setActiveTab(t.id)}
              style={{
                flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
                padding: '10px 12px', borderRadius: 10, border: 'none', cursor: 'pointer',
                fontSize: '0.8rem', fontWeight: activeTab === t.id ? 800 : 600,
                background: activeTab === t.id ? 'var(--brand-primary)' : 'transparent',
                color: activeTab === t.id ? '#fff' : 'var(--text-muted)',
                transition: 'all 0.2s ease',
                boxShadow: activeTab === t.id ? '0 2px 8px rgba(240,130,50,0.3)' : 'none'
              }}
            >
              <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>{t.icon}</span>
              {t.label}
            </button>
          ))}
        </div>

        {message && (
          <div style={{ padding: 12, borderRadius: 8, background: message.includes('Failed') || message.includes('Error') ? '#ef4444' : '#10b981', color: '#fff', fontWeight: 600, fontSize: '0.85rem' }}>
            {message}
          </div>
        )}

        {/* ── TAB: Manual Feeds (Original) ── */}
        {activeTab === 'manual' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div style={{ padding: '16px 20px', background: 'var(--bg-elevated)', borderRadius: 12 }}>
              <h2 style={{ margin: '0 0 4px', fontSize: '1.1rem', fontWeight: 700 }}>Manual Feeds</h2>
              <p style={{ margin: 0, color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
                Update data shown to members in the live feed.
              </p>
            </div>

            {/* Port Congestion Section */}
            <section>
              <h3 style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 12, fontSize: '1rem', fontWeight: 700 }}>
                <span className="material-symbols-outlined" style={{ color: '#f59e0b', fontSize: '1.2rem' }}>directions_boat</span>
                Port Index
              </h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                {data.ports.map((p, i) => (
                  <div key={i} style={{ display: 'flex', flexDirection: 'column', gap: 8, background: 'var(--bg-base)', padding: 12, borderRadius: 10, border: '1px solid var(--border-subtle)' }}>
                    <input type="text" value={p.port} onChange={e => updatePort(i, 'port', e.target.value)} placeholder="Port Name" style={{ width: '100%', background: 'transparent', border: '1px solid var(--border-default)', color: 'var(--text-primary)', padding: '10px', borderRadius: 8, fontSize: '0.9rem' }} />
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                      <input type="text" value={p.status} onChange={e => updatePort(i, 'status', e.target.value)} placeholder="Status" style={{ background: 'transparent', border: '1px solid var(--border-default)', color: 'var(--text-primary)', padding: '10px', borderRadius: 8, fontSize: '0.9rem' }} />
                      <select value={p.color} onChange={e => updatePort(i, 'color', e.target.value)} style={{ background: 'transparent', border: '1px solid var(--border-default)', color: 'var(--text-primary)', padding: '10px', borderRadius: 8, fontSize: '0.9rem' }}>
                        <option value="#ef4444">High</option>
                        <option value="#f59e0b">Med</option>
                        <option value="#10b981">Low</option>
                      </select>
                    </div>
                  </div>
                ))}
              </div>
            </section>

            {/* Alerts Section */}
            <section>
              <h3 style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 12, fontSize: '1rem', fontWeight: 700 }}>
                <span className="material-symbols-outlined" style={{ color: '#ef4444', fontSize: '1.2rem' }}>warning</span>
                Alerts Feed
              </h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                {data.alerts.map((a, i) => (
                  <div key={i} style={{ background: 'var(--bg-base)', padding: 12, borderRadius: 10, display: 'flex', flexDirection: 'column', gap: 8, border: '1px solid var(--border-subtle)' }}>
                    <input type="text" value={a.title} onChange={e => updateAlert(i, 'title', e.target.value)} placeholder="Alert Title" style={{ background: 'transparent', border: '1px solid var(--border-default)', color: 'var(--text-primary)', padding: '10px', borderRadius: 8, fontWeight: 700, fontSize: '0.9rem' }} />
                    <textarea value={a.detail} onChange={e => updateAlert(i, 'detail', e.target.value)} placeholder="Details..." style={{ background: 'transparent', border: '1px solid var(--border-default)', color: 'var(--text-secondary)', padding: '10px', borderRadius: 8, minHeight: 60, fontFamily: 'inherit', fontSize: '0.85rem' }} />
                    <select value={a.severity} onChange={e => updateAlert(i, 'severity', e.target.value)} style={{ background: 'transparent', border: '1px solid var(--border-default)', color: 'var(--text-primary)', padding: '10px', borderRadius: 8, fontSize: '0.9rem' }}>
                      <option value="high">Critical</option>
                      <option value="medium">Warning</option>
                      <option value="low">Info</option>
                    </select>
                  </div>
                ))}
              </div>
            </section>

            <button 
              onClick={handleSaveIntelligence} 
              disabled={saving}
              className="btn btn-primary btn-lg"
              style={{ width: '100%', height: 48, borderRadius: 12, fontSize: '0.95rem' }}
            >
              <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>save</span>
              {saving ? 'Saving...' : 'Update Manual Intelligence'}
            </button>
          </div>
        )}

        {/* ── TAB: Official Blog ── */}
        {activeTab === 'blog' && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div className="feed-card" style={{ padding: 20, borderRadius: 14 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 18 }}>
                <div style={{ width: 36, height: 36, borderRadius: 10, background: 'rgba(240,130,50,0.1)', color: 'var(--brand-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>edit_document</span>
                </div>
                <h3 style={{ fontSize: '1rem', fontWeight: 800, margin: 0 }}>Write New Post</h3>
              </div>

              <form onSubmit={handlePublishBlog} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
                <div className="form-group">
                  <label style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)', display: 'block', marginBottom: 4 }}>Article Title</label>
                  <input required value={blogTitle} onChange={e => setBlogTitle(e.target.value)} placeholder="e.g. New Ghana Customs Regulations" style={{ padding: 10, fontSize: '0.9rem', width: '100%', boxSizing: 'border-box' }} />
                </div>
                
                <div className="form-group">
                  <label style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)', display: 'block', marginBottom: 4 }}>Category</label>
                  <select value={blogCategory} onChange={e => setBlogCategory(e.target.value)} style={{ padding: 10, fontSize: '0.9rem', width: '100%', boxSizing: 'border-box', background: 'var(--bg-base)', color: 'var(--text-primary)', border: '1px solid var(--border-default)', borderRadius: 8 }}>
                    <option value="Logistics Update">Logistics Update</option>
                    <option value="Association News">Association News</option>
                    <option value="Policy Change">Policy Change</option>
                  </select>
                </div>

                <div className="form-group">
                  <label style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)', display: 'block', marginBottom: 4 }}>Image URL (Optional)</label>
                  <input value={blogImage} onChange={e => setBlogImage(e.target.value)} placeholder="https://example.com/image.jpg" style={{ padding: 10, fontSize: '0.9rem', width: '100%', boxSizing: 'border-box' }} />
                </div>

                <div className="form-group">
                  <label style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)', display: 'block', marginBottom: 4 }}>Article Content</label>
                  <textarea required value={blogContent} onChange={e => setBlogContent(e.target.value)} placeholder="Write your post here..." rows="6" style={{ padding: 10, fontSize: '0.9rem', width: '100%', boxSizing: 'border-box', borderRadius: 8, border: '1px solid var(--border-default)', fontFamily: 'inherit' }} />
                </div>

                <button type="submit" className="btn btn-primary" disabled={publishing} style={{ height: 46, marginTop: 4, justifyContent: 'center', fontSize: '0.9rem' }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>publish</span>
                  {publishing ? 'Publishing...' : 'Publish Article'}
                </button>
              </form>
            </div>

            <h3 style={{ fontSize: '1rem', fontWeight: 800, marginTop: 10 }}>Published Posts</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {blogs.map(b => (
                <div key={b.id} className="feed-card" style={{ padding: 16, borderRadius: 12, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <span style={{ fontSize: '0.65rem', fontWeight: 800, color: 'var(--brand-primary)', textTransform: 'uppercase' }}>{b.category}</span>
                    <div style={{ fontWeight: 800, fontSize: '0.95rem' }}>{b.title}</div>
                    <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{new Date(b.created_at).toLocaleDateString()}</div>
                  </div>
                  <button onClick={() => handleDeleteBlog(b.id)} style={{ width: 34, height: 34, borderRadius: 8, background: 'rgba(239,68,68,0.1)', color: '#ef4444', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>delete</span>
                  </button>
                </div>
              ))}
              {blogs.length === 0 && (
                <div style={{ padding: 20, textAlign: 'center', color: 'var(--text-muted)', background: 'var(--bg-elevated)', borderRadius: 12 }}>
                  No official blog posts published yet.
                </div>
              )}
            </div>
          </div>
        )}

      </div>
    </AppLayout>
  )
}
