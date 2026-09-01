import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'seller_product_detail_screen.dart';
import '../../../widgets/seller_bottom_nav.dart';

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

  String selectedCategoryFilter = "All";
  String selectedStockFilter = "All";

  static const Color sapphireBlue = Color(0xFF2563EB);
  static const Color sapphireLight = Color(0xFFEFF6FF);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color cardBorderColor = Color(0xFFE2E8F0);
  static const Color bgColor = Colors.white;

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
    if (mounted) setState(() => isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      final data = await supabase
          .from('products')
          .select('*')
          .eq('seller_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        products = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        products = [];
        isLoading = false;
      });
    }
  }

  // ================= 1-TAP TOGGLE STOCK =================
  Future<void> _toggleProductStock(String productId, bool currentStatus) async {
    try {
      await supabase
          .from('products')
          .update({'is_active': !currentStatus})
          .eq('id', productId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentStatus ? "Item marked Out of Stock" : "Item marked In Stock!"),
          backgroundColor: currentStatus ? Colors.orange : const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );

      fetchMyProducts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update stock: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // ================= DELETE PRODUCT =================
  Future<void> _deleteProduct(String productId) async {
    try {
      await supabase.from('products').delete().eq('id', productId);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Product deleted successfully"), backgroundColor: Colors.red),
      );

      fetchMyProducts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete product: $e"), backgroundColor: Colors.red),
      );
    }
  }

  List<String> get categoriesList {
    final Set<String> set = {"All"};
    for (final p in products) {
      final cat = p['category']?.toString().trim();
      if (cat != null && cat.isNotEmpty) set.add(cat);
    }
    return set.toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = products.where((p) {
      final name = (p['name']?.toString() ?? '').toLowerCase();
      final cat = (p['category']?.toString() ?? '').toLowerCase();
      final query = searchController.text.trim().toLowerCase();

      final matchesQuery = query.isEmpty || name.contains(query) || cat.contains(query);

      bool matchesCategory = true;
      if (selectedCategoryFilter != 'All') {
        matchesCategory = cat == selectedCategoryFilter.toLowerCase();
      }

      bool matchesStock = true;
      final isActive = (p['is_active'] as bool?) ?? true;
      final stockVal = (p['stock'] as num?)?.toInt() ?? 0;

      if (selectedStockFilter == 'In Stock') matchesStock = isActive && stockVal > 0;
      if (selectedStockFilter == 'Out of Stock') matchesStock = !isActive || stockVal == 0;

      return matchesQuery && matchesCategory && matchesStock;
    }).toList();

    final totalCount = products.length;
    final inStockCount = products.where((p) => ((p['is_active'] as bool?) ?? true) && ((p['stock'] as num?)?.toInt() ?? 0) > 0).length;
    final outOfStockCount = totalCount - inStockCount;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "My Products Catalog",
          style: TextStyle(color: slateDark, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: sapphireBlue))
          : RefreshIndicator(
              onRefresh: fetchMyProducts,
              color: sapphireBlue,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            const SizedBox(height: 8),

                            // ================= 1. ROYAL SAPPHIRE HERO BANNER =================
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: _buildHeroCard(totalCount, inStockCount, outOfStockCount),
                            ),

                            const SizedBox(height: 14),

                            // ================= 2. SEARCH BAR =================
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: cardBorderColor, width: 1.2),
                                ),
                                child: TextField(
                                  controller: searchController,
                                  onChanged: (_) => setState(() {}),
                                  style: const TextStyle(fontSize: 13, color: slateDark, fontWeight: FontWeight.w700),
                                  decoration: const InputDecoration(
                                    hintText: "Search products by name or category...",
                                    hintStyle: TextStyle(color: slateMuted, fontSize: 12.5),
                                    prefixIcon: Icon(Icons.search_rounded, color: sapphireBlue, size: 20),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(vertical: 11),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // ================= 3. CATEGORY FILTER BAR =================
                            _buildCategoryFilterBar(),

                            const SizedBox(height: 12),
                          ],
                        ),
                      ),

                      // ================= 4. RESPONSIVE PRODUCTS GRID =================
                      if (filtered.isEmpty)
                        SliverToBoxAdapter(child: _buildEmptyView())
                      else
                        SliverLayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.crossAxisExtent;
                            int crossAxisCount = 2;
                            double childAspectRatio = 0.58;

                            if (width >= 1000) {
                              crossAxisCount = 4;
                              childAspectRatio = 0.68;
                            } else if (width >= 700) {
                              crossAxisCount = 3;
                              childAspectRatio = 0.64;
                            } else if (width < 360) {
                              crossAxisCount = 2;
                              childAspectRatio = 0.54;
                            }

                            return SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              sliver: SliverGrid(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final item = filtered[index];
                                    return _modernProductGridCard(item).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05);
                                  },
                                  childCount: filtered.length,
                                ),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: childAspectRatio,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: const SellerBottomNav(currentIndex: 2),
    );
  }

  // ================= HERO CARD BANNER =================
  Widget _buildHeroCard(int total, int inStock, int outStock) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2563EB),
            Color(0xFF1D4ED8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: sapphireBlue.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Inventory Overview",
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Manage stock & pricing status",
                      style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 11, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: sapphireBlue,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () async {
                  final res = await Navigator.pushNamed(context, '/add_product');
                  if (res == true) fetchMyProducts();
                },
                icon: const Icon(Icons.add_circle_rounded, color: sapphireBlue, size: 15),
                label: const Text("Add Product", style: TextStyle(color: sapphireBlue, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _kpiStatChip("Total Items", "$total", Icons.inventory_2_rounded),
              const SizedBox(width: 6),
              _kpiStatChip("In Stock", "$inStock", Icons.check_circle_rounded),
              const SizedBox(width: 6),
              _kpiStatChip("Out of Stock", "$outStock", Icons.remove_circle_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiStatChip(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900)),
                  Text(
                    label,
                    style: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 9, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: categoriesList.map((cat) {
          final isSelected = selectedCategoryFilter == cat;
          return InkWell(
            onTap: () => setState(() => selectedCategoryFilter = cat),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? sapphireBlue : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? sapphireBlue : const Color(0xFFE2E8F0)),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  color: isSelected ? Colors.white : slateDark,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ================= MODERN 2-COLUMN GRID CARD =================
  Widget _modernProductGridCard(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final name = item['name']?.toString() ?? 'Unnamed Product';
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final origPrice = (item['original_price'] as num?)?.toDouble() ?? price;
    final category = item['category']?.toString() ?? 'General';
    final size = item['size']?.toString() ?? 'N/A';
    final stock = (item['stock'] as num?)?.toInt() ?? 0;
    final isActive = (item['is_active'] as bool?) ?? true;
    final imageUrl = item['image_url']?.toString();

    final discountPercent = (origPrice > price && origPrice > 0) ? (((origPrice - price) / origPrice) * 100).round() : 0;

    return InkWell(
      onTap: () async {
        final updated = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (ctx) => SellerProductDetailScreen(product: item),
          ),
        );
        if (updated == true && mounted) fetchMyProducts();
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cardBorderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // IMAGE THUMBNAIL WITH BADGES & DELETE BUTTON
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16.5)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  padding: const EdgeInsets.all(4),
                  child: (imageUrl != null && imageUrl.isNotEmpty)
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (ctx, err, stack) => Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Center(child: Icon(Icons.broken_image_rounded, color: slateMuted, size: 32)),
                          ),
                        )
                      : Container(
                          color: const Color(0xFFF1F5F9),
                          child: const Center(child: Icon(Icons.inventory_2_outlined, color: slateMuted, size: 36)),
                        ),
                ),
                // Stock Status Badge
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF10B981) : Colors.orange,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isActive ? "IN STOCK" : "OUT OF STOCK",
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                // Discount Badge
                if (discountPercent > 0)
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: sapphireBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "-$discountPercent%",
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // PRODUCT INFO BODY
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(color: sapphireLight, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          category.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: sapphireBlue, fontSize: 8, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        "Size: $size",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: slateMuted, fontSize: 9.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: slateDark, fontSize: 12.5, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text("Rs. ${price.toStringAsFixed(0)}", style: const TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w900)),
                          if (origPrice > price) ...[
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                "Rs. ${origPrice.toStringAsFixed(0)}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: slateMuted, fontSize: 9, decoration: TextDecoration.lineThrough),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        "Qty: $stock",
                        style: const TextStyle(color: slateDark, fontSize: 9.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Divider(height: 1),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Transform.scale(
                      scale: 0.7,
                      child: Switch(
                        value: isActive,
                        activeThumbColor: sapphireBlue,
                        onChanged: (val) => _toggleProductStock(id, isActive),
                      ),
                    ),
                    InkWell(
                      onTap: () => _confirmDeleteProduct(id, name),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 12),
                            SizedBox(width: 2),
                            Text(
                              "Delete",
                              style: TextStyle(color: Color(0xFFEF4444), fontSize: 9.5, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  void _confirmDeleteProduct(String productId, String productName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Product?", style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text("Are you sure you want to delete '$productName'? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteProduct(productId);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory_2_outlined, color: slateMuted, size: 48),
          const SizedBox(height: 12),
          const Text("No Products Found", style: TextStyle(color: slateDark, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text("Click '+ Add Product' to list new items in your store.", style: TextStyle(color: slateMuted, fontSize: 13)),
        ],
      ),
    );
  }
}