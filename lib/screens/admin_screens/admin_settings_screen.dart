import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/platform_settings_service.dart';
import '../../services/session_service.dart';
import 'admin_banners_screen.dart';

class AdminSettingsScreen extends StatefulWidget {
  final bool isStandalone;
  const AdminSettingsScreen({super.key, this.isStandalone = false});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final supabase = Supabase.instance.client;

  double commissionRate = 6.0;
  double totalPlatformGMV = 49389.0;
  bool isMaintenanceMode = false;
  bool is2FAEnabled = true;
  bool isEmailAlertsEnabled = true;
  bool isSmsNotificationsEnabled = false;
  bool isAutoApproveSellers = false;

  static const Color primaryTeal = Color(0xFF10B981);
  static const Color primaryDark = Color(0xFF047857);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateLight = Color(0xFF94A3B8);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color bgLight = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _fetchPlatformMetrics();
    _loadMaintenanceMode();
  }

  Future<void> _loadMaintenanceMode() async {
    final active = await PlatformSettingsService.isMaintenanceModeActive();
    if (mounted) setState(() => isMaintenanceMode = active);
  }

  Future<void> _toggleMaintenanceMode(bool val) async {
    setState(() => isMaintenanceMode = val);
    await PlatformSettingsService.setMaintenanceMode(val);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          val
              ? "Platform Maintenance Activated: Buyers & Sellers are now blocked."
              : "Platform Maintenance Deactivated: System is back Live for all.",
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5),
        ),
        backgroundColor: val ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _fetchPlatformMetrics() async {
    try {
      final ordersRes = await supabase.from('orders').select('total_amount, status');
      double sum = 0.0;
      for (final o in ordersRes) {
        final amount = (o['total_amount'] as num?)?.toDouble() ?? 0.0;
        final st = (o['status']?.toString() ?? '').toLowerCase();
        if (st != 'cancelled') {
          sum += amount;
        }
      }
      if (mounted) {
        setState(() {
          if (sum > 0) totalPlatformGMV = sum;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              "Log Out Admin",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 17, color: slateDark),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to end your Super Admin session?",
          style: GoogleFonts.poppins(color: slateMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: GoogleFonts.poppins(color: slateMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Log Out", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SessionService.clearSession();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final adminEmail = user?.email ?? "aliraza4025346@gmail.com";
    final estimatedRev = totalPlatformGMV * (commissionRate / 100);

    Widget bodyContent = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= 1. SUPER ADMIN PROFILE CARD =================
              _buildAdminProfileCard(adminEmail).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04),

              const SizedBox(height: 12),

              // ================= 2. PLATFORM MAINTENANCE MODE CARD =================
              _buildMaintenanceModeCard().animate().fadeIn(delay: 70.ms, duration: 300.ms).slideY(begin: 0.04),

              const SizedBox(height: 12),

              // ================= 3. HOME BANNERS & SLIDERS CARD =================
              _buildBannerManagerCard().animate().fadeIn(delay: 110.ms, duration: 300.ms).slideY(begin: 0.04),

              const SizedBox(height: 12),

              // ================= 4. PLATFORM COMMISSION RATE CARD =================
              _buildCommissionRateCard(estimatedRev).animate().fadeIn(delay: 150.ms, duration: 300.ms).slideY(begin: 0.04),

              const SizedBox(height: 12),

              // ================= 5. SECURITY SETTINGS CARD =================
              _buildSecuritySettingsCard().animate().fadeIn(delay: 210.ms, duration: 300.ms).slideY(begin: 0.04),

              const SizedBox(height: 12),

              // ================= 6. PLATFORM INFO CARD =================
              _buildPlatformInfoCard().animate().fadeIn(delay: 280.ms, duration: 300.ms).slideY(begin: 0.04),

              const SizedBox(height: 18),

              // ================= 7. LOGOUT BUTTON =================
              _buildLogoutButton().animate().fadeIn(delay: 350.ms, duration: 300.ms),
            ],
          ),
        ),
      ),
    );

    if (widget.isStandalone) {
      return Scaffold(
        backgroundColor: bgLight,
        appBar: AppBar(
          toolbarHeight: 46.0,
          title: Text(
            "StyLuxe",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: slateDark, fontSize: 16),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slateDark, size: 16),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(child: bodyContent),
      );
    }

    return bodyContent;
  }

  // ================= 1. SUPER ADMIN PROFILE CARD =================
  Widget _buildAdminProfileCard(String adminEmail) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryTeal, primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryTeal.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // White SA Avatar Box
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              "SA",
              style: GoogleFonts.poppins(
                color: primaryTeal,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Super Admin",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  adminEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "Full Platform Access",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Verified Shield Icon
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  // ================= 2. PLATFORM MAINTENANCE MODE CARD =================
  Widget _buildMaintenanceModeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMaintenanceMode ? const Color(0xFFFDE68A) : borderColor,
          width: isMaintenanceMode ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isMaintenanceMode
                ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
                : const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isMaintenanceMode
                            ? const Color(0xFFFEF3C7)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.engineering_rounded,
                        color: isMaintenanceMode ? const Color(0xFFD97706) : slateMuted,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Platform Maintenance",
                            style: GoogleFonts.poppins(
                              color: slateDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                          Text(
                            "Block non-admin logins & show maintenance",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: slateMuted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.72,
                child: CupertinoSwitch(
                  value: isMaintenanceMode,
                  activeTrackColor: const Color(0xFFF59E0B),
                  onChanged: _toggleMaintenanceMode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isMaintenanceMode ? const Color(0xFFFEF3C7) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isMaintenanceMode ? const Color(0xFFFDE68A) : const Color(0xFFDCFCE7),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isMaintenanceMode ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isMaintenanceMode
                        ? "MAINTENANCE ACTIVE: Buyers & sellers are redirected to Maintenance Screen."
                        : "SYSTEM LIVE: All customers and sellers can log in normally.",
                    style: GoogleFonts.poppins(
                      color: isMaintenanceMode ? const Color(0xFFB45309) : const Color(0xFF15803D),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= 3. HOME BANNERS & SLIDERS CARD =================
  Widget _buildBannerManagerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.view_carousel_rounded,
                    color: Color(0xFF6366F1),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Home Sliders & Banners",
                        style: GoogleFonts.poppins(
                          color: slateDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      Text(
                        "Manage visual promo carousels on Customer Home",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: slateMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              minimumSize: const Size(80, 34),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminBannersScreen(isStandalone: true),
                ),
              );
            },
            child: Text(
              "Manage",
              style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ================= 4. COMMISSION RATE CARD =================
  Widget _buildCommissionRateCard(double estimatedRev) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Platform Commission Rate",
                      style: GoogleFonts.poppins(
                        color: slateDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      "Applied to all seller revenues",
                      style: GoogleFonts.poppins(
                        color: slateMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4EA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${commissionRate.round()}%",
                  style: GoogleFonts.poppins(
                    color: primaryTeal,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: primaryTeal,
              inactiveTrackColor: const Color(0xFFE2E8F0),
              trackHeight: 4.5,
              thumbColor: primaryTeal,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
              overlayColor: primaryTeal.withValues(alpha: 0.15),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
            ),
            child: Slider(
              value: commissionRate,
              min: 1.0,
              max: 20.0,
              divisions: 19,
              onChanged: (val) {
                setState(() => commissionRate = val);
              },
            ),
          ),

          // Slider Min / Max Labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("1%", style: GoogleFonts.poppins(color: slateLight, fontSize: 10, fontWeight: FontWeight.w600)),
                Text("20%", style: GoogleFonts.poppins(color: slateLight, fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Estimated Calculation Text
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(color: slateMuted, fontSize: 11.5, fontWeight: FontWeight.w500),
              children: [
                const TextSpan(text: "Estimated monthly revenue: "),
                TextSpan(
                  text: "Rs. ${estimatedRev.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}",
                  style: GoogleFonts.poppins(color: primaryTeal, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= 3. SECURITY SETTINGS CARD =================
  Widget _buildSecuritySettingsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded, color: primaryTeal, size: 18),
              const SizedBox(width: 6),
              Text(
                "Security Settings",
                style: GoogleFonts.poppins(
                  color: slateDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 1. Two-Factor Authentication
          _buildToggleItem(
            title: "Two-Factor Authentication",
            subtitle: "SMS OTP on login",
            value: is2FAEnabled,
            onChanged: (v) => setState(() => is2FAEnabled = v),
          ),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),

          // 2. Email Alerts
          _buildToggleItem(
            title: "Email Alerts",
            subtitle: "Seller actions & payouts",
            value: isEmailAlertsEnabled,
            onChanged: (v) => setState(() => isEmailAlertsEnabled = v),
          ),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),

          // 3. SMS Notifications
          _buildToggleItem(
            title: "SMS Notifications",
            subtitle: "Critical alerts via SMS",
            value: isSmsNotificationsEnabled,
            onChanged: (v) => setState(() => isSmsNotificationsEnabled = v),
          ),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),

          // 4. Auto-Approve Sellers
          _buildToggleItem(
            title: "Auto-Approve Sellers",
            subtitle: "Skip manual review (risky)",
            value: isAutoApproveSellers,
            onChanged: (v) => setState(() => isAutoApproveSellers = v),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: slateDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  color: slateMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Transform.scale(
          scale: 0.72,
          child: CupertinoSwitch(
            value: value,
            activeTrackColor: primaryTeal,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // ================= 4. PLATFORM INFO CARD =================
  Widget _buildPlatformInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              const Icon(Icons.language_rounded, color: primaryTeal, size: 18),
              const SizedBox(width: 6),
              Text(
                "Platform Info",
                style: GoogleFonts.poppins(
                  color: slateDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Rows
          _buildInfoRow("Platform", "Styluxe Multi-Vendor"),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          _buildInfoRow("App Version", "v1.0.0 (Build 2026)"),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          _buildInfoRow("Database Status", "Supabase Connected", isStatus: true),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          _buildInfoRow("Server Region", "AP-South (Active)"),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isStatus = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: slateMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (isStatus)
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                value,
                style: GoogleFonts.poppins(
                  color: slateDark,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          )
        else
          Text(
            value,
            style: GoogleFonts.poppins(
              color: slateDark,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }

  // ================= 5. LOGOUT BUTTON =================
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFEF4444),
          side: const BorderSide(color: Color(0xFFFCA5A5)),
          padding: EdgeInsets.zero,
          alignment: Alignment.center,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white,
        ),
        onPressed: _handleLogout,
        icon: const Icon(Icons.logout_rounded, size: 16),
        label: Text(
          "Log Out Super Admin",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
