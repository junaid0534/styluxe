import 'dart:typed_data';

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
  final descriptionController = TextEditingController();
  final stockController = TextEditingController(text: "10");
  final colorController = TextEditingController();

  String? selectedCategory;
  String? selectedSize = "All";

  final List<XFile> _imageFiles = [];
  final List<Uint8List> _imageBytesList = [];

  bool isLoading = false;

  final int maxImages = 6;

  final List<String> sizes = [
    "All",
    "S",
    "M",
    "L",
    "XL",
    "XXL",
  ];

  final List<String> categories = [
    "Men",
    "Women",
    "Kids",
    "T-Shirt",
    "Shirt",
    "Hoodie",
    "Jeans",
    "Jacket",
    "Trouser",
    "Kurta",
    "Dresses",
    "Suits",
    "Shoes",
    "Accessories",
    "Bags",
    "Watches",
    "Other",
  ];

  @override
  void initState() {
    super.initState();

    if (widget.preSelectedCategory != null &&
        widget.preSelectedCategory!.trim().isNotEmpty) {
      selectedCategory = _normalizeCategory(widget.preSelectedCategory!);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    descriptionController.dispose();
    stockController.dispose();
    colorController.dispose();
    super.dispose();
  }

  // ================= NORMALIZE CATEGORY =================
  String _normalizeCategory(String value) {
    final category = value.trim().toLowerCase();

    switch (category) {
      case "dress":
      case "dresses":
        return "Dresses";

      case "suite":
      case "suites":
      case "suit":
      case "suits":
        return "Suits";

      case "tshirt":
      case "t-shirt":
      case "t shirt":
      case "t-shirts":
      case "t shirts":
        return "T-Shirt";

      case "shirt":
      case "shirts":
        return "Shirt";

      case "hoodie":
      case "hoodies":
        return "Hoodie";

      case "jean":
      case "jeans":
        return "Jeans";

      case "jacket":
      case "jackets":
        return "Jacket";

      case "trouser":
      case "trousers":
        return "Trouser";

      case "kurta":
      case "kurtas":
        return "Kurta";

      case "kid":
      case "kids":
      case "children":
        return "Kids";

      default:
        return value.trim();
    }
  }

  String _contentType(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith(".png")) return "image/png";
    if (lower.endsWith(".webp")) return "image/webp";
    if (lower.endsWith(".jpeg")) return "image/jpeg";
    if (lower.endsWith(".jpg")) return "image/jpeg";

    return "image/jpeg";
  }

  // ================= PICK MULTIPLE IMAGES =================
  Future<void> _pickImages() async {
    try {
      final pickedFiles = await ImagePicker().pickMultiImage(
        imageQuality: 85,
      );

      if (pickedFiles.isEmpty) return;

      final availableSlots = maxImages - _imageFiles.length;

      if (availableSlots <= 0) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("You can upload maximum $maxImages images"),
            backgroundColor: Colors.orange,
          ),
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

      if (pickedFiles.length > availableSlots) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Only $availableSlots more image(s) were added"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint("Pick Images Error: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Image selection failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeImage(int index) {
    if (index < 0 || index >= _imageFiles.length) return;

    setState(() {
      _imageFiles.removeAt(index);
      _imageBytesList.removeAt(index);
    });
  }

  void _setMainImage(int index) {
    if (index <= 0 || index >= _imageFiles.length) return;

    setState(() {
      final file = _imageFiles.removeAt(index);
      final bytes = _imageBytesList.removeAt(index);

      _imageFiles.insert(0, file);
      _imageBytesList.insert(0, bytes);
    });
  }

  // ================= UPLOAD ALL IMAGES =================
  Future<List<String>> _uploadProductImages({
    required String userId,
  }) async {
    final uploadedUrls = <String>[];

    for (int i = 0; i < _imageBytesList.length; i++) {
      final file = _imageFiles[i];
      final bytes = _imageBytesList[i];

      final safeFileName =
          '${DateTime.now().millisecondsSinceEpoch}_${i}_${file.name}'
              .replaceAll(" ", "_")
              .replaceAll("/", "_");

      final filePath = '$userId/$safeFileName';

      await supabase.storage.from('product_images').uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              contentType: _contentType(file.name),
              upsert: true,
            ),
          );

      final imageUrl =
          supabase.storage.from('product_images').getPublicUrl(filePath);

      uploadedUrls.add(imageUrl);
    }

    return uploadedUrls;
  }

  // ================= UPLOAD PRODUCT =================
  Future<void> _uploadProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageBytesList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least 1 product image"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (selectedCategory == null || selectedCategory!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select category"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception("User not logged in");
      }

      final userId = currentUser.id;
      final parsedPrice = double.tryParse(priceController.text.trim());
      final parsedStock = int.tryParse(stockController.text.trim());

      if (parsedPrice == null || parsedPrice <= 0) {
        throw Exception("Please enter a valid price");
      }

      if (parsedStock == null || parsedStock < 0) {
        throw Exception("Please enter a valid stock quantity");
      }

      // 1. Upload all selected images to Supabase Storage
      final uploadedImageUrls = await _uploadProductImages(
        userId: userId,
      );

      if (uploadedImageUrls.isEmpty) {
        throw Exception("Image upload failed");
      }

      final mainImageUrl = uploadedImageUrls.first;

      // 2. Insert product and get product id
      final insertedProduct = await supabase
          .from('products')
          .insert({
            'seller_id': userId,
            'name': nameController.text.trim(),
            'price': parsedPrice,
            'description': descriptionController.text.trim(),
            'category': selectedCategory,
            'size': selectedSize,
            'color': colorController.text.trim(),
            'stock': parsedStock,
            'image_url': mainImageUrl,
            'is_active': true,
          })
          .select('id')
          .single();

      final productId = insertedProduct['id'];

      if (productId == null) {
        throw Exception("Product id not found after insert");
      }

      // 3. Save all image urls in product_images table
      final imageRows = List.generate(uploadedImageUrls.length, (index) {
        return {
          'product_id': productId,
          'image_url': uploadedImageUrls[index],
          'sort_order': index,
        };
      });

      await supabase.from('product_images').insert(imageRows);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Product added successfully with ${uploadedImageUrls.length} image(s)",
          ),
          backgroundColor: const Color(0xFF22C55E),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Upload Product Error: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
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
        backgroundColor: const Color(0xFFA8E063),
        surfaceTintColor: const Color(0xFFA8E063),
        elevation: 0,
        centerTitle: false,
        toolbarHeight: kToolbarHeight,
        iconTheme: const IconThemeData(
          color: Color(0xFF111827),
        ),
        title: const Text(
          "Add Product",
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
                    maxWidth: 950,
                  ),
                  child: Form(
                    key: _formKey,
                    child: isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _formContent(isMobile: true),
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: _imagePickerCard(isMobile: false),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _formFieldsOnly(isMobile: false),
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

  List<Widget> _formContent({required bool isMobile}) {
    return [
      _pageHeader(isMobile: isMobile),
      const SizedBox(height: 18),
      _imagePickerCard(isMobile: isMobile),
      const SizedBox(height: 22),
      ..._formFieldsOnly(isMobile: isMobile),
    ];
  }

  List<Widget> _formFieldsOnly({required bool isMobile}) {
    return [
      if (!isMobile) _pageHeader(isMobile: isMobile),

      if (!isMobile) const SizedBox(height: 18),

      _whiteCard(
        child: Column(
          children: [
            TextFormField(
              controller: nameController,
              decoration: _inputDecoration(
                label: "Product Name *",
                icon: Icons.shopping_bag_outlined,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return "Product name is required";
                }

                if (v.trim().length < 3) {
                  return "Product name is too short";
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    decoration: _inputDecoration(
                      label: "Price *",
                      icon: Icons.payments_outlined,
                    ),
                    validator: (v) {
                      final price = double.tryParse(v?.trim() ?? "");

                      if (price == null || price <= 0) {
                        return "Invalid price";
                      }

                      return null;
                    },
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: TextFormField(
                    controller: stockController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: _inputDecoration(
                      label: "Stock *",
                      icon: Icons.inventory_2_outlined,
                    ),
                    validator: (v) {
                      final stock = int.tryParse(v?.trim() ?? "");

                      if (stock == null || stock < 0) {
                        return "Invalid stock";
                      }

                      return null;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (widget.preSelectedCategory != null &&
                widget.preSelectedCategory!.trim().isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.category_outlined,
                      color: Color(0xFF4F46E5),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Category: ${selectedCategory ?? widget.preSelectedCategory}",
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: categories.contains(selectedCategory)
                    ? selectedCategory
                    : null,
                decoration: _inputDecoration(
                  label: "Category *",
                  icon: Icons.category_outlined,
                ),
                items: categories.map((category) {
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
                    return "Category is required";
                  }

                  return null;
                },
              ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedSize,
                    decoration: _inputDecoration(
                      label: "Size *",
                      icon: Icons.straighten_outlined,
                    ),
                    items: sizes.map((size) {
                      return DropdownMenuItem(
                        value: size,
                        child: Text(size),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedSize = value;
                      });
                    },
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return "Size required";
                      }

                      return null;
                    },
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: TextFormField(
                    controller: colorController,
                    decoration: _inputDecoration(
                      label: "Color *",
                      icon: Icons.color_lens_outlined,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return "Color required";
                      }

                      return null;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: descriptionController,
              maxLines: 4,
              decoration: _inputDecoration(
                label: "Description",
                icon: Icons.description_outlined,
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 22),

      SizedBox(
        width: double.infinity,
        height: 58,
        child: ElevatedButton.icon(
          onPressed: isLoading ? null : _uploadProduct,
          icon: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.add_circle_outline),
          label: Text(
            isLoading ? "ADDING PRODUCT..." : "ADD PRODUCT",
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF22C55E),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade400,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),

      const SizedBox(height: 30),
    ];
  }

  Widget _pageHeader({required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Create New Product",
          style: TextStyle(
            fontSize: isMobile ? 26 : 32,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Upload product details, multiple images, size, color, stock, and price.",
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: isMobile ? 14 : 16,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _imagePickerCard({required bool isMobile}) {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Product Images",
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: const Color(0xFFBBF7D0),
                  ),
                ),
                child: Text(
                  "${_imageFiles.length}/$maxImages",
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            "First image will be used as main product thumbnail.",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12.8,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 14),

          GestureDetector(
            onTap: isLoading ? null : _pickImages,
            child: AspectRatio(
              aspectRatio: isMobile ? 1.25 : 1.02,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    width: 1.2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _imageBytesList.isNotEmpty
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(
                            _imageBytesList.first,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            left: 12,
                            top: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.58),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Text(
                                "Main Image",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.58),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "Add More",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_a_photo_outlined,
                              size: 38,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            "Tap to upload product images",
                            style: TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "You can upload up to $maxImages images",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          if (_imageBytesList.isNotEmpty) ...[
            const SizedBox(height: 14),
            _selectedImagesGrid(),
          ],
        ],
      ),
    );
  }

  Widget _selectedImagesGrid() {
    return GridView.builder(
      itemCount: _imageBytesList.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final isMain = index == 0;

        return GestureDetector(
          onTap: isLoading ? null : () => _setMainImage(index),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isMain
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFE5E7EB),
                width: isMain ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  _imageBytesList[index],
                  fit: BoxFit.cover,
                ),

                if (isMain)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Text(
                        "Main",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),

                Positioned(
                  right: 5,
                  top: 5,
                  child: InkWell(
                    onTap: isLoading ? null : () => _removeImage(index),
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      height: 26,
                      width: 26,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.62),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                  ),
                ),

                if (!isMain)
                  Positioned(
                    left: 5,
                    bottom: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Text(
                        "Tap to main",
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _whiteCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF4F46E5),
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      labelStyle: TextStyle(
        color: Colors.grey.shade600,
        fontWeight: FontWeight.w600,
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
          width: 1.2,
        ),
      ),
    );
  }
}