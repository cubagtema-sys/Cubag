import { Navigate } from 'react-router-dom'

/**
 * Wraps a route and redirects to /login if no valid session exists.
 * Checks both cubag_token (JWT) and cubag_user (profile) in localStorage.
 */
export default function ProtectedRoute({ children, adminOnly = false }) {
  const token = localStorage.getItem('cubag_token')
  const userRaw = localStorage.getItem('cubag_user')

  if (!token || !userRaw) {
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
