import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../theme/app_theme.dart';

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
      _showMessage("Please fill all password fields", Colors.red);
      return;
    }

    if (newPassword.length < 8) {
      _showMessage("Password must be at least 8 characters long", Colors.red);
      return;
    }

    if (newPassword != confirmPassword) {
      _showMessage("New passwords do not match", Colors.red);
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
      try {
        await supabase.from('notifications').insert({
          'user_id': userId,
          'title': 'Password Changed Successfully',
          'message': 'Your account password has been updated.',
          'is_read': false,
        });
      } catch (e) {
        debugPrint("Notification insert info: $e");
      }

      if (!mounted) return;

      _showMessage(
        "Password changed successfully. Please log in again.",
        AppColors.primary,
      );

      await Future.delayed(const Duration(milliseconds: 1200));

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
        message = "Failed to change password. Please check current password.";
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

      // ================= PURE WHITE STYLUXE APP BAR =================
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.slateDark, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Change Password",
          style: TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),

      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= STYLUXE THEME EMERALD HEADER CARD =================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      height: 54,
                      width: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.30),
                        ),
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: Colors.white,
                        size: 28,
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
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Ensure your account stays secure with a strong password.",
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.90),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06),

              const SizedBox(height: 20),

              // ================= FORM CARD =================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.035),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
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
                            color: AppColors.slateMuted,
                            size: 20,
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
                            color: AppColors.slateMuted,
                            size: 20,
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
                            color: AppColors.slateMuted,
                            size: 20,
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
              ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.06),

              const SizedBox(height: 16),

              // ================= PASSWORD GUIDELINE NOTE =================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(16),
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
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Your new password must be at least 8 characters long for security.",
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 180.ms),

              const SizedBox(height: 24),

              // ================= CHANGE BUTTON =================
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        )
                      : const Text(
                          "CHANGE PASSWORD",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                ),
              ).animate().fadeIn(delay: 240.ms).slideY(begin: 0.06),
            ],
          ),
        ),
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
      labelStyle: const TextStyle(
        color: AppColors.slateMuted,
        fontWeight: FontWeight.w500,
        fontSize: 13.5,
      ),
      prefixIcon: Icon(
        icon,
        color: AppColors.primary,
        size: 20,
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.5,
        ),
      ),
    );
  }
}