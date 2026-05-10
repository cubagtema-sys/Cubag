import { BrowserRouter, Routes, Route } from 'react-router-dom'
import ProtectedRoute from './components/ProtectedRoute.jsx'
import { usePushNotifications } from './hooks/usePushNotifications.js'

// Landing
import Landing from './pages/Landing.jsx'

// Auth pages
import Login from './pages/Login.jsx'
import Register from './pages/Register.jsx'
import ForgotPassword from './pages/ForgotPassword.jsx'
import ResetPassword from './pages/ResetPassword.jsx'
import OTPVerification from './pages/OTPVerification.jsx'
import VerifyEmail from './pages/VerifyEmail.jsx'

// Member portal pages
import Dashboard from './pages/Dashboard.jsx'
import Profile from './pages/Profile.jsx'
import Settings from './pages/Settings.jsx'
import Tasks from './pages/Tasks.jsx'
import LicenseRenewal from './pages/LicenseRenewal.jsx'
import Announcements from './pages/Announcements.jsx'
import Events from './pages/Events.jsx'
import Networking from './pages/Networking.jsx'
import MemberDetail from './pages/MemberDetail.jsx'
import Messaging from './pages/Messaging.jsx'
import Payments from './pages/Payments.jsx'
import PaymentHistory from './pages/PaymentHistory.jsx'
import AdminPaymentSettings from './pages/AdminPaymentSettings.jsx'
import Surveys from './pages/Surveys.jsx'
import LiveData from './pages/LiveData.jsx'
import Engagement from './pages/Engagement.jsx'
import Notifications from './pages/Notifications.jsx'
import PublicServices from './pages/PublicServices.jsx'
import VesselMovements from './pages/VesselMovements.jsx'
import VanningSchedules from './pages/VanningSchedules.jsx'
import CargoSchedules from './pages/CargoSchedules.jsx'
import AdminCargoSchedules from './pages/AdminCargoSchedules.jsx'
import AdminTickets from './pages/AdminTickets.jsx'
import AdminDashboard from './pages/AdminDashboard.jsx'
import AdminSettings from './pages/AdminSettings.jsx'
import AdminAnnouncements from './pages/AdminAnnouncements.jsx'
import AdminTasks from './pages/AdminTasks.jsx'
import AdminLicenseRenewal from './pages/AdminLicenseRenewal.jsx'
import AdminFees from './pages/AdminFees.jsx'
import AdminEvents from './pages/AdminEvents.jsx'
import AdminSurveys from './pages/AdminSurveys.jsx'
import AdminMembers from './pages/AdminMembers.jsx'
import AdminPayments from './pages/AdminPayments.jsx'
import AdminPublicMaterials from './pages/AdminPublicMaterials.jsx'
import AdminIntelligence from './pages/AdminIntelligence.jsx'

const P = ({ children }) => <ProtectedRoute>{children}</ProtectedRoute>
const A = ({ children }) => <ProtectedRoute adminOnly>{children}</ProtectedRoute>

export default function App() {
  usePushNotifications()
  return (
    <BrowserRouter>
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
    </BrowserRouter>
  )
}
