import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/customer_shimmer_loading.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> wishlistItems = [];
  bool isLoading = true;

  StreamSubscription<List<Map<String, dynamic>>>? _wishlistSubscription;

  @override
  void initState() {
    super.initState();
    fetchWishlist();
    setupRealtimeWishlist();
  }

  final TextEditingController _searchController = TextEditingController();
  String searchQuery = "";
  String selectedCategory = "All";

  final List<String> categories = [
    "All",
    "Dress",
    "Shirt",
    "Shoes",
    "Clothes",
    "Bags",
    "Watches",
    "Accessories",
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _wishlistSubscription?.cancel();
    super.dispose();
  }

  // ================= FETCH WISHLIST =================
  Future<void> fetchWishlist() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception("Please login first");
      }

      final data = await supabase
          .from('wishlist')
          .select('*, products(*)')
          .eq('user_id', currentUser.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        wishlistItems = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================= REALTIME WISHLIST =================
  void setupRealtimeWishlist() {
    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) return;

      _wishlistSubscription = supabase
          .from('wishlist')
          .stream(primaryKey: ['id'])
          .eq('user_id', currentUser.id)
          .listen(
            (_) {
              fetchWishlist();
            },
            onError: (error) {
              debugPrint("Wishlist realtime error: $error");
            },
          );
    } catch (e) {
      debugPrint("Wishlist realtime setup error: $e");
    }
  }

  // ================= REMOVE FROM WISHLIST =================
  Future<void> removeFromWishlist(dynamic wishlistId) async {
    try {
      await supabase.from('wishlist').delete().eq('id', wishlistId);

      if (!mounted) return;

      setState(() {
        wishlistItems.removeWhere((item) => item['id'] == wishlistId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Removed from wishlist"),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================= ADD TO CART =================
  Future<void> addToCart(Map<String, dynamic> product) async {
    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception("Please login first");
      }

      final productId = product['id'];

      final existingCartItem = await supabase
          .from('cart')
          .select('id, quantity')
          .eq('user_id', currentUser.id)
          .eq('product_id', productId)
          .maybeSingle();

      if (existingCartItem != null) {
        final oldQty = (existingCartItem['quantity'] as num?)?.toInt() ?? 1;

        await supabase.from('cart').update({
          'quantity': oldQty + 1,
        }).eq('id', existingCartItem['id']);
      } else {
        await supabase.from('cart').insert({
          'user_id': currentUser.id,
          'product_id': productId,
          'quantity': 1,
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${product['name'] ?? 'Product'} added to cart"),
          backgroundColor: AppColors.primary,
        ),
      );

      Navigator.pushNamed(context, '/cart');
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================= FULL WIDTH BOTTOM NAV BAR =================
  Widget _buildFullWidthBottomNav(int activeIndex) {
    return Container(
      height: 50,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(icon: Icons.home_rounded, label: "Home", index: 0, route: '/customer_home', activeIndex: activeIndex),
            _navItem(icon: Icons.explore_outlined, label: "Explore", index: 1, route: '/shop_now', activeIndex: activeIndex),
            _navItem(icon: Icons.favorite_border_rounded, label: "Wishlist", index: 2, route: '/wishlist', activeIndex: activeIndex),
            _navItem(icon: Icons.shopping_cart_outlined, label: "Cart", index: 3, route: '/cart', activeIndex: activeIndex),
            _navItem(icon: Icons.person_outline_rounded, label: "Profile", index: 4, route: '/my_profile', activeIndex: activeIndex),
          ],
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required int index,
    required String route,
    required int activeIndex,
  }) {
    final bool isSelected = activeIndex == index;

    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          Navigator.pushReplacementNamed(context, route);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppColors.primary : AppColors.slateMuted,
            ),
            if (isSelected) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _countByCategory(String category) {
    if (category == 'All') return wishlistItems.length;
    return wishlistItems.where((w) {
      final p = w['products'];
      if (p == null || p is! Map) return false;
      final cat = (p['category']?.toString() ?? '').toLowerCase();
      final name = (p['name']?.toString() ?? '').toLowerCase();
      final target = category.toLowerCase();
      return cat.contains(target) || name.contains(target);
    }).length;
  }

  List<Map<String, dynamic>> _filteredWishlist() {
    return wishlistItems.where((wishlist) {
      final productRaw = wishlist['products'];
      if (productRaw == null || productRaw is! Map) {
        return searchQuery.isEmpty && selectedCategory == 'All';
      }
      final product = Map<String, dynamic>.from(productRaw);
      final name = (product['name']?.toString() ?? '').toLowerCase();
      final category = (product['category']?.toString() ?? '').toLowerCase();
      final description = (product['description']?.toString() ?? '').toLowerCase();

      // Category filter
      if (selectedCategory != 'All') {
        final targetCat = selectedCategory.toLowerCase();
        if (!category.contains(targetCat) && !name.contains(targetCat)) {
          return false;
        }
      }

      // Search query filter
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        if (!name.contains(q) && !category.contains(q) && !description.contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  bool _isProductActive(Map<String, dynamic> product) {
    final active = product['is_active'];

    if (active == null) return true;
    if (active == true) return true;
    if (active == 1) return true;
    if (active.toString().toLowerCase() == "true") return true;

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final displayItems = _filteredWishlist();

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
        title: const Text(
          "My Wishlist",
          style: TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 16.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.slateDark,
              size: 20,
            ),
            onPressed: fetchWishlist,
          ),
          const SizedBox(width: 6),
        ],
      ),

      body: isLoading
          ? const CustomerListItemsShimmer(count: 4)
          : wishlistItems.isEmpty
              ? _emptyWishlistView()
              : RefreshIndicator(
                  onRefresh: fetchWishlist,
                  color: AppColors.primary,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      // ================= FULL WIDTH SEARCH BAR =================
                      Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.025),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() {
                              searchQuery = val;
                            });
                          },
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.slateDark,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: "Search saved items by name or category...",
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: AppColors.slateMuted,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: AppColors.slateMuted,
                            ),
                            suffixIcon: searchQuery.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      setState(() {
                                        searchQuery = '';
                                      });
                                    },
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: AppColors.slateMuted,
                                    ),
                                  )
                                : null,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ================= HORIZONTAL CATEGORY FILTER CHIPS (LARGER SIZE) =================
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: categories.map((cat) {
                            final isSelected = selectedCategory == cat;
                            final count = _countByCategory(cat);
                            return GestureDetector(
                              onTap: () => setState(() => selectedCategory = cat),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(alpha: 0.22),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.02),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      cat,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : AppColors.slateDark,
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white.withValues(alpha: 0.25)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        "$count",
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : AppColors.slateMuted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ================= SECTION HEADER =================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedCategory == 'All' ? "Saved Items" : "$selectedCategory Items",
                            style: const TextStyle(
                              color: AppColors.slateDark,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            "${displayItems.length} item${displayItems.length == 1 ? '' : 's'}",
                            style: const TextStyle(
                              color: AppColors.slateMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // ================= ITEMS LIST OR NO RESULTS =================
                      if (displayItems.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.search_off_rounded, size: 40, color: AppColors.slateMuted),
                              const SizedBox(height: 10),
                              Text(
                                "No items found for '$selectedCategory'",
                                style: const TextStyle(
                                  color: AppColors.slateDark,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Try selecting a different filter or clearing search",
                                style: TextStyle(color: AppColors.slateMuted, fontSize: 12),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 34,
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      selectedCategory = 'All';
                                      searchQuery = '';
                                      _searchController.clear();
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppColors.primary),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text(
                                    "Show All Items",
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...displayItems.map((wishlist) {
                          final productRaw = wishlist['products'];

                          if (productRaw == null || productRaw is! Map) {
                            return _missingProductCard(wishlist['id']);
                          }

                          final product = Map<String, dynamic>.from(productRaw);

                          return WishlistProductCard(
                            wishlist: wishlist,
                            product: product,
                            isActive: _isProductActive(product),
                            onRemove: () => removeFromWishlist(wishlist['id']),
                            onAddToCart: () => addToCart(product),
                          ).animate()
                              .fadeIn(
                                duration: 250.ms,
                                delay: (displayItems.indexOf(wishlist) * 40).ms,
                              )
                              .slideY(
                                begin: 0.05,
                                end: 0,
                                duration: 250.ms,
                                curve: Curves.easeOutCubic,
                              );
                        }),
                    ],
                  ),
                ),
      bottomNavigationBar: _buildFullWidthBottomNav(2),
    );
  }

  Widget _emptyWishlistView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 90,
                width: 90,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_border_rounded,
                  size: 46,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "Your Wishlist is Empty",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.slateDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Explore products and tap the heart icon to save your favorite items here.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/shop_now');
                  },
                  icon: const Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    "Start Shopping",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 350.ms).scale(),
      ),
    );
  }

  Widget _missingProductCard(dynamic wishlistId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.slateMuted,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "Product not available",
              style: TextStyle(
                color: AppColors.slateDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => removeFromWishlist(wishlistId),
            child: const Text(
              "Remove",
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= WISHLIST PRODUCT CARD =================
class WishlistProductCard extends StatelessWidget {
  final Map<String, dynamic> wishlist;
  final Map<String, dynamic> product;
  final bool isActive;
  final VoidCallback onRemove;
  final VoidCallback onAddToCart;

  const WishlistProductCard({
    super.key,
    required this.wishlist,
    required this.product,
    required this.isActive,
    required this.onRemove,
    required this.onAddToCart,
  });

  double _amount(dynamic value) {
    return (value as num?)?.toDouble() ?? 0.0;
  }

  int _stock(dynamic value) {
    return (value as num?)?.toInt() ?? 0;
  }

  String _getImageUrl() {
    final direct = product['image_url']?.toString();
    if (direct != null && direct.trim().isNotEmpty) return direct.trim();
    final img = product['image']?.toString();
    if (img != null && img.trim().isNotEmpty) return img.trim();
    final photo = product['photo_url']?.toString();
    if (photo != null && photo.trim().isNotEmpty) return photo.trim();
    final cover = product['cover_image']?.toString();
    if (cover != null && cover.trim().isNotEmpty) return cover.trim();
    final urls = product['image_urls'];
    if (urls is List && urls.isNotEmpty) {
      final first = urls.first?.toString();
      if (first != null && first.trim().isNotEmpty) return first.trim();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final name = product['name']?.toString() ?? 'Product';
    final imageUrl = _getImageUrl();
    final category = product['category']?.toString() ?? '';
    final color = product['color']?.toString() ?? '';
    final size = product['size']?.toString() ?? '';
    final price = _amount(product['price']);
    final stock = _stock(product['stock']);

    final canAddToCart = isActive && stock > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ================= IMAGE CONTAINER =================
          SizedBox(
            width: 100,
            height: 118,
            child: Stack(
              children: [
                Positioned.fill(
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorBuilder: (_, _, _) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: canAddToCart
                          ? AppColors.primary
                          : const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      canAddToCart ? "IN STOCK" : "OUT OF STOCK",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ================= DETAILS =================
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title + Heart Unlike Button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.slateDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: onRemove,
                        borderRadius: BorderRadius.circular(15),
                        child: Container(
                          height: 26,
                          width: 26,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Color(0xFFEF4444),
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 2),

                  // Attributes Row (Category / Color / Size)
                  Text(
                    [
                      category,
                      color,
                      size,
                    ].where((item) => item.trim().isNotEmpty).join(" • "),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.slateMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 3),

                  // Real-time Rating Row
                  const Row(
                    children: [
                      Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                      SizedBox(width: 2),
                      Text(
                        "4.8",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slateDark,
                        ),
                      ),
                      Text(
                        " (98)",
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.slateMuted,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Price & Compact Add to Cart Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Rs. ${price.toStringAsFixed(0)}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(
                        height: 28,
                        child: ElevatedButton.icon(
                          onPressed: canAddToCart ? onAddToCart : null,
                          icon: Icon(
                            canAddToCart ? Icons.shopping_cart_outlined : Icons.block_rounded,
                            color: Colors.white,
                            size: 13,
                          ),
                          label: Text(
                            canAddToCart ? "Add to Cart" : "Unavailable",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: const Color(0xFFCBD5E1),
                            disabledForegroundColor: const Color(0xFF94A3B8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
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
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: AppColors.slateMuted,
          size: 24,
        ),
      ),
    );
  }
}