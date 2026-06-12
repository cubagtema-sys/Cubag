import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../components/app_logo.dart';

const _kOrange = Color(0xFFf08232);
const _kOrangeDark = Color(0xFFd96e1c);
const _kNavyCard = Color(0xFF0F172A);
const _kPurpleGlow = Color(0xFF6366F1);

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _heroKey = GlobalKey();
  final _featuresKey = GlobalKey();
  final _metricsKey = GlobalKey();
  final _faqKey = GlobalKey();
  final _ctaKey = GlobalKey();

  bool _scrolled = false;
  bool _mobileMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.offset > 20) {
      if (!_scrolled) setState(() => _scrolled = true);
    } else {
      if (_scrolled) setState(() => _scrolled = false);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
    }
    setState(() => _mobileMenuOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 950;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Premium clean off-white
      body: Stack(
        children: [
          // 1. Ambient Glowing Orbs Background
          Positioned(
            top: -150,
            right: -150,
            child: _AmbientGlow(color: _kOrange.withAlpha(12), size: 550),
          ),
          Positioned(
            top: size.height * 0.35,
            left: -150,
            child: _AmbientGlow(color: Colors.amber.withAlpha(8), size: 450),
          ),
          Positioned(
            bottom: -100,
            right: -50,
            child: _AmbientGlow(color: _kOrange.withAlpha(10), size: 500),
          ),

          // 2. High-Tech Grid Overlay
          Positioned.fill(
            child: CustomPaint(
              painter: _GridBackgroundPainter(
                gridColor: Colors.black.withAlpha(10),
                gridSpacing: 50.0,
              ),
            ),
          ),

          // 3. Scrollable Content Layer
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  const SizedBox(height: 90), // Header spacing offset
                  
                  // Hero Section
                  Padding(
                    key: _heroKey,
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: isMobile ? _buildMobileHero(size) : _buildDesktopHero(size),
                      ),
                    ),
                  ),

                  // Metrics Bar
                  Padding(
                    key: _metricsKey,
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: _buildMetricsGrid(isMobile),
                      ),
                    ),
                  ),

                  // Features Showcase Section
                  Padding(
                    key: _featuresKey,
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 64.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: _buildFeaturesSection(isMobile),
                      ),
                    ),
                  ),

                  // Expandable FAQ Section
                  Padding(
                    key: _faqKey,
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 64.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: _buildFAQSection(),
                      ),
                    ),
                  ),

                  // Call to Action Banner
                  Padding(
                    key: _ctaKey,
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: _buildCTABanner(),
                      ),
                    ),
                  ),

                  // Footer Section
                  _buildFooter(isMobile),
                ],
              ),
            ),
          ),

          // 4. Glassmorphic Header Navigation Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(context, isMobile),
          ),

          // 5. Mobile Hamburger Navigation Overlay Drawer
          if (_mobileMenuOpen) _buildMobileMenuDrawer(context),
        ],
      ),
    );
  }

  // --- Header UI ---
  Widget _buildHeader(BuildContext context, bool isMobile) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      decoration: BoxDecoration(
        color: _scrolled ? Colors.white.withAlpha(225) : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: _scrolled ? Colors.black.withAlpha(15) : Colors.transparent,
            width: 1,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo
              GestureDetector(
                onTap: () => _scrollTo(_heroKey),
                child: Row(
                  children: [
                    const AppLogo(size: 40, borderRadius: 10, showShadow: true),
                    const SizedBox(width: 12),
                    Text(
                      'CUBAG',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF0F172A),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Desktop Nav
              if (!isMobile)
                Row(
                  children: [
                    _headerLink('Features', () => _scrollTo(_featuresKey)),
                    _headerLink('Metrics', () => _scrollTo(_metricsKey)),
                    _headerLink('FAQ', () => _scrollTo(_faqKey)),
                  ],
                ),
              // Header CTAs
              if (!isMobile)
                Row(
                  children: [
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(
                        'Sign In',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF475569),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => context.go('/register'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kOrange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Join CUBAG',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                IconButton(
                  onPressed: () => setState(() => _mobileMenuOpen = true),
                  icon: const Icon(Icons.menu, color: Color(0xFF0F172A), size: 28),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerLink(String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            text,
            style: GoogleFonts.outfit(
              color: const Color(0xFF475569),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // --- Mobile Hamburger Overlay Menu ---
  Widget _buildMobileMenuDrawer(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _mobileMenuOpen = false),
        child: Container(
          color: Colors.black.withAlpha(100),
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {}, // Prevent tap bubble
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 280,
                height: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(left: BorderSide(color: Colors.black12)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'NAVIGATION',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _mobileMenuOpen = false),
                          icon: const Icon(Icons.close, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _drawerLink('Platform Features', () => _scrollTo(_featuresKey)),
                    _drawerLink('Key Metrics', () => _scrollTo(_metricsKey)),
                    _drawerLink('Frequently Asked Questions', () => _scrollTo(_faqKey)),
                    const Spacer(),
                    const Divider(color: Colors.black12),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => context.go('/login'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kOrange,
                          side: const BorderSide(color: _kOrange, width: 2.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Login',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => context.go('/register'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Register Now',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _drawerLink(String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            const Icon(Icons.arrow_forward_ios, size: 12, color: _kOrange),
            const SizedBox(width: 12),
            Text(
              text,
              style: GoogleFonts.outfit(
                color: const Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Desktop Layout Hero ---
  Widget _buildDesktopHero(Size size) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Hero Description Left Side
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _kOrange.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kOrange.withAlpha(75)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: _kOrange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PORT LOGISTICS & COMPLIANCE HUB',
                      style: GoogleFonts.outfit(
                        color: _kOrange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Empowering Ghana\'s\nCustoms ',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF0F172A),
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        letterSpacing: -1.5,
                      ),
                    ),
                    TextSpan(
                      text: 'Brokerage',
                      style: GoogleFonts.outfit(
                        color: _kOrange,
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        letterSpacing: -1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Seamlessly orchestrate real-time vessel telemetry, cargo schedules, mobile payments, and unified compliance workflows in Ghana\'s most advanced customs enterprise suite.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF475569),
                  fontSize: 16,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 40),
              Row(
                children: [
                  SizedBox(
                    height: 56,
                    width: 180,
                    child: ElevatedButton(
                      onPressed: () => context.go('/register'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Get Started',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    height: 56,
                    width: 180,
                    child: OutlinedButton(
                      onPressed: () => _scrollTo(_featuresKey),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kOrange,
                        side: const BorderSide(color: _kOrange, width: 2.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Explore Features',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 40),
        // Interactive Live Sandbox Mockup Deck Right Side
        const Expanded(
          flex: 5,
          child: _HeroMockupDeck(),
        ),
      ],
    );
  }

  // --- Mobile Layout Hero ---
  Widget _buildMobileHero(Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _kOrange.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kOrange.withAlpha(75)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: _kOrange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'PORT LOGISTICS & COMPLIANCE HUB',
                style: GoogleFonts.outfit(
                  color: _kOrange,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Empowering Ghana\'s\nCustoms ',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF0F172A),
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  letterSpacing: -1.0,
                ),
              ),
              TextSpan(
                text: 'Brokerage',
                style: GoogleFonts.outfit(
                  color: _kOrange,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  letterSpacing: -1.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Seamlessly orchestrate real-time vessel telemetry, cargo schedules, mobile payments, and unified compliance workflows in Ghana\'s most advanced customs enterprise suite.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: const Color(0xFF475569),
            fontSize: 14,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        Column(
          children: [
            SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/register'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Get Started',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _scrollTo(_featuresKey),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kOrange,
                  side: const BorderSide(color: _kOrange, width: 2.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Explore Features',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 60),
        const _HeroMockupDeck(),
      ],
    );
  }

  // --- Metrics Ticker / Grid ---
  Widget _buildMetricsGrid(bool isMobile) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isMobile ? (MediaQuery.of(context).size.width < 500 ? 1 : 2) : 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isMobile ? 1.6 : 1.25,
      children: const [
        _MetricCard(
          number: '1,200+',
          label: 'Active Members',
          detail: 'Accredited customs clearing brokers',
        ),
        _MetricCard(
          number: '24/7',
          label: 'Live Telemetry',
          detail: 'AIS ship tracking and ETA updates',
        ),
        _MetricCard(
          number: '99.9%',
          label: 'System Uptime',
          detail: 'Guaranteed core engine availability',
        ),
        _MetricCard(
          number: 'Instant',
          label: 'Dues & License',
          detail: 'Mobile Money and card payment processing',
        ),
      ],
    );
  }

  // --- Feature Showcase ---
  Widget _buildFeaturesSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'PLATFORM CAPABILITIES',
          style: GoogleFonts.outfit(
            color: _kOrange,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Unified Features for Modern Port Logistics',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: const Color(0xFF0F172A),
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Text(
            'Everything a customs broker needs to manage schedules, track cargo vessels, pay annual fees, and network with agents at Tema & Takoradi Port.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 48),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isMobile ? 1 : 2,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
          childAspectRatio: isMobile ? 1.15 : 1.15,
          children: const [
            _FeatureCard(
              icon: Icons.radar,
              title: 'Live Vessel Tracking & AIS',
              description: 'Access real-time global navigation coordinate mapping, anchorage speeds, ETA forecasts, and live status reports for inbound freight carriers.',
              bullets: [
                'Precise location mapping',
                'Anchorage & underway telemetry',
                'Customs docking reports',
              ],
            ),
            _FeatureCard(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Automated License Renewal & Dues',
              description: 'Quickly pay annual license fees and association dues via integrated Mobile Money and Debit Cards. Instantly generate official invoices.',
              bullets: [
                'Instant payment confirmations',
                'Automatic PDF receipts',
                'Licensure progress tracking',
              ],
            ),
            _FeatureCard(
              icon: Icons.verified_user_outlined,
              title: 'Tasks & Compliance Scoring',
              description: 'Upload required license clearances and training evidence. View dynamic compliance ratings and checklists evaluated by administrators.',
              bullets: [
                'Digital evidence upload manager',
                'Admin rating checklists',
                'Instant suspension alerts',
              ],
            ),
            _FeatureCard(
              icon: Icons.hub_outlined,
              title: 'Ghana Broker Directory Hub',
              description: 'Stay connected with other verified freight forwarders, terminal sub-admins, and port controllers inside a secure unified member directory.',
              bullets: [
                'Verified broker credentials',
                'Fast direct messaging',
                'Customs resource networking',
              ],
            ),
          ],
        ),
      ],
    );
  }

  // --- FAQ Section ---
  Widget _buildFAQSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'FAQ',
          style: GoogleFonts.outfit(
            color: _kOrange,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Frequently Asked Questions',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: const Color(0xFF0F172A),
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 32),
        const _FAQCard(
          question: 'What is CUBAG and who is this platform for?',
          answer: 'The Customs Brokers Association of Ghana (CUBAG) platform is a dedicated enterprise workspace designed for verified customs brokers, freight forwarders, and port operators in Ghana to manage cargo logs, track vessel locations, pay license dues, and network securely.',
        ),
        const _FAQCard(
          question: 'How do I pay my annual membership license fees?',
          answer: 'Once logged in, navigate to the "Payments" page. You can review pending dues, choose to renew your license, and complete the transaction instantly using mobile money (MTN, Telecel, AT) or standard banking cards. Your receipt is generated automatically.',
        ),
        const _FAQCard(
          question: 'Why does my digital ID card say suspended?',
          answer: 'Your membership rating and ID card status depend on your compliance checklist tasks (e.g. uploading verification documents, paying dues). If important clearances are missing or expired, your score drops and status shows as suspended. Complete the items on the Tasks page to resolve this.',
        ),
        const _FAQCard(
          question: 'Can I track incoming cargo vessels in real time?',
          answer: 'Yes. CUBAG is connected directly to AIS (Automatic Identification System) maritime satellite networks, providing live updates on ship coordinates, draft depth, knot speeds, departure points, and estimated times of arrival (ETA) at Tema and Takoradi Ports.',
        ),
      ],
    );
  }

  // --- CTA Banner ---
  Widget _buildCTABanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _kOrange,
            _kOrangeDark,
            Color(0xFFEA580C),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _kOrange.withAlpha(25),
            blurRadius: 40,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'JOIN THE DIGITAL ECOSYSTEM',
            style: GoogleFonts.outfit(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Elevate Your Customs Brokerage Business',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Text(
              'Gain access to real-time telemetry, automated invoices, member directories, and full compliance tools to streamline operations at Ghana ports.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white.withAlpha(200),
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 36),
          SizedBox(
            height: 58,
            width: 200,
            child: ElevatedButton(
              onPressed: () => context.go('/register'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _kOrange,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Register Now',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Footer UI ---
  Widget _buildFooter(bool isMobile) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF030712), // Elegant dark slate footer for structured grounding
      ),
      width: double.infinity,
      padding: const EdgeInsets.only(top: 64, bottom: 32, left: 24, right: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo / Info Column
                  Expanded(
                    flex: isMobile ? 12 : 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const AppLogo(size: 36, borderRadius: 8),
                            const SizedBox(width: 12),
                            Text(
                              'CUBAG',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Dedicated to digitizing, validating, and accelerating the clearing and forwarding trade ecosystem in the Republic of Ghana.',
                          style: GoogleFonts.inter(
                            color: Colors.white38,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isMobile) ...[
                    const Spacer(),
                    // Column 1
                    Expanded(
                      flex: 2,
                      child: _footerCol(
                        'Platform',
                        ['Live Tracker', 'Vanning Logs', 'Members', 'Payments'],
                      ),
                    ),
                    // Column 2
                    Expanded(
                      flex: 2,
                      child: _footerCol(
                        'Association',
                        ['About Us', 'Contact', 'News feed', 'Support'],
                      ),
                    ),
                    // Column 3
                    Expanded(
                      flex: 2,
                      child: _footerCol(
                        'Security',
                        ['Privacy Policy', 'Terms of Use', 'GHA Customs', 'Certifications'],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 48),
              const Divider(color: Colors.white10),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '© ${DateTime.now().year} Customs Brokers Association of Ghana. All Rights Reserved.',
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (!isMobile)
                    Text(
                      'Secured with AES-256 & TLS 1.3',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF10B981),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footerCol(String title, List<String> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 18),
        ...links.map((link) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {},
            child: Text(
              link,
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 13,
              ),
            ),
          ),
        )),
      ],
    );
  }
}

// --- Animated Mockup Display Grid (Right Hero Area) ---
class _HeroMockupDeck extends StatelessWidget {
  const _HeroMockupDeck();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 420,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Tech Grid Circles (decorative)
          Positioned(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _kOrange.withAlpha(20), width: 1.5),
              ),
            ),
          ),
          Positioned(
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _kPurpleGlow.withAlpha(15), width: 1.5),
              ),
            ),
          ),

          // Card 1: Vessel Tracker (Top Left, floats slowly)
          const Positioned(
            top: 20,
            left: 20,
            child: _FloatingWidget(
              durationSeconds: 5,
              offsetRange: 8.0,
              child: _TiltedCard(
                child: _VesselTrackerMockup(),
              ),
            ),
          ),

          // Card 2: Compliance Circle Widget (Bottom Right, offsets differently)
          const Positioned(
            bottom: 20,
            right: 15,
            child: _FloatingWidget(
              durationSeconds: 4,
              offsetRange: 12.0,
              child: _TiltedCard(
                child: _ComplianceMockup(),
              ),
            ),
          ),

          // Card 3: Digital Membership ID Card (Center, sits slightly in front, tilts)
          const Positioned(
            top: 140,
            left: 40,
            child: _FloatingWidget(
              durationSeconds: 6,
              offsetRange: 6.0,
              child: _TiltedCard(
                child: _DigitalCardMockup(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Dynamic Vessel Telemetry Mockup Widget ---
class _VesselTrackerMockup extends StatefulWidget {
  const _VesselTrackerMockup();

  @override
  State<_VesselTrackerMockup> createState() => _VesselTrackerMockupState();
}

class _VesselTrackerMockupState extends State<_VesselTrackerMockup> with SingleTickerProviderStateMixin {
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(240),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withAlpha(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _kOrange.withAlpha(40),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.directions_boat, size: 14, color: _kOrange),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'MSC AMSTERDAM',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF0F172A),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withAlpha(35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withAlpha(80)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'UNDERWAY',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF10B981),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SPEED', style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 8, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('18.4 KTS', style: GoogleFonts.outfit(color: const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ETA', style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 8, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('2h 14m', style: GoogleFonts.outfit(color: const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DRAFT', style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 8, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('12.5 M', style: GoogleFonts.outfit(color: const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _progressController,
            builder: (context, child) {
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TEMA (GH)', style: GoogleFonts.outfit(color: const Color(0xFF475569), fontSize: 10, fontWeight: FontWeight.bold)),
                      Text('${(_progressController.value * 100).toInt()}%', style: GoogleFonts.outfit(color: _kOrange, fontSize: 10, fontWeight: FontWeight.bold)),
                      Text('LOMÉ (TG)', style: GoogleFonts.outfit(color: const Color(0xFF475569), fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: _progressController.value,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [_kOrange, Colors.amber]),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Positioned(
                        left: (290 - 48) * _progressController.value,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: _kOrange, blurRadius: 6, spreadRadius: 1),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// --- Dynamic Compliance Dashboard Mockup Widget ---
class _ComplianceMockup extends StatefulWidget {
  const _ComplianceMockup();

  @override
  State<_ComplianceMockup> createState() => _ComplianceMockupState();
}

class _ComplianceMockupState extends State<_ComplianceMockup> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 0.85).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(240),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withAlpha(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'MEMBER COMPLIANCE',
            style: GoogleFonts.outfit(
              color: const Color(0xFF64748B),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CustomPaint(
                      painter: _ComplianceRingPainter(
                        progress: _progressAnimation.value,
                        activeColor: const Color(0xFFf08232),
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(_progressAnimation.value * 100).toInt()}%',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF0F172A),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'VERIFIED',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF10B981),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _complianceItem('Annual License Fee', true),
          const SizedBox(height: 8),
          _complianceItem('Security Clearance', true),
          const SizedBox(height: 8),
          _complianceItem('Vessel Manifest Duty', false),
        ],
      ),
    );
  }

  Widget _complianceItem(String label, bool done) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            color: const Color(0xFF334155),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done ? const Color(0xFF10B981) : Colors.amber,
          size: 11,
        ),
      ],
    );
  }
}

class _ComplianceRingPainter extends CustomPainter {
  final double progress;
  final Color activeColor;

  _ComplianceRingPainter({required this.progress, required this.activeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;

    final bgPaint = Paint()
      ..color = Colors.black.withAlpha(15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    final fgPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ComplianceRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.activeColor != activeColor;
  }
}

// --- Digital Access Card Mockup Widget ---
class _DigitalCardMockup extends StatelessWidget {
  const _DigitalCardMockup();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290,
      height: 175,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1A3A),
            _kNavyCard,
            _kOrange,
          ],
          stops: [0.0, 0.6, 1.0],
        ),
        border: Border.all(color: Colors.white.withAlpha(35)),
        boxShadow: [
          BoxShadow(
            color: _kOrange.withAlpha(20),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(85),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Opacity(
              opacity: 0.1,
              child: const AppLogo(size: 110, borderRadius: 30),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CUBAG DIGITAL ID',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        'CUSTOMS BROKERS ASSOCIATION OF GHANA',
                        style: GoogleFonts.outfit(
                          color: Colors.white30,
                          fontSize: 5.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const AppLogo(size: 26, borderRadius: 6),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(120),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.amberAccent.withAlpha(150)),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KOFI MENSAH',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'LIC NO: GHA-CB-2026-904',
                        style: GoogleFonts.outfit(
                          color: Colors.white60,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981).withAlpha(100)),
                    ),
                    child: Text(
                      'ACTIVE MEMBER',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF10B981),
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- 3D Hover Mouse tilt card decorator ---
class _TiltedCard extends StatefulWidget {
  final Widget child;
  const _TiltedCard({required this.child});

  @override
  State<_TiltedCard> createState() => _TiltedCardState();
}

class _TiltedCardState extends State<_TiltedCard> {
  double _rotX = 0.0;
  double _rotY = 0.0;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _rotX = 0.0;
        _rotY = 0.0;
      }),
      onHover: (event) {
        final RenderBox? box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final size = box.size;
        final localPos = event.localPosition;
        
        final rx = -((localPos.dy - size.height / 2) / (size.height / 2)) * 12 * (math.pi / 180);
        final ry = ((localPos.dx - size.width / 2) / (size.width / 2)) * 12 * (math.pi / 180);
        
        setState(() {
          _rotX = rx;
          _rotY = ry;
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: _isHovered ? 50 : 300),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001) // perspective
          ..rotateX(_rotX)
          ..rotateY(_rotY),
        transformAlignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}

// --- Sine Wave Vertical Floating Widget decorator ---
class _FloatingWidget extends StatefulWidget {
  final Widget child;
  final double offsetRange;
  final int durationSeconds;

  const _FloatingWidget({
    required this.child,
    this.offsetRange = 10.0,
    this.durationSeconds = 4,
  });

  @override
  State<_FloatingWidget> createState() => _FloatingWidgetState();
}

class _FloatingWidgetState extends State<_FloatingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.durationSeconds),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(
      begin: -widget.offsetRange,
      end: widget.offsetRange,
    ).animate(CurvedAnimation(
      parent: _floatController,
      curve: Curves.easeInOutSine,
    ));
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// --- Ambient Background Glow Orb ---
class _AmbientGlow extends StatelessWidget {
  final Color color;
  final double size;

  const _AmbientGlow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: size * 0.4,
            spreadRadius: size * 0.2,
          ),
        ],
      ),
    );
  }
}

// --- High Tech Background Grid CustomPainter ---
class _GridBackgroundPainter extends CustomPainter {
  final Color gridColor;
  final double gridSpacing;

  const _GridBackgroundPainter({
    required this.gridColor,
    this.gridSpacing = 50.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [gridColor, gridColor.withAlpha(0)],
        stops: const [0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- Metric Counter Card Widget ---
class _MetricCard extends StatefulWidget {
  final String number;
  final String label;
  final String detail;

  const _MetricCard({
    required this.number,
    required this.label,
    required this.detail,
  });

  @override
  State<_MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<_MetricCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(200),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _hovered ? _kOrange.withAlpha(120) : Colors.black.withAlpha(10),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _hovered ? _kOrange.withAlpha(15) : Colors.black.withAlpha(5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.number,
              style: GoogleFonts.outfit(
                color: _kOrange,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: const Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.detail,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Platform Pillars Feature Showcase Card ---
class _FeatureCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<String> bullets;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.bullets,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0.0, _hovered ? -8.0 : 0.0, 0.0),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _hovered 
              ? const Color(0xFFF1F5F9).withAlpha(220)
              : Colors.white.withAlpha(180),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _hovered 
                ? _kOrange.withAlpha(120) 
                : Colors.black.withAlpha(10),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _hovered ? _kOrange.withAlpha(15) : Colors.black.withAlpha(5),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _hovered ? _kOrange : _kOrange.withAlpha(25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                widget.icon,
                color: _hovered ? Colors.white : _kOrange,
                size: 26,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.title,
              style: GoogleFonts.outfit(
                color: const Color(0xFF0F172A),
                fontSize: 19,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.description,
              style: GoogleFonts.inter(
                color: const Color(0xFF475569),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.black12),
            const SizedBox(height: 12),
            ...widget.bullets.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: _kOrange, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      b,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF334155),
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// --- Accordion FAQ List Tile Widget ---
class _FAQCard extends StatefulWidget {
  final String question;
  final String answer;

  const _FAQCard({required this.question, required this.answer});

  @override
  State<_FAQCard> createState() => _FAQCardState();
}

class _FAQCardState extends State<_FAQCard> {
  bool _expanded = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _expanded || _hovered
                ? const Color(0xFFF1F5F9).withAlpha(220)
                : Colors.white.withAlpha(180),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _expanded 
                  ? _kOrange.withAlpha(100) 
                  : (_hovered ? Colors.black.withAlpha(25) : Colors.black.withAlpha(10)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: _kOrange,
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    widget.answer,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF475569),
                      fontSize: 13.5,
                      height: 1.6,
                    ),
                  ),
                ),
                crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
