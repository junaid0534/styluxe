import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
      final role = data['role'];
      if (!mounted) return;
      if (role == 'seller') {
        Navigator.pushReplacementNamed(context, '/seller');
      } else {
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
      backgroundColor: Colors.white,
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
                          child: Column(
                            children: [
                              // ── TOP HEADER (fixed at top area) ──
                              const SizedBox(height: 40),
                              _buildHeader(),
                              const SizedBox(height: 28),

                              // ── FORM CARD (takes remaining space, centered) ──
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      _buildCard(),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),
                            ],
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

  // ===================== HEADER (fixed at top) =====================
  Widget _buildHeader() {
    return Column(
      children: [
        // Shopping bag icon
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: _emerald,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: _emerald.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: const Icon(Icons.shopping_bag, color: Colors.white, size: 28),
        ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),

        const SizedBox(height: 14),

        // StyLuxe
        Text.rich(
          TextSpan(children: [
            TextSpan(text: "Sty", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _dark)),
            TextSpan(text: "Luxe", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _emerald)),
          ]),
        ),

        const SizedBox(height: 6),

        // Subtitle
        const Text(
          "Welcome back! Login to your account",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: _gray),
        ),
      ],
    );
  }

  // ===================== LOGIN CARD =====================
  Widget _buildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          const Text("Log In", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _dark)),
          const SizedBox(height: 22),

          // Email
          _inputField(controller: emailController, hint: "Email Address", icon: Icons.mail_outlined, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 14),

          // Password
          _inputField(controller: passwordController, hint: "Password", icon: Icons.lock_outlined, isPassword: true, hideText: isPasswordHidden, toggle: () => setState(() => isPasswordHidden = !isPasswordHidden)),
          const SizedBox(height: 8),

          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: resetPassword,
              child: const Text("Forgot Password?", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _emerald)),
            ),
          ),
          const SizedBox(height: 18),

          // Login button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isLoading ? null : loginUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: _emerald,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text("Log In", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 16),
                    ]),
            ),
          ),
          const SizedBox(height: 20),

          // OR Divider
          Row(children: [
            const Expanded(child: Divider(color: _border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text("OR", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _gray.withOpacity(0.6))),
            ),
            const Expanded(child: Divider(color: _border)),
          ]),
          const SizedBox(height: 20),

          // Social buttons
          Row(children: [
            Expanded(child: _socialBtn("Google", const FaIcon(FontAwesomeIcons.google, size: 15, color: Color(0xFFEA4335)), "Google")),
            const SizedBox(width: 12),
            Expanded(child: _socialBtn("Facebook", const FaIcon(FontAwesomeIcons.facebook, size: 15, color: Color(0xFF1877F2)), "Facebook")),
          ]),
          const SizedBox(height: 24),

          // Sign Up link
          Center(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text("Don't have an account? ", style: TextStyle(fontSize: 14, color: _gray)),
              GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(context, '/signup'),
                child: const Text("Sign Up", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _emerald)),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ===================== INPUT FIELD (modern bordered) =====================
  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool hideText = false,
    VoidCallback? toggle,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword ? hideText : false,
      style: const TextStyle(fontSize: 14, color: _dark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: _slate400),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, size: 20, color: _gray),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _emerald, width: 1.5),
        ),
        suffixIcon: isPassword
            ? GestureDetector(
                onTap: toggle,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Icon(hideText ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: _gray),
                ),
              )
            : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 0),
      ),
    );
  }

  // ===================== SOCIAL BUTTON =====================
  Widget _socialBtn(String label, Widget icon, String providerName) {
    final loading = isSocialLoading && socialProviderLoading == providerName;
    return OutlinedButton(
      onPressed: isSocialLoading ? null : () => loginWithOAuth(
        providerName == "Google" ? OAuthProvider.google : OAuthProvider.facebook,
        providerName,
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 11),
        side: const BorderSide(color: _border, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Colors.white,
      ),
      child: loading
          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              icon,
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _dark)),
            ]),
    );
  }
}