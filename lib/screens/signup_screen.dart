import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  // ===================== BACKEND STATE (UNCHANGED) =====================
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final usernameController = TextEditingController();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  String selectedRole = 'customer';
  bool isLoading = false;
  bool hidePassword = true;
  bool hideConfirmPassword = true;

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
    usernameController.dispose();
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

  // ===================== SIGNUP (BACKEND UNCHANGED) =====================
  Future<void> signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (passwordController.text.trim() != confirmPasswordController.text.trim()) {
      _showSnack(message: "Passwords do not match", bg: Colors.orange);
      return;
    }
    setState(() => isLoading = true);
    try {
      final AuthResponse response = await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        data: {
          'username': usernameController.text.trim(),
          'name': nameController.text.trim(),
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
                      width: 440,
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: Column(
                            children: [
                              // ── HEADER (fixed top) ──
                              const SizedBox(height: 32),
                              _buildHeader(),
                              const SizedBox(height: 24),

                              // ── FORM CARD ──
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: _buildCard(),
                              ),

                              const SizedBox(height: 24),
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

  // ===================== HEADER =====================
  Widget _buildHeader() {
    return Column(
      children: [
        // Logo icon
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: _emerald,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: _emerald.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 28),
        ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),

        const SizedBox(height: 14),

        // StyLuxe
        Text.rich(TextSpan(children: [
          TextSpan(text: "Sty", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _dark)),
          TextSpan(text: "Luxe", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _emerald)),
        ])),

        const SizedBox(height: 6),

        const Text(
          "Join StyLuxe Marketplace today",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _gray),
        ),
      ],
    );
  }

  // ===================== CARD =====================
  Widget _buildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            const Text("Create Account", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _dark)),
            const SizedBox(height: 20),

            // Role tabs
            _buildRoleTabs(),
            const SizedBox(height: 18),

            // Fields
            _inputField(controller: usernameController, hint: "Username", icon: Icons.person_outline_rounded),
            const SizedBox(height: 14),
            _inputField(controller: nameController, hint: "Full Name", icon: Icons.badge_outlined),
            const SizedBox(height: 14),
            _inputField(controller: emailController, hint: "Email Address", icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 14),
            _inputField(controller: phoneController, hint: "Phone Number", icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
            const SizedBox(height: 14),
            _inputField(controller: passwordController, hint: "Password", icon: Icons.lock_outline_rounded, isPassword: true, hideText: hidePassword, toggle: () => setState(() => hidePassword = !hidePassword)),
            const SizedBox(height: 14),
            _inputField(controller: confirmPasswordController, hint: "Confirm Password", icon: Icons.lock_outline_rounded, isPassword: true, hideText: hideConfirmPassword, toggle: () => setState(() => hideConfirmPassword = !hideConfirmPassword)),
            const SizedBox(height: 22),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : signUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _emerald,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text("Create Account", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 16),
                      ]),
              ),
            ),
            const SizedBox(height: 20),

            // Footer
            Center(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text("Already have an account? ", style: TextStyle(fontSize: 14, color: _gray)),
                GestureDetector(
                  onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text("Login", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _emerald)),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== ROLE TABS =====================
  Widget _buildRoleTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Expanded(child: _roleTab("Customer", Icons.person_outline_rounded, "customer")),
        const SizedBox(width: 4),
        Expanded(child: _roleTab("Seller", Icons.storefront_outlined, "seller")),
      ]),
    );
  }

  Widget _roleTab(String label, IconData icon, String value) {
    final active = selectedRole == value;
    return GestureDetector(
      onTap: () => setState(() => selectedRole = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? _emerald : Colors.transparent, width: 1.2),
          boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))] : [],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: active ? _emerald : _gray),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13.5, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: active ? _emerald : _gray)),
        ]),
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
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword ? hideText : false,
      style: const TextStyle(fontSize: 14, color: _dark),
      validator: (value) {
        final t = value?.trim() ?? "";
        if (t.isEmpty) return "$hint is required";
        if (hint == "Email Address" && !t.contains("@")) return "Enter valid email";
        if (hint == "Phone Number" && t.length < 10) return "Enter valid phone number";
        if (hint == "Password" && t.length < 6) return "Password must be at least 6 characters";
        if (hint == "Confirm Password" && t.length < 6) return "Confirm password must be at least 6 characters";
        return null;
      },
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 1.5),
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
}