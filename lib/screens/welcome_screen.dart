import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    // Auto navigate after 3 seconds splash duration
    _splashTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Decorative background subtle glow
            Center(
              child: Container(
                height: 260,
                width: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.06),
                ),
              ),
            ),

            // Center Content: Splash Brand Identity
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Styluxe Animated Logo Badge
                  Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: AppShadows.primaryGlow,
                    ),
                    child: const Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.white,
                      size: 54,
                    ),
                  )
                      .animate()
                      .scale(
                        duration: 800.ms,
                        curve: Curves.easeOutBack,
                      )
                      .fadeIn(duration: 600.ms),

                  const SizedBox(height: 28),

                  // Brand Title: Styluxe
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: "Sty",
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: AppColors.slateDark,
                            letterSpacing: -1.0,
                          ),
                        ),
                        TextSpan(
                          text: "luxe",
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            letterSpacing: -1.0,
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 300.ms, duration: 600.ms)
                      .slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 10),

                  // Slogan Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.bgLight,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: Text(
                      "LUXURY FASHION MARKETPLACE",
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.slateMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 500.ms, duration: 600.ms),
                ],
              ),
            ),

            // Bottom Loading Indicator & Quick Navigation Button
            Positioned(
              left: 24,
              right: 24,
              bottom: 30,
              child: Column(
                children: [
                  // Smooth Circular Progress / Loader
                  const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ).animate().fadeIn(delay: 700.ms),

                  const SizedBox(height: 20),

                  // Manual Tap Shortcut Button: Get Started
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        _splashTimer?.cancel();
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.slateDark,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Get Started",
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.1, end: 0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}