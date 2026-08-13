import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final supabase = Supabase.instance.client;

  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;
  bool obscureCurrent = true;
  bool obscureNew = true;
  bool obscureConfirm = true;

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // ================= CHANGE PASSWORD =================
  Future<void> _changePassword() async {
    final currentPassword = currentPasswordController.text.trim();
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      _showMessage("Please fill all fields", Colors.red);
      return;
    }

    if (newPassword.length < 8) {
      _showMessage("Password must be at least 8 characters", Colors.red);
      return;
    }

    if (newPassword != confirmPassword) {
      _showMessage("Passwords do not match", Colors.red);
      return;
    }

    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception("Please login first");
      }

      final userId = user.id;
      final email = user.email;

      if (email == null || email.isEmpty) {
        throw Exception("User email not found");
      }

      // ================= VERIFY CURRENT PASSWORD =================
      await supabase.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );

      // ================= UPDATE PASSWORD =================
      await supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );

      // ================= SEND NOTIFICATION =================
      // Same simple structure as your old working code.
      final response = await supabase.from('notifications').insert({
        'user_id': userId,
        'title': 'Password Changed Successfully',
        'message': 'Your password has been updated successfully.',
        'is_read': false,
      }).select();

      debugPrint("Password notification inserted: $response");

      if (!mounted) return;

      _showMessage(
        "Password changed successfully",
        const Color(0xFF22C55E),
      );

      await Future.delayed(const Duration(seconds: 1));

      await supabase.auth.signOut();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false,
      );
    } on AuthException catch (e) {
      String message = e.message;

      if (message.toLowerCase().contains("invalid")) {
        message = "Current password is incorrect";
      }

      _showMessage(message, Colors.red);
    } catch (e) {
      debugPrint("Password Change Error: $e");

      String message = e.toString();

      if (message.toLowerCase().contains("invalid")) {
        message = "Current password is incorrect";
      } else {
        message = "Something went wrong: $e";
      }

      _showMessage(message, Colors.red);
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  void _showMessage(String msg, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
      ),
    );
  }

  // ================= BUILD UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      // ================= SAME PREVIOUS APP BAR =================
      appBar: AppBar(
        backgroundColor: const Color(0xFFA8E063),
        surfaceTintColor: const Color(0xFFA8E063),
        elevation: 0,
        centerTitle: false,
        toolbarHeight: kToolbarHeight,
        iconTheme: const IconThemeData(
          color: Color(0xFF111827),
        ),
        title: const Text(
          "Change Password",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.3,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= HEADER CARD =================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF4F46E5),
                      Color(0xFF7C3AED),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.24),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -38,
                      top: -42,
                      child: _GlowCircle(
                        size: 130,
                        opacity: 0.12,
                      ),
                    ),
                    Positioned(
                      left: -42,
                      bottom: -48,
                      child: _GlowCircle(
                        size: 145,
                        opacity: 0.08,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          height: 62,
                          width: 62,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.17),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20),
                            ),
                          ),
                          child: const Icon(
                            Icons.lock_reset_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Update Password",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Your new password must be at least 8 characters.",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.84),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08),

              const SizedBox(height: 22),

              // ================= FORM CARD =================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.045),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: currentPasswordController,
                      obscureText: obscureCurrent,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        label: "Current Password",
                        icon: Icons.lock_outline_rounded,
                        suffix: IconButton(
                          icon: Icon(
                            obscureCurrent
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey.shade600,
                          ),
                          onPressed: () {
                            setState(() {
                              obscureCurrent = !obscureCurrent;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        label: "New Password",
                        icon: Icons.password_rounded,
                        suffix: IconButton(
                          icon: Icon(
                            obscureNew
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey.shade600,
                          ),
                          onPressed: () {
                            setState(() {
                              obscureNew = !obscureNew;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!isLoading) _changePassword();
                      },
                      decoration: _inputDecoration(
                        label: "Confirm New Password",
                        icon: Icons.verified_user_outlined,
                        suffix: IconButton(
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey.shade600,
                          ),
                          onPressed: () {
                            setState(() {
                              obscureConfirm = !obscureConfirm;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.08),

              const SizedBox(height: 18),

              // ================= PASSWORD NOTE =================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFDE68A),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFFF59E0B),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Password instruction: at least 8 characters.",
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 13.2,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 180.ms),

              const SizedBox(height: 28),

              // ================= CHANGE BUTTON =================
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF22C55E),
                    disabledBackgroundColor: Colors.grey.shade400,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        )
                      : const Text(
                          "CHANGE PASSWORD",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ).animate().fadeIn(delay: 240.ms).slideY(begin: 0.08),
            ],
          ),
        ),
      ),
    );
  }

  // ================= INPUT DECORATION =================
  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Colors.grey.shade600,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF6366F1),
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFFE5E7EB),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFF6366F1),
          width: 1.5,
        ),
      ),
    );
  }
}

// ================= GLOW CIRCLE =================
class _GlowCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _GlowCircle({
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}