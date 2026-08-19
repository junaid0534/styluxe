import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddProductScreen extends StatefulWidget {
  final String? preSelectedCategory;

  const AddProductScreen({
    super.key,
    this.preSelectedCategory,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  final nameController = TextEditingController();
  final priceController = TextEditingController();
  final originalPriceController = TextEditingController();
  final descriptionController = TextEditingController();
  final stockController = TextEditingController(text: "10");
  final colorController = TextEditingController();
  final fabricController = TextEditingController();
  final customCategoryController = TextEditingController();

  String? selectedCategory;
  String selectedGender = "Unisex";
  String selectedStitchedStatus = "Stitched";
  List<String> selectedSizes = ["M", "L"];

  final List<XFile> _imageFiles = [];
  final List<Uint8List> _imageBytesList = [];
  bool isLoading = false;
  final int maxImages = 6;

  List<String> categoriesList = [
    "Men's Wear",
    "Women's Dresses",
    "Suits",
    "Jeans",
    "Shirts",
    "T-Shirts",
    "Hoodies",
    "Jackets",
    "Trousers",
    "Kurtis",
    "Sneakers",
    "Heels & Sandals",
    "Formal Shoes",
    "Watches",
    "Bags & Backpacks",
    "Jewelry",
    "Perfumes",
    "Electronics & Gadgets",
    "Home & Living",
  ];

  static const Color sapphireBlue = Color(0xFF2563EB);
  static const Color sapphireLight = Color(0xFFEFF6FF);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color cardBorderColor = Color(0xFF93C5FD);
  static const Color bgColor = Colors.white;

  @override
  void initState() {
    super.initState();
    if (widget.preSelectedCategory != null && widget.preSelectedCategory!.trim().isNotEmpty) {
      selectedCategory = widget.preSelectedCategory!.trim();
      if (!categoriesList.contains(selectedCategory)) {
        categoriesList.insert(0, selectedCategory!);
      }
    } else {
      selectedCategory = "Women's Dresses";
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    originalPriceController.dispose();
    descriptionController.dispose();
    stockController.dispose();
    colorController.dispose();
    fabricController.dispose();
    customCategoryController.dispose();
    super.dispose();
  }

  bool get isClothingCategory {
    final cat = (selectedCategory ?? '').toLowerCase();
    return cat.contains('dress') ||
        cat.contains('suit') ||
        cat.contains('wear') ||
        cat.contains('shirt') ||
        cat.contains('jean') ||
        cat.contains('hoodie') ||
        cat.contains('jacket') ||
        cat.contains('trouser') ||
        cat.contains('kurti');
  }

  bool get isShoeCategory {
    final cat = (selectedCategory ?? '').toLowerCase();
    return cat.contains('shoe') || cat.contains('sneaker') || cat.contains('heel') || cat.contains('sandal') || cat.contains('boot');
  }

  List<String> get availableSizesForCategory {
    if (isShoeCategory) {
      return ["36", "37", "38", "39", "40", "41", "42", "43", "44", "45"];
    } else if (isClothingCategory) {
      return ["XS", "S", "M", "L", "XL", "XXL", "Free Size"];
    } else {
      return ["One Size (N/A)"];
    }
  }

  String _contentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith(".png")) return "image/png";
    if (lower.endsWith(".webp")) return "image/webp";
    return "image/jpeg";
  }

  // ================= PICK IMAGES =================
  Future<void> _pickImages() async {
    try {
      final pickedFiles = await ImagePicker().pickMultiImage(imageQuality: 85);
      if (pickedFiles.isEmpty) return;

      final availableSlots = maxImages - _imageFiles.length;
      if (availableSlots <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Maximum $maxImages images allowed"), backgroundColor: Colors.orange),
        );
        return;
      }

      final selectedFiles = pickedFiles.take(availableSlots).toList();
      final List<Uint8List> selectedBytes = [];

      for (final file in selectedFiles) {
        final bytes = await file.readAsBytes();
        selectedBytes.add(bytes);
      }

      if (!mounted) return;
      setState(() {
        _imageFiles.addAll(selectedFiles);
        _imageBytesList.addAll(selectedBytes);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Image picker error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
      _imageBytesList.removeAt(index);
    });
  }

  // ================= SHOW CUSTOM CATEGORY DIALOG =================
  void _showAddCustomCategoryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.add_box_rounded, color: sapphireBlue),
            SizedBox(width: 8),
            Text("New Category Name", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: customCategoryController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "e.g., Abayas, Handmade Crafts, Luxury Accessories",
            hintStyle: const TextStyle(fontSize: 12, color: slateMuted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: sapphireBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final newCat = customCategoryController.text.trim();
              if (newCat.isNotEmpty) {
                setState(() {
                  if (!categoriesList.contains(newCat)) {
                    categoriesList.insert(0, newCat);
                  }
                  selectedCategory = newCat;
                });
                customCategoryController.clear();
              }
              Navigator.pop(ctx);
            },
            child: const Text("Add & Select", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ================= UPLOAD PRODUCT =================
  Future<void> _uploadProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageBytesList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least 1 product image"), backgroundColor: Colors.orange),
      );
      return;
    }

    if (selectedCategory == null || selectedCategory!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select or type a category"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      final priceVal = double.parse(priceController.text.trim());
      final originalPriceVal = double.tryParse(originalPriceController.text.trim());
      final stockVal = int.parse(stockController.text.trim());

      // 1. Upload Images
      final uploadedUrls = <String>[];
      for (int i = 0; i < _imageBytesList.length; i++) {
        final file = _imageFiles[i];
        final bytes = _imageBytesList[i];
        final safeName = '${DateTime.now().millisecondsSinceEpoch}_${i}_${file.name}'.replaceAll(" ", "_");
        final path = '${user.id}/$safeName';

        await supabase.storage.from('product_images').uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: _contentType(file.name), upsert: true),
            );

        final publicUrl = supabase.storage.from('product_images').getPublicUrl(path);
        uploadedUrls.add(publicUrl);
      }

      final mainImage = uploadedUrls.first;
      final formattedSizesStr = selectedSizes.join(", ");

      // Build rich description metadata fallback
      final metaNotes = [];
      if (isClothingCategory) {
        metaNotes.add("Stitched: $selectedStitchedStatus");
        if (fabricController.text.trim().isNotEmpty) metaNotes.add("Fabric: ${fabricController.text.trim()}");
        metaNotes.add("Gender: $selectedGender");
      }
      final finalDesc = descriptionController.text.trim() + (metaNotes.isNotEmpty ? "\n\n[Details]: ${metaNotes.join(' | ')}" : "");

      // 2. Insert into products
      final productRes = await supabase.from('products').insert({
        'seller_id': user.id,
        'name': nameController.text.trim(),
        'price': priceVal,
        'original_price': originalPriceVal ?? priceVal,
        'description': finalDesc,
        'category': selectedCategory,
        'size': formattedSizesStr,
        'color': colorController.text.trim(),
        'stock': stockVal,
        'image_url': mainImage,
        'is_active': true,
      }).select('id').single();

      final productId = productRes['id'];

      // 3. Insert into product_images
      if (productId != null && uploadedUrls.length > 1) {
        final imageRows = List.generate(uploadedUrls.length, (index) {
          return {
            'product_id': productId,
            'image_url': uploadedUrls[index],
            'sort_order': index,
          };
        });
        await supabase.from('product_images').insert(imageRows);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Product published successfully! 🎉"),
          backgroundColor: Color(0xFF10B981),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to publish product: $e"), backgroundColor: Colors.red),
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
        title: const Text("Add New Product", style: TextStyle(color: slateDark, fontSize: 18, fontWeight: FontWeight.w900)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: sapphireBlue))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ================= 1. IMAGE UPLOADER SECTION =================
                        _sectionTitle("Product Media Gallery", "Upload up to 6 high quality product photos"),
                        const SizedBox(height: 12),
                        _buildImagePickerGrid(),

                        const SizedBox(height: 24),

                        // ================= 2. CATEGORY SELECTOR & WRITE-IN =================
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                "Product Category",
                                style: TextStyle(color: slateDark, fontSize: 14.5, fontWeight: FontWeight.w900),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: sapphireBlue),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: _showAddCustomCategoryDialog,
                              icon: const Icon(Icons.add_rounded, color: sapphireBlue, size: 15),
                              label: const Text("+ Custom Category", style: TextStyle(color: sapphireBlue, fontSize: 11, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildCategorySelector(),

                        const SizedBox(height: 24),

                        // ================= 3. BASIC PRODUCT INFORMATION =================
                        _sectionTitle("Product Info", "Name, Price & Stock details"),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nameController,
                          validator: (val) => val == null || val.trim().isEmpty ? "Please enter product title" : null,
                          decoration: _inputDecoration("Product Title", "e.g., Designer Embroidered Lawn Dress", Icons.title_rounded),
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: priceController,
                                keyboardType: TextInputType.number,
                                validator: (val) => val == null || val.trim().isEmpty ? "Price required" : null,
                                decoration: _inputDecoration("Selling Price (Rs.)", "e.g., 4999", Icons.attach_money_rounded),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: originalPriceController,
                                keyboardType: TextInputType.number,
                                decoration: _inputDecoration("Original Price (Rs.)", "Optional", Icons.money_off_rounded),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: stockController,
                                keyboardType: TextInputType.number,
                                validator: (val) => val == null || val.trim().isEmpty ? "Stock count required" : null,
                                decoration: _inputDecoration("Stock Quantity", "e.g., 25", Icons.inventory_rounded),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: colorController,
                                decoration: _inputDecoration("Color / Variant", "e.g., Emerald Green", Icons.palette_outlined),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // ================= 4. ITEM-SPECIFIC DYNAMIC PROPERTIES =================
                        if (isClothingCategory) ...[
                          _sectionTitle("Clothing Specifications", "Stitched status & Fabric details"),
                          const SizedBox(height: 12),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              const Text("Stitched Status: ", style: TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w700)),
                              ...["Stitched", "Unstitched", "Semi-Stitched"].map((st) {
                                final isSel = selectedStitchedStatus == st;
                                return ChoiceChip(
                                  label: Text(st, style: TextStyle(color: isSel ? Colors.white : slateDark, fontSize: 11, fontWeight: FontWeight.w700)),
                                  selected: isSel,
                                  selectedColor: sapphireBlue,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  onSelected: (sel) => setState(() => selectedStitchedStatus = st),
                                );
                              }),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: fabricController,
                            decoration: _inputDecoration("Fabric / Material", "e.g., Pure Lawn, Silk, Denim, Chiffon", Icons.texture_rounded),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // ================= 5. DYNAMIC SIZES SELECTOR =================
                        _sectionTitle("Available Sizes", "Select all sizes in stock"),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: availableSizesForCategory.map((sz) {
                            final isSel = selectedSizes.contains(sz);
                            return FilterChip(
                              label: Text(sz, style: TextStyle(color: isSel ? Colors.white : slateDark, fontWeight: FontWeight.w800, fontSize: 12)),
                              selected: isSel,
                              selectedColor: sapphireBlue,
                              backgroundColor: const Color(0xFFF1F5F9),
                              checkmarkColor: Colors.white,
                              onSelected: (sel) {
                                setState(() {
                                  if (sel) {
                                    selectedSizes.add(sz);
                                  } else {
                                    selectedSizes.remove(sz);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 24),

                        // ================= 6. DESCRIPTION =================
                        _sectionTitle("Product Description", "Full details, washing instructions, or specs"),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: descriptionController,
                          maxLines: 4,
                          decoration: _inputDecoration("Detailed Description", "Describe quality, fit, and package contents...", Icons.description_outlined),
                        ),

                        const SizedBox(height: 32),

                        // ================= 7. PUBLISH BUTTON =================
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: sapphireBlue,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                          ),
                          onPressed: _uploadProduct,
                          icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 20),
                          label: const Text("PUBLISH PRODUCT NOW", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
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

  Widget _buildCategorySelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categoriesList.map((cat) {
          final isSelected = selectedCategory == cat;
          return InkWell(
            onTap: () => setState(() {
              selectedCategory = cat;
              selectedSizes = [availableSizesForCategory.first];
            }),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? sapphireBlue : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? sapphireBlue : const Color(0xFFE2E8F0)),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  color: isSelected ? Colors.white : slateDark,
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildImagePickerGrid() {
    return Row(
      children: [
        InkWell(
          onTap: _pickImages,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: sapphireLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: sapphireBlue, width: 1.5),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_rounded, color: sapphireBlue, size: 26),
                SizedBox(height: 4),
                Text("Add Photo", style: TextStyle(color: sapphireBlue, fontSize: 10, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _imageBytesList.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: index == 0 ? sapphireBlue : const Color(0xFFE2E8F0), width: index == 0 ? 2 : 1),
                        image: DecorationImage(image: MemoryImage(_imageBytesList[index]), fit: BoxFit.cover),
                      ),
                    ),
                    if (index == 0)
                      Positioned(
                        left: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(color: sapphireBlue, borderRadius: BorderRadius.circular(6)),
                          child: const Text("THUMB", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                        ),
                      ),
                    Positioned(
                      right: 12,
                      top: 4,
                      child: InkWell(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 12),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}