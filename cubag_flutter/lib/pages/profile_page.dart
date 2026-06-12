import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' show ImageFilter;
import '../components/app_layout.dart';
import '../components/trend_line.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';


class StandingTier {
  final String label;
  final Color color;
  final IconData icon;
  final String badgeText;

  StandingTier({
    required this.label,
    required this.color,
    required this.icon,
    required this.badgeText,
  });

  static StandingTier getFromStars(double stars) {
    if (stars >= 4.5) {
      return StandingTier(
        label: 'Elite Standing',
        color: const Color(0xFFD4AF37), // Classic Gold
        icon: Icons.workspace_premium,
        badgeText: 'ELITE MEMBER',
      );
    } else if (stars >= 3.5) {
      return StandingTier(
        label: 'Good Standing',
        color: const Color(0xFF10B981), // Emerald Green
        icon: Icons.verified_user,
        badgeText: 'ACTIVE MEMBER',
      );
    } else if (stars >= 2.0) {
      return StandingTier(
        label: 'Warning / Probationary',
        color: const Color(0xFFF59E0B), // Amber
        icon: Icons.warning_amber,
        badgeText: 'PROBATIONARY',
      );
    } else {
      return StandingTier(
        label: 'Suspended / Delinquent',
        color: const Color(0xFFEF4444), // Red
        icon: Icons.block,
        badgeText: 'SUSPENDED',
      );
    }
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic> _user = {};
  bool _showIdCard = false;
  bool _isLoading = true;
  bool _uploadingPhoto = false;
  String? _localPhotoPath; // optimistic local preview URL


  @override
  void initState() {
    super.initState();
    _fetchUser();
  }

  Future<void> _fetchUser() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService().get('/auth/me');
      if (res.statusCode == 200) setState(() => _user = res.data ?? {});
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _uploadAvatar() async {
    // Pick image file
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true, // needed for Flutter Web
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null && file.path == null) return;

    // Optimistic preview
    final String? previousPhoto = _user['profile_photo']?.toString();
    setState(() => _uploadingPhoto = true);

    try {
      final api = ApiService();
      late MultipartFile mpFile;
      if (file.bytes != null) {
        // Flutter Web — bytes only
        mpFile = MultipartFile.fromBytes(
          file.bytes!,
          filename: file.name,
        );
      } else {
        // Native — path available
        mpFile = await MultipartFile.fromFile(file.path!, filename: file.name);
      }

      final formData = FormData.fromMap({'photo': mpFile});
      final res = await api.upload('/auth/upload-photo', formData);

      if (res.statusCode == 200 && res.data['photo_url'] != null) {
        final photoUrl = res.data['photo_url'].toString();
        setState(() {
          _user = {..._user, 'profile_photo': photoUrl};
        });
        // ── Update the global AuthService so the header avatar refreshes ──
        if (mounted) {
          await Provider.of<AuthService>(context, listen: false).updatePhoto(photoUrl);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Profile photo updated!'),
              backgroundColor: Color(0xFF10b981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        final msg = res.data['message']?.toString() ?? 'Upload failed';
        setState(() => _user = {..._user, 'profile_photo': previousPhoto});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ $msg'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
      }
    } catch (e) {
      setState(() => _user = {..._user, 'profile_photo': previousPhoto});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Upload error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  String get _initials {
    final name = _user['name']?.toString().trim() ?? '';
    if (name.isEmpty) return '??';
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '??';

    final initials = parts.map((n) => n[0]).join('').toUpperCase();
    return initials.length > 2 ? initials.substring(0, 2) : initials;
  }

  String get _uniqueMemberId {
    final agencyCode = _user['agency_code']?.toString() ?? '';
    if (agencyCode.isNotEmpty && agencyCode != 'null') return agencyCode;

    final last = (_user['name']?.toString().split(' ').lastOrNull ?? '').toUpperCase();
    final id = _user['id']?.toString() ?? '';
    return id.isNotEmpty ? 'CUBAG-$last-00$id' : '—';
  }

  String _formatDate(String? str) {
    if (str == null) return '—';
    final d = DateTime.tryParse(str);
    if (d == null) return '—';
    return '${d.day} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppLayout(
        title: 'My Profile',
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final primary = Theme.of(context).primaryColor;
    final rawExpiry = _user['license_expiry_date']?.toString() ?? _user['licenseExpiryDate']?.toString();
    final expiry = (rawExpiry == null || rawExpiry == 'None' || rawExpiry == 'null' || rawExpiry.isEmpty) ? null : rawExpiry;
    final daysLeft = expiry != null ? DateTime.tryParse(expiry)?.difference(DateTime.now()).inDays : null;

    final complianceScore = int.tryParse(_user['compliance_score']?.toString() ?? '') ?? 100;
    final starRating = double.tryParse(_user['star_rating']?.toString() ?? '') ?? 5.0;
    final tier = StandingTier.getFromStars(starRating);

    return AppLayout(
      title: 'My Profile',
      child: Stack(children: [
        Column(children: [
          // Profile Header Card
          Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), clipBehavior: Clip.antiAlias, child: Column(children: [
            Container(height: 100, decoration: BoxDecoration(gradient: LinearGradient(colors: [primary, primary.withValues(alpha: 0.7)]))),
            Transform.translate(
              offset: const Offset(0, -40),
              child: Column(children: [
                Stack(children: [
                  // Avatar — shows photo if available, else initials
                  GestureDetector(
                    onTap: _uploadingPhoto ? null : _uploadAvatar,
                    child: Stack(children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        child: _user['profile_photo'] != null && _user['profile_photo'].toString().isNotEmpty
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: _user['profile_photo'].toString(),
                                width: 72, height: 72, fit: BoxFit.cover,
                                placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                                errorWidget: (_, _, _) => CircleAvatar(
                                  radius: 36,
                                  backgroundColor: primary.withValues(alpha: 0.1),
                                  child: Text(_initials, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primary)),
                                ),
                              ),
                            )
                          : CircleAvatar(
                              radius: 36,
                              backgroundColor: primary.withValues(alpha: 0.1),
                              child: Text(_initials, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primary)),
                            ),
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                          child: _uploadingPhoto
                            ? const Padding(
                                padding: EdgeInsets.all(6),
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.photo_camera, color: Colors.white, size: 14),
                        ),
                      ),
                    ]),
                  ),

                ]),
                const SizedBox(height: 8),

                Text(_user['name']?.toString() ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(_user['role']?.toString() ?? '', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFFD700), size: 18),
                    Text(
                      '${starRating.toStringAsFixed(1)} / 5.0 Stars',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      '(${tier.label})',
                      style: TextStyle(color: tier.color, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: LinearProgressIndicator(
                          value: complianceScore / 100.0,
                          backgroundColor: Colors.grey.shade200,
                          color: tier.color,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$complianceScore/100 Compliance Score',
                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: tier.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)), child: Text(tier.badgeText, style: TextStyle(color: tier.color, fontWeight: FontWeight.bold, fontSize: 12))),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _showIdCard = true),
                    icon: const Icon(Icons.badge, size: 16),
                    label: const Text('ID Card', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
              ]),
            ),
          ])),
          const SizedBox(height: 16),

          // Professional Details Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              const Padding(padding: EdgeInsets.all(16), child: Align(alignment: Alignment.centerLeft, child: Text('Professional Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
              const Divider(height: 1),
              _detailRow('MEMBER ID', _uniqueMemberId),
              _detailRow('ORGANIZATION', _user['company']?.toString() ?? 'Independent'),
              _detailRow('EMAIL ADDRESS', _user['email']?.toString() ?? '—'),
              _detailRow('PHONE NUMBER', _user['phone']?.toString() ?? 'Not provided'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: (_user['status'] == 'active' ? primary : Colors.red).withValues(alpha: 0.05)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('LICENSE', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        (daysLeft != null && daysLeft < 0) 
                          ? 'EXPIRED / INACTIVE' 
                          : _user['license_number']?.toString() ?? (_user['status'] == 'active' ? 'CBG-${DateTime.now().year}-${_user['id']?.toString() ?? 'LIC'}' : 'PAYMENT REQUIRED'), 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: (daysLeft != null && daysLeft < 0) || _user['status'] != 'active' ? Colors.red : null, 
                          fontSize: 16
                        )
                      ),
                      if (daysLeft != null) Text(daysLeft < 0 ? 'Expired ${_formatDate(expiry)}' : daysLeft <= 30 ? 'Expires in $daysLeft days — ${_formatDate(expiry)}' : 'Valid until ${_formatDate(expiry)}', style: TextStyle(fontSize: 12, color: daysLeft < 0 ? Colors.red : daysLeft <= 30 ? Colors.orange : Colors.grey)),
                    ])),
                    // Show Renew only if license is expired or expiring within 60 days
                    if (_user['status'] != 'active')
                      OutlinedButton(
                        onPressed: () => context.go('/payments'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Pay to Activate', style: TextStyle(fontSize: 12)),
                      )
                    else if (daysLeft != null && daysLeft <= 60)
                      OutlinedButton(
                        onPressed: () => context.go('/payments'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          foregroundColor: daysLeft < 0 ? Colors.red : Colors.orange,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(daysLeft < 0 ? 'Renew Now' : 'Renew Soon', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                  ]),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/payment-history'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('View License History'),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('HISTORICAL COMPLIANCE TREND', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 14),
                  TrendLineWidget(
                    points: (_user['rating_history'] as List?)
                            ?.map((h) => double.tryParse(h['compliance_score']?.toString() ?? '') ?? 100.0)
                            .toList() ??
                        [complianceScore.toDouble()],
                    color: tier.color,
                    height: 100,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildMathBreakdownSection(_user, primary),
            ),
          ),
        ]),

        // Digital ID Card Overlay
        if (_showIdCard)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: const Color(0xFF020617).withValues(alpha: 0.85),
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: const Color(0xFFf08232).withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: tier.color.withValues(alpha: 0.35),
                              blurRadius: 40,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: const Color(0xFFf08232).withValues(alpha: 0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Stack(
                            children: [
                              // Security Grid Watermark
                              Positioned.fill(
                                child: Opacity(
                                  opacity: 0.04,
                                  child: CustomPaint(
                                    painter: _IdGridPainter(color: const Color(0xFF0F172A)),
                                  ),
                                ),
                              ),
                              // Glowing Orbs
                              Positioned(
                                top: -80,
                                right: -80,
                                child: Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        const Color(0xFFf08232).withValues(alpha: 0.15),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: -100,
                                left: -60,
                                child: Container(
                                  width: 220,
                                  height: 220,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        tier.color.withValues(alpha: 0.15),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Content Column
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Header
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            // Tiny Logo Indicator
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFf08232).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: const Color(0xFFf08232).withValues(alpha: 0.3),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.shield,
                                                  color: Color(0xFFf08232),
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'CUBAG',
                                                  style: GoogleFonts.outfit(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 18,
                                                    color: const Color(0xFF0F172A),
                                                    letterSpacing: 1,
                                                  ),
                                                ),
                                                Text(
                                                  'DIGITAL IDENTITY',
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 9,
                                                    color: const Color(0xFFf08232),
                                                    letterSpacing: 0.8,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        // Status Chip / Shield Icon
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: tier.color.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: tier.color.withValues(alpha: 0.2),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                tier.icon,
                                                color: tier.color,
                                                size: 12,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                tier.badgeText,
                                                style: GoogleFonts.outfit(
                                                  color: tier.color,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    
                                    // User Avatar & Frame
                                    Stack(
                                      alignment: Alignment.bottomRight,
                                      children: [
                                        Container(
                                          width: 110,
                                          height: 110,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(24),
                                            border: Border.all(
                                              color: tier.color,
                                              width: 3,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: tier.color.withValues(alpha: 0.25),
                                                blurRadius: 15,
                                                offset: const Offset(0, 5),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(20),
                                            child: _user['profile_photo'] != null &&
                                                    _user['profile_photo'].toString().isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl: _user['profile_photo'].toString(),
                                                    width: 110,
                                                    height: 110,
                                                    fit: BoxFit.cover,
                                                    placeholder: (context, url) => const Center(
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Color(0xFFf08232),
                                                      ),
                                                    ),
                                                    errorWidget: (_, _, _) => CircleAvatar(
                                                      radius: 55,
                                                      backgroundColor: const Color(0xFFF1F5F9),
                                                      child: Text(
                                                        _initials,
                                                        style: GoogleFonts.outfit(
                                                          fontSize: 32,
                                                          fontWeight: FontWeight.bold,
                                                          color: const Color(0xFF64748B),
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : CircleAvatar(
                                                    radius: 55,
                                                    backgroundColor: const Color(0xFFF1F5F9),
                                                    child: Text(
                                                      _initials,
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 32,
                                                        fontWeight: FontWeight.bold,
                                                        color: const Color(0xFF64748B),
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        // Verification Check Badge
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black12,
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Icon(
                                              Icons.verified,
                                              color: _user['status'] == 'active'
                                                  ? const Color(0xFF10B981)
                                                  : Colors.grey,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    // User Name & Title
                                    Text(
                                      _user['name']?.toString() ?? '',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _user['role']?.toString().toUpperCase() ?? 'BROKER MEMBER',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF64748B),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    
                                    // Credentials Grid Container
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          // Row 1: Member ID & License No.
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'MEMBER ID',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                        color: const Color(0xFF94A3B8),
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      _uniqueMemberId,
                                                      style: GoogleFonts.outfit(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                        color: const Color(0xFF0F172A),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                height: 24,
                                                width: 1,
                                                color: const Color(0xFFE2E8F0),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'LICENSE NO.',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                        color: const Color(0xFF94A3B8),
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      _user['license_number']?.toString() ??
                                                          (_user['status'] == 'active'
                                                              ? 'CBG-${DateTime.now().year}-${_user['id']?.toString() ?? 'LIC'}'
                                                              : 'PENDING'),
                                                      style: GoogleFonts.outfit(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                        color: const Color(0xFF0F172A),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 10),
                                            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                                          ),
                                          // Row 2: Expires & Compliance
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'LICENSE EXPIRES',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                        color: const Color(0xFF94A3B8),
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      expiry != null ? _formatDate(expiry) : 'Not Set',
                                                      style: GoogleFonts.outfit(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                        color: daysLeft == null
                                                            ? const Color(0xFF64748B)
                                                            : daysLeft < 0
                                                                ? const Color(0xFFEF4444)
                                                                : daysLeft <= 30
                                                                    ? const Color(0xFFF59E0B)
                                                                    : const Color(0xFF0F172A),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                height: 24,
                                                width: 1,
                                                color: const Color(0xFFE2E8F0),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'COMPLIANCE RATING',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                        color: const Color(0xFF94A3B8),
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.star,
                                                          color: Color(0xFFFFD700),
                                                          size: 14,
                                                        ),
                                                        const SizedBox(width: 2),
                                                        Text(
                                                          '${starRating.toStringAsFixed(1)} ($complianceScore%)',
                                                          style: GoogleFonts.outfit(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 13,
                                                            color: const Color(0xFF0F172A),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    
                                    // QR Code Section
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFFf08232).withValues(alpha: 0.2),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFf08232).withValues(alpha: 0.05),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          CachedNetworkImage(
                                            imageUrl:
                                                'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${Uri.encodeComponent('https://winningedgeinvestment.com/#/verify-member/${_user['id']}')}',
                                            width: 110,
                                            height: 110,
                                            errorWidget: (context, error, stackTrace) => Container(
                                              width: 110,
                                              height: 110,
                                              color: const Color(0xFFF8FAFC),
                                              child: const Icon(
                                                Icons.qr_code_2,
                                                size: 40,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                          // Futuristic horizontal scan line visual effect
                                          Positioned(
                                            top: 55,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              height: 2,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFf08232),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(0xFFf08232).withValues(alpha: 0.5),
                                                    blurRadius: 4,
                                                    spreadRadius: 1,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'SCAN AT CHECKPOINTS',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFFf08232),
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Secure digital credential verification',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Close Button positioned absolutely inside the stack
                              Positioned(
                                top: 12,
                                right: 12,
                                child: GestureDetector(
                                  onTap: () => setState(() => _showIdCard = false),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Color(0xFF64748B),
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _detailRow(String label, String value) {
    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        ])),
      ])),
      const Divider(height: 1),
    ]);
  }

  Widget _buildMathBreakdownSection(Map<String, dynamic> m, Color primary) {
    final bd = m['breakdown'] as Map<String, dynamic>?;
    if (bd == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: Text('Loading compliance breakdown details...', style: TextStyle(color: Colors.grey, fontSize: 12))),
      );
    }

    final paymentScore = bd['payment_score'] ?? 0;
    final paymentPunctual = bd['payment_punctual_score'] ?? 0;
    final paymentHistory = bd['payment_history_score'] ?? 0;
    final overdueCount = bd['overdue_payments_count'] ?? 0;
    final totalPaid = bd['total_payments_paid'] ?? 0;
    final onTimePaid = bd['on_time_payments_paid'] ?? 0;

    final taskScore = bd['task_score'] ?? 0;
    final licenseScore = bd['license_score'] ?? 0;
    final taskCompletionScore = bd['task_completion_score'] ?? 0;
    final totalTasks = bd['total_tasks'] ?? 0;
    final completedTasks = bd['completed_tasks'] ?? 0;

    final engagementScore = bd['engagement_score'] ?? 0;
    final surveyScore = bd['survey_score'] ?? 0;
    final totalSurveys = bd['total_surveys'] ?? 0;
    final respondedSurveys = bd['responded_surveys'] ?? 0;
    final agmScore = bd['agm_score'] ?? 0;

    final adminScore = bd['admin_score'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'COMPLIANCE BREAKDOWN MATH',
          style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        
        _breakdownTile(
          icon: Icons.payments_outlined,
          color: const Color(0xFF10B981),
          title: 'Payment Compliance',
          scoreText: '$paymentScore / 40 pts',
          details: [
            '• Punctual payment (no outstanding overdue): $paymentPunctual / 25 pts',
            '• On-time payment history ratio ($onTimePaid / $totalPaid paid on time): $paymentHistory / 15 pts',
            if (overdueCount > 0) '• WARNING: $overdueCount overdue payments detected.'
          ],
        ),
        
        _breakdownTile(
          icon: Icons.task_alt_outlined,
          color: const Color(0xFF3B82F6),
          title: 'Task & Document Compliance',
          scoreText: '$taskScore / 30 pts',
          details: [
            '• License renewal status: $licenseScore / 15 pts',
            '• Required tasks compliance ($completedTasks / $totalTasks completed): $taskCompletionScore / 15 pts',
          ],
        ),

        _breakdownTile(
          icon: Icons.campaign_outlined,
          color: const Color(0xFF8B5CF6),
          title: 'Engagement & Activities',
          scoreText: '$engagementScore / 20 pts',
          details: [
            '• Survey response rate ($respondedSurveys / $totalSurveys completed): $surveyScore / 10 pts',
            '• Annual General Meeting (AGM) attendance: $agmScore / 10 pts',
          ],
        ),

        _breakdownTile(
          icon: Icons.rate_review_outlined,
          color: const Color(0xFFF59E0B),
          title: 'Admin Manual Review',
          scoreText: '$adminScore / 10 pts',
          details: [
            '• Direct administrative compliance modifier: $adminScore / 10 pts',
          ],
        ),
      ],
    );
  }

  Widget _breakdownTile({
    required IconData icon,
    required Color color,
    required String title,
    required String scoreText,
    required List<String> details,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Text(
                scoreText,
                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...details.map((detail) => Padding(
            padding: const EdgeInsets.only(top: 2, left: 24),
            child: Text(
              detail,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          )),
        ],
      ),
    );
  }
}

extension StringCapitalize on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

class _IdGridPainter extends CustomPainter {
  final Color color;
  _IdGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    const spacing = 18.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
