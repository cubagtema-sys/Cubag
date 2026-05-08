import { Navigate } from 'react-router-dom'

/**
 * Wraps a route and redirects to /login if no valid session exists.
 * Checks both cubag_token (JWT) and cubag_user (profile) in localStorage,
 * AND validates that the token has not expired.
 */
export default function ProtectedRoute({ children, adminOnly = false }) {
  const token = localStorage.getItem('cubag_token')
  const userRaw = localStorage.getItem('cubag_user')

  if (!token || !userRaw) {
    return <Navigate to="/login" replace />
  }

  // Decode JWT payload and check expiry (without a library)
  try {
    const payload = JSON.parse(atob(token.split('.')[1]))
    const nowSecs = Math.floor(Date.now() / 1000)
    if (payload.exp && payload.exp < nowSecs) {
      // Token expired — clear session and force re-login
      localStorage.removeItem('cubag_token')
      localStorage.removeItem('cubag_user')
      return <Navigate to="/login" replace />
    }
  } catch {
    // Malformed token
    localStorage.removeItem('cubag_token')
    localStorage.removeItem('cubag_user')
    return <Navigate to="/login" replace />
  }

  try {
    const user = JSON.parse(userRaw)
    if (adminOnly && user.role !== 'admin') {
      return <Navigate to="/dashboard" replace />
    }
  } catch {
    return <Navigate to="/login" replace />
  }

  return children
}
