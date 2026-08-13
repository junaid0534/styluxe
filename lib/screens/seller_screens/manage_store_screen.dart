import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  final descriptionController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final websiteController = TextEditingController();

  String? selectedCategory;
  bool isLoading = false;

  final List<String> storeCategories = [
    "Fashion",
    "Clothing",
    "Footwear",
    "Accessories",
    "Ethnic Wear",
  ];

  @override
  void dispose() {
    storeNameController.dispose();
    descriptionController.dispose();
    phoneController.dispose();
    addressController.dispose();
    websiteController.dispose();
    super.dispose();
  }

  // ================= SAVE STORE INFO TO SUPABASE =================
  Future<void> saveStoreInformation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception("User not logged in");
      }

      final sellerId = currentUser.id;

      await supabase.from('seller_stores').upsert(
        {
          'seller_id': sellerId,
          'store_name': storeNameController.text.trim(),
          'store_category': selectedCategory,
          'description': descriptionController.text.trim(),
          'phone': phoneController.text.trim(),
          'address': addressController.text.trim(),
          'website': websiteController.text.trim(),
          'is_active': true,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'seller_id',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Store information saved successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      storeNameController.clear();
      descriptionController.clear();
      phoneController.clear();
      addressController.clear();
      websiteController.clear();

      setState(() {
        selectedCategory = null;
      });
    } catch (e) {
      debugPrint("Save Store Error: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to save store: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  // ================= BUILD UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Color(0xFF111827),
        ),
        title: const Text(
          "Manage Store",
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final bool isMobile = width < 650;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 28,
                vertical: 20,
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
                            children: _mobileLayout(isMobile),
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: _storeBannerCard(isMobile: false),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _formSection(isMobile: false),
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

  List<Widget> _mobileLayout(bool isMobile) {
    return [
      _pageHeader(isMobile: isMobile),
      const SizedBox(height: 18),
      _storeBannerCard(isMobile: true),
      const SizedBox(height: 22),
      ..._formSection(isMobile: true),
    ];
  }

  List<Widget> _formSection({required bool isMobile}) {
    return [
      if (!isMobile) _pageHeader(isMobile: isMobile),
      if (!isMobile) const SizedBox(height: 18),

      _whiteCard(
        child: Column(
          children: [
            TextFormField(
              controller: storeNameController,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                label: "Store Name",
                hint: "Enter your store name",
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

            DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              decoration: _inputDecoration(
                label: "Store Category",
                hint: "Select store category",
                icon: Icons.category_outlined,
              ),
              items: storeCategories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategory = value;
                });
              },
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return "Store category is required";
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: descriptionController,
              maxLines: 4,
              decoration: _inputDecoration(
                label: "Store Description",
                hint: "Write a short description about your store",
                icon: Icons.description_outlined,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return "Store description is required";
                }
                if (v.trim().length < 10) {
                  return "Description must be at least 10 characters";
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                label: "Phone Number",
                hint: "Enter store phone number",
                icon: Icons.phone_outlined,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return "Phone number is required";
                }
                if (v.trim().length < 10) {
                  return "Enter a valid phone number";
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: addressController,
              maxLines: 2,
              decoration: _inputDecoration(
                label: "Store Address",
                hint: "Enter complete store address",
                icon: Icons.location_on_outlined,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return "Store address is required";
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: websiteController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              decoration: _inputDecoration(
                label: "Website / Instagram",
                hint: "Enter website or Instagram link optional",
                icon: Icons.link_outlined,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.08),

      const SizedBox(height: 24),

      SizedBox(
        width: double.infinity,
        height: 58,
        child: ElevatedButton.icon(
          onPressed: isLoading ? null : saveStoreInformation,
          icon: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: Text(
            isLoading ? "SAVING..." : "SAVE STORE INFORMATION",
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 41, 197, 90),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade400,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.08),

      const SizedBox(height: 40),
    ];
  }

  Widget _pageHeader({required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Store Information",
          style: TextStyle(
            fontSize: isMobile ? 26 : 34,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Add your seller store details. This information will be saved with your seller account.",
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: isMobile ? 14 : 16,
            height: 1.4,
          ),
        ),
      ],
    ).animate().fadeIn().slideY(begin: 0.08);
  }

  Widget _storeBannerCard({required bool isMobile}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: isMobile ? 1.6 : 1.05,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromARGB(255, 49, 212, 73),
                Color.fromARGB(255, 167, 197, 118),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -35,
                top: -35,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: -40,
                bottom: -40,
                child: Container(
                  width: 145,
                  height: 145,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: isMobile ? 74 : 88,
                        height: isMobile ? 74 : 88,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.24),
                          ),
                        ),
                        child: Icon(
                          Icons.storefront_rounded,
                          size: isMobile ? 40 : 48,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        "Store Profile",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Seller account store details",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().scale(delay: 80.ms);
  }

  Widget _whiteCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      labelStyle: TextStyle(
        color: Colors.grey.shade700,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(
        color: Colors.grey.shade400,
        fontWeight: FontWeight.w400,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFF4F46E5),
          width: 1.6,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.4,
        ),
      ),
    );
  }
}