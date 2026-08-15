import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Subtle Soft Radial Glow Background Accents
          Positioned(
            top: -size.height * 0.08,
            right: -size.width * 0.15,
            child: Container(
              height: size.width * 0.8,
              width: size.width * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
            ),
          ).animate().scale(duration: 2000.ms, curve: Curves.easeInOut),

          Positioned(
            bottom: size.height * 0.08,
            left: -size.width * 0.15,
            child: Container(
              height: size.width * 0.75,
              width: size.width * 0.75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withValues(alpha: 0.06),
              ),
            ),
          ).animate().scale(duration: 2500.ms, curve: Curves.easeInOut),

          // Decorative Floating Studio Badges
          Positioned(
            top: size.height * 0.16,
            left: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_rounded, color: AppColors.primary, size: 16),
                  SizedBox(width: 6),
                  Text("100% Authentic Brands", style: TextStyle(color: AppColors.slateDark, fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3, end: 0),
          ),

          Positioned(
            top: size.height * 0.24,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.local_shipping_rounded, color: Color(0xFFF59E0B), size: 16),
                  SizedBox(width: 6),
                  Text("Express Delivery", style: TextStyle(color: AppColors.slateDark, fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ).animate().fadeIn(delay: 800.ms).slideY(begin: -0.3, end: 0),
          ),

          // Main Center Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Animated Brand Logo Badge
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer Pulsing Aura Ring
                      Container(
                        height: 116,
                        width: 116,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.12),
                        ),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 0.92, end: 1.12, duration: 1500.ms),

                      // Main Logo Box
                      Container(
                        height: 92,
                        width: 92,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF047857)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.32),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shopping_bag_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ],
                  ).animate().scale(duration: 800.ms, curve: Curves.elasticOut).fadeIn(duration: 600.ms),

                  const SizedBox(height: 30),

                  // Brand Title: StyLuxe
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: "Sty",
                          style: TextStyle(
                            fontSize: 46,
                            fontWeight: FontWeight.w900,
                            color: AppColors.slateDark,
                            letterSpacing: -1.2,
                          ),
                        ),
                        TextSpan(
                          text: "luxe",
                          style: TextStyle(
                            fontSize: 46,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            letterSpacing: -1.2,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms, duration: 600.ms).slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 10),

                  // Tagline
                  const Text(
                    "Elevate Your Everyday Style & Couture",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.slateMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ).animate().fadeIn(delay: 500.ms, duration: 600.ms),

                  const SizedBox(height: 18),

                  // Badge Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      "PREMIUM CLOTHING MARKETPLACE",
                      style: TextStyle(
                        color: AppColors.slateMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ).animate().fadeIn(delay: 700.ms, duration: 600.ms),

                  const Spacer(flex: 3),

                  // Bottom Action Area
                  Column(
                    children: [
                      // Get Started Primary Action Button
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.32),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Get Started",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              SizedBox(width: 10),
                              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.2, end: 0).shimmer(delay: 1500.ms, duration: 1200.ms),

                      const SizedBox(height: 14),

                      // Secondary Link: Sign in
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        child: RichText(
                          text: const TextSpan(
                            text: "Already have an account? ",
                            style: TextStyle(color: AppColors.slateMuted, fontSize: 13.5),
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
                      ).animate().fadeIn(delay: 1100.ms),

                      const SizedBox(height: 12),
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