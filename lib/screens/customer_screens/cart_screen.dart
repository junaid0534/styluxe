import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> cartItems = [];
  bool isLoading = true;
  double totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    fetchCart();
  }

  // ================= FETCH CART FROM SUPABASE =================
  Future<void> fetchCart() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) throw Exception("Please login first");

      final data = await supabase
          .from('cart')
          .select('*, products(*)')
          .eq('user_id', currentUser.id)
          .order('added_at', ascending: false);

      if (!mounted) return;

      setState(() {
        cartItems = List<Map<String, dynamic>>.from(data);
        calculateTotal();
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Fetch Cart Error: $e");
      if (!mounted) return;
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void calculateTotal() {
    totalAmount = cartItems.fold(0.0, (sum, item) {
      final product = item['products'] ?? {};
      final price = (product['price'] as num?)?.toDouble() ?? 0.0;
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      return sum + (price * qty);
    });
  }

  Future<void> updateQuantity(dynamic cartId, int newQuantity) async {
    if (newQuantity < 1) return;

    try {
      await supabase.from('cart').update({
        'quantity': newQuantity,
      }).eq('id', cartId);

      fetchCart();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> removeFromCart(dynamic cartId) async {
    try {
      await supabase.from('cart').delete().eq('id', cartId);
      fetchCart();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> clearCart() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Clear Cart", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to remove all items from your cart?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: AppColors.slateMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Clear All", style: TextStyle(color: AppColors.roseRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      await supabase.from('cart').delete().eq('user_id', currentUser.id);
      fetchCart();
    } catch (e) {
      debugPrint("Clear Cart Error: $e");
    }
  }

  // ================= BUILD UI =================
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

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
          "My Cart",
          style: TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          if (cartItems.isNotEmpty)
            IconButton(
              tooltip: "Clear Cart",
              icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.roseRed, size: 22),
              onPressed: clearCart,
            ),
          IconButton(
            tooltip: "Refresh Cart",
            icon: const Icon(Icons.refresh_rounded, color: AppColors.slateDark, size: 22),
            onPressed: fetchCart,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : cartItems.isEmpty
              ? _emptyCartView()
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: fetchCart,
                        color: AppColors.primary,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: EdgeInsets.fromLTRB(
                            width >= 760 ? 32 : 16,
                            16,
                            width >= 760 ? 32 : 16,
                            20,
                          ),
                          itemCount: cartItems.length,
                          itemBuilder: (context, index) {
                            final item = cartItems[index];
                            final product = item['products'] ?? {};

                            return CartItemCard(
                              item: item,
                              product: Map<String, dynamic>.from(product),
                              onQuantityChanged: (newQty) {
                                updateQuantity(item['id'], newQty);
                              },
                              onRemove: () {
                                removeFromCart(item['id']);
                              },
                            ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms);
                          },
                        ),
                      ),
                    ),

                    // Bottom Total & Checkout Bar
                    _bottomCheckoutBar(),
                  ],
                ),
      bottomNavigationBar: _buildFullWidthBottomNav(3),
    );
  }

  // ================= FULL WIDTH BOTTOM NAV BAR =================
  Widget _buildFullWidthBottomNav(int activeIndex) {
    return Container(
      height: 64,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
          color: isSelected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
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

  // ================= EMPTY CART VIEW =================
  Widget _emptyCartView() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 76,
                width: 76,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  size: 38,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Your cart is empty",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.slateDark,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Looks like you haven't added anything to your cart yet.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/shop_now');
                  },
                  icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 18),
                  label: const Text(
                    "Start Shopping",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
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
        ),
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  // ================= BOTTOM CHECKOUT BAR =================
  Widget _bottomCheckoutBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total Items",
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                "${cartItems.length} items",
                style: const TextStyle(
                  color: AppColors.slateDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total Amount",
                style: TextStyle(
                  color: AppColors.slateDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                "Rs. ${totalAmount.toStringAsFixed(0)}",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/checkout');
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Proceed to Checkout",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= CART ITEM CARD =================
class CartItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Map<String, dynamic> product;
  final Function(int) onQuantityChanged;
  final VoidCallback onRemove;

  const CartItemCard({
    super.key,
    required this.item,
    required this.product,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final quantity = (item['quantity'] as num?)?.toInt() ?? 1;

    final String name = product['name']?.toString() ?? 'Product';
    String resolvedImageUrl = (product['image_url'] ??
            product['image'] ??
            product['photo_url'] ??
            product['cover_image'])
        ?.toString() ??
        '';

    if (resolvedImageUrl.isEmpty &&
        product['image_urls'] is List &&
        (product['image_urls'] as List).isNotEmpty) {
      resolvedImageUrl = product['image_urls'][0].toString();
    }

    final String imageUrl = resolvedImageUrl.trim();
    final String category = product['category']?.toString() ?? 'General';
    final String size = product['size']?.toString() ?? '';
    final String color = product['color']?.toString() ?? '';
    final double price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final double itemTotal = price * quantity;

    final String formattedPrice = "Rs. ${price.toStringAsFixed(0)}";
    final String formattedTotal = "Rs. ${itemTotal.toStringAsFixed(0)}";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          // ================= PRODUCT IMAGE (Uncropped BoxFit.contain) =================
          Container(
            width: 105,
            height: 115,
            color: const Color(0xFFFAFAFA),
            padding: const EdgeInsets.all(6),
            child: Center(
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain, // Full image view!
                      errorBuilder: (_, __, ___) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),
          ),

          // ================= PRODUCT DETAILS =================
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          height: 28,
                          width: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.roseRed,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Text(
                    [category, color, size]
                        .where((s) => s.trim().isNotEmpty)
                        .join(" • "),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.slateMuted,
                      fontSize: 11,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    formattedPrice,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Quantity Selector
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            _QuantityButton(
                              icon: Icons.remove_rounded,
                              onTap: () => onQuantityChanged(quantity - 1),
                            ),
                            Container(
                              width: 28,
                              alignment: Alignment.center,
                              child: Text(
                                "$quantity",
                                style: const TextStyle(
                                  color: AppColors.slateDark,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            _QuantityButton(
                              icon: Icons.add_rounded,
                              onTap: () => onQuantityChanged(quantity + 1),
                            ),
                          ],
                        ),
                      ),

                      // Item Subtotal
                      Text(
                        formattedTotal,
                        style: const TextStyle(
                          color: AppColors.slateDark,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
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
      child: Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          size: 32,
          color: AppColors.primary.withOpacity(0.60),
        ),
      ),
    );
  }
}

// ================= QUANTITY BUTTON =================
class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QuantityButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 32,
        width: 30,
        child: Icon(icon, size: 16, color: AppColors.slateDark),
      ),
    );
  }
}