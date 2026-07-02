import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/session_storage.dart';
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
import '../pages/admin_event_attendees_page.dart';
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
import '../pages/mobile_menu_page.dart';
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
    final token = await SessionStorage.instance.getString('cubag_token');
    final bool loggedIn = token != null;
    final String loc = state.matchedLocation;
    final role = await SessionStorage.instance.getString('cubag_role');

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
    GoRoute(
      path: '/member-detail/:id',
      builder: (c, s) => MemberDetailPage(memberId: s.pathParameters['id']),
    ),
    GoRoute(path: '/public-services', builder: (c, s) => const Scaffold(body: Center(child: Text('Public Services are currently unavailable.')))),
    GoRoute(path: '/admin-unavailable', builder: (c, s) => const _AdminUnavailablePage()),

    // ── Member pages (wrapped in UserShell for bottom nav, state kept alive) ──
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => UserShell(child: navigationShell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/dashboard', builder: (c, s) => const DashboardPage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/announcements', builder: (c, s) => const AnnouncementsPage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/cargo-schedules', builder: (c, s) => const CargoSchedulesPage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/engagement', builder: (c, s) => const EngagementPage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/events', builder: (c, s) => const EventsPage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/license-renewal', builder: (c, s) => const LicenseRenewalPage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/live-data', builder: (c, s) => const LiveDataPage())]),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/messaging',
              builder: (c, s) => MessagingPage(
                initialUserId: s.uri.queryParameters['id'],
                initialUserName: s.uri.queryParameters['name'],
                initialUserCompany: s.uri.queryParameters['company'],
              ),
            ),
          ],
        ),
        StatefulShellBranch(routes: [GoRoute(path: '/networking', builder: (c, s) => const NetworkingPage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/notifications', builder: (c, s) => const NotificationsPage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/menu', builder: (c, s) => const MobileMenuPage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/payment-history', builder: (c, s) => const PaymentHistoryPage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/payments', builder: (c, s) => const PaymentsPage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (c, s) => const ProfilePage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (c, s) => const SettingsPage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/surveys', builder: (c, s) => const SurveysPage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/tasks', builder: (c, s) => const TasksPage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/vanning-schedules', builder: (c, s) => const VanningSchedulesPage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/vessel-movements', builder: (c, s) => const VesselMovementsPage())]),
      ],
    ),

    // ── Admin pages — state kept alive using StatefulShellRoute (instant tab switching, no reload) ──
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => navigationShell,
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/admin/announcements',
              pageBuilder: (c, s) => const NoTransitionPage(child: AdminAnnouncementsPage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/admin/analytics',
              pageBuilder: (c, s) => const NoTransitionPage(child: AdminAnalyticsPage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/admin/audit-log',
              pageBuilder: (c, s) => const NoTransitionPage(child: AdminAuditLogPage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/admin/cargo-schedules',
              pageBuilder: (c, s) => const NoTransitionPage(child: AdminCargoSchedulesPage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/admin/dashboard',
              pageBuilder: (c, s) => const NoTransitionPage(child: AdminDashboardPage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/admin/events',
              pageBuilder: (c, s) => const NoTransitionPage(child: AdminEventsPage()),
              routes: [
                GoRoute(
                  path: ':id/attendees',
                  pageBuilder: (context, state) => CustomTransitionPage<void>(
                    key: state.pageKey,
                    child: AdminEventAttendeesPage(
                      eventId: int.parse(state.pathParameters['id'] ?? '0'),
                      title: state.uri.queryParameters['title'] ?? 'Event',
                    ),
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(milliseconds: 150),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/admin/fees',
              pageBuilder: (c, s) => const NoTransitionPage(child: AdminFeesPage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/admin/intelligence',
              pageBuilder: (c, s) => const NoTransitionPage(child: AdminIntelligencePage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/admin/license-renewal',
              pageBuilder: (c, s) => const NoTransitionPage(child: AdminLicenseRenewalPage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/admin/members',
              pageBuilder: (c, s) => const NoTransitionPage(child: AdminMembersPage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/admin/payments',
              pageBuilder: (c, s) => const NoTransitionPage(child: AdminPaymentsPage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/admin/payment-settings',
              pageBuilder: (c, s) => const NoTransitionPage(child: AdminPaymentSettingsPage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/admin/settings',
              pageBuilder: (c, s) => const NoTransitionPage(child: AdminSettingsPage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/admin/surveys',
              pageBuilder: (c, s) => const NoTransitionPage(child: AdminSurveysPage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/admin/tasks',
              pageBuilder: (c, s) => const NoTransitionPage(child: AdminTasksPage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/admin/tickets',
              pageBuilder: (c, s) => const NoTransitionPage(child: AdminTicketsPage()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/admin/sub-admins',
              pageBuilder: (c, s) => const NoTransitionPage(child: AdminSubAdminsPage()),
            ),
          ],
        ),
      ],
    ),
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
    final email = await SessionStorage.instance.getString('cubag_email');
    if (mounted) setState(() => _email = email);
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Visual Element
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFFfff7ed),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFf08232).withAlpha(40), width: 3),
                        ),
                        child: const Icon(Icons.desktop_windows_rounded, size: 48, color: Color(0xFFf08232)),
                      ),
                      const SizedBox(height: 32),

                      // Title
                      const Text(
                        'Admin Portal Restricted',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0f172a),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Description
                      const Text(
                        'To maintain security and full functionality, the admin dashboard is only accessible via a desktop web browser.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF64748b),
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Account Info Card
                      if (_email != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFf8fafc),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFe2e8f0)),
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0xFFe2e8f0),
                                radius: 18,
                                child: Icon(Icons.person, size: 20, color: Color(0xFF64748b)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('LOGGED IN AS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94a3b8), letterSpacing: 1)),
                                    Text(_email!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1e293b))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 12),

                      // Web URL Action
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFfff7ed),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFf08232).withAlpha(50)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.link, size: 18, color: Color(0xFFf08232)),
                            SizedBox(width: 8),
                            Text(
                              'cubag-platform.web.app',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFf08232)),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _loggingOut ? null : _logout,
                          icon: _loggingOut
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.logout_rounded, size: 20),
                          label: Text(
                            _loggingOut ? 'Signing out...' : 'Sign Out',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFf08232),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

