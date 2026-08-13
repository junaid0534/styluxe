import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final supabase = Supabase.instance.client;

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final cityController = TextEditingController();

  Uint8List? _imageBytes;
  String? currentAvatarUrl;

  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    loadCurrentProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    cityController.dispose();
    super.dispose();
  }

  Future<void> loadCurrentProfile() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final user = supabase.auth.currentUser;

      if (user != null) {
        nameController.text = user.userMetadata?['name']?.toString() ?? "";
        phoneController.text = user.userMetadata?['phone']?.toString() ?? "";
        cityController.text = user.userMetadata?['city']?.toString() ?? "";
        currentAvatarUrl = user.userMetadata?['avatar_url']?.toString();
      }
    } catch (e) {
      debugPrint("Profile load error: $e");
    }

    if (!mounted) return;

    setState(() => isLoading = false);
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();

        if (!mounted) return;

        setState(() {
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Image error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter your name"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;

    setState(() => isSaving = true);

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception("Please login first");
      }

      String? avatarUrl = currentAvatarUrl;

      // ================= UPLOAD AVATAR =================
      if (_imageBytes != null) {
        final fileName =
            'avatars/${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

        await supabase.storage.from('avatars').uploadBinary(
              fileName,
              _imageBytes!,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/jpeg',
              ),
            );

        avatarUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
      }

      // ================= UPDATE AUTH METADATA =================
      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'name': nameController.text.trim(),
            'phone': phoneController.text.trim(),
            'city': cityController.text.trim(),
            'avatar_url': avatarUrl,
          },
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile updated successfully"),
          backgroundColor: Color(0xFF22C55E),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (mounted) {
      setState(() => isSaving = false);
    }
  }

  ImageProvider? _profileImageProvider() {
    if (_imageBytes != null) {
      return MemoryImage(_imageBytes!);
    }

    if (currentAvatarUrl != null && currentAvatarUrl!.trim().isNotEmpty) {
      return NetworkImage(currentAvatarUrl!);
    }

    return null;
  }

  String _initial() {
    final name = nameController.text.trim();

    if (name.isEmpty) return "C";

    return name[0].toUpperCase();
  }

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
          "Edit Profile",
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

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF22C55E),
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                child: Column(
                  children: [
                    // ================= PROFILE IMAGE CARD =================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF4F46E5),
                            Color(0xFF7C3AED),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
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
                            right: -36,
                            top: -42,
                            child: _GlowCircle(
                              size: 130,
                              opacity: 0.12,
                            ),
                          ),
                          Positioned(
                            left: -44,
                            bottom: -50,
                            child: _GlowCircle(
                              size: 145,
                              opacity: 0.08,
                            ),
                          ),

                          Column(
                            children: [
                              GestureDetector(
                                onTap: _pickImage,
                                child: Stack(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.22),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.25),
                                          width: 1,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 62,
                                        backgroundColor: Colors.white,
                                        backgroundImage: _profileImageProvider(),
                                        child: _profileImageProvider() == null
                                            ? Text(
                                                _initial(),
                                                style: const TextStyle(
                                                  color: Color(0xFF4F46E5),
                                                  fontSize: 38,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 4,
                                      right: 4,
                                      child: Container(
                                        height: 38,
                                        width: 38,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF22C55E),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.15),
                                              blurRadius: 10,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt_rounded,
                                          color: Colors.white,
                                          size: 19,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().scale(
                                    duration: 500.ms,
                                    curve: Curves.easeOutBack,
                                  ),
                              const SizedBox(height: 18),
                              const Text(
                                "Update Your Profile",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Tap image to change your profile picture",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
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
                            controller: nameController,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration(
                              label: "Full Name",
                              icon: Icons.person_outline_rounded,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration(
                              label: "Phone Number",
                              icon: Icons.phone_outlined,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: cityController,
                            textInputAction: TextInputAction.done,
                            decoration: _inputDecoration(
                              label: "City",
                              icon: Icons.location_city_outlined,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.08),

                    const SizedBox(height: 26),

                    // ================= SAVE BUTTON =================
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFF22C55E),
                          disabledBackgroundColor: Colors.grey.shade400,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.4,
                                ),
                              )
                            : const Text(
                                "SAVE PROFILE",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
                    ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.08),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
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