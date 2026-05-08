import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'
import CustomSelect from '../components/CustomSelect'
import ConfirmModal from '../components/ConfirmModal'

const API_URL = import.meta.env.VITE_API_URL

const CATEGORY_OPTIONS = [
  { value: 'Policy', label: 'Policy Documents' },
  { value: 'Forms', label: 'Official Forms' },
  { value: 'Guides', label: 'User Guides' },
  { value: 'Images', label: 'Public Media' },
  { value: 'Other', label: 'Miscellaneous' }
]

export default function AdminPublicMaterials() {
  const [materials, setMaterials] = useState([])
  const [loading, setLoading] = useState(true)
  const [form, setForm] = useState({ title: '', category: 'Policy', file: null })
  const [submitting, setSubmitting] = useState(false)
  const [pendingDelete, setPendingDelete] = useState(null)
  const token = localStorage.getItem('cubag_token')

  const fetchMaterials = async () => {
    try {
      setLoading(true)
      const res = await fetch(`${API_URL}/public-materials/public`, {
        headers: { Authorization: `Bearer ${token}` }
      })
      if (res.ok) {
        const data = await res.json()
        setMaterials(data)
      }
    } catch (e) {
      console.error(e)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchMaterials()
  }, [])

  const handleFileChange = (e) => {
    setForm({ ...form, file: e.target.files[0] })
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!form.file) return alert('Please select a file to upload.')

    setSubmitting(true)
    const formData = new FormData()
    formData.append('title', form.title)
    formData.append('category', form.category)
    formData.append('material', form.file)

    try {
      const res = await fetch(`${API_URL}/public-materials`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        body: formData
      })
      if (res.ok) {
        setForm({ title: '', category: 'Policy', file: null })
        fetchMaterials()
      }
    } catch (e) {
      console.error(e)
    } finally {
      setSubmitting(false)
    }
  }

  const handleDelete = async (id) => {
    try {
      await fetch(`${API_URL}/public-materials/${id}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` }
      })
      fetchMaterials()
    } catch (e) {}
    finally { setPendingDelete(null) }
  }

  return (
    <AppLayout title="Materials">
      <div style={{ maxWidth: 800, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 20 }}>

        {/* Header */}
        <div>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Public Materials</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Manage documents and media available to the public guest portal.</p>
        </div>

        {/* Upload Form */}
        <div className="feed-card" style={{ padding: 20, borderRadius: 12 }}>
          <h3 style={{ fontSize: '1.1rem', marginBottom: 16, display: 'flex', alignItems: 'center', gap: 8 }}>
            <span className="material-symbols-outlined" style={{ color: 'var(--brand-primary)' }}>upload_file</span>
            Upload New Material
          </h3>
          <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            <div className="form-group">
              <label style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)' }}>Material Title</label>
              <input
                required
                value={form.title}
                onChange={e => setForm({ ...form, title: e.target.value })}
                placeholder="e.g. 2026 Import Guidelines"
                style={{ padding: 10, fontSize: '0.9rem' }}
              />
            </div>
            <div className="form-row" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div className="form-group">
                <label style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)' }}>Category</label>
                <CustomSelect
                  value={form.category}
                  onChange={val => setForm({ ...form, category: val })}
                  options={CATEGORY_OPTIONS}
                />
              </div>
              <div className="form-group">
                <label style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)' }}>File Source</label>
                <div style={{ position: 'relative', height: 40 }}>
                  <input
                    type="file"
                    onChange={handleFileChange}
                    style={{ opacity: 0, position: 'absolute', inset: 0, width: '100%', cursor: 'pointer', zIndex: 2 }}
                  />
                  <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'var(--bg-base)', border: '1.5px dashed var(--border-default)', borderRadius: 8, fontSize: '0.8rem', color: form.file ? 'var(--brand-primary)' : 'var(--text-muted)', fontWeight: form.file ? 700 : 400 }}>
                    {form.file ? form.file.name : 'Choose File...'}
                  </div>
                </div>
              </div>
            </div>
            <button type="submit" className="btn btn-primary" disabled={submitting} style={{ height: 44, marginTop: 6 }}>
              {submitting ? 'Uploading...' : 'Publish to Public Portal'}
            </button>
          </form>
        </div>

        {/* Materials List */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <h3 style={{ fontSize: '1rem', fontWeight: 700, color: 'var(--text-secondary)', marginLeft: 4 }}>Published Content</h3>

          {loading ? (
            <div style={{ padding: 40, textAlign: 'center', color: 'var(--text-muted)' }}>Loading materials...</div>
          ) : materials.length === 0 ? (
            <div className="card" style={{ textAlign: 'center', padding: 40, color: 'var(--text-muted)' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '3rem', marginBottom: 12 }}>folder_off</span>
              <p>No public materials uploaded yet.</p>
            </div>
          ) : materials.map(m => (
            <div key={m.id} className="feed-card" style={{ padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 14 }}>
              <div style={{ width: 44, height: 44, borderRadius: 10, background: 'rgba(240,130,50,0.1)', color: 'var(--brand-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <span className="material-symbols-outlined">
                  {m.file_type === 'pdf' ? 'picture_as_pdf' :
                   ['jpg', 'png', 'jpeg'].includes(m.file_type) ? 'image' :
                   ['xls', 'xlsx'].includes(m.file_type) ? 'table_chart' : 'description'}
                </span>
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 700, fontSize: '0.9rem', color: 'var(--text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{m.title}</div>
                <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)', display: 'flex', gap: 8 }}>
                  <span style={{ fontWeight: 700, color: 'var(--brand-primary)' }}>{m.category}</span>
                  <span>•</span>
                  <span>{new Date(m.created_at).toLocaleDateString()}</span>
                </div>
              </div>
              <button
                onClick={() => setPendingDelete(m.id)}
                style={{ background: 'none', border: 'none', color: 'var(--brand-danger)', cursor: 'pointer', padding: 4 }}
              >
                <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>delete</span>
              </button>
            </div>
          ))}
        </div>

        <ConfirmModal
          open={!!pendingDelete}
          message="Are you sure you want to remove this material from the public portal?"
          onConfirm={() => handleDelete(pendingDelete)}
          onCancel={() => setPendingDelete(null)}
        />
      </div>
    </AppLayout>
  )
}
