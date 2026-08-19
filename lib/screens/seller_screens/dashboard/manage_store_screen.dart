import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  static const Color cardBorderColor = Color(0xFF93C5FD);
  static const Color bgColor = Colors.white;

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

      final data = await supabase
          .from('seller_stores')
          .select('*')
          .eq('seller_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (data != null) {
        storeNameController.text = data['store_name']?.toString() ?? '';
        taglineController.text = data['tagline']?.toString() ?? '';
        descriptionController.text = data['description']?.toString() ?? '';
        phoneController.text = data['phone']?.toString() ?? '';
        addressController.text = data['address']?.toString() ?? '';
        websiteController.text = data['website']?.toString() ?? '';
        logoUrl = data['logo_url']?.toString();
        bannerUrl = data['banner_url']?.toString();

        final cat = data['store_category']?.toString();
        if (cat != null && storeCategories.contains(cat)) {
          selectedCategory = cat;
        }
      }

      setState(() => isLoading = false);
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ================= PICK LOGO / BANNER =================
  Future<void> _pickImage(bool isLogo) async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
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

      // 1. Upload Logo if picked
      if (_logoBytes != null && _logoName != null) {
        final path = 'logos/${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await supabase.storage.from('store_assets').uploadBinary(
              path,
              _logoBytes!,
              fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
            );
        uploadedLogo = supabase.storage.from('store_assets').getPublicUrl(path);
      }

      // 2. Upload Banner if picked
      if (_bannerBytes != null && _bannerName != null) {
        final path = 'banners/${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await supabase.storage.from('store_assets').uploadBinary(
              path,
              _bannerBytes!,
              fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
            );
        uploadedBanner = supabase.storage.from('store_assets').getPublicUrl(path);
      }

      // 3. Upsert seller store details
      await supabase.from('seller_stores').upsert(
        {
          'seller_id': user.id,
          'store_name': storeNameController.text.trim(),
          'tagline': taglineController.text.trim(),
          'store_category': selectedCategory,
          'description': descriptionController.text.trim(),
          'phone': phoneController.text.trim(),
          'address': addressController.text.trim(),
          'website': websiteController.text.trim(),
          'logo_url': uploadedLogo,
          'banner_url': uploadedBanner,
          'is_active': true,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'seller_id',
      );

      if (!mounted) return;

      setState(() {
        logoUrl = uploadedLogo;
        bannerUrl = uploadedBanner;
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Store Profile saved successfully! 🎉"),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save store info: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Store Management & Branding",
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
                        // ================= 1. BANNER & LOGO HEADER CARD =================
                        _buildBrandingHeader(),

                        const SizedBox(height: 24),

                        // ================= 2. STORE BRANDING INFORMATION =================
                        _sectionTitle("Basic Store Info", "Store Name, Tagline & Department"),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: storeNameController,
                          validator: (val) => val == null || val.trim().isEmpty ? "Please enter store name" : null,
                          decoration: _inputDecoration("Store Name", "e.g., StyLuxe Official Flagship Store", Icons.store_rounded),
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: taglineController,
                          decoration: _inputDecoration("Store Tagline / Slogan", "e.g., Premium Multi-Category Fashion & Luxury", Icons.verified_rounded),
                        ),
                        const SizedBox(height: 14),

                        DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          decoration: _inputDecoration("Store Main Department", "", Icons.category_rounded),
                          items: storeCategories.map((cat) {
                            return DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 13, color: slateDark)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => selectedCategory = val);
                          },
                        ),

                        const SizedBox(height: 24),

                        // ================= 3. CONTACT & LOCATION DETAILS =================
                        _sectionTitle("Contact & Pickup Location", "Customer support phone & warehouse address"),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: phoneController,
                                keyboardType: TextInputType.phone,
                                validator: (val) => val == null || val.trim().isEmpty ? "Phone number required" : null,
                                decoration: _inputDecoration("Support Phone", "+92 300 1234567", Icons.phone_rounded),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: websiteController,
                                decoration: _inputDecoration("Website / Handle", "e.g., styluxe.com/shop", Icons.language_rounded),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: addressController,
                          validator: (val) => val == null || val.trim().isEmpty ? "Pickup address required" : null,
                          decoration: _inputDecoration("Pickup / Business Address", "e.g., Shop #42, Liberty Market, Gulberg III, Lahore", Icons.location_on_rounded),
                        ),

                        const SizedBox(height: 24),

                        // ================= 4. STORE BIO / DESCRIPTION =================
                        _sectionTitle("Store Profile Bio", "Tell customers about your brand story"),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: descriptionController,
                          maxLines: 3,
                          decoration: _inputDecoration("Store Description", "Specializing in high-quality fashion, shoes, and luxury accessories with fast nationwide delivery...", Icons.description_outlined),
                        ),

                        const SizedBox(height: 32),

                        // ================= 5. SAVE BUTTON =================
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: sapphireBlue,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                          ),
                          onPressed: isSaving ? null : saveStoreInformation,
                          icon: isSaving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          label: Text(
                            isSaving ? "SAVING STORE CHANGES..." : "SAVE STORE PROFILE CHANGES",
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: _buildSellerBottomNav(4),
    );
  }

  // ================= BRANDING HEADER CARD =================
  Widget _buildBrandingHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Banner Area
          Stack(
            children: [
              Container(
                height: 130,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20.5)),
                  gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
                ),
                child: _bannerBytes != null
                    ? ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(20.5)), child: Image.memory(_bannerBytes!, fit: BoxFit.cover))
                    : (bannerUrl != null && bannerUrl!.isNotEmpty)
                        ? ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(20.5)), child: Image.network(bannerUrl!, fit: BoxFit.cover))
                        : const Center(child: Icon(Icons.storefront_rounded, color: Colors.white30, size: 48)),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                    foregroundColor: sapphireBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: () => _pickImage(false),
                  icon: const Icon(Icons.camera_alt_rounded, color: sapphireBlue, size: 14),
                  label: const Text("Edit Banner", style: TextStyle(color: sapphireBlue, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),

          // Logo Avatar & Store Title Preview
          Transform.translate(
            offset: const Offset(0, -35),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: sapphireBlue, width: 3),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                        ),
                        child: ClipOval(
                          child: _logoBytes != null
                              ? Image.memory(_logoBytes!, fit: BoxFit.cover)
                              : (logoUrl != null && logoUrl!.isNotEmpty)
                                  ? Image.network(logoUrl!, fit: BoxFit.cover)
                                  : const Center(child: Icon(Icons.store_rounded, color: sapphireBlue, size: 36)),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: InkWell(
                          onTap: () => _pickImage(true),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(color: sapphireBlue, shape: BoxShape.circle),
                            child: const Icon(Icons.edit_rounded, color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storeNameController.text.isEmpty ? "Your Store Name" : storeNameController.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: slateDark, fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          selectedCategory,
                          style: const TextStyle(color: sapphireBlue, fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                      ],
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

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: slateDark, fontSize: 15.5, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(color: slateMuted, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: sapphireBlue, size: 20),
      labelStyle: const TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w700),
      hintStyle: const TextStyle(color: slateMuted, fontSize: 12),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: sapphireBlue, width: 2)),
    );
  }

  // ================= 5-TAB SELLER BOTTOM NAV BAR =================
  Widget _buildSellerBottomNav(int currentIndex) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border.all(color: cardBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            if (index == 0) Navigator.pushReplacementNamed(context, '/seller');
            if (index == 1) Navigator.pushNamed(context, '/active_orders');
            if (index == 2) Navigator.pushNamed(context, '/my_products');
            if (index == 3) Navigator.pushNamed(context, '/seller_analytics');
            if (index == 4) return;
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: sapphireBlue,
          unselectedItemColor: slateMuted,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_mall_outlined),
              activeIcon: Icon(Icons.local_mall_rounded),
              label: "Orders",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2_rounded),
              label: "Products",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded),
              label: "Analytics",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: "Settings",
            ),
          ],
        ),
      ),
    );
  }
}