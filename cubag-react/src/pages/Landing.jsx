import { Link } from 'react-router-dom'

export default function Landing() {
  return (
    <div className="welcome-screen">
      <div className="welcome-bg">
        <div className="welcome-orb orb-1"></div>
        <div className="welcome-orb orb-2"></div>
      </div>

      <div className="welcome-content">
        <div className="welcome-header">
          <img src="/logo.jpeg" alt="CUBAG Logo" className="welcome-logo"
            onError={(e) => { e.target.style.display = 'none' }} />
          <h1 className="welcome-title-large">CUBAG</h1>
          <p className="welcome-subtitle-bold">Enterprise Mobility</p>
        </div>

        <div className="welcome-features">
          <div className="feature-row">
            <span className="feature-icon material-symbols-outlined">sailing</span>
            <div>
              <h3>Live Logistics</h3>
              <p>Vessel tracking &amp; forex rates</p>
            </div>
          </div>
          <div className="feature-row">
            <span className="feature-icon material-symbols-outlined">payments</span>
            <div>
              <h3>Payments</h3>
              <p>Pay dues &amp; levies instantly</p>
            </div>
          </div>
          <div className="feature-row">
            <span className="feature-icon material-symbols-outlined">fact_check</span>
            <div>
              <h3>Compliance</h3>
              <p>Renew licenses &amp; track tasks</p>
            </div>
          </div>
          <div className="feature-row">
            <span className="feature-icon material-symbols-outlined">handshake</span>
            <div>
              <h3>Networking</h3>
              <p>Connect with fellow brokers</p>
            </div>
          </div>
        </div>

        <div className="welcome-actions">
          <Link to="/register" className="btn btn-primary btn-full btn-lg">
            Get Started
          </Link>
          <Link to="/login" className="btn btn-outline btn-full btn-lg bg-white">
            Log In to Account
          </Link>
          <Link to="/public-services" className="public-link">
            Continue as Public Guest
          </Link>
        </div>
      </div>

      <footer className="landing-footer" style={{ padding: '24px 20px', textAlign: 'center', background: 'rgba(255,255,255,0.05)', backdropFilter: 'blur(10px)' }}>
        <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontWeight: 600, letterSpacing: '0.02em' }}>
          © 2026 CUBAG PLATFORM • VERSION 1.0
        </div>
      </footer>
    </div>
  )
}
