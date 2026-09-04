import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProductScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const EditProductScreen({
    super.key,
    required this.product,
  });

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  late TextEditingController nameController;
  late TextEditingController priceController;
  late TextEditingController originalPriceController;
  late TextEditingController descriptionController;
  late TextEditingController stockController;
  late TextEditingController colorController;

  final FocusNode colorFocusNode = FocusNode();
  bool showColorPalette = false;

  String? selectedCategory;
  List<String> selectedSizes = [];
  bool isLoading = false;

  final List<String> categoriesList = [
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
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color cardBorderColor = Color(0xFF93C5FD);
  static const Color bgColor = Colors.white;

  @override
  void initState() {
    super.initState();
    colorFocusNode.addListener(() {
      if (colorFocusNode.hasFocus && !showColorPalette) {
        setState(() => showColorPalette = true);
      }
    });

    final p = widget.product;
    nameController = TextEditingController(text: p['name']?.toString() ?? '');
    priceController = TextEditingController(text: (p['price'] as num?)?.toString() ?? '');
    originalPriceController = TextEditingController(text: (p['original_price'] as num?)?.toString() ?? (p['price'] as num?)?.toString() ?? '');
    descriptionController = TextEditingController(text: p['description']?.toString() ?? '');
    stockController = TextEditingController(text: (p['stock'] as num?)?.toString() ?? '10');
    colorController = TextEditingController(text: p['color']?.toString() ?? '');

    selectedCategory = p['category']?.toString();
    if (selectedCategory != null && !categoriesList.contains(selectedCategory)) {
      categoriesList.insert(0, selectedCategory!);
    }

    final rawSize = p['size']?.toString() ?? '';
    if (rawSize.isNotEmpty) {
      selectedSizes = rawSize.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    if (selectedSizes.isEmpty) selectedSizes = ["M"];
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    originalPriceController.dispose();
    descriptionController.dispose();
    stockController.dispose();
    colorController.dispose();
    colorFocusNode.dispose();
    super.dispose();
  }

  final List<String> popularColors = [
    "Black",
    "White",
    "Navy Blue",
    "Royal Blue",
    "Maroon",
    "Red",
    "Brown",
    "Beige",
    "Sage Grey",
    "Emerald Green",
    "Purple",
    "Pink",
    "Olive",
    "Grey",
  ];

  Color _getColorFromName(String name) {
    final n = name.trim().toLowerCase();
    if (n.contains('black')) return const Color(0xFF1E293B);
    if (n.contains('white')) return const Color(0xFFF8FAFC);
    if (n.contains('navy')) return const Color(0xFF1E3A8A);
    if (n.contains('royal')) return const Color(0xFF2563EB);
    if (n.contains('blue')) return const Color(0xFF3B82F6);
    if (n.contains('maroon')) return const Color(0xFF881337);
    if (n.contains('red')) return const Color(0xFFDC2626);
    if (n.contains('brown')) return const Color(0xFF78350F);
    if (n.contains('beige')) return const Color(0xFFD4B996);
    if (n.contains('sage') || (n.contains('grey') && n.contains('sage'))) return const Color(0xFF9CA3AF);
    if (n.contains('emerald') || n.contains('green')) return const Color(0xFF059669);
    if (n.contains('purple')) return const Color(0xFF9333EA);
    if (n.contains('pink')) return const Color(0xFFEC4899);
    if (n.contains('yellow')) return const Color(0xFFEAB308);
    if (n.contains('olive')) return const Color(0xFF65A30D);
    if (n.contains('gold')) return const Color(0xFFCA8A04);
    if (n.contains('grey') || n.contains('gray')) return const Color(0xFF64748B);
    if (n.contains('orange')) return const Color(0xFFEA580C);
    if (n.contains('teal')) return const Color(0xFF0D9488);
    return const Color(0xFF2563EB);
  }

  List<String> get availableSizes {
    final cat = (selectedCategory ?? '').toLowerCase();
    if (cat.contains('shoe') || cat.contains('sneaker') || cat.contains('heel') || cat.contains('sandal') || cat.contains('boot')) {
      return ["36", "37", "38", "39", "40", "41", "42", "43", "44", "45", "46", "6", "7", "8", "9", "10", "11", "12"];
    } else if (cat.contains('dress') || cat.contains('suit') || cat.contains('wear') || cat.contains('shirt') || cat.contains('jean') || cat.contains('kurti')) {
      return ["XS", "S", "M", "L", "XL", "XXL", "3XL", "Free Size"];
    } else {
      return ["Standard Size", "One Size", "Small", "Medium", "Large"];
    }
  }

  // ================= SAVE PRODUCT EDITS =================
  Future<void> _saveProductEdits() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      final productId = widget.product['id']?.toString();
      if (productId == null) throw Exception("Invalid product id");

      final priceVal = double.parse(priceController.text.trim());
      final origPriceVal = double.tryParse(originalPriceController.text.trim());
      final stockVal = int.parse(stockController.text.trim());

      await supabase.from('products').update({
        'name': nameController.text.trim(),
        'price': priceVal,
        'original_price': origPriceVal ?? priceVal,
        'description': descriptionController.text.trim(),
        'category': selectedCategory,
        'size': selectedSizes.join(', '),
        'color': colorController.text.trim(),
        'stock': stockVal,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', productId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Product updated successfully! 🎉"),
          backgroundColor: Color(0xFF10B981),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update product: $e"), backgroundColor: Colors.red),
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
        title: const Text("Edit Product Details", style: TextStyle(color: slateDark, fontSize: 18, fontWeight: FontWeight.w900)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: sapphireBlue))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        TextFormField(
                          controller: nameController,
                          validator: (val) => val == null || val.trim().isEmpty ? "Title required" : null,
                          decoration: _inputDecoration("Product Title", "Title", Icons.title_rounded),
                        ),
                        const SizedBox(height: 14),

                        // Prices
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: priceController,
                                keyboardType: TextInputType.number,
                                validator: (val) => val == null || val.trim().isEmpty ? "Price required" : null,
                                decoration: _inputDecoration("Selling Price (Rs.)", "Selling Price", Icons.attach_money_rounded),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: originalPriceController,
                                keyboardType: TextInputType.number,
                                decoration: _inputDecoration("Original Price (Rs.)", "Original Price", Icons.money_off_rounded),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Stock & Color
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: stockController,
                                keyboardType: TextInputType.number,
                                validator: (val) => val == null || val.trim().isEmpty ? "Stock required" : null,
                                decoration: _inputDecoration("Stock Quantity", "Quantity", Icons.inventory_rounded),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: colorController,
                                focusNode: colorFocusNode,
                                onTap: () {
                                  if (!showColorPalette) {
                                    setState(() => showColorPalette = true);
                                  }
                                },
                                decoration: _inputDecoration("Color / Variant", "e.g., Black, Navy Blue, Maroon", Icons.palette_outlined).copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      showColorPalette ? Icons.keyboard_arrow_up_rounded : Icons.palette_outlined,
                                      color: showColorPalette ? sapphireBlue : slateMuted,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() => showColorPalette = !showColorPalette),
                                    tooltip: showColorPalette ? "Hide Colors" : "Show Colors",
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (showColorPalette) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Select Colors (Tap to add/remove)", style: TextStyle(color: slateDark, fontSize: 11.5, fontWeight: FontWeight.w700)),
                                    InkWell(
                                      onTap: () => setState(() => showColorPalette = false),
                                      child: const Text("Done", style: TextStyle(color: sapphireBlue, fontSize: 11.5, fontWeight: FontWeight.w800)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: popularColors.map((clr) {
                                    final currentList = colorController.text.split(',').map((c) => c.trim().toLowerCase()).toList();
                                    final isSel = currentList.contains(clr.toLowerCase());
                                    return FilterChip(
                                      avatar: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: _getColorFromName(clr),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSel ? Colors.white70 : Colors.black12,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      label: Text(clr, style: TextStyle(color: isSel ? Colors.white : slateDark, fontSize: 10.5, fontWeight: FontWeight.w700)),
                                      selected: isSel,
                                      selectedColor: sapphireBlue,
                                      backgroundColor: Colors.white,
                                      checkmarkColor: Colors.white,
                                      onSelected: (sel) {
                                        final existing = colorController.text.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
                                        if (sel) {
                                          if (!existing.any((c) => c.toLowerCase() == clr.toLowerCase())) {
                                            existing.add(clr);
                                          }
                                        } else {
                                          existing.removeWhere((c) => c.toLowerCase() == clr.toLowerCase());
                                        }
                                        setState(() {
                                          colorController.text = existing.join(", ");
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Category Dropdown
                        DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          decoration: _inputDecoration("Category", "", Icons.category_rounded),
                          items: categoriesList.map((cat) {
                            return DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 13, color: slateDark)));
                          }).toList(),
                          onChanged: (val) => setState(() => selectedCategory = val),
                        ),
                        const SizedBox(height: 16),

                        // Sizes Selector
                        const Text("Available Sizes", style: TextStyle(color: slateDark, fontSize: 14, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: availableSizes.map((sz) {
                            final isSel = selectedSizes.contains(sz);
                            return FilterChip(
                              label: Text(sz, style: TextStyle(color: isSel ? Colors.white : slateDark, fontWeight: FontWeight.w800, fontSize: 11.5)),
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

                        const SizedBox(height: 16),

                        // Description
                        TextFormField(
                          controller: descriptionController,
                          maxLines: 4,
                          decoration: _inputDecoration("Product Description", "Full product description", Icons.description_outlined),
                        ),

                        const SizedBox(height: 28),

                        // Save Button
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: sapphireBlue,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 3,
                          ),
                          onPressed: _saveProductEdits,
                          icon: const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                          label: const Text("SAVE CHANGES", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
}
