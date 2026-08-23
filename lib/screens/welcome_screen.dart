import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    _checkActiveSession();
  }

  Future<void> _checkActiveSession() async {
    try {
      final supabase = Supabase.instance.client;

      // Small delay to allow Supabase auth to restore session from local device storage if needed
      await Future.delayed(const Duration(milliseconds: 300));

      final isValid = await SessionService.isSessionValid();
      if (isValid && mounted) {
        // Get role from cache or database
        String? role = await SessionService.getCachedRole();
        final currentUser = supabase.auth.currentUser;

        if ((role == null || role.isEmpty) && currentUser != null) {
          try {
            final userDoc = await supabase.from('users').select('role').eq('id', currentUser.id).maybeSingle();
            role = userDoc?['role']?.toString().toLowerCase();
          } catch (e) {
            debugPrint("Role fetch note: $e");
          }
        }

        role = (role ?? 'customer').toLowerCase();

        if (!mounted) return;

        if (role == 'admin' || role == 'super_admin') {
          Navigator.pushReplacementNamed(context, '/super_admin');
          return;
        } else if (role == 'seller') {
          Navigator.pushReplacementNamed(context, '/seller');
          return;
        } else {
          Navigator.pushReplacementNamed(context, '/customer_home');
          return;
        }
      }
    } catch (e) {
      debugPrint("WelcomeScreen session check: $e");
    }

    if (mounted) {
      setState(() => _isCheckingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Gradient Soft Radial Glows
          Positioned(
            top: -size.height * 0.10,
            right: -size.width * 0.20,
            child: Container(
              height: size.width * 0.95,
              width: size.width * 0.95,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.14),
                    AppColors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .scaleXY(begin: 0.9, end: 1.15, duration: 4000.ms, curve: Curves.easeInOut),

          Positioned(
            bottom: -size.height * 0.05,
            left: -size.width * 0.20,
            child: Container(
              height: size.width * 0.90,
              width: size.width * 0.90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF06B6D4).withValues(alpha: 0.10),
                    const Color(0xFF06B6D4).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .scaleXY(begin: 1.1, end: 0.9, duration: 4500.ms, curve: Curves.easeInOut),

          // Floating Feature Badge 1 (Authentic Brands)
          Positioned(
            top: size.height * 0.14,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_rounded, color: AppColors.primary, size: 15),
                  SizedBox(width: 5),
                  Text(
                    "100% Authentic Brands",
                    style: TextStyle(color: AppColors.slateDark, fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .fadeIn(delay: 500.ms, duration: 600.ms)
             .moveY(begin: 0, end: -6, duration: 2400.ms, curve: Curves.easeInOut),
          ),

          // Floating Feature Badge 2 (Fast Delivery & Luxury)
          Positioned(
            top: size.height * 0.22,
            right: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Color(0xFFF59E0B), size: 15),
                  SizedBox(width: 5),
                  Text(
                    "Curated Luxury & Trends",
                    style: TextStyle(color: AppColors.slateDark, fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .fadeIn(delay: 700.ms, duration: 600.ms)
             .moveY(begin: -5, end: 3, duration: 2800.ms, curve: Curves.easeInOut),
          ),

          // Main Center Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Animated Brand Logo Emblem
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulsing Rings
                      Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.08),
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true))
                       .scaleXY(begin: 0.9, end: 1.18, duration: 1800.ms, curve: Curves.easeInOut),

                      Container(
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.12),
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true))
                       .scaleXY(begin: 0.95, end: 1.08, duration: 1400.ms, curve: Curves.easeInOut),

                      // Core Logo Container
                      Container(
                        height: 82,
                        width: 82,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF047857)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.shopping_bag_rounded,
                            color: Colors.white,
                            size: 42,
                          ),
                        ),
                      ).animate()
                       .scale(duration: 800.ms, curve: Curves.elasticOut)
                       .shimmer(delay: 1200.ms, duration: 1500.ms),
                    ],
                  ),

                  const SizedBox(height: 26),

                  // Brand Title: StyLuxe
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: "Sty",
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: AppColors.slateDark,
                            letterSpacing: -1.2,
                          ),
                        ),
                        TextSpan(
                          text: "luxe",
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            letterSpacing: -1.2,
                          ),
                        ),
                      ],
                    ),
                  ).animate()
                   .fadeIn(delay: 250.ms, duration: 600.ms)
                   .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),

                  const SizedBox(height: 8),

                  // Updated Subtitle / Tagline
                  const Text(
                    "Discover Fashion, Lifestyle & Luxury Trends",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.slateMuted,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ).animate()
                   .fadeIn(delay: 450.ms, duration: 600.ms)
                   .slideY(begin: 0.15, end: 0),

                  const SizedBox(height: 16),

                  // Updated Marketplace Badge (Clothes + All Categories)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.diamond_outlined, color: AppColors.primary, size: 13),
                        SizedBox(width: 6),
                        Text(
                          "LUXURY & LIFESTYLE MARKETPLACE",
                          style: TextStyle(
                            color: AppColors.slateDark,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ).animate()
                   .fadeIn(delay: 650.ms, duration: 600.ms)
                   .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),

                  const Spacer(flex: 3),

                  // Bottom Action Area
                  Column(
                    children: [
                      // Compact Get Started Button
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Get Started",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 17),
                            ],
                          ),
                        ),
                      ).animate()
                       .fadeIn(delay: 850.ms, duration: 500.ms)
                       .slideY(begin: 0.2, end: 0)
                       .shimmer(delay: 1600.ms, duration: 1200.ms),

                      const SizedBox(height: 12),

                      // Secondary Link: Sign in
                      InkWell(
                        onTap: () {
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: RichText(
                            text: const TextSpan(
                              text: "Already have an account? ",
                              style: TextStyle(color: AppColors.slateMuted, fontSize: 13),
                              children: [
                                TextSpan(
                                  text: "Log In",
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 1050.ms),

                      const SizedBox(height: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}