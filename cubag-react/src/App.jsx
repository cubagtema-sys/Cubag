import { lazy, Suspense } from 'react'
import { BrowserRouter, Routes, Route } from 'react-router-dom'
import ProtectedRoute from './components/ProtectedRoute.jsx'
import { usePushNotifications } from './hooks/usePushNotifications.js'

// Landing (keep eager for SEO/Speed)
import Landing from './pages/Landing.jsx'
import Login from './pages/Login.jsx'

// Lazy load everything else
const Register            = lazy(() => import('./pages/Register.jsx'))
const ForgotPassword     = lazy(() => import('./pages/ForgotPassword.jsx'))
const ResetPassword      = lazy(() => import('./pages/ResetPassword.jsx'))
const OTPVerification    = lazy(() => import('./pages/OTPVerification.jsx'))
const VerifyEmail        = lazy(() => import('./pages/VerifyEmail.jsx'))
const PublicServices     = lazy(() => import('./pages/PublicServices.jsx'))
const VerifyMember       = lazy(() => import('./pages/VerifyMember.jsx'))

const Dashboard          = lazy(() => import('./pages/Dashboard.jsx'))
const Profile            = lazy(() => import('./pages/Profile.jsx'))
const Settings           = lazy(() => import('./pages/Settings.jsx'))
const Tasks              = lazy(() => import('./pages/Tasks.jsx'))
const LicenseRenewal     = lazy(() => import('./pages/LicenseRenewal.jsx'))
const Announcements      = lazy(() => import('./pages/Announcements.jsx'))
const Events             = lazy(() => import('./pages/Events.jsx'))
const Networking         = lazy(() => import('./pages/Networking.jsx'))
const MemberDetail       = lazy(() => import('./pages/MemberDetail.jsx'))
const Messaging          = lazy(() => import('./pages/Messaging.jsx'))
const Payments           = lazy(() => import('./pages/Payments.jsx'))
const PaymentHistory     = lazy(() => import('./pages/PaymentHistory.jsx'))
const Surveys            = lazy(() => import('./pages/Surveys.jsx'))
const LiveData           = lazy(() => import('./pages/LiveData.jsx'))
const Engagement         = lazy(() => import('./pages/Engagement.jsx'))
const Notifications      = lazy(() => import('./pages/Notifications.jsx'))
const VesselMovements    = lazy(() => import('./pages/VesselMovements.jsx'))
const VanningSchedules   = lazy(() => import('./pages/VanningSchedules.jsx'))
const CargoSchedules     = lazy(() => import('./pages/CargoSchedules.jsx'))

const AdminDashboard        = lazy(() => import('./pages/AdminDashboard.jsx'))
const AdminCargoSchedules   = lazy(() => import('./pages/AdminCargoSchedules.jsx'))
const AdminTickets          = lazy(() => import('./pages/AdminTickets.jsx'))
const AdminSettings         = lazy(() => import('./pages/AdminSettings.jsx'))
const AdminAnnouncements    = lazy(() => import('./pages/AdminAnnouncements.jsx'))
const AdminTasks            = lazy(() => import('./pages/AdminTasks.jsx'))
const AdminLicenseRenewal   = lazy(() => import('./pages/AdminLicenseRenewal.jsx'))
const AdminPaymentSettings  = lazy(() => import('./pages/AdminPaymentSettings.jsx'))
const AdminFees             = lazy(() => import('./pages/AdminFees.jsx'))
const AdminEvents           = lazy(() => import('./pages/AdminEvents.jsx'))
const AdminSurveys          = lazy(() => import('./pages/AdminSurveys.jsx'))
const AdminMembers          = lazy(() => import('./pages/AdminMembers.jsx'))
const AdminPayments         = lazy(() => import('./pages/AdminPayments.jsx'))
const AdminPublicMaterials  = lazy(() => import('./pages/AdminPublicMaterials.jsx'))
const AdminIntelligence     = lazy(() => import('./pages/AdminIntelligence.jsx'))

const Loader = () => (
  <div style={{ height: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'var(--bg-base)' }}>
    <div className="logo-loader">
      <img src="/logo.jpeg" alt="Loading..." style={{ width: 60, height: 60, borderRadius: 14 }} />
    </div>
  </div>
)

const P = ({ children }) => <ProtectedRoute>{children}</ProtectedRoute>
const A = ({ children }) => <ProtectedRoute adminOnly>{children}</ProtectedRoute>

export default function App() {
  usePushNotifications()
  return (
    <BrowserRouter>
      <Suspense fallback={<Loader />}>
        <Routes>
          {/* Public */}
          <Route path="/"                    element={<Landing />} />
          <Route path="/login"               element={<Login />} />
          <Route path="/register"            element={<Register />} />
          <Route path="/forgot-password"     element={<ForgotPassword />} />
          <Route path="/reset-password"      element={<ResetPassword />} />
          <Route path="/verify-otp"          element={<OTPVerification />} />
          <Route path="/verify-email"        element={<VerifyEmail />} />
          <Route path="/public-services"     element={<PublicServices />} />
          <Route path="/live-data"           element={<LiveData />} />
          <Route path="/vessel-movements"    element={<VesselMovements />} />
          <Route path="/vanning-schedules"   element={<VanningSchedules />} />
          <Route path="/cargo-schedules"     element={<CargoSchedules />} />
          <Route path="/verify/:id"          element={<VerifyMember />} />

          {/* Admin — protected + adminOnly */}
          <Route path="/admin"               element={<A><AdminDashboard /></A>} />
          <Route path="/admin/cargo-schedules" element={<A><AdminCargoSchedules /></A>} />
          <Route path="/admin/tickets"       element={<A><AdminTickets /></A>} />
          <Route path="/admin/settings"      element={<A><AdminSettings /></A>} />
          <Route path="/admin/announcements" element={<A><AdminAnnouncements /></A>} />
          <Route path="/admin/tasks"         element={<A><AdminTasks /></A>} />
          <Route path="/admin/license-renewal" element={<A><AdminLicenseRenewal /></A>} />
          <Route path="/admin/payment-settings" element={<A><AdminPaymentSettings /></A>} />
          <Route path="/admin/fees"          element={<A><AdminFees /></A>} />
          <Route path="/admin/public-materials" element={<A><AdminPublicMaterials /></A>} />
          <Route path="/admin/events"        element={<A><AdminEvents /></A>} />
          <Route path="/admin/surveys"       element={<A><AdminSurveys /></A>} />
          <Route path="/admin/members"       element={<A><AdminMembers /></A>} />
          <Route path="/admin/payments"      element={<A><AdminPayments /></A>} />
          <Route path="/admin/intelligence"  element={<A><AdminIntelligence /></A>} />

          {/* Member portal — protected */}
          <Route path="/dashboard"           element={<P><Dashboard /></P>} />
          <Route path="/profile"             element={<P><Profile /></P>} />
          <Route path="/settings"            element={<P><Settings /></P>} />
          <Route path="/tasks"               element={<P><Tasks /></P>} />
          <Route path="/license-renewal"     element={<P><LicenseRenewal /></P>} />
          <Route path="/announcements"       element={<P><Announcements /></P>} />
          <Route path="/events"              element={<P><Events /></P>} />
          <Route path="/networking"          element={<P><Networking /></P>} />
          <Route path="/members/:id"         element={<P><MemberDetail /></P>} />
          <Route path="/messaging"           element={<P><Messaging /></P>} />
          <Route path="/payments"            element={<P><Payments /></P>} />
          <Route path="/payment-history"     element={<P><PaymentHistory /></P>} />
          <Route path="/surveys"             element={<P><Surveys /></P>} />
          <Route path="/engagement"          element={<P><Engagement /></P>} />
          <Route path="/notifications"       element={<P><Notifications /></P>} />

          {/* 404 */}
          <Route path="*" element={<div style={{ textAlign: 'center', padding: '50px' }}><h2>404 - Page Not Found</h2><a href="/">Return Home</a></div>} />
        </Routes>
      </Suspense>
    </BrowserRouter>
  )
}
