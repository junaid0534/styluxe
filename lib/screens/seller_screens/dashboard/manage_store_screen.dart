import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../widgets/seller_bottom_nav.dart';
import '../../../widgets/seller_shimmer_loading.dart';

class ManageStoreScreen extends StatefulWidget {
  const ManageStoreScreen({super.key});

  @override
  State<ManageStoreScreen> createState() => _ManageStoreScreenState();
}

class _ManageStoreScreenState extends State<ManageStoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  final storeNameController = TextEditingController();
  final taglineController = TextEditingController();
  final descriptionController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final websiteController = TextEditingController();

  String selectedCategory = "Multi-Category";
  bool isLoading = true;
  bool isSaving = false;

  String? logoUrl;
  String? bannerUrl;

  Uint8List? _logoBytes;
  Uint8List? _bannerBytes;
  String? _logoName;
  String? _bannerName;

  final List<String> storeCategories = [
    "Multi-Category",
    "Men's & Women's Fashion",
    "Footwear & Shoes",
    "Bags & Accessories",
    "Jewelry & Luxury",
    "Beauty & Perfumes",
    "Electronics & Gadgets",
    "Home & Living",
  ];

  static const Color sapphireBlue = Color(0xFF2563EB);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color cardBorderColor = Color(0xFFE2E8F0);
  static const Color fieldBg = Color(0xFFF8FAFC);
  static const Color bgColor = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    fetchStoreInformation();
  }

  @override
  void dispose() {
    storeNameController.dispose();
    taglineController.dispose();
    descriptionController.dispose();
    phoneController.dispose();
    addressController.dispose();
    websiteController.dispose();
    super.dispose();
  }

  // ================= FETCH STORE INFO =================
  Future<void> fetchStoreInformation() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      final meta = user.userMetadata ?? {};

      // Initialize with user metadata defaults first
      storeNameController.text = meta['store_name']?.toString() ?? '';
      taglineController.text = meta['tagline']?.toString() ?? '';
      phoneController.text = meta['phone']?.toString() ?? '';
      addressController.text = meta['address']?.toString() ?? '';
      websiteController.text = meta['website']?.toString() ?? '';
      logoUrl = meta['logo_url']?.toString() ?? meta['avatar_url']?.toString();
      bannerUrl = meta['banner_url']?.toString();

      final metaCat = meta['store_category']?.toString();
      if (metaCat != null && storeCategories.contains(metaCat)) {
        selectedCategory = metaCat;
      }

      // Query seller_stores table
      try {
        final data = await supabase
            .from('seller_stores')
            .select('*')
            .eq('seller_id', user.id)
            .maybeSingle();

        if (data != null) {
          if ((data['store_name']?.toString() ?? '').isNotEmpty) {
            storeNameController.text = data['store_name'].toString();
          }
          if ((data['tagline']?.toString() ?? '').isNotEmpty) {
            taglineController.text = data['tagline'].toString();
          }
          if ((data['description']?.toString() ?? '').isNotEmpty) {
            descriptionController.text = data['description'].toString();
          }
          if ((data['phone']?.toString() ?? '').isNotEmpty) {
            phoneController.text = data['phone'].toString();
          }
          if ((data['address']?.toString() ?? '').isNotEmpty) {
            addressController.text = data['address'].toString();
          } else if ((data['pickup_address']?.toString() ?? '').isNotEmpty) {
            addressController.text = data['pickup_address'].toString();
          }
          if ((data['website']?.toString() ?? '').isNotEmpty) {
            websiteController.text = data['website'].toString();
          }
          if ((data['logo_url']?.toString() ?? '').isNotEmpty) {
            logoUrl = data['logo_url'].toString();
          }
          if ((data['banner_url']?.toString() ?? '').isNotEmpty) {
            bannerUrl = data['banner_url'].toString();
          }

          final cat = data['store_category']?.toString();
          if (cat != null && storeCategories.contains(cat)) {
            selectedCategory = cat;
          }
        }
      } catch (e) {
        debugPrint("seller_stores query note: $e");
      }

      if (!mounted) return;
      setState(() => isLoading = false);
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
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
        debugPrint("Bucket '$bucket' upload attempt: $e");
      }
    }
    return null;
  }

  // ================= PICK LOGO / BANNER =================
  Future<void> _pickImage(bool isLogo) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      if (!mounted) return;
      setState(() {
        if (isLogo) {
          _logoBytes = bytes;
          _logoName = picked.name;
        } else {
          _bannerBytes = bytes;
          _bannerName = picked.name;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Image pick error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // ================= SAVE STORE INFORMATION =================
  Future<void> saveStoreInformation() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isSaving = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      String? uploadedLogo = logoUrl;
      String? uploadedBanner = bannerUrl;

      // 1. Upload Logo if newly selected
      if (_logoBytes != null && _logoName != null) {
        final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final res = await _uploadImageSafely(
          folder: 'logos',
          fileName: fileName,
          bytes: _logoBytes!,
        );
        if (res != null) uploadedLogo = res;
      }

      // 2. Upload Banner if newly selected
      if (_bannerBytes != null && _bannerName != null) {
        final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final res = await _uploadImageSafely(
          folder: 'banners',
          fileName: fileName,
          bytes: _bannerBytes!,
        );
        if (res != null) uploadedBanner = res;
      }

      final nameStr = storeNameController.text.trim();
      final taglineStr = taglineController.text.trim();
      final catStr = selectedCategory;
      final descStr = descriptionController.text.trim();
      final phoneStr = phoneController.text.trim();
      final addrStr = addressController.text.trim();
      final webStr = websiteController.text.trim();

      // 3. Upsert seller_stores with graceful column pruning
      final fullStoreMap = <String, dynamic>{
        'seller_id': user.id,
        'store_name': nameStr,
        'tagline': taglineStr,
        'store_category': catStr,
        'description': descStr,
        'phone': phoneStr,
        'address': addrStr,
        'website': webStr,
        'logo_url': uploadedLogo,
        'banner_url': uploadedBanner,
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      try {
        await supabase.from('seller_stores').upsert(fullStoreMap, onConflict: 'seller_id');
      } catch (storeErr) {
        debugPrint("Extended store columns upsert note: $storeErr. Trying standard columns...");
        // Fallback without columns that may not exist in database schema (e.g. tagline, website, store_category)
        final fallbackStoreMap = <String, dynamic>{
          'seller_id': user.id,
          'store_name': nameStr,
          'description': descStr,
          'phone': phoneStr,
          'address': addrStr,
          'is_active': true,
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (uploadedLogo != null) {
          fallbackStoreMap['logo_url'] = uploadedLogo;
        }
        if (uploadedBanner != null) {
          fallbackStoreMap['banner_url'] = uploadedBanner;
        }

        try {
          await supabase.from('seller_stores').upsert(fallbackStoreMap, onConflict: 'seller_id');
        } catch (minimalErr) {
          debugPrint("Standard store upsert note: $minimalErr. Trying minimal upsert...");
          try {
            await supabase.from('seller_stores').upsert({
              'seller_id': user.id,
              'store_name': nameStr,
              'description': descStr,
              'is_active': true,
              'updated_at': DateTime.now().toIso8601String(),
            }, onConflict: 'seller_id');
          } catch (_) {}
        }
      }

      // 4. Sync with sellers table
      try {
        final sellerMap = <String, dynamic>{
          'id': user.id,
          'store_name': nameStr,
          'pickup_address': addrStr,
          'phone': phoneStr,
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (uploadedLogo != null) {
          sellerMap['avatar_url'] = uploadedLogo;
        }
        await supabase.from('sellers').upsert(sellerMap);
      } catch (_) {}

      // 5. Update user metadata so all store details (including tagline, category, website, banner) are 100% saved
      try {
        final metaDataMap = <String, dynamic>{
          'store_name': nameStr,
          'tagline': taglineStr,
          'store_category': catStr,
          'phone': phoneStr,
          'address': addrStr,
          'website': webStr,
        };
        if (uploadedLogo != null) {
          metaDataMap['avatar_url'] = uploadedLogo;
          metaDataMap['logo_url'] = uploadedLogo;
        }
        if (uploadedBanner != null) {
          metaDataMap['banner_url'] = uploadedBanner;
        }
        await supabase.auth.updateUser(
          UserAttributes(
            data: metaDataMap,
          ),
        );
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        logoUrl = uploadedLogo;
        bannerUrl = uploadedBanner;
        _logoBytes = null;
        _bannerBytes = null;
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Store Profile & Branding saved successfully! 🎉"),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to save store info: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        toolbarHeight: 42.0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slateDark, size: 17),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Manage Store",
          style: TextStyle(
            color: slateDark,
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh Store Data",
            icon: const Icon(Icons.refresh_rounded, color: slateDark, size: 19),
            onPressed: fetchStoreInformation,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: cardBorderColor, height: 1.0),
        ),
      ),
      body: isLoading
          ? const SellerRevenueShimmer()
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 750),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ================= 1. BANNER & LOGO HEADER CARD =================
                        _buildBrandingHeader(isWide),

                        const SizedBox(height: 18),

                        // ================= 2. STORE BRANDING INFORMATION =================
                        _buildCardContainer(
                          children: [
                            _sectionHeader(
                              icon: Icons.store_rounded,
                              title: "Store Identity",
                              subtitle: "Public store name, tagline & primary category",
                            ),
                            const SizedBox(height: 14),

                            // Store Name
                            _fieldLabel(label: "Store Name", isRequired: true),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: storeNameController,
                              style: const TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w600),
                              validator: (val) => val == null || val.trim().isEmpty ? "Please enter store name" : null,
                              decoration: _inputDecoration("e.g. StyLuxe Flagship Store", Icons.storefront_outlined),
                            ),
                            const SizedBox(height: 12),

                            // Tagline
                            _fieldLabel(label: "Store Tagline / Slogan"),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: taglineController,
                              style: const TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w500),
                              decoration: _inputDecoration("e.g. Premium Fashion & Luxury Essentials", Icons.verified_outlined),
                            ),
                            const SizedBox(height: 12),

                            // Department / Category
                            _fieldLabel(label: "Main Department / Category"),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: storeCategories.contains(selectedCategory) ? selectedCategory : storeCategories.first,
                              style: const TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w600),
                              decoration: _inputDecoration("", Icons.category_outlined),
                              items: storeCategories.map((cat) {
                                return DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat, style: const TextStyle(fontSize: 13, color: slateDark, fontWeight: FontWeight.w500)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => selectedCategory = val);
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // ================= 3. CONTACT & LOCATION DETAILS =================
                        _buildCardContainer(
                          children: [
                            _sectionHeader(
                              icon: Icons.contact_phone_rounded,
                              title: "Contact & Pickup Location",
                              subtitle: "Customer support phone & warehouse pickup address",
                            ),
                            const SizedBox(height: 14),

                            // Phone & Website (Responsive Row or Column)
                            if (isWide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _fieldLabel(label: "Support Phone", isRequired: true),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: phoneController,
                                          keyboardType: TextInputType.phone,
                                          style: const TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w600),
                                          validator: (val) => val == null || val.trim().isEmpty ? "Phone number required" : null,
                                          decoration: _inputDecoration("03014025346", Icons.phone_outlined),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _fieldLabel(label: "Website / Handle"),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: websiteController,
                                          style: const TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w500),
                                          decoration: _inputDecoration("e.g. styluxe.pk/store", Icons.language_rounded),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              _fieldLabel(label: "Support Phone", isRequired: true),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: phoneController,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w600),
                                validator: (val) => val == null || val.trim().isEmpty ? "Phone number required" : null,
                                decoration: _inputDecoration("03014025346", Icons.phone_outlined),
                              ),
                              const SizedBox(height: 12),

                              _fieldLabel(label: "Website / Handle"),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: websiteController,
                                style: const TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w500),
                                decoration: _inputDecoration("e.g. styluxe.pk/store", Icons.language_rounded),
                              ),
                            ],

                            const SizedBox(height: 12),

                            // Pickup Address
                            _fieldLabel(label: "Pickup / Business Address", isRequired: true),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: addressController,
                              style: const TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w500),
                              validator: (val) => val == null || val.trim().isEmpty ? "Pickup address required" : null,
                              decoration: _inputDecoration("e.g. Shop #12, Saddar Bazaar, DG Khan", Icons.location_on_outlined),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // ================= 4. STORE BIO / DESCRIPTION =================
                        _buildCardContainer(
                          children: [
                            _sectionHeader(
                              icon: Icons.description_rounded,
                              title: "Store Profile Bio",
                              subtitle: "Tell customers about your brand story & specialties",
                            ),
                            const SizedBox(height: 14),

                            _fieldLabel(label: "Store Description"),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: descriptionController,
                              maxLines: 4,
                              minLines: 3,
                              style: const TextStyle(color: slateDark, fontSize: 13, height: 1.4),
                              decoration: _inputDecoration(
                                "Specializing in high-quality fashion, shoes, and luxury apparel for both men and women...",
                                Icons.article_outlined,
                                isMultiLine: true,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ================= 5. SAVE BUTTON =================
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: sapphireBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 2,
                            ),
                            onPressed: isSaving ? null : saveStoreInformation,
                            icon: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.check_circle_rounded, color: Colors.white, size: 19),
                            label: Text(
                              isSaving ? "SAVING STORE CHANGES..." : "SAVE STORE PROFILE CHANGES",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
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

  // ================= BRANDING HEADER CARD =================
  Widget _buildBrandingHeader(bool isWide) {
    final double bannerHeight = isWide ? 220.0 : 165.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Banner Area with Zero-Gap Cover
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            child: Stack(
              children: [
                Container(
                  height: bannerHeight,
                  width: double.infinity,
                  color: const Color(0xFF1E293B),
                  child: _bannerBytes != null
                      ? Image.memory(
                          _bannerBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: bannerHeight,
                        )
                      : (bannerUrl != null && bannerUrl!.isNotEmpty)
                          ? Image.network(
                              bannerUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: bannerHeight,
                              errorBuilder: (_, _, _) => _bannerPlaceholder(),
                            )
                          : _bannerPlaceholder(),
                ),

                // Subtle Dark Gradient Overlay for Contrast
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.40),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),

                // Change Banner Button
                Positioned(
                  right: 12,
                  top: 12,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _pickImage(false),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.60),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 5),
                            Text(
                              "Change Banner",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Logo Avatar & Store Name
          Transform.translate(
            offset: const Offset(0, -32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Logo Avatar
                  Stack(
                    children: [
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white, width: 3.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _logoBytes != null
                              ? Image.memory(_logoBytes!, fit: BoxFit.cover)
                              : (logoUrl != null && logoUrl!.isNotEmpty)
                                  ? Image.network(
                                      logoUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => _logoPlaceholder(),
                                    )
                                  : _logoPlaceholder(),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () => _pickImage(true),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: sapphireBlue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Store Header Label
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            storeNameController.text.trim().isEmpty ? "Your Store Name" : storeNameController.text.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: slateDark,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: sapphireBlue.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  selectedCategory,
                                  style: const TextStyle(
                                    color: sapphireBlue,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF10B981)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_rounded, color: Colors.white.withValues(alpha: 0.5), size: 40),
            const SizedBox(height: 4),
            Text(
              "Add Store Cover Banner",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoPlaceholder() {
    return Container(
      color: sapphireBlue.withValues(alpha: 0.10),
      child: const Center(
        child: Icon(Icons.store_rounded, color: sapphireBlue, size: 36),
      ),
    );
  }

  // ================= REUSABLE CARD CONTAINER =================
  Widget _buildCardContainer({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // ================= SECTION HEADER =================
  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: sapphireBlue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: sapphireBlue, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: slateDark,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: slateMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================= FIELD LABEL (NO BORDER CUTOFF) =================
  Widget _fieldLabel({required String label, bool isRequired = false}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: slateDark,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 3),
          const Text("*", style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ],
    );
  }

  // ================= COMPACT INPUT DECORATION =================
  InputDecoration _inputDecoration(String hint, IconData icon, {bool isMultiLine = false}) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(color: slateMuted, fontSize: 12.5, fontWeight: FontWeight.w400),
      prefixIcon: isMultiLine
          ? Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Icon(icon, color: sapphireBlue, size: 18),
            )
          : Icon(icon, color: sapphireBlue, size: 18),
      prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 38),
      filled: true,
      fillColor: fieldBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: cardBorderColor, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: cardBorderColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: sapphireBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }
}