/**
 * ConfirmModal - replaces window.confirm() for mobile compatibility.
 * Usage: <ConfirmModal open={!!pending} message="..." onConfirm={...} onCancel={() => setPending(null)} />
 */
export default function ConfirmModal({ open, message, onConfirm, onCancel, danger = true }) {
  if (!open) return null
  return (
    <div style={{
      position: 'fixed', inset: 0, zIndex: 9998,
      background: 'rgba(0,0,0,0.55)', display: 'flex', alignItems: 'center', justifyContent: 'center',
      padding: 24, backdropFilter: 'blur(4px)'
    }}>
      <div style={{
        background: 'var(--bg-elevated)', borderRadius: 16, padding: 28,
        maxWidth: 380, width: '100%', boxShadow: 'var(--shadow-lg)',
        border: '1px solid var(--border-subtle)', animation: 'fadeIn 0.2s ease'
      }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 14, marginBottom: 24 }}>
          <span className="material-symbols-outlined" style={{
            fontSize: '1.8rem', color: danger ? 'var(--brand-danger)' : 'var(--brand-primary)', flexShrink: 0
          }}>
            {danger ? 'warning' : 'help'}
          </span>
          <p style={{ margin: 0, fontSize: '0.95rem', color: 'var(--text-primary)', lineHeight: 1.5 }}>
            {message}
          </p>
        </div>
        <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
          <button
            onClick={onCancel}
            className="btn btn-ghost"
            style={{ flex: 1 }}
          >
            Cancel
          </button>
          <button
            onClick={() => { onConfirm(); onCancel(); }}
            className="btn"
            style={{ flex: 1, background: danger ? 'var(--brand-danger)' : 'var(--brand-primary)', color: '#fff' }}
          >
            Confirm
          </button>
        </div>
      </div>
      <style>{`@keyframes fadeIn { from { opacity:0; transform: scale(0.95); } to { opacity:1; transform: scale(1); } }`}</style>
    </div>
  )
}
