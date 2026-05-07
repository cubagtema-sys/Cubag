import { Link } from 'react-router-dom'

export default function Footer() {
  return (
    <footer className="footer">
      <div className="container">
        <div className="footer-grid">
          <div className="footer-brand">
            <div className="nav-brand" style={{ marginBottom: 10 }}>
              <img src="/logo.jpeg" alt="CUBAG" style={{ height: 48, width: 'auto', objectFit: 'contain' }}
                onError={e => { e.target.style.display = 'none' }} />
              <span className="brand-text" style={{ fontSize: '1.4rem' }}>CUBAG</span>
            </div>
            <p>Customs Brokers Association of Ghana</p>
          </div>

          <div className="footer-col">
            <h4>Platform</h4>
            <ul>
              <li><Link to="/login">Member Login</Link></li>
              <li><Link to="/register">Register</Link></li>
              <li><Link to="/live-data">Live Data</Link></li>
              <li><Link to="/license-renewal">License Renewal</Link></li>
            </ul>
          </div>

          <div className="footer-col">
            <h4>Association</h4>
            <ul>
              <li><a href="#about">About CUBAG</a></li>
              <li><a href="#">Governance</a></li>
              <li><a href="#">News &amp; Events</a></li>
              <li><a href="#contact">Contact</a></li>
            </ul>
          </div>

          <div className="footer-col">
            <h4>Services</h4>
            <ul>
              <li><Link to="/public-services">Company Directory</Link></li>
              <li><Link to="/live-data">Vessel Movements</Link></li>
              <li><Link to="/live-data">Forex Rates</Link></li>
              <li><Link to="/public-services">Public Services</Link></li>
            </ul>
          </div>
        </div>

        <div className="footer-bottom">
          <span>© 2026 CUBAG — Customs Brokers Association of Ghana. All rights reserved.</span>
        </div>
      </div>
    </footer>
  )
}
