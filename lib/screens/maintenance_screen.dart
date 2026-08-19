import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/platform_settings_service.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  bool isChecking = false;

  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color amberAccent = Color(0xFFF59E0B);
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  Future<void> _checkStatus() async {
    setState(() => isChecking = true);
    await Future.delayed(const Duration(milliseconds: 700));

    final isActive = await PlatformSettingsService.isMaintenanceModeActive();
    if (!mounted) return;

    setState(() => isChecking = false);

    if (!isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Maintenance Completed! Welcome back to StyLuxe.",
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "System upgrade is still in progress. Please check back shortly.",
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
          ),
          backgroundColor: amberAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 1. StyLuxe Brand Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: primaryTeal,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "SX",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "StyLuxe",
                        style: GoogleFonts.poppins(
                          color: slateDark,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 300.ms),

                  const SizedBox(height: 36),

                  // 2. Glowing Maintenance Illustration Icon
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulsing outer halo
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: amberAccent.withValues(alpha: 0.12),
                        ),
                      ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                       .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.15, 1.15), duration: 1800.ms),

                      // Inner badge
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: amberAccent.withValues(alpha: 0.35), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: amberAccent.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.engineering_rounded,
                          color: amberAccent,
                          size: 44,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 150.ms, duration: 400.ms).scale(),

                  const SizedBox(height: 28),

                  // 3. Maintenance Title & Description
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: amberAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "SYSTEM MAINTENANCE ACTIVE",
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFB45309),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    "Platform Under Maintenance",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: slateDark,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    "We are currently performing scheduled system upgrades to bring you a faster and more reliable shopping experience. Customer and seller accounts are temporarily paused.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: slateMuted,
                      fontSize: 12.5,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. Details / Status Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildStatusRow(
                          icon: Icons.timer_outlined,
                          title: "Estimated Time",
                          value: "~30–45 Mins",
                          color: primaryTeal,
                        ),
                        const Divider(height: 20, color: Color(0xFFF1F5F9)),
                        _buildStatusRow(
                          icon: Icons.cloud_sync_rounded,
                          title: "Upgrade Scope",
                          value: "Database & Security",
                          color: const Color(0xFF3B82F6),
                        ),
                        const Divider(height: 20, color: Color(0xFFF1F5F9)),
                        _buildStatusRow(
                          icon: Icons.verified_user_outlined,
                          title: "Data Safety",
                          value: "100% Protected",
                          color: const Color(0xFF10B981),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 250.ms, duration: 350.ms).slideY(begin: 0.04),

                  const SizedBox(height: 28),

                  // 5. Action Buttons
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryTeal,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        alignment: Alignment.center,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        shadowColor: primaryTeal.withValues(alpha: 0.3),
                      ),
                      onPressed: isChecking ? null : _checkStatus,
                      icon: isChecking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                      label: Text(
                        isChecking ? "Checking Status..." : "Check Status & Try Again",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                    child: Text(
                      "Back to Login Screen",
                      style: GoogleFonts.poppins(
                        color: slateMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                color: slateMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: slateDark,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
