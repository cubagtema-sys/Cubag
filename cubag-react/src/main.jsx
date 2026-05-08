import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.jsx'
import './styles/globals.css'
import './styles/landing.css'
import './styles/dashboard.css'
import './styles/auth.css'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)

// Hide splash screen after load
setTimeout(() => {
  document.body.classList.add('loaded')
}, 2000)

// ─── Capacitor: check JWT on app resume from background ──────────────────────
// When user brings the app back from background, validate token expiry.
// If expired, clear session and reload to /login.
function checkTokenOnResume() {
  const token = localStorage.getItem('cubag_token')
  if (!token) return
  try {
    const payload = JSON.parse(atob(token.split('.')[1]))
    const nowSecs = Math.floor(Date.now() / 1000)
    if (payload.exp && payload.exp < nowSecs) {
      localStorage.removeItem('cubag_token')
      localStorage.removeItem('cubag_user')
      window.location.href = '/login'
    }
  } catch {
    localStorage.removeItem('cubag_token')
    localStorage.removeItem('cubag_user')
    window.location.href = '/login'
  }
}

// Capacitor App plugin resume event (works on Android & iOS)
import('@capacitor/app').then(({ App: CapApp }) => {
  CapApp.addListener('resume', checkTokenOnResume)
}).catch(() => {
  // Not running in Capacitor (web browser) — use Page Visibility API as fallback
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') checkTokenOnResume()
  })
})
