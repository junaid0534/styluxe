import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart'; // Uncomment for mobile

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

  // Simple manual location input for web + mobile
  Future<void> _pickLocationManually() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter Location"),
        content: TextField(
          controller: addressController,
          decoration: const InputDecoration(hintText: "e.g. Wah Cantt, Punjab"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, addressController.text),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (result != null) {
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditMode ? "Address Updated!" : "Address Saved Successfully!"),
          backgroundColor: const Color.fromARGB(255, 246, 248, 246),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }

    setState(() => isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 181, 213, 225),
      appBar: AppBar(
        title: Text(isEditMode ? "Edit Address" : "Add New Address"),
        backgroundColor: const Color.fromARGB(255, 190, 189, 86),
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Location Picker Button
              GestureDetector(
                onTap: _pickLocationManually,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                    color: Colors.grey[50],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on, size: 50, color: Color(0xFF4F46E5)),
                      const SizedBox(height: 10),
                      const Text(
                        "Tap to set location",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      if (addressController.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            addressController.text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              TextFormField(
                controller: fullNameController,
                decoration: _inputDecoration("Full Name"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration("Phone Number"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: addressController,
                maxLines: 3,
                decoration: _inputDecoration("Full Address"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: cityController,
                decoration: _inputDecoration("City"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),

              const SizedBox(height: 24),

              SwitchListTile(
                title: const Text("Set as Default Address"),
                value: isDefault,
                onChanged: (val) => setState(() => isDefault = val),
                activeThumbColor: const Color(0xFF4F46E5),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _saveAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 109, 201, 99),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(isEditMode ? "UPDATE ADDRESS" : "SAVE ADDRESS",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      filled: true,
      fillColor: Colors.white,
    );
  }
}