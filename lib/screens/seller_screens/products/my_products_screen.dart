import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'seller_product_detail_screen.dart';
import '../../../widgets/seller_bottom_nav.dart';
import '../../../widgets/seller_shimmer_loading.dart';

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
  bool _isNavVisible = true;

  String selectedCategoryFilter = "All";
  String selectedStockFilter = "All";

  static const Color sapphireBlue = Color(0xFF2563EB);
  static const Color sapphireLight = Color(0xFFEFF6FF);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color cardBorderColor = Color(0xFFE2E8F0);
  static const Color bgColor = Colors.white;

  StreamSubscription? _productsSub;

  @override
  void initState() {
    super.initState();
    fetchMyProducts();
    _subscribeRealtimeProducts();
    searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _productsSub?.cancel();
    searchController.dispose();
    super.dispose();
  }

  void _subscribeRealtimeProducts() {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      _productsSub = supabase
          .from('products')
          .stream(primaryKey: ['id'])
          .eq('seller_id', user.id)
          .listen((_) {
            if (mounted) fetchMyProducts(silent: true);
          });
    } catch (_) {}
  }

  // ================= FETCH MY PRODUCTS =================
  Future<void> fetchMyProducts({bool silent = false}) async {
    if (!silent && mounted) setState(() => isLoading = true);

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
        // Filter out deleted/archived products
        products = List<Map<String, dynamic>>.from(data).where((p) {
          if (p['is_deleted'] == true) return false;
          if (p['status']?.toString().toLowerCase() == 'deleted') return false;
          return true;
        }).toList();
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
    final totalUnitsCount = products.fold<int>(0, (sum, p) => sum + ((p['stock'] as num?)?.toInt() ?? 0));
    final inStockCount = products.where((p) => ((p['is_active'] as bool?) ?? true) && ((p['stock'] as num?)?.toInt() ?? 0) > 0).length;
    final outOfStockCount = totalCount - inStockCount;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        toolbarHeight: 42.0,
        centerTitle: true,
        title: const Text(
          "Products",
          style: TextStyle(
            color: slateDark,
            fontSize: 17.5,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          InkWell(
            onTap: () async {
              final res = await Navigator.pushNamed(context, '/add_product');
              if (res == true) fetchMyProducts();
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: sapphireBlue,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: sapphireBlue.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(0.92, 0.92), end: const Offset(1.08, 1.08), duration: 1200.ms, curve: Curves.easeInOut),
          const SizedBox(width: 14),
        ],
      ),
      body: isLoading
          ? const SellerProductsShimmer()
          : NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is UserScrollNotification) {
                  if (notification.direction == ScrollDirection.reverse) {
                    if (_isNavVisible) setState(() => _isNavVisible = false);
                  } else if (notification.direction == ScrollDirection.forward) {
                    if (!_isNavVisible) setState(() => _isNavVisible = true);
                  }
                } else if (notification is ScrollEndNotification) {
                  if (!_isNavVisible) setState(() => _isNavVisible = true);
                }
                return false;
              },
              child: RefreshIndicator(
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

                              // ================= 1. ROYAL SAPPHIRE 3-METRIC KPI ROW =================
                              _buildMetricsSummaryRow(totalCount, totalUnitsCount, outOfStockCount),

                              const SizedBox(height: 12),

                              // ================= 2. ULTRA-CLEAN SINGLE SEARCH BAR =================
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: TextField(
                                  controller: searchController,
                                  onChanged: (_) => setState(() {}),
                                  style: const TextStyle(fontSize: 13, color: slateDark, fontWeight: FontWeight.w600),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: const Color(0xFFF1F5F9),
                                    isDense: true,
                                    hintText: "Search products by name or category...",
                                    hintStyle: const TextStyle(color: slateMuted, fontSize: 12.5),
                                    prefixIcon: const Icon(Icons.search_rounded, color: slateMuted, size: 20),
                                    suffixIcon: searchController.text.isNotEmpty
                                        ? InkWell(
                                            onTap: () {
                                              searchController.clear();
                                              setState(() {});
                                            },
                                            child: const Icon(Icons.clear_rounded, color: slateMuted, size: 18),
                                          )
                                        : null,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: sapphireBlue, width: 1.5),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),

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
                              double childAspectRatio = 0.56;

                              if (width >= 1000) {
                                crossAxisCount = 4;
                                childAspectRatio = 0.68;
                              } else if (width >= 700) {
                                crossAxisCount = 3;
                                childAspectRatio = 0.62;
                              } else if (width < 360) {
                                crossAxisCount = 2;
                                childAspectRatio = 0.52;
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
            ),
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: _isNavVisible ? (58.0 + MediaQuery.of(context).padding.bottom) : 0.0,
        child: Wrap(
          children: [
            AnimatedSlide(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              offset: _isNavVisible ? Offset.zero : const Offset(0, 1.0),
              child: const SellerBottomNav(currentIndex: 2),
            ),
          ],
        ),
      ),
    );
  }

  // ================= 1. ROYAL SAPPHIRE 3-METRIC KPI ROW =================
  Widget _buildMetricsSummaryRow(int total, int inStockUnits, int outStock) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _modernKpiCard(
            label: "Total Items",
            value: "$total",
            icon: Icons.inventory_2_outlined,
            iconColor: Colors.white,
            iconBg: Colors.white.withValues(alpha: 0.18),
          ),
          const SizedBox(width: 8),
          _modernKpiCard(
            label: "In Stock Units",
            value: "$inStockUnits",
            icon: Icons.check_circle_rounded,
            iconColor: const Color(0xFF34D399),
            iconBg: Colors.white.withValues(alpha: 0.18),
          ),
          const SizedBox(width: 8),
          _modernKpiCard(
            label: "Out of Stock",
            value: "$outStock",
            icon: Icons.remove_circle_rounded,
            iconColor: const Color(0xFFFCA5A5),
            iconBg: Colors.white.withValues(alpha: 0.18),
          ),
        ],
      ),
    );
  }

  Widget _modernKpiCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(4.5),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 14),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFDBEAFE),
                fontSize: 10,
                fontWeight: FontWeight.w600,
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorderColor, width: 1.2),
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
          // IMAGE THUMBNAIL WITH BADGES
          Expanded(
            child: InkWell(
              onTap: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => SellerProductDetailScreen(product: item),
                  ),
                );
                if (updated == true && mounted) fetchMyProducts();
              },
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
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
                    padding: const EdgeInsets.all(6),
                    child: (imageUrl != null && imageUrl.isNotEmpty)
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (ctx, err, stack) => Container(
                              color: const Color(0xFFF1F5F9),
                              child: const Center(child: Icon(Icons.broken_image_rounded, color: slateMuted, size: 28)),
                            ),
                          )
                        : Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Center(child: Icon(Icons.inventory_2_outlined, color: slateMuted, size: 32)),
                          ),
                  ),
                  // Stock Status Pill (Top-Left)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: (!isActive || stock <= 0)
                            ? const Color(0xFFEF4444)
                            : (stock <= 5 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 4.5,
                            height: 4.5,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (!isActive || stock <= 0)
                                ? "OUT OF STOCK"
                                : (stock <= 5 ? "LOW: $stock" : "IN STOCK: $stock"),
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Discount Badge (Bottom-Left)
                  if (discountPercent > 0)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: sapphireBlue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "-$discountPercent%",
                          style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // PRODUCT INFO BODY
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category & Size Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(color: sapphireLight, borderRadius: BorderRadius.circular(5)),
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
                // Title
                InkWell(
                  onTap: () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => SellerProductDetailScreen(product: item),
                      ),
                    );
                    if (updated == true && mounted) fetchMyProducts();
                  },
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: slateDark, fontSize: 12.5, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 3),
                // Price & Quantity
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text("Rs. ${price.toStringAsFixed(0)}", style: const TextStyle(color: sapphireBlue, fontSize: 13, fontWeight: FontWeight.w900)),
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
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        "Qty: $stock",
                        style: const TextStyle(color: slateDark, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 6),

                // ================= BOTTOM 1-TAP STATUS TOGGLE =================
                InkWell(
                  onTap: () => _toggleProductStock(id, isActive),
                  borderRadius: BorderRadius.circular(9),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: isActive ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isActive ? const Color(0xFF10B981) : slateMuted,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isActive ? "Active (Listed)" : "Inactive (Off)",
                              style: TextStyle(
                                color: isActive ? const Color(0xFF047857) : slateMuted,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          isActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                          color: isActive ? const Color(0xFF10B981) : slateMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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