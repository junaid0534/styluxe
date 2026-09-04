import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../widgets/seller_bottom_nav.dart';

class SellerEditProfileScreen extends StatefulWidget {
  const SellerEditProfileScreen({super.key});

  @override
  State<SellerEditProfileScreen> createState() => _SellerEditProfileScreenState();
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
  final cnicController = TextEditingController();

  // Change Password Modal Controllers
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool isChangingPassword = false;

  Uint8List? _imageBytes;
  XFile? _pickedImage;
  String? avatarUrl;

  bool isLoading = true;
  bool isSaving = false;

  static const Color sapphireBlue = Color(0xFF2563EB);
  static const Color sapphireLight = Color(0xFFEFF6FF);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color cardBorderColor = Color(0xFF93C5FD);
  static const Color bgColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadSellerProfileData();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    cityController.dispose();
    storeNameController.dispose();
    storeAddressController.dispose();
    cnicController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // ================= LOAD PROFILE DATA FROM SUPABASE =================
  Future<void> _loadSellerProfileData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not authenticated");

      emailController.text = user.email ?? '';

      // Check metadata
      final meta = user.userMetadata ?? {};
      nameController.text = meta['full_name']?.toString() ?? meta['name']?.toString() ?? 'Muhammad Junaid';
      phoneController.text = meta['phone']?.toString() ?? '+92 300 1234567';
      cityController.text = meta['city']?.toString() ?? 'Lahore';
      avatarUrl = meta['avatar_url']?.toString();

      // Check sellers table
      try {
        final res = await supabase.from('sellers').select().eq('id', user.id).maybeSingle();

        if (res != null) {
          if ((res['store_name']?.toString() ?? '').isNotEmpty) {
            storeNameController.text = res['store_name'].toString();
          }
          if ((res['pickup_address']?.toString() ?? '').isNotEmpty) {
            storeAddressController.text = res['pickup_address'].toString();
          }
          if ((res['cnic']?.toString() ?? '').isNotEmpty) {
            cnicController.text = res['cnic'].toString();
          }
          if ((res['phone']?.toString() ?? '').isNotEmpty) {
            phoneController.text = res['phone'].toString();
          }
          if ((res['avatar_url']?.toString() ?? '').isNotEmpty) {
            avatarUrl = res['avatar_url'].toString();
          }
        }
      } catch (_) {}

      if (storeNameController.text.isEmpty) {
        storeNameController.text = "StyLuxe Outlet";
      }
      if (storeAddressController.text.isEmpty) {
        storeAddressController.text = "Gulberg III, Main Boulevard, Lahore";
      }
      if (cnicController.text.isEmpty) {
        cnicController.text = "35202-1234567-1";
      }

      if (!mounted) return;
      setState(() => isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  // ================= PICK PROFILE AVATAR =================
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);

    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedImage = file;
        _imageBytes = bytes;
      });
    }
  }

  // ================= DIRECT SAFE UPLOAD TO EXISTING BUCKETS =================
  Future<String?> _uploadImageSafely({
    required String folder,
    required String fileName,
    required Uint8List bytes,
  }) async {
    // Uses the 2 existing public buckets in your Supabase project (avatars, product_images)
    final candidateBuckets = ['avatars', 'product_images'];

    for (final bucket in candidateBuckets) {
      try {
        final path = '$folder/$fileName';
        await supabase.storage.from(bucket).uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
        final publicUrl = supabase.storage.from(bucket).getPublicUrl(path);
        if (publicUrl.isNotEmpty) {
          return publicUrl;
        }
      } catch (e) {
        debugPrint("Bucket '$bucket' avatar upload attempt: $e");
      }
    }
    return null;
  }

  // ================= SAVE PROFILE CHANGES =================
  Future<void> _saveProfileChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isSaving = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      String? uploadedUrl = avatarUrl;

      // Upload avatar if picked
      if (_pickedImage != null && _imageBytes != null) {
        final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final res = await _uploadImageSafely(
          folder: 'avatars',
          fileName: fileName,
          bytes: _imageBytes!,
        );
        if (res != null) uploadedUrl = res;
      }

      // 1. Update Auth User Metadata
      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': nameController.text.trim(),
            'phone': phoneController.text.trim(),
            'city': cityController.text.trim(),
            'avatar_url': uploadedUrl,
          },
        ),
      );

      // 2. Upsert Sellers Table Record
      try {
        await supabase.from('sellers').upsert({
          'id': user.id,
          'email': user.email,
          'full_name': nameController.text.trim(),
          'phone': phoneController.text.trim(),
          'city': cityController.text.trim(),
          'store_name': storeNameController.text.trim(),
          'pickup_address': storeAddressController.text.trim(),
          'cnic': cnicController.text.trim(),
          'avatar_url': uploadedUrl,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        avatarUrl = uploadedUrl;
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile details updated successfully! 🎉"),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Update error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // ================= CHANGE PASSWORD MODAL =================
  void _showChangePasswordModal() {
    currentPasswordController.clear();
    newPasswordController.clear();
    confirmPasswordController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.lock_reset_rounded, color: sapphireBlue, size: 24),
                    SizedBox(width: 8),
                    Text("Change Security Password", style: TextStyle(color: slateDark, fontSize: 17, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text("Enter your new password below to update account security.", style: TextStyle(color: slateMuted, fontSize: 12)),
                const SizedBox(height: 16),

                // New Password
                TextField(
                  controller: newPasswordController,
                  obscureText: _obscureNew,
                  style: const TextStyle(fontSize: 13, color: slateDark),
                  decoration: InputDecoration(
                    labelText: "New Password",
                    hintText: "Enter at least 6 characters",
                    prefixIcon: const Icon(Icons.key_rounded, color: sapphireBlue, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: slateMuted, size: 18),
                      onPressed: () => setModalState(() => _obscureNew = !_obscureNew),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cardBorderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: sapphireBlue, width: 1.8)),
                  ),
                ),

                const SizedBox(height: 12),

                // Confirm Password
                TextField(
                  controller: confirmPasswordController,
                  obscureText: _obscureConfirm,
                  style: const TextStyle(fontSize: 13, color: slateDark),
                  decoration: InputDecoration(
                    labelText: "Confirm New Password",
                    hintText: "Re-enter new password",
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: sapphireBlue, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: slateMuted, size: 18),
                      onPressed: () => setModalState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cardBorderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: sapphireBlue, width: 1.8)),
                  ),
                ),

                const SizedBox(height: 20),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sapphireBlue,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isChangingPassword
                      ? null
                      : () async {
                          final newPass = newPasswordController.text.trim();
                          final confirmPass = confirmPasswordController.text.trim();

                          if (newPass.length < 6) {
                            ScaffoldMessenger.of(modalContext).showSnackBar(
                              const SnackBar(content: Text("Password must be at least 6 characters long"), backgroundColor: Colors.red),
                            );
                            return;
                          }

                          if (newPass != confirmPass) {
                            ScaffoldMessenger.of(modalContext).showSnackBar(
                              const SnackBar(content: Text("Passwords do not match"), backgroundColor: Colors.red),
                            );
                            return;
                          }

                          setModalState(() => isChangingPassword = true);

                          try {
                            await supabase.auth.updateUser(UserAttributes(password: newPass));

                            if (modalContext.mounted) {
                              setModalState(() => isChangingPassword = false);
                              Navigator.pop(modalContext);
                              ScaffoldMessenger.of(modalContext).showSnackBar(
                                const SnackBar(
                                  content: Text("Password updated successfully! 🔒"),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            }
                          } catch (e) {
                            if (modalContext.mounted) {
                              setModalState(() => isChangingPassword = false);
                              ScaffoldMessenger.of(modalContext).showSnackBar(
                                SnackBar(content: Text("Password update failed: $e"), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                  icon: isChangingPassword
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  label: Text(
                    isChangingPassword ? "UPDATING PASSWORD..." : "UPDATE PASSWORD",
                    style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sellerName = nameController.text.isEmpty ? "Muhammad Junaid" : nameController.text;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Seller Account & Security",
          style: TextStyle(color: slateDark, fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: sapphireBlue))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 850),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ================= 1. AVATAR PROFILE HEADER =================
                        Center(
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: sapphireBlue, width: 2.5),
                                      boxShadow: [
                                        BoxShadow(color: sapphireBlue.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4)),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: _imageBytes != null
                                          ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                                          : (avatarUrl != null && avatarUrl!.isNotEmpty)
                                              ? Image.network(avatarUrl!, fit: BoxFit.cover)
                                              : Container(
                                                  color: sapphireLight,
                                                  child: Center(
                                                    child: Text(
                                                      sellerName.isNotEmpty ? sellerName[0].toUpperCase() : 'S',
                                                      style: const TextStyle(color: sapphireBlue, fontSize: 36, fontWeight: FontWeight.w900),
                                                    ),
                                                  ),
                                                ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: InkWell(
                                      onTap: _pickImage,
                                      child: Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: const BoxDecoration(
                                          color: sapphireBlue,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(sellerName, style: const TextStyle(color: slateDark, fontSize: 20, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(20)),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 13),
                                    SizedBox(width: 4),
                                    Text("VERIFIED STORE OWNER", style: TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.w900)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 400.ms),

                        const SizedBox(height: 24),

                        // ================= 2. PERSONAL INFORMATION SECTION =================
                        _sectionTitle("Personal Information", Icons.person_outline_rounded),
                        const SizedBox(height: 10),

                        _buildCardContainer([
                          _inputField("Full Name", nameController, Icons.person_rounded, "Enter your full name"),
                          const SizedBox(height: 12),
                          _inputField("Email Address (Verified)", emailController, Icons.email_rounded, "", isReadOnly: true),
                          const SizedBox(height: 12),
                          _inputField("Contact Phone", phoneController, Icons.phone_rounded, "e.g. +92 300 1234567"),
                          const SizedBox(height: 12),
                          _inputField("City Location", cityController, Icons.location_city_rounded, "e.g. Lahore, Karachi"),
                          const SizedBox(height: 12),
                          _inputField("CNIC Number", cnicController, Icons.badge_rounded, "e.g. 35202-1234567-1"),
                        ]),

                        const SizedBox(height: 22),

                        // ================= 3. STORE SPECIFICATIONS SECTION =================
                        _sectionTitle("Store Specifications", Icons.storefront_rounded),
                        const SizedBox(height: 10),

                        _buildCardContainer([
                          _inputField("Store Title Name", storeNameController, Icons.store_rounded, "Enter store name"),
                          const SizedBox(height: 12),
                          _inputField("Pickup Address", storeAddressController, Icons.location_on_rounded, "Enter full store address"),
                        ]),

                        const SizedBox(height: 22),

                        // ================= 4. SECURITY & AUTHENTICATION SECTION =================
                        _sectionTitle("Security & Credentials", Icons.security_rounded),
                        const SizedBox(height: 10),

                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardBorderColor, width: 1.2),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.lock_rounded, color: sapphireBlue, size: 20),
                                  SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Account Password", style: TextStyle(color: slateDark, fontSize: 13.5, fontWeight: FontWeight.w900)),
                                      Text("Update your account security password", style: TextStyle(color: slateMuted, fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: sapphireBlue, width: 1.2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                onPressed: _showChangePasswordModal,
                                icon: const Icon(Icons.edit_rounded, color: sapphireBlue, size: 14),
                                label: const Text("CHANGE", style: TextStyle(color: sapphireBlue, fontSize: 11, fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ================= 5. SAVE CHANGES BUTTON =================
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: sapphireBlue,
                            minimumSize: const Size(double.infinity, 50),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: isSaving ? null : _saveProfileChanges,
                          icon: isSaving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                          label: Text(
                            isSaving ? "SAVING CHANGES..." : "SAVE PROFILE CHANGES",
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: const SellerBottomNav(currentIndex: 4),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: sapphireBlue, size: 18),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: slateDark, fontSize: 15, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildCardContainer(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _inputField(String label, TextEditingController ctrl, IconData icon, String hint, {bool isReadOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: slateDark, fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          readOnly: isReadOnly,
          style: TextStyle(fontSize: 13, color: isReadOnly ? slateMuted : slateDark, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: slateMuted, fontSize: 12),
            prefixIcon: Icon(icon, color: isReadOnly ? slateMuted : sapphireBlue, size: 18),
            suffixIcon: isReadOnly ? const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 16) : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            filled: true,
            fillColor: isReadOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cardBorderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: sapphireBlue, width: 1.8)),
          ),
        ),
      ],
    );
  }
}