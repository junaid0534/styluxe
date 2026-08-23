import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/platform_settings_service.dart';
import '../services/session_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ===================== BACKEND STATE (UNCHANGED) =====================
  final supabase = Supabase.instance.client;
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool isPasswordHidden = true;
  bool isSocialLoading = false;
  String? socialProviderLoading;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _showSnack({required String message, Color bg = const Color(0xFF0B1C30)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  // ===================== EMAIL LOGIN (BACKEND UNCHANGED) =====================
  Future<void> loginUser() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showSnack(message: "Please fill all fields", bg: Colors.orange);
      return;
    }

    setState(() => isLoading = true);
    try {
      final AuthResponse response = await supabase.auth.signInWithPassword(email: email, password: password);
      final user = response.user;
      if (user == null) throw Exception("Login failed");
      if (user.emailConfirmedAt == null) {
        await supabase.auth.signOut();
        if (!mounted) return;
        _showSnack(message: "Please verify your email first", bg: Colors.orange);
        setState(() => isLoading = false);
        return;
      }
      final data = await supabase.from('users').select('role').eq('id', user.id).single();
      final role = data['role']?.toString().toLowerCase() ?? 'customer';

      if (!mounted) return;

      // Check Admin Privileges
      const adminEmails = ['aliraza4025346@gmail.com'];
      final isAdmin = adminEmails.contains(email.toLowerCase()) || role == 'admin' || role == 'super_admin';

      // Enforce Platform Maintenance Mode for non-admins
      if (!isAdmin) {
        final isMaintenance = await PlatformSettingsService.isMaintenanceModeActive();
        if (isMaintenance) {
          await supabase.auth.signOut();
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/maintenance');
          setState(() => isLoading = false);
          return;
        }
      }

      if (!mounted) return;

      // Designated Super Admin — route to admin dashboard
      if (isAdmin) {
        await SessionService.recordActivity(role: 'admin');
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/super_admin');
      } else if (role == 'seller') {
        // Check if seller store is suspended / inactive
        try {
          final storeRes = await supabase
              .from('seller_stores')
              .select('is_active, store_name')
              .eq('seller_id', user.id)
              .maybeSingle();

          if (storeRes != null && storeRes['is_active'] == false) {
            await SessionService.clearSession();
            if (!mounted) return;
            _showSnack(
              message: "Account Suspended: Store '${storeRes['store_name'] ?? 'Your store'}' is deactivated by Admin.",
              bg: const Color(0xFFBA1A1A),
            );
            setState(() => isLoading = false);
            return;
          }
        } catch (e) {
          debugPrint("Seller store status check note: $e");
        }

        await SessionService.recordActivity(role: 'seller');
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/seller');
      } else {
        await SessionService.recordActivity(role: 'customer');
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/customer_home');
      }
    } on AuthException catch (e) {
      _showSnack(message: e.message, bg: const Color(0xFFBA1A1A));
    } catch (e) {
      _showSnack(message: e.toString(), bg: const Color(0xFFBA1A1A));
    }
    if (mounted) setState(() => isLoading = false);
  }

  // ===================== OAUTH LOGIN (BACKEND UNCHANGED) =====================
  Future<void> loginWithOAuth(OAuthProvider provider, String providerName) async {
    if (isLoading || isSocialLoading) return;
    setState(() { isSocialLoading = true; socialProviderLoading = providerName; });
    try {
      await supabase.auth.signInWithOAuth(provider);
    } on AuthException catch (e) {
      _showSnack(message: e.message, bg: const Color(0xFFBA1A1A));
    } catch (e) {
      _showSnack(message: e.toString(), bg: const Color(0xFFBA1A1A));
    }
    if (mounted) setState(() { isSocialLoading = false; socialProviderLoading = null; });
  }

  // ===================== RESET PASSWORD (BACKEND UNCHANGED) =====================
  Future<void> resetPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      _showSnack(message: "Enter email first to reset password", bg: Colors.orange);
      return;
    }
    try {
      await supabase.auth.resetPasswordForEmail(email);
      _showSnack(message: "Password reset link sent to email", bg: const Color(0xFF10B981));
    } catch (e) {
      _showSnack(message: e.toString(), bg: const Color(0xFFBA1A1A));
    }
  }

  // ===================== COLORS =====================
  static const _emerald = Color(0xFF10B981);
  static const _dark = Color(0xFF0F172A);
  static const _gray = Color(0xFF64748B);
  static const _slate400 = Color(0xFF94A3B8);
  static const _border = Color(0xFFE2E8F0);

  // ===================== BUILD =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Center(
                    child: SizedBox(
                      width: 400,
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Spacer(flex: 1),
                                _buildHeader(),
                                const SizedBox(height: 24),
                                _buildCard(),
                                const Spacer(flex: 2),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ===================== HEADER =====================
  Widget _buildHeader() {
    return Column(
      children: [
        // Shopping bag icon with rounded aesthetic
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _emerald,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _emerald.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 26),
        ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),

        const SizedBox(height: 12),

        // StyLuxe Brand
        Text.rich(
          TextSpan(children: [
            TextSpan(
              text: "Sty",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: _dark,
                letterSpacing: -0.8,
              ),
            ),
            TextSpan(
              text: "Luxe",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: _emerald,
                letterSpacing: -0.8,
              ),
            ),
          ]),
        ),

        const SizedBox(height: 4),

        // Subtitle
        const Text(
          "Welcome back! Login to your account",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _gray,
          ),
        ),
      ],
    );
  }

  // ===================== LOGIN CARD (Matches Reference Image) =====================
  Widget _buildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Log In",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _dark,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),

          // Email Input (Compact standard height)
          _inputField(
            controller: emailController,
            hint: "Email Address",
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),

          // Password Input (Compact standard height)
          _inputField(
            controller: passwordController,
            hint: "Password",
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            hideText: isPasswordHidden,
            toggle: () => setState(() => isPasswordHidden = !isPasswordHidden),
          ),
          const SizedBox(height: 10),

          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: resetPassword,
              child: const Text(
                "Forgot Password?",
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _emerald,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 1. Primary Login Button (Compact Pill matching Reference Image)
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: isLoading ? null : loginUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: _emerald,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      "Login",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),

          // OR Divider
          Row(
            children: [
              const Expanded(child: Divider(color: Color(0xFFE2E8F0), height: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  "OR",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _slate400.withValues(alpha: 0.8),
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: Color(0xFFE2E8F0), height: 1)),
            ],
          ),

          const SizedBox(height: 14),

          // 2. Full-Width Social Buttons matching Reference Image
          _socialFullPillBtn(
            label: "Login with Google",
            icon: const FaIcon(FontAwesomeIcons.google, size: 15, color: Color(0xFFEA4335)),
            provider: OAuthProvider.google,
            providerName: "Google",
          ),
          const SizedBox(height: 10),

          _socialFullPillBtn(
            label: "Login with Facebook",
            icon: const FaIcon(FontAwesomeIcons.facebook, size: 15, color: Color(0xFF1877F2)),
            provider: OAuthProvider.facebook,
            providerName: "Facebook",
          ),

          const SizedBox(height: 24),

          // 3. Register link (matching reference layout)
          Center(
            child: GestureDetector(
              onTap: () => Navigator.pushReplacementNamed(context, '/signup'),
              child: RichText(
                text: const TextSpan(
                  text: "Don't have an account? ",
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _gray,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text: "Register here",
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: _emerald,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================== COMPACT INPUT FIELD =====================
  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool hideText = false,
    VoidCallback? toggle,
  }) {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isPassword ? hideText : false,
        style: const TextStyle(fontSize: 13, color: _dark, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12.5, color: _slate400, fontWeight: FontWeight.w400),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Icon(icon, size: 17, color: _gray),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 0),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: _border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: _emerald, width: 1.4),
          ),
          suffixIcon: isPassword
              ? GestureDetector(
                  onTap: toggle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      hideText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 17,
                      color: _gray,
                    ),
                  ),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 0),
        ),
      ),
    );
  }

  // ===================== FULL-WIDTH PILL SOCIAL BUTTON =====================
  Widget _socialFullPillBtn({
    required String label,
    required Widget icon,
    required OAuthProvider provider,
    required String providerName,
  }) {
    final loading = isSocialLoading && socialProviderLoading == providerName;
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: OutlinedButton(
        onPressed: isSocialLoading ? null : () => loginWithOAuth(provider, providerName),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: const Color(0xFFF8FAFC),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _dark,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}