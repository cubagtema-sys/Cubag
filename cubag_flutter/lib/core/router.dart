import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/admin_analytics_page.dart';
import '../pages/admin_audit_log_page.dart';
import '../services/telemetry_service.dart';
import '../pages/admin_announcements_page.dart';
import '../pages/admin_cargo_schedules_page.dart';
import '../pages/admin_dashboard_page.dart';
import '../pages/admin_events_page.dart';
import '../pages/admin_fees_page.dart';
import '../pages/admin_intelligence_page.dart';
import '../pages/admin_license_renewal_page.dart';
import '../pages/admin_members_page.dart';
import '../pages/admin_payments_page.dart';
import '../pages/admin_payment_settings_page.dart';
import '../pages/admin_settings_page.dart';
import '../pages/admin_surveys_page.dart';
import '../pages/admin_tasks_page.dart';
import '../pages/admin_tickets_page.dart';
import '../pages/admin_sub_admins_page.dart';
import '../pages/announcements_page.dart';
import '../pages/cargo_schedules_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/engagement_page.dart';
import '../pages/events_page.dart';
import '../pages/forgot_password_page.dart';
import '../pages/landing_page.dart';
import '../pages/license_renewal_page.dart';
import '../pages/live_data_page.dart';
import '../pages/login_page.dart';
import '../pages/member_detail_page.dart';
import '../pages/messaging_page.dart';
import '../pages/networking_page.dart';
import '../pages/notifications_page.dart';
import '../pages/otp_verification_page.dart';
import '../pages/payment_history_page.dart';
import '../pages/payments_page.dart';
import '../pages/profile_page.dart';
import '../pages/register_page.dart';
import '../pages/reset_password_page.dart';
import '../pages/settings_page.dart';
import '../pages/surveys_page.dart';
import '../pages/tasks_page.dart';
import '../pages/vanning_schedules_page.dart';
import '../pages/verify_email_page.dart';
import '../pages/verify_member_page.dart';
import '../pages/vessel_movements_page.dart';
import '../components/user_shell.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';

/// Routes accessible without a JWT token.
const _publicRoutes = {
  '/', '/login', '/register', '/forgot-password', '/reset-password',
  '/verify-email', '/otp-verification', '/public-services',
};

bool _isPublic(String path) =>
    _publicRoutes.contains(path) || path.startsWith('/verify-member/');

bool _isAdminRoute(String path) => path.startsWith('/admin/');

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  observers: [TelemetryRouteObserver()],
  redirect: (context, state) async {
    final prefs = await SharedPreferences.getInstance();
    final bool loggedIn = prefs.getString('cubag_token') != null;
    final String loc = state.matchedLocation;
    final role = prefs.getString('cubag_role');

    if (!loggedIn && !_isPublic(loc)) return '/login';
    if (loggedIn && _isAdminRoute(loc)) {
      // Only full admins AND sub-admins may access admin routes
      if (role != 'admin' && role != 'sub_admin') return '/dashboard';
      if (!kIsWeb) return '/admin-unavailable';
    }
    if (loggedIn && (loc == '/' || loc == '/login')) {
      if (role == 'admin' || role == 'sub_admin') {
        return kIsWeb ? '/admin/dashboard' : '/admin-unavailable';
      }
      return '/dashboard';
    }
    return null;
  },
  routes: [
    // ── Public / Auth ──────────────────────────────────────────────────
    GoRoute(path: '/',                builder: (c, s) => const LandingPage()),
    GoRoute(path: '/login',           builder: (c, s) => const LoginPage()),
    GoRoute(path: '/register',        builder: (c, s) => const RegisterPage()),
    GoRoute(path: '/forgot-password', builder: (c, s) => const ForgotPasswordPage()),
    GoRoute(
      path: '/reset-password',
      builder: (c, s) => ResetPasswordPage(
        email: s.uri.queryParameters['email'],
        token: s.uri.queryParameters['token'],
      ),
    ),
    GoRoute(
      path: '/verify-email',
      builder: (c, s) => VerifyEmailPage(token: s.uri.queryParameters['token']),
    ),
    GoRoute(
      path: '/otp-verification',
      builder: (c, s) => OTPVerificationPage(email: s.uri.queryParameters['email']),
    ),
    GoRoute(
      path: '/verify-member/:id',
      builder: (c, s) => VerifyMemberPage(memberId: s.pathParameters['id']),
    ),
    GoRoute(path: '/public-services', builder: (c, s) => const Scaffold(body: Center(child: Text('Public Services are currently unavailable.')))),
    GoRoute(path: '/admin-unavailable', builder: (c, s) => const _AdminUnavailablePage()),

    // ── Member pages (wrapped in UserShell for bottom nav) ────────────
    ShellRoute(
      builder: (context, state, child) => UserShell(child: child),
      routes: [
        GoRoute(path: '/dashboard',         builder: (c, s) => const DashboardPage()),
        GoRoute(path: '/announcements',     builder: (c, s) => const AnnouncementsPage()),
        GoRoute(path: '/cargo-schedules',   builder: (c, s) => const CargoSchedulesPage()),
        GoRoute(path: '/engagement',        builder: (c, s) => const EngagementPage()),
        GoRoute(path: '/events',            builder: (c, s) => const EventsPage()),
        GoRoute(path: '/license-renewal',   builder: (c, s) => const LicenseRenewalPage()),
        GoRoute(path: '/live-data',         builder: (c, s) => const LiveDataPage()),
        GoRoute(path: '/messaging',         builder: (c, s) => const MessagingPage()),
        GoRoute(path: '/networking',        builder: (c, s) => const NetworkingPage()),
        GoRoute(path: '/notifications',     builder: (c, s) => const NotificationsPage()),
        GoRoute(path: '/payment-history',   builder: (c, s) => const PaymentHistoryPage()),
        GoRoute(path: '/payments',          builder: (c, s) => const PaymentsPage()),
        GoRoute(path: '/profile',           builder: (c, s) => const ProfilePage()),
        GoRoute(path: '/settings',          builder: (c, s) => const SettingsPage()),
        GoRoute(path: '/surveys',           builder: (c, s) => const SurveysPage()),
        GoRoute(path: '/tasks',             builder: (c, s) => const TasksPage()),
        GoRoute(path: '/vanning-schedules', builder: (c, s) => const VanningSchedulesPage()),
        GoRoute(path: '/vessel-movements',  builder: (c, s) => const VesselMovementsPage()),
        GoRoute(
          path: '/member-detail/:id',
          builder: (c, s) => MemberDetailPage(memberId: s.pathParameters['id']),
        ),
      ],
    ),

    // ── Admin pages ─────────────────────────────────────────────────────
    GoRoute(path: '/admin/announcements',    builder: (c, s) => const AdminAnnouncementsPage()),
    GoRoute(path: '/admin/analytics',        builder: (c, s) => const AdminAnalyticsPage()),
    GoRoute(path: '/admin/audit-log',        builder: (c, s) => const AdminAuditLogPage()),
    GoRoute(path: '/admin/cargo-schedules',  builder: (c, s) => const AdminCargoSchedulesPage()),
    GoRoute(path: '/admin/dashboard',        builder: (c, s) => const AdminDashboardPage()),
    GoRoute(path: '/admin/events',           builder: (c, s) => const AdminEventsPage()),
    GoRoute(path: '/admin/fees',             builder: (c, s) => const AdminFeesPage()),
    GoRoute(path: '/admin/intelligence',     builder: (c, s) => const AdminIntelligencePage()),
    GoRoute(path: '/admin/license-renewal',  builder: (c, s) => const AdminLicenseRenewalPage()),
    GoRoute(path: '/admin/members',          builder: (c, s) => const AdminMembersPage()),
    GoRoute(path: '/admin/payments',         builder: (c, s) => const AdminPaymentsPage()),
    GoRoute(path: '/admin/payment-settings', builder: (c, s) => const AdminPaymentSettingsPage()),
    GoRoute(path: '/admin/settings',         builder: (c, s) => const AdminSettingsPage()),
    GoRoute(path: '/admin/surveys',          builder: (c, s) => const AdminSurveysPage()),
    GoRoute(path: '/admin/tasks',            builder: (c, s) => const AdminTasksPage()),
    GoRoute(path: '/admin/tickets',          builder: (c, s) => const AdminTicketsPage()),
    GoRoute(path: '/admin/sub-admins',        builder: (c, s) => const AdminSubAdminsPage()),
  ],
);

class _AdminUnavailablePage extends StatelessWidget {
  const _AdminUnavailablePage();

  @override
  Widget build(BuildContext context) {
    // Read saved email for display
    return _AdminUnavailableBody();
  }
}

class _AdminUnavailableBody extends StatefulWidget {
  @override
  State<_AdminUnavailableBody> createState() => _AdminUnavailableBodyState();
}

class _AdminUnavailableBodyState extends State<_AdminUnavailableBody> {
  String? _email;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _email = prefs.getString('cubag_email'));
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    await auth.logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: const Color(0xFFfff7ed),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFf08232).withAlpha(60), width: 2),
                  ),
                  child: const Icon(Icons.desktop_windows_outlined, size: 44, color: Color(0xFFf08232)),
                ),
                const SizedBox(height: 24),

                // Title
                const Text(
                  'Admin Portal',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0f172a)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The admin console is only available\non the web browser.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Color(0xFF64748b), height: 1.5),
                ),

                const SizedBox(height: 24),

                // Logged-in-as chip
                if (_email != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFf1f5f9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFe2e8f0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_circle_outlined, size: 18, color: Color(0xFF64748b)),
                        const SizedBox(width: 8),
                        Text(
                          'Logged in as $_email',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                // Web URL hint
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFfff7ed),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFf08232).withAlpha(50)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_browser, size: 18, color: Color(0xFFf08232)),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'cubag-backend.onrender.com',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFf08232)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // Logout button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _loggingOut ? null : _logout,
                    icon: _loggingOut
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.logout_rounded, size: 20),
                    label: Text(
                      _loggingOut ? 'Signing out...' : 'Sign Out & Switch Account',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFf08232),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

