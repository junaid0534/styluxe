import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../theme/app_theme.dart';

class AddAddressScreen extends StatefulWidget {
  final Map<String, dynamic>? existingAddress;

  const AddAddressScreen({super.key, this.existingAddress});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  late TextEditingController fullNameController;
  late TextEditingController phoneController;
  late TextEditingController addressController;
  late TextEditingController cityController;

  bool isDefault = false;
  bool isSaving = false;
  bool isEditMode = false;

  @override
  void initState() {
    super.initState();
    isEditMode = widget.existingAddress != null;

    fullNameController = TextEditingController(text: widget.existingAddress?['full_name'] ?? '');
    phoneController = TextEditingController(text: widget.existingAddress?['phone'] ?? '');
    addressController = TextEditingController(text: widget.existingAddress?['address'] ?? '');
    cityController = TextEditingController(text: widget.existingAddress?['city'] ?? '');
    isDefault = widget.existingAddress?['is_default'] ?? false;
  }

  @override
  void dispose() {
    fullNameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    cityController.dispose();
    super.dispose();
  }

  // Manual location picker dialog
  Future<void> _pickLocationManually() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final tempController = TextEditingController(text: addressController.text);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            "Enter Full Location Address",
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.slateDark, fontSize: 18),
          ),
          content: TextField(
            controller: tempController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "House #, Street, Area, City",
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: AppColors.slateMuted, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, tempController.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Save Location", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        addressController.text = result;
      });
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      final userId = supabase.auth.currentUser!.id;

      final data = {
        'user_id': userId,
        'full_name': fullNameController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'city': cityController.text.trim(),
        'is_default': isDefault,
      };

      if (isEditMode) {
        await supabase.from('shipping_addresses').update(data).eq('id', widget.existingAddress!['id']);
      } else {
        await supabase.from('shipping_addresses').insert(data);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditMode ? "Address Updated!" : "Address Saved Successfully!"),
          backgroundColor: AppColors.primary,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }

    if (mounted) {
      setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        toolbarHeight: 46.0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.slateDark, size: 21),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditMode ? "Edit Address" : "Add New Address",
          style: const TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 16.5,
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Location Picker Banner Container (Compact)
              GestureDetector(
                onTap: _pickLocationManually,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.30),
                          ),
                        ),
                        child: const Icon(
                          Icons.my_location_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Set Delivery Location",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              addressController.text.isNotEmpty
                                  ? addressController.text
                                  : "Tap to type or select full address",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_location_alt_outlined, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04),

              const SizedBox(height: 16),

              // Form Input Card Container (Compact)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: fullNameController,
                      style: const TextStyle(fontSize: 13, color: AppColors.slateDark, fontWeight: FontWeight.w500),
                      decoration: _inputDecoration("Full Name", Icons.person_outline_rounded),
                      validator: (v) => (v == null || v.trim().isEmpty) ? "Please enter full name" : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 13, color: AppColors.slateDark, fontWeight: FontWeight.w500),
                      decoration: _inputDecoration("Phone Number", Icons.phone_outlined),
                      validator: (v) => (v == null || v.trim().isEmpty) ? "Please enter phone number" : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: addressController,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 13, color: AppColors.slateDark, fontWeight: FontWeight.w500),
                      decoration: _inputDecoration("Full Address (House, Street, Area)", Icons.home_outlined),
                      validator: (v) => (v == null || v.trim().isEmpty) ? "Please enter full address" : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: cityController,
                      style: const TextStyle(fontSize: 13, color: AppColors.slateDark, fontWeight: FontWeight.w500),
                      decoration: _inputDecoration("City", Icons.location_city_outlined),
                      validator: (v) => (v == null || v.trim().isEmpty) ? "Please enter city" : null,
                    ),

                    const SizedBox(height: 12),

                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        dense: true,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        title: const Text(
                          "Set as Default Address",
                          style: TextStyle(
                            color: AppColors.slateDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: const Text(
                          "Use as primary shipping destination",
                          style: TextStyle(
                            color: AppColors.slateMuted,
                            fontSize: 11,
                          ),
                        ),
                        value: isDefault,
                        onChanged: (val) => setState(() => isDefault = val),
                        activeThumbColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.04),

              const SizedBox(height: 20),

              // Action Button (Compact 42px)
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _saveAddress,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          isEditMode ? "UPDATE ADDRESS" : "SAVE ADDRESS",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.04),
            ],
          ),
        ),
      ),
    ),
  ),
);
}

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: AppColors.slateMuted,
        fontWeight: FontWeight.w500,
        fontSize: 12.5,
      ),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 17),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.roseRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.roseRed, width: 1.4),
      ),
    );
  }
}