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

// ─── Check JWT validity when app returns to foreground ───────────────────────
// The Page Visibility API works in both web browsers AND Capacitor WebViews.
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

document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible') checkTokenOnResume()
})
