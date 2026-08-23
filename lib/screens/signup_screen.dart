import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  // ===================== BACKEND STATE =====================
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  String selectedRole = 'customer';
  bool isLoading = false;
  bool hidePassword = true;
  bool hideConfirmPassword = true;
  bool isSocialLoading = false;
  String? socialProviderLoading;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnack({required String message, Color bg = const Color(0xFF0F172A)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  // ===================== SIGNUP =====================
  Future<void> signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (passwordController.text.trim() != confirmPasswordController.text.trim()) {
      _showSnack(message: "Passwords do not match", bg: Colors.orange);
      return;
    }
    setState(() => isLoading = true);
    try {
      final fullName = nameController.text.trim();
      final username = fullName.isNotEmpty ? fullName.split(' ').first.toLowerCase() : emailController.text.trim().split('@').first;

      final AuthResponse response = await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        data: {
          'username': username,
          'name': fullName.isNotEmpty ? fullName : "User",
          'phone': phoneController.text.trim(),
          'role': selectedRole,
        },
      );
      if (response.user != null) {
        if (!mounted) return;
        _showSnack(
          message: selectedRole == 'seller'
              ? "Seller account created! Please verify your email."
              : "Account created successfully! Please verify your email.",
          bg: const Color(0xFF10B981),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    } on AuthException catch (e) {
      _showSnack(message: e.message, bg: const Color(0xFFBA1A1A));
    } catch (e) {
      _showSnack(message: "Error: ${e.toString()}", bg: const Color(0xFFBA1A1A));
    }
    if (mounted) setState(() => isLoading = false);
  }

  // ===================== OAUTH SIGNUP =====================
  Future<void> signUpWithOAuth(OAuthProvider provider, String providerName) async {
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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Top Circular Back Arrow Button
                        Align(
                          alignment: Alignment.centerLeft,
                          child: InkWell(
                            onTap: () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              } else {
                                Navigator.pushReplacementNamed(context, '/login');
                              }
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              height: 38,
                              width: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                shape: BoxShape.circle,
                                border: Border.all(color: _border),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 16,
                                color: _dark,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // 2. Centered Logo Emblem
                        Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF047857)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: _emerald.withValues(alpha: 0.28),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.shopping_bag_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                        ),

                        const SizedBox(height: 16),

                        // 3. Centered Title & Subtitle (Matching Reference Image)
                        Center(
                          child: Column(
                            children: [
                              const Text(
                                "Sign up",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: _dark,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Create your StyLuxe account",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _gray,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // 4. Role Selection Switcher (Customer / Seller)
                        _buildRoleTabs(),

                        const SizedBox(height: 16),

                        // 5. Full Name (Single Full Width Field)
                        _formFieldWithLabel(
                          label: "Full name*",
                          controller: nameController,
                          hint: "Full name",
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return "Full name is required";
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        // 6. Email (Full Width)
                        _formFieldWithLabel(
                          label: "Email*",
                          controller: emailController,
                          hint: "Email",
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) {
                            final t = val?.trim() ?? "";
                            if (t.isEmpty) return "Email is required";
                            if (!t.contains("@") || !t.contains(".")) return "Enter valid email";
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        // 7. Phone Number (Full Width with + Prefix Indicator)
                        _formFieldWithLabel(
                          label: "Phone number",
                          controller: phoneController,
                          hint: "+92 300 1234567",
                          keyboardType: TextInputType.phone,
                        ),

                        const SizedBox(height: 12),

                        // 8. Password & Confirm Password (2 Columns Layout)
                        Row(
                          children: [
                            Expanded(
                              child: _formFieldWithLabel(
                                label: "Password*",
                                controller: passwordController,
                                hint: "••••••••",
                                isPassword: true,
                                hideText: hidePassword,
                                toggle: () => setState(() => hidePassword = !hidePassword),
                                validator: (val) {
                                  if (val == null || val.trim().length < 6) return "Min 6 chars";
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _formFieldWithLabel(
                                label: "Confirm Password*",
                                controller: confirmPasswordController,
                                hint: "••••••••",
                                isPassword: true,
                                hideText: hideConfirmPassword,
                                toggle: () => setState(() => hideConfirmPassword = !hideConfirmPassword),
                                validator: (val) {
                                  if (val == null || val.trim().length < 6) return "Min 6 chars";
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // 9. Primary Sign Up Button (Exact Reference Match)
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : signUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _emerald,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text(
                                    "Sign up",
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 10. "or" Divider
                        Row(
                          children: [
                            const Expanded(child: Divider(color: _border, height: 1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                "or",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _slate400,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider(color: _border, height: 1)),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // 11. Social Buttons (Google & Facebook with Official Icons)
                        Row(
                          children: [
                            Expanded(
                              child: _socialBtn(
                                label: "Google",
                                icon: const FaIcon(FontAwesomeIcons.google, size: 15, color: Color(0xFFEA4335)),
                                provider: OAuthProvider.google,
                                providerName: "Google",
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _socialBtn(
                                label: "Facebook",
                                icon: const FaIcon(FontAwesomeIcons.facebook, size: 15, color: Color(0xFF1877F2)),
                                provider: OAuthProvider.facebook,
                                providerName: "Facebook",
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // 12. Footer Navigation Link (matching reference)
                        Center(
                          child: GestureDetector(
                            onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                            child: RichText(
                              text: const TextSpan(
                                text: "Already have an account? ",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _gray,
                                  fontWeight: FontWeight.w500,
                                ),
                                children: [
                                  TextSpan(
                                    text: "Sign in",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: _emerald,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
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
  }

  // ===================== FORM FIELD WITH TOP LABEL =====================
  Widget _formFieldWithLabel({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool hideText = false,
    VoidCallback? toggle,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: _dark,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 42,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: isPassword ? hideText : false,
            validator: validator,
            style: const TextStyle(fontSize: 13, color: _dark, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 12.5, color: _slate400, fontWeight: FontWeight.w400),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _border, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _emerald, width: 1.4),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 1.4),
              ),
              suffixIcon: isPassword
                  ? GestureDetector(
                      onTap: toggle,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
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
        ),
      ],
    );
  }

  // ===================== ROLE TABS =====================
  Widget _buildRoleTabs() {
    return Container(
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(child: _roleTab("Customer", Icons.person_outline_rounded, "customer")),
          const SizedBox(width: 4),
          Expanded(child: _roleTab("Seller", Icons.storefront_outlined, "seller")),
        ],
      ),
    );
  }

  Widget _roleTab(String label, IconData icon, String value) {
    final active = selectedRole == value;
    return GestureDetector(
      onTap: () => setState(() => selectedRole = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 7.5),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? _emerald : Colors.transparent, width: 1.2),
          boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: active ? _emerald : _gray),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? _emerald : _gray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== SOCIAL BUTTON =====================
  Widget _socialBtn({
    required String label,
    required Widget icon,
    required OAuthProvider provider,
    required String providerName,
  }) {
    final loading = isSocialLoading && socialProviderLoading == providerName;
    return SizedBox(
      height: 42,
      child: OutlinedButton(
        onPressed: isSocialLoading ? null : () => signUpWithOAuth(provider, providerName),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          side: const BorderSide(color: _border, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: const Color(0xFFF8FAFC),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _dark,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}