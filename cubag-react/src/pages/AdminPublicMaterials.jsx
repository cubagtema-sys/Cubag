import { useState, useEffect } from 'react'
import AppLayout from '../components/AppLayout'
import CustomSelect from '../components/CustomSelect'
import ConfirmModal from '../components/ConfirmModal'
import { Browser } from '@capacitor/browser'

const API_URL = import.meta.env.VITE_API_URL

const CATEGORY_OPTIONS = [
  { value: 'Policy', label: 'Policy Documents',  icon: 'description' },
  { value: 'Forms',  label: 'Official Forms',    icon: 'edit_document' },
  { value: 'Guides', label: 'User Guides',       icon: 'menu_book' },
  { value: 'Images', label: 'Public Media',      icon: 'image' },
  { value: 'Other',  label: 'Miscellaneous',     icon: 'folder' },
]

const FILE_COLORS = {
  pdf: '#ef4444', xlsx: '#22c55e', xls: '#22c55e',
  docx: '#3b82f6', doc: '#3b82f6', jpg: '#f59e0b',
  png: '#f59e0b', jpeg: '#f59e0b'
}
const fileColor = (t) => FILE_COLORS[t] || 'var(--brand-primary)'
const fileIcon  = (t) => {
  if (t === 'pdf') return 'picture_as_pdf'
  if (['jpg','png','jpeg'].includes(t)) return 'image'
  if (['xls','xlsx'].includes(t)) return 'table_chart'
  if (['doc','docx'].includes(t)) return 'description'
  return 'file_present'
}

export default function AdminPublicMaterials() {
  const [materials, setMaterials] = useState([])
  const [loading, setLoading]     = useState(true)
  const [form, setForm]           = useState({ title: '', category: 'Policy', file: null })
  const [submitting, setSubmitting] = useState(false)
  const [pendingDelete, setPendingDelete] = useState(null)
  const [successMsg, setSuccessMsg] = useState('')
  const token = localStorage.getItem('cubag_token')

  const fetchMaterials = async () => {
    try {
      setLoading(true)
      const res = await fetch(`${API_URL}/public-materials/public`, {
        headers: { Authorization: `Bearer ${token}` }
      })
      if (res.ok) setMaterials(await res.json())
    } catch (e) { console.error(e) }
    finally { setLoading(false) }
  }

  useEffect(() => { fetchMaterials() }, []) // eslint-disable-line

  const handleFileChange = (e) => setForm({ ...form, file: e.target.files[0] })

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
        setSuccessMsg('Material published successfully!')
        fetchMaterials()
        setTimeout(() => setSuccessMsg(''), 3000)
      }
    } catch (e) { console.error(e) }
    finally { setSubmitting(false) }
  }

  const handleDelete = async (id) => {
    try {
      await fetch(`${API_URL}/public-materials/${id}`, {
        method: 'DELETE', headers: { Authorization: `Bearer ${token}` }
      })
      fetchMaterials()
    } catch (e) {}
    finally { setPendingDelete(null) }
  }

  const handleViewFile = async (url) => {
    if (!url) return

    // If URL is relative (starts with /), prepend the base URL (strip /api to avoid /api/api/)
    let fullUrl = url
    if (url.startsWith('/')) {
      const base = API_URL.replace(/\/api\/?$/, '')
      fullUrl = `${base}${url}`
    }

    try {
      await Browser.open({ url: fullUrl })
    } catch (e) {
      window.open(fullUrl, '_blank')
    }
  }

  return (
    <AppLayout title="Materials">
      <div style={{ maxWidth: 820, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 20 }}>

        <div>
          <h2 style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--text-primary)' }}>Public Materials</h2>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Manage documents and media available on the public guest portal.</p>
        </div>

        {/* ── Upload Form ── */}
        <div className="feed-card" style={{ padding: 20, borderRadius: 14 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 18 }}>
            <div style={{ width: 36, height: 36, borderRadius: 10, background: 'rgba(240,130,50,0.1)', color: 'var(--brand-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1.2rem' }}>upload_file</span>
            </div>
            <h3 style={{ fontSize: '1rem', fontWeight: 800, margin: 0 }}>Upload New Material</h3>
          </div>

          {successMsg && (
            <div style={{ padding: '10px 14px', background: 'rgba(16,185,129,0.1)', color: '#10b981', borderRadius: 10, marginBottom: 14, fontSize: '0.82rem', fontWeight: 700, border: '1px solid rgba(16,185,129,0.2)' }}>
              {successMsg}
            </div>
          )}

          <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            {/* Title */}
            <div className="form-group">
              <label style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)', display: 'block', marginBottom: 4 }}>Material Title</label>
              <input
                required value={form.title}
                onChange={e => setForm({ ...form, title: e.target.value })}
                placeholder="e.g. 2026 Import Guidelines"
                style={{ padding: 10, fontSize: '0.9rem', width: '100%', boxSizing: 'border-box' }}
              />
            </div>

            {/* Category — vertical layout as requested */}
            <div className="form-group">
              <label style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)', display: 'block', marginBottom: 4 }}>Category</label>
              <CustomSelect value={form.category} onChange={val => setForm({ ...form, category: val })} options={CATEGORY_OPTIONS} icon="folder" />
            </div>

            {/* File source */}
            <div className="form-group">
              <label style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--text-secondary)', display: 'block', marginBottom: 4 }}>File Source</label>
              <div style={{ position: 'relative', height: 52 }}>
                <input type="file" onChange={handleFileChange} style={{ opacity: 0, position: 'absolute', inset: 0, width: '100%', cursor: 'pointer', zIndex: 2 }} />
                <div style={{
                  position: 'absolute', inset: 0,
                  display: 'flex', alignItems: 'center', gap: 8,
                  background: 'var(--bg-base)',
                  border: `1.5px dashed ${form.file ? 'var(--brand-primary)' : 'var(--border-default)'}`,
                  borderRadius: 10, padding: '0 12px',
                  overflow: 'hidden'          /* prevent any child from escaping */
                }}>
                  <span className="material-symbols-outlined" style={{ fontSize: '1.1rem', color: form.file ? 'var(--brand-primary)' : 'var(--text-muted)', flexShrink: 0 }}>attach_file</span>
                  <span style={{
                    fontSize: '0.82rem',
                    color: form.file ? 'var(--brand-primary)' : 'var(--text-muted)',
                    fontWeight: form.file ? 700 : 400,
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                    whiteSpace: 'nowrap',
                    minWidth: 0,
                    flex: 1
                  }}>
                    {form.file ? form.file.name : 'Click to choose file...'}
                  </span>
                  {form.file && (
                    <span style={{ fontSize: '0.65rem', fontWeight: 800, color: 'var(--brand-primary)', background: 'rgba(240,130,50,0.1)', padding: '2px 8px', borderRadius: 20, flexShrink: 0, textTransform: 'uppercase' }}>
                      {form.file.name.split('.').pop()}
                    </span>
                  )}
                </div>
              </div>
            </div>


            <button type="submit" className="btn btn-primary" disabled={submitting} style={{ height: 46, marginTop: 4, justifyContent: 'center', fontSize: '0.9rem' }}>
              <span className="material-symbols-outlined" style={{ fontSize: '1.1rem' }}>publish</span>
              {submitting ? 'Uploading...' : 'Publish to Public Portal'}
            </button>
          </form>
        </div>

        {/* ── Published Materials List ── */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <h3 style={{ fontSize: '0.9rem', fontWeight: 800, color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
              Published Content
            </h3>
            {!loading && (
              <span style={{ fontSize: '0.72rem', color: 'var(--text-muted)', fontWeight: 600 }}>{materials.length} item{materials.length !== 1 ? 's' : ''}</span>
            )}
          </div>

          {loading ? (
            <div style={{ padding: 40, textAlign: 'center', color: 'var(--text-muted)' }}>
              <div className="spinner" style={{ margin: '0 auto 12px' }} />
              Loading materials...
            </div>
          ) : materials.length === 0 ? (
            <div className="card" style={{ textAlign: 'center', padding: 48, color: 'var(--text-muted)', borderRadius: 14 }}>
              <span className="material-symbols-outlined" style={{ fontSize: '3rem', display: 'block', marginBottom: 12, opacity: 0.3 }}>folder_off</span>
              <p style={{ fontWeight: 600 }}>No public materials uploaded yet.</p>
            </div>
          ) : materials.map(m => {
            const color = fileColor(m.file_type)

            return (
              <div key={m.id} className="feed-card" style={{ padding: '14px 16px', borderRadius: 14 }}>
                {/* ── Vertical layout: category / file name / source ── */}
                <div style={{ display: 'flex', gap: 14, alignItems: 'flex-start' }}>
                  {/* Icon */}
                  <div style={{ width: 44, height: 44, borderRadius: 12, background: `${color}18`, border: `1.5px solid ${color}30`, color, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, marginTop: 2 }}>
                    <span className="material-symbols-outlined" style={{ fontSize: '1.4rem' }}>{fileIcon(m.file_type)}</span>
                  </div>

                  {/* Content stacked vertically */}
                  <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 4 }}>
                    {/* Row 1: Category pill */}
                    <span style={{ display: 'inline-flex', alignSelf: 'flex-start', fontSize: '0.6rem', fontWeight: 800, color, background: `${color}15`, padding: '2px 8px', borderRadius: 20, textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                      {m.category}
                    </span>
                    {/* Row 2: File / title */}
                    <div style={{ fontWeight: 800, fontSize: '0.9rem', color: 'var(--text-primary)', lineHeight: 1.3 }}>{m.title}</div>
                    {/* Row 3: Source / date */}
                    <div style={{ fontSize: '0.7rem', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: 6 }}>
                      <span className="material-symbols-outlined" style={{ fontSize: '0.85rem' }}>calendar_today</span>
                      {new Date(m.created_at).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })}
                      <span style={{ opacity: 0.4 }}>•</span>
                      <span className="material-symbols-outlined" style={{ fontSize: '0.85rem' }}>attach_file</span>
                      {m.file_type?.toUpperCase() || 'FILE'}
                    </div>
                  </div>

                  {/* Actions */}
                  <div style={{ display: 'flex', gap: 6, flexShrink: 0 }}>
                    <button
                      onClick={() => handleViewFile(m.file_url)}
                      style={{ width: 34, height: 34, borderRadius: 8, background: 'rgba(240,130,50,0.08)', color: 'var(--brand-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', border: 'none', cursor: 'pointer' }}
                      title="View file"
                    >
                      <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>open_in_new</span>
                    </button>
                    <button
                      onClick={() => setPendingDelete(m.id)}
                      style={{ width: 34, height: 34, borderRadius: 8, border: '1px solid rgba(239,68,68,0.2)', background: 'rgba(239,68,68,0.06)', color: '#ef4444', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
                      title="Delete material"
                    >
                      <span className="material-symbols-outlined" style={{ fontSize: '1rem' }}>delete</span>
                    </button>
                  </div>
                </div>
              </div>
            )
          })}
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
