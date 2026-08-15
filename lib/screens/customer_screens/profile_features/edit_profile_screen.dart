import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';

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
          backgroundColor: AppColors.primary,
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
          "Edit Profile",
          style: TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Column(
                      children: [
                        // ================= STYLUXE THEME EMERALD PROFILE CARD =================
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.28),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3.5),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    backgroundImage: _profileImageProvider(),
                                    child: _profileImageProvider() == null
                                        ? Text(
                                            _initial(),
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 32,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    height: 34,
                                    width: 34,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 6,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: AppColors.primary,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().scale(
                                duration: 400.ms,
                                curve: Curves.easeOutBack,
                              ),
                          const SizedBox(height: 16),
                          const Text(
                            "Update Your Profile",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Tap picture to change your profile image",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.90),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 350.ms),

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
                            offset: const Offset(0, 8),
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
                    ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.06),

                    const SizedBox(height: 24),

                    // ================= SAVE BUTTON =================
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.4,
                                ),
                              )
                            : const Text(
                                "SAVE PROFILE",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.06),
                  ],
                ),
              ),
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