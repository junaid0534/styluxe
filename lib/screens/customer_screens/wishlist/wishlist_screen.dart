import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';

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

  @override
  void dispose() {
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.slateDark, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "My Wishlist",
          style: TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.slateDark,
              size: 22,
            ),
            onPressed: fetchWishlist,
          ),
          const SizedBox(width: 6),
        ],
      ),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : wishlistItems.isEmpty
              ? _emptyWishlistView()
              : RefreshIndicator(
                  onRefresh: fetchWishlist,
                  color: AppColors.primary,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      _summaryCard()
                          .animate()
                          .fadeIn(duration: 350.ms)
                          .slideY(begin: 0.08, end: 0),

                      const SizedBox(height: 20),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Saved Items",
                          style: TextStyle(
                            color: AppColors.slateDark,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      ...wishlistItems.map((wishlist) {
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
                              duration: 350.ms,
                              delay: (wishlistItems.indexOf(wishlist) * 70).ms,
                            )
                            .slideY(
                              begin: 0.08,
                              end: 0,
                              duration: 350.ms,
                              curve: Curves.easeOutCubic,
                            );
                      }),
                    ],
                  ),
                ),
      bottomNavigationBar: _buildFullWidthBottomNav(2),
    );
  }

  // ================= FULL WIDTH BOTTOM NAV BAR =================
  Widget _buildFullWidthBottomNav(int activeIndex) {
    return Container(
      height: 64,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppColors.primary : AppColors.slateMuted,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.40),
                  ),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Your Wishlist",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${wishlistItems.length} saved item${wishlistItems.length == 1 ? '' : 's'}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyWishlistView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 46,
          ),
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
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 86,
                width: 86,
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
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          // ================= IMAGE CONTAINER =================
          Container(
            width: 110,
            height: 135,
            color: const Color(0xFFF8FAFC),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            errorBuilder: (_, _, _) => _imagePlaceholder(),
                          )
                        : _imagePlaceholder(),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: canAddToCart
                          ? AppColors.primary
                          : const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      canAddToCart ? "IN STOCK" : "UNAVAILABLE",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
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
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                            color: AppColors.slateDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: onRemove,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 32,
                          width: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFEF4444),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

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
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Strictly PKR Price Format
                  Text(
                    "Rs. ${price.toStringAsFixed(0)}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: canAddToCart ? onAddToCart : null,
                      icon: const Icon(
                        Icons.shopping_cart_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                      label: Text(
                        canAddToCart ? "Add to Cart" : "Unavailable",
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: const Color(0xFFCBD5E1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
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
          size: 30,
        ),
      ),
    );
  }
}