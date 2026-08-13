import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellerEditProfileScreen extends StatefulWidget {
  const SellerEditProfileScreen({super.key});

  @override
  State<SellerEditProfileScreen> createState() =>
      _SellerEditProfileScreenState();
}

class _SellerEditProfileScreenState extends State<SellerEditProfileScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final cityController = TextEditingController();
  final storeNameController = TextEditingController();
  final storeAddressController = TextEditingController();
  final businessCategoryController = TextEditingController();
  final storeDescriptionController = TextEditingController();

  Uint8List? _imageBytes;
  XFile? _pickedImage;

  String? avatarUrl;

  bool isLoading = true;
  bool isSaving = false;

  static const Color appGreen = Color(0xFFA8E063);
  static const Color darkText = Color(0xFF111827);
  static const Color mutedText = Color(0xFF6B7280);
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color bgColor = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    loadSellerProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    cityController.dispose();
    storeNameController.dispose();
    storeAddressController.dispose();
    businessCategoryController.dispose();
    storeDescriptionController.dispose();
    super.dispose();
  }

  // ================= LOAD SELLER PROFILE =================
  Future<void> loadSellerProfile() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception("Seller not logged in");
      }

      final metadata = user.userMetadata ?? {};

      nameController.text =
          metadata['name']?.toString() ?? metadata['full_name']?.toString() ?? '';

      emailController.text = user.email ?? '';

      phoneController.text = metadata['phone']?.toString() ?? '';
      cityController.text = metadata['city']?.toString() ?? '';
      storeNameController.text = metadata['store_name']?.toString() ?? '';
      storeAddressController.text = metadata['store_address']?.toString() ?? '';
      businessCategoryController.text =
          metadata['business_category']?.toString() ?? '';
      storeDescriptionController.text =
          metadata['store_description']?.toString() ?? '';

      avatarUrl = metadata['avatar_url']?.toString();

      if (!mounted) return;

      setState(() => isLoading = false);
    } catch (e) {
      debugPrint("Load Seller Profile Error: $e");

      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Profile load error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================= PICK IMAGE =================
  Future<void> pickProfileImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      if (!mounted) return;

      setState(() {
        _pickedImage = picked;
        _imageBytes = bytes;
      });
    } catch (e) {
      debugPrint("Pick Image Error: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Image pick error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================= SAVE SELLER PROFILE =================
  Future<void> saveSellerProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;

    setState(() => isSaving = true);

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception("Seller not logged in");
      }

      String? finalAvatarUrl = avatarUrl;

      // ================= UPLOAD AVATAR =================
      if (_imageBytes != null) {
        final safeFileName =
            '${user.id}_${DateTime.now().millisecondsSinceEpoch}_${_pickedImage?.name ?? "seller_avatar.jpg"}'
                .replaceAll(" ", "_");

        final filePath = 'seller_profiles/$safeFileName';

        await supabase.storage.from('avatars').uploadBinary(
              filePath,
              _imageBytes!,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );

        finalAvatarUrl = supabase.storage.from('avatars').getPublicUrl(filePath);
      }

      // ================= UPDATE AUTH METADATA =================
      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'name': nameController.text.trim(),
            'full_name': nameController.text.trim(),
            'phone': phoneController.text.trim(),
            'city': cityController.text.trim(),
            'store_name': storeNameController.text.trim(),
            'store_address': storeAddressController.text.trim(),
            'business_category': businessCategoryController.text.trim(),
            'store_description': storeDescriptionController.text.trim(),
            'avatar_url': finalAvatarUrl,
            'role': 'seller',
          },
        ),
      );

      if (!mounted) return;

      setState(() {
        avatarUrl = finalAvatarUrl;
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Seller profile updated successfully"),
          backgroundColor: Color(0xFF22C55E),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Save Seller Profile Error: $e");

      if (!mounted) return;

      setState(() => isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Profile save error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _initials() {
    final name = nameController.text.trim();

    if (name.isEmpty) return "S";

    final parts = name.split(" ").where((e) => e.trim().isNotEmpty).toList();

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return "${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}"
        .toUpperCase();
  }

  // ================= BUILD UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,

      // ================= SAME GREEN APP BAR =================
      appBar: AppBar(
        backgroundColor: appGreen,
        surfaceTintColor: appGreen,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: kToolbarHeight,
        iconTheme: const IconThemeData(
          color: darkText,
        ),
        title: const Text(
          "Edit Seller Profile",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: darkText,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(
              Icons.refresh_rounded,
              color: darkText,
            ),
            onPressed: isSaving ? null : loadSellerProfile,
          ),
          const SizedBox(width: 6),
        ],
      ),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF22C55E),
              ),
            )
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final isMobile = width < 700;

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      isMobile ? 16 : 28,
                      16,
                      isMobile ? 16 : 28,
                      30,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 1000,
                        ),
                        child: Form(
                          key: _formKey,
                          child: isMobile
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _profileHeader(),
                                    const SizedBox(height: 20),
                                    _personalInfoCard(),
                                    const SizedBox(height: 18),
                                    _storeInfoCard(),
                                    const SizedBox(height: 24),
                                    _saveButton(),
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        children: [
                                          _profileHeader(),
                                          const SizedBox(height: 18),
                                          _saveButton(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 22),
                                    Expanded(
                                      flex: 6,
                                      child: Column(
                                        children: [
                                          _personalInfoCard(),
                                          const SizedBox(height: 18),
                                          _storeInfoCard(),
                                        ],
                                      ),
                                    ),
                                  ],
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

  // ================= PROFILE HEADER =================
  Widget _profileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkText,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -35,
            top: -42,
            child: _GlowCircle(
              size: 130,
              opacity: 0.08,
            ),
          ),
          Positioned(
            left: -42,
            bottom: -48,
            child: _GlowCircle(
              size: 145,
              opacity: 0.06,
            ),
          ),
          Column(
            children: [
              Stack(
                children: [
                  Container(
                    height: 116,
                    width: 116,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: appGreen,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: appGreen.withValues(alpha: 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      backgroundImage: _imageBytes != null
                          ? MemoryImage(_imageBytes!)
                          : avatarUrl != null && avatarUrl!.trim().isNotEmpty
                              ? NetworkImage(avatarUrl!) as ImageProvider
                              : null,
                      child: _imageBytes == null &&
                              (avatarUrl == null || avatarUrl!.trim().isEmpty)
                          ? Text(
                              _initials(),
                              style: const TextStyle(
                                color: darkText,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 4,
                    child: InkWell(
                      onTap: isSaving ? null : pickProfileImage,
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        height: 38,
                        width: 38,
                        decoration: BoxDecoration(
                          color: appGreen,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: darkText,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: darkText,
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Text(
                nameController.text.trim().isEmpty
                    ? "Seller Profile"
                    : nameController.text.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                emailController.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontSize: 13.2,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      color: appGreen,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Seller Account",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08);
  }

  // ================= PERSONAL INFO CARD =================
  Widget _personalInfoCard() {
    return _whiteCard(
      title: "Personal Information",
      subtitle: "Update your basic seller details",
      icon: Icons.person_outline_rounded,
      accentColor: const Color(0xFF2563EB),
      bgTint: const Color(0xFFEFF6FF),
      child: Column(
        children: [
          TextFormField(
            controller: nameController,
            decoration: _inputDecoration(
              label: "Full Name *",
              icon: Icons.badge_outlined,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return "Name is required";
              }

              if (v.trim().length < 3) {
                return "Name is too short";
              }

              return null;
            },
            onChanged: (_) {
              setState(() {});
            },
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: emailController,
            enabled: false,
            decoration: _inputDecoration(
              label: "Email",
              icon: Icons.email_outlined,
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration(
                    label: "Phone",
                    icon: Icons.phone_outlined,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: cityController,
                  decoration: _inputDecoration(
                    label: "City",
                    icon: Icons.location_city_outlined,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.08);
  }

  // ================= STORE INFO CARD =================
  Widget _storeInfoCard() {
    return _whiteCard(
      title: "Store Information",
      subtitle: "Update your public store details",
      icon: Icons.store_outlined,
      accentColor: const Color(0xFF16A34A),
      bgTint: const Color(0xFFF0FDF4),
      child: Column(
        children: [
          TextFormField(
            controller: storeNameController,
            decoration: _inputDecoration(
              label: "Store Name *",
              icon: Icons.storefront_outlined,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return "Store name is required";
              }

              if (v.trim().length < 3) {
                return "Store name is too short";
              }

              return null;
            },
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: businessCategoryController,
            decoration: _inputDecoration(
              label: "Business Category",
              icon: Icons.category_outlined,
            ),
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: storeAddressController,
            maxLines: 2,
            decoration: _inputDecoration(
              label: "Store Address",
              icon: Icons.location_on_outlined,
            ),
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: storeDescriptionController,
            maxLines: 4,
            decoration: _inputDecoration(
              label: "Store Bio / Description",
              icon: Icons.description_outlined,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 160.ms).slideY(begin: 0.08);
  }

  // ================= WHITE CARD =================
  Widget _whiteCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color bgTint,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: bgTint,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.12),
                  ),
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: darkText,
                        fontSize: 17.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: mutedText,
                        fontSize: 12.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  // ================= INPUT DECORATION =================
  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF4F46E5),
      ),
      filled: true,
      fillColor: bgColor,
      labelStyle: const TextStyle(
        color: mutedText,
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 17,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(
          color: borderColor,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(
          color: borderColor,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(
          color: Color(0xFF4F46E5),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.2,
        ),
      ),
    );
  }

  // ================= SAVE BUTTON =================
  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: isSaving ? null : saveSellerProfile,
        icon: isSaving
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.save_outlined,
                color: Colors.white,
                size: 21,
              ),
        label: Text(
          isSaving ? "SAVING PROFILE..." : "SAVE PROFILE",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFF22C55E),
          disabledBackgroundColor: Colors.grey.shade400,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 220.ms).slideY(begin: 0.08);
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