import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({super.key});

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen> {
  final supabase = Supabase.instance.client;

  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> products = [];
  bool isLoading = true;

  String selectedCategory = "All";
  String selectedStockFilter = "All";

  final List<String> stockFilters = [
    "All",
    "Active",
    "Inactive",
    "In Stock",
    "Low Stock",
    "Out of Stock",
  ];

  final List<String> sizes = ["S", "M", "L", "XL", "XXL"];

  @override
  void initState() {
    super.initState();
    fetchMyProducts();
    searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ================= FETCH MY PRODUCTS =================
  Future<void> fetchMyProducts() async {
    if (mounted) {
      setState(() => isLoading = true);
    }

    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception("User not logged in");
      }

      final data = await supabase
          .from('products')
          .select('*')
          .eq('seller_id', currentUser.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        products = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Fetch Products Error: $e");

      if (!mounted) return;

      setState(() {
        products = [];
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to load products: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================= FILTER CATEGORIES =================
  List<String> get categories {
    final Set<String> uniqueCategories = {};

    for (final product in products) {
      final category = product['category']?.toString().trim();
      if (category != null && category.isNotEmpty) {
        uniqueCategories.add(category);
      }
    }

    return ["All", ...uniqueCategories.toList()..sort()];
  }

  // ================= FILTERED PRODUCTS =================
  List<Map<String, dynamic>> get filteredProducts {
    final query = searchController.text.trim().toLowerCase();

    return products.where((product) {
      final name = product['name']?.toString().toLowerCase() ?? "";
      final category = product['category']?.toString() ?? "";
      final color = product['color']?.toString().toLowerCase() ?? "";
      final size = product['size']?.toString().toLowerCase() ?? "";
      final stock = (product['stock'] as num?)?.toInt() ?? 0;
      final isActive = product['is_active'] as bool? ?? true;

      final matchesSearch = query.isEmpty ||
          name.contains(query) ||
          category.toLowerCase().contains(query) ||
          color.contains(query) ||
          size.contains(query);

      final matchesCategory =
          selectedCategory == "All" || category == selectedCategory;

      bool matchesStock = true;

      if (selectedStockFilter == "Active") {
        matchesStock = isActive;
      } else if (selectedStockFilter == "Inactive") {
        matchesStock = !isActive;
      } else if (selectedStockFilter == "In Stock") {
        matchesStock = stock > 5;
      } else if (selectedStockFilter == "Low Stock") {
        matchesStock = stock > 0 && stock <= 5;
      } else if (selectedStockFilter == "Out of Stock") {
        matchesStock = stock <= 0;
      }

      return matchesSearch && matchesCategory && matchesStock;
    }).toList();
  }

  int get totalProducts => products.length;

  int get activeProducts {
    return products.where((p) => (p['is_active'] as bool? ?? true)).length;
  }

  int get outOfStockProducts {
    return products.where((p) {
      final stock = (p['stock'] as num?)?.toInt() ?? 0;
      return stock <= 0;
    }).length;
  }

  double get inventoryValue {
    return products.fold(0.0, (sum, product) {
      final price = (product['price'] as num?)?.toDouble() ?? 0.0;
      final stock = (product['stock'] as num?)?.toInt() ?? 0;
      return sum + (price * stock);
    });
  }

  // ================= DELETE PRODUCT =================
  Future<void> deleteProduct(dynamic productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            "Delete Product?",
            style: TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            "This product will be permanently deleted. This action cannot be undone.",
            style: TextStyle(
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception("User not logged in");
      }

      await supabase
          .from('products')
          .delete()
          .eq('id', productId)
          .eq('seller_id', currentUser.id);

      await fetchMyProducts();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Product deleted successfully"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint("Delete Product Error: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Delete failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================= ACTIVE / INACTIVE TOGGLE =================
  Future<void> toggleProductStatus(Map<String, dynamic> product) async {
    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception("User not logged in");
      }

      final productId = product['id'];
      final currentStatus = product['is_active'] as bool? ?? true;

      await supabase
          .from('products')
          .update({
            'is_active': !currentStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', productId)
          .eq('seller_id', currentUser.id);

      await fetchMyProducts();
    } catch (e) {
      debugPrint("Toggle Product Error: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Status update failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================= UPDATE PRODUCT =================
  Future<void> updateProduct({
    required dynamic productId,
    required String name,
    required String price,
    required String description,
    required String category,
    required String size,
    required String color,
    required String stock,
  }) async {
    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception("User not logged in");
      }

      final parsedPrice = double.tryParse(price.trim());
      final parsedStock = int.tryParse(stock.trim());

      if (parsedPrice == null || parsedPrice <= 0) {
        throw Exception("Please enter a valid price");
      }

      if (parsedStock == null || parsedStock < 0) {
        throw Exception("Please enter a valid stock quantity");
      }

      await supabase
          .from('products')
          .update({
            'name': name.trim(),
            'price': parsedPrice,
            'description': description.trim(),
            'category': category.trim(),
            'size': size.trim(),
            'color': color.trim(),
            'stock': parsedStock,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', productId)
          .eq('seller_id', currentUser.id);

      await fetchMyProducts();

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Product updated successfully"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint("Update Product Error: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Update failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================= EDIT PRODUCT SHEET =================
  void openEditProductSheet(Map<String, dynamic> product) {
    final nameController =
        TextEditingController(text: product['name']?.toString() ?? "");
    final priceController =
        TextEditingController(text: product['price']?.toString() ?? "");
    final descriptionController =
        TextEditingController(text: product['description']?.toString() ?? "");
    final categoryController =
        TextEditingController(text: product['category']?.toString() ?? "");
    final colorController =
        TextEditingController(text: product['color']?.toString() ?? "");
    final stockController =
        TextEditingController(text: product['stock']?.toString() ?? "0");

    String selectedSize = product['size']?.toString() ?? "M";
    if (!sizes.contains(selectedSize)) {
      selectedSize = "M";
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 18,
                bottom: bottomInset + 20,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Edit Product",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      _editInput(
                        controller: nameController,
                        label: "Product Name",
                        icon: Icons.shopping_bag_outlined,
                      ),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: _editInput(
                              controller: priceController,
                              label: "Price",
                              icon: Icons.payments_outlined,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _editInput(
                              controller: stockController,
                              label: "Stock",
                              icon: Icons.inventory_2_outlined,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: _editInput(
                              controller: categoryController,
                              label: "Category",
                              icon: Icons.category_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedSize,
                              decoration: _editDecoration(
                                label: "Size",
                                icon: Icons.straighten_outlined,
                              ),
                              items: sizes.map((size) {
                                return DropdownMenuItem(
                                  value: size,
                                  child: Text(size),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setSheetState(() {
                                  selectedSize = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      _editInput(
                        controller: colorController,
                        label: "Color",
                        icon: Icons.color_lens_outlined,
                      ),

                      const SizedBox(height: 14),

                      _editInput(
                        controller: descriptionController,
                        label: "Description",
                        icon: Icons.description_outlined,
                        maxLines: 4,
                      ),

                      const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            updateProduct(
                              productId: product['id'],
                              name: nameController.text,
                              price: priceController.text,
                              description: descriptionController.text,
                              category: categoryController.text,
                              size: selectedSize,
                              color: colorController.text,
                              stock: stockController.text,
                            );
                          },
                          icon: const Icon(Icons.save_outlined),
                          label: const Text(
                            "SAVE CHANGES",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      priceController.dispose();
      descriptionController.dispose();
      categoryController.dispose();
      colorController.dispose();
      stockController.dispose();
    });
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
          "My Products",
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: fetchMyProducts,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color.fromARGB(255, 50, 192, 90),
        foregroundColor: Colors.white,
        elevation: 0,
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/add_product');
          if (result == true) {
            fetchMyProducts();
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          "Add Product",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            int gridCount = 1;
            if (width >= 1350) {
              gridCount = 4;
            } else if (width >= 1000) {
              gridCount = 3;
            } else if (width >= 650) {
              gridCount = 2;
            }

            final bool isMobile = width < 650;

            return RefreshIndicator(
              onRefresh: fetchMyProducts,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : 28,
                        vertical: 18,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1400),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ================= HEADER =================
                              Text(
                                "Product Inventory",
                                style: TextStyle(
                                  fontSize: isMobile ? 26 : 34,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF111827),
                                ),
                              ),

                              const SizedBox(height: 8),

                              Text(
                                "Manage your products, stock, pricing, and availability.",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: isMobile ? 14 : 16,
                                ),
                              ),

                              const SizedBox(height: 22),

                              // ================= SUMMARY =================
                              isMobile
                                  ? Column(
                                      children: [
                                        _summaryCard(
                                          title: "Total Products",
                                          value: totalProducts.toString(),
                                          icon: Icons.inventory_2_outlined,
                                          color: const Color(0xFF4F46E5),
                                        ),
                                        const SizedBox(height: 12),
                                        _summaryCard(
                                          title: "Active Products",
                                          value: activeProducts.toString(),
                                          icon: Icons.visibility_outlined,
                                          color: const Color(0xFF22C55E),
                                        ),
                                        const SizedBox(height: 12),
                                        _summaryCard(
                                          title: "Out of Stock",
                                          value: outOfStockProducts.toString(),
                                          icon: Icons.warning_amber_rounded,
                                          color: const Color(0xFFEF4444),
                                        ),
                                        const SizedBox(height: 12),
                                        _summaryCard(
                                          title: "Inventory Value",
                                          value:
                                              "PKR ${inventoryValue.toStringAsFixed(0)}",
                                          icon:
                                              Icons.account_balance_wallet_outlined,
                                          color: const Color(0xFFF59E0B),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Expanded(
                                          child: _summaryCard(
                                            title: "Total Products",
                                            value: totalProducts.toString(),
                                            icon: Icons.inventory_2_outlined,
                                            color: const Color(0xFF4F46E5),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: _summaryCard(
                                            title: "Active Products",
                                            value: activeProducts.toString(),
                                            icon: Icons.visibility_outlined,
                                            color: const Color(0xFF22C55E),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: _summaryCard(
                                            title: "Out of Stock",
                                            value:
                                                outOfStockProducts.toString(),
                                            icon: Icons.warning_amber_rounded,
                                            color: const Color(0xFFEF4444),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: _summaryCard(
                                            title: "Inventory Value",
                                            value:
                                                "PKR ${inventoryValue.toStringAsFixed(0)}",
                                            icon: Icons
                                                .account_balance_wallet_outlined,
                                            color: const Color(0xFFF59E0B),
                                          ),
                                        ),
                                      ],
                                    ),

                              const SizedBox(height: 24),

                              // ================= SEARCH =================
                              TextField(
                                controller: searchController,
                                decoration: InputDecoration(
                                  hintText:
                                      "Search by name, category, color, size...",
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  suffixIcon: searchController.text.isNotEmpty
                                      ? IconButton(
                                          onPressed: () {
                                            searchController.clear();
                                          },
                                          icon: const Icon(Icons.close_rounded),
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF4F46E5),
                                      width: 1.6,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // ================= FILTERS =================
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    ...categories.map((category) {
                                      return _filterChip(
                                        label: category,
                                        selected: selectedCategory == category,
                                        onTap: () {
                                          setState(() {
                                            selectedCategory = category;
                                          });
                                        },
                                      );
                                    }),
                                    const SizedBox(width: 12),
                                    Container(
                                      height: 32,
                                      width: 1,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(width: 12),
                                    ...stockFilters.map((filter) {
                                      return _filterChip(
                                        label: filter,
                                        selected:
                                            selectedStockFilter == filter,
                                        onTap: () {
                                          setState(() {
                                            selectedStockFilter = filter;
                                          });
                                        },
                                      );
                                    }),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 22),

                              // ================= PRODUCTS =================
                              if (filteredProducts.isEmpty)
                                _emptyProductsView()
                              else
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  itemCount: filteredProducts.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: gridCount,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: width >= 1000
                                        ? 0.76
                                        : width >= 650
                                            ? 0.72
                                            : 0.78,
                                  ),
                                  itemBuilder: (context, index) {
                                    return _buildProductCard(
                                      filteredProducts[index],
                                    );
                                  },
                                ),

                              const SizedBox(height: 90),
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

  // ================= SUMMARY CARD =================
  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= FILTER CHIP =================
  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        selected: selected,
        label: Text(label),
        backgroundColor: Colors.white,
        selectedColor: const Color.fromARGB(255, 99, 212, 119),
        labelStyle: TextStyle(
          color: selected ? Colors.white : const Color(0xFF374151),
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(
          color: selected ? const Color(0xFF4F46E5) : Colors.grey.shade300,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }

  // ================= PRODUCT CARD =================
  Widget _buildProductCard(Map<String, dynamic> product) {
    final String name = product['name']?.toString() ?? "Product";
    final String category = product['category']?.toString() ?? "N/A";
    final String color = product['color']?.toString() ?? "N/A";
    final String size = product['size']?.toString() ?? "N/A";
    final String imageUrl = product['image_url']?.toString() ?? "";
    final String description = product['description']?.toString() ?? "";

    final double price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final int stock = (product['stock'] as num?)?.toInt() ?? 0;
    final bool isActive = product['is_active'] as bool? ?? true;

    final Color stockColor = stock <= 0
        ? Colors.red
        : stock <= 5
            ? Colors.orange
            : Colors.green;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= IMAGE =================
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                Positioned.fill(
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) {
                            return _imagePlaceholder();
                          },
                        )
                      : _imagePlaceholder(),
                ),

                Positioned(
                  top: 12,
                  left: 12,
                  child: _smallBadge(
                    label: isActive ? "Active" : "Inactive",
                    color: isActive ? Colors.green : Colors.grey,
                  ),
                ),

                Positioned(
                  top: 12,
                  right: 12,
                  child: _smallBadge(
                    label: stock <= 0 ? "Out" : "$stock pcs",
                    color: stockColor,
                  ),
                ),
              ],
            ),
          ),

          // ================= DETAILS =================
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        "PKR ${price.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: Color(0xFF16A34A),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(
                    "$category • $color • $size",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 8),

                  if (description.trim().isNotEmpty)
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    )
                  else
                    Text(
                      "No description added",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),

                  const Spacer(),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => openEditProductSheet(product),
                          icon: const Icon(Icons.edit_outlined, size: 17),
                          label: const Text("Edit"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4F46E5),
                            side: const BorderSide(
                              color: Color(0xFF4F46E5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: isActive ? "Make Inactive" : "Make Active",
                        onPressed: () => toggleProductStatus(product),
                        style: IconButton.styleFrom(
                          backgroundColor: isActive
                              ? Colors.orange.withValues(alpha: 0.12)
                              : Colors.green.withValues(alpha: 0.12),
                        ),
                        icon: Icon(
                          isActive
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: isActive ? Colors.orange : Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: "Delete",
                        onPressed: () => deleteProduct(product['id']),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withValues(alpha: 0.10),
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.08);
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFEFF3FF),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: Color(0xFF94A3B8),
          size: 52,
        ),
      ),
    );
  }

  Widget _smallBadge({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _emptyProductsView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 78,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            "No Products Found",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            products.isEmpty
                ? "Add your first product to start selling."
                : "No products match your current filters.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.pushNamed(context, '/add_product');
              if (result == true) fetchMyProducts();
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text("Add Product"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 46, 169, 62),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _editDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFF4F46E5),
          width: 1.6,
        ),
      ),
    );
  }

  Widget _editInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: _editDecoration(
        label: label,
        icon: icon,
      ),
    );
  }
}