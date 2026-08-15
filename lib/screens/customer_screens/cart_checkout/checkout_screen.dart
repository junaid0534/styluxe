import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'order_placed_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> cartItems = [];
  bool isLoading = true;
  double totalAmount = 0.0;

  final customerNameController = TextEditingController();
  final phoneController = TextEditingController();
  final cityController = TextEditingController();
  final addressController = TextEditingController();
  final couponController = TextEditingController();

  String appliedCouponCode = '';
  double discountAmount = 0.0;
  Map<String, dynamic>? activeCoupon;

  String selectedPaymentMethod = "Cash on Delivery";

  final List<String> paymentMethods = [
    "Cash on Delivery",
    "EasyPaisa",
    "JazzCash",
    "Bank Transfer",
  ];

  @override
  void initState() {
    super.initState();
    fetchCart();
  }

  @override
  void dispose() {
    customerNameController.dispose();
    phoneController.dispose();
    cityController.dispose();
    addressController.dispose();
    couponController.dispose();
    super.dispose();
  }

  // ================= FETCH CART =================
  Future<void> fetchCart() async {
    setState(() => isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) throw Exception("User not logged in");

      final data = await supabase
          .from('cart')
          .select('*, products(*)')
          .eq('user_id', currentUser.id);

      if (!mounted) return;

      setState(() {
        cartItems = List<Map<String, dynamic>>.from(data);
        calculateTotal();
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Cart Error: $e");
      if (!mounted) return;

      setState(() {
        cartItems = [];
        totalAmount = 0.0;
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to load cart: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================= CALCULATE TOTAL =================
  void calculateTotal() {
    final double subtotal = cartItems.fold(0.0, (sum, item) {
      final product = item['products'] ?? {};
      final price = (product['price'] as num?)?.toDouble() ?? 0.0;
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;

      return sum + (price * qty);
    });

    if (activeCoupon != null) {
      final discountType = activeCoupon!['discount_type']?.toString() ?? 'percentage';
      final discountVal = (activeCoupon!['discount_value'] as num?)?.toDouble() ?? 0.0;
      final minOrder = (activeCoupon!['min_order_amount'] as num?)?.toDouble() ?? 0.0;
      final targetSellerId = activeCoupon!['seller_id']?.toString();

      if (subtotal >= minOrder) {
        double eligibleAmount = subtotal;

        if (targetSellerId != null && targetSellerId.isNotEmpty) {
          eligibleAmount = 0.0;
          for (final item in cartItems) {
            final product = item['products'] ?? {};
            if (product['seller_id']?.toString() == targetSellerId) {
              final price = (product['price'] as num?)?.toDouble() ?? 0.0;
              final qty = (item['quantity'] as num?)?.toInt() ?? 1;
              eligibleAmount += (price * qty);
            }
          }
        }

        if (discountType == 'percentage') {
          discountAmount = (eligibleAmount * discountVal) / 100.0;
          final maxDiscount = (activeCoupon!['max_discount_amount'] as num?)?.toDouble();
          if (maxDiscount != null && maxDiscount > 0 && discountAmount > maxDiscount) {
            discountAmount = maxDiscount;
          }
        } else if (discountType == 'fixed') {
          discountAmount = discountVal;
        }
      } else {
        discountAmount = 0.0;
      }
    } else {
      discountAmount = 0.0;
    }

    if (discountAmount > subtotal) {
      discountAmount = subtotal;
    }

    totalAmount = subtotal;
  }

  // ================= APPLY COUPON LOGIC =================
  Future<void> applyCoupon(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return;

    try {
      final data = await supabase
          .from('coupons')
          .select('*')
          .eq('code', cleanCode)
          .eq('is_active', true)
          .maybeSingle();

      if (data != null) {
        final minOrder = (data['min_order_amount'] as num?)?.toDouble() ?? 0.0;
        final subtotal = cartItems.fold(0.0, (sum, item) {
          final product = item['products'] ?? {};
          final price = (product['price'] as num?)?.toDouble() ?? 0.0;
          final qty = (item['quantity'] as num?)?.toInt() ?? 1;
          return sum + (price * qty);
        });

        if (subtotal < minOrder) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Order subtotal must be at least Rs. ${minOrder.toStringAsFixed(0)} for this coupon."),
                backgroundColor: AppColors.roseRed,
              ),
            );
          }
          return;
        }

        setState(() {
          activeCoupon = data;
          appliedCouponCode = cleanCode;
          calculateTotal();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Coupon '$cleanCode' applied successfully!"),
              backgroundColor: AppColors.primary,
            ),
          );
        }
        return;
      }
    } catch (_) {}

    final Map<String, Map<String, dynamic>> builtInCoupons = {
      "INDEPENDENCE14": {
        "code": "INDEPENDENCE14",
        "title": "14th August Special",
        "discount_type": "percentage",
        "discount_value": 14.0,
        "min_order_amount": 500.0,
      },
      "SUMMER50": {
        "code": "SUMMER50",
        "title": "Summer Sale",
        "discount_type": "percentage",
        "discount_value": 50.0,
        "max_discount_amount": 1000.0,
        "min_order_amount": 1500.0,
      },
      "FLASHSALE500": {
        "code": "FLASHSALE500",
        "title": "Flash Discount",
        "discount_type": "fixed",
        "discount_value": 500.0,
        "min_order_amount": 2000.0,
      },
      "FREESHIP": {
        "code": "FREESHIP",
        "title": "Free Delivery",
        "discount_type": "fixed",
        "discount_value": 99.0,
        "min_order_amount": 1000.0,
      },
    };

    if (builtInCoupons.containsKey(cleanCode)) {
      final couponData = builtInCoupons[cleanCode]!;
      final minOrder = (couponData['min_order_amount'] as num?)?.toDouble() ?? 0.0;
      final subtotal = cartItems.fold(0.0, (sum, item) {
        final product = item['products'] ?? {};
        final price = (product['price'] as num?)?.toDouble() ?? 0.0;
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        return sum + (price * qty);
      });

      if (subtotal < minOrder) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Order subtotal must be at least Rs. ${minOrder.toStringAsFixed(0)} for this coupon."),
              backgroundColor: AppColors.roseRed,
            ),
          );
        }
        return;
      }

      setState(() {
        activeCoupon = couponData;
        appliedCouponCode = cleanCode;
        calculateTotal();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Coupon '$cleanCode' applied successfully!"),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid or expired coupon code."),
            backgroundColor: AppColors.roseRed,
          ),
        );
      }
    }
  }

  // ================= NOTIFICATION HELPER =================
  Future<void> _sendOrderConfirmedNotification({
    required String userId,
    required String orderCode,
    required double orderAmount,
    required List<Map<String, dynamic>> sellerItems,
  }) async {
    try {
      final itemNames = sellerItems.map((item) {
        final product = item['products'] ?? {};
        return product['name']?.toString() ?? 'Product';
      }).toList();

      final shortItems = itemNames.take(2).join(", ");
      final extraCount = itemNames.length > 2 ? itemNames.length - 2 : 0;

      final itemsText = extraCount > 0
          ? "$shortItems and $extraCount more item(s)"
          : shortItems;

      await supabase.from('notifications').insert({
        'user_id': userId,
        'title': 'Order Confirmed',
        'message':
            'Your order #$orderCode has been confirmed successfully. Status: Pending. Items: $itemsText. Total: Rs. ${orderAmount.toStringAsFixed(0)}.',
        'is_read': false,
      });

      debugPrint("Order confirmed notification inserted for $orderCode");
    } catch (e) {
      debugPrint("Order confirmed notification error: $e");
    }
  }

  // ================= PLACE ORDER =================
  Future<void> placeOrder() async {
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Your cart is empty"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please complete customer details first"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) throw Exception("User not logged in");

      final userId = currentUser.id;
      final baseOrderId = "ORD${DateTime.now().millisecondsSinceEpoch}";

      // Group cart items by seller_id
      final Map<String, List<Map<String, dynamic>>> itemsBySeller = {};

      for (final item in cartItems) {
        final product = item['products'] ?? {};
        final sellerId = product['seller_id']?.toString();

        if (sellerId == null || sellerId.isEmpty) {
          throw Exception(
            "Seller ID missing for product: ${product['name'] ?? 'Unknown Product'}",
          );
        }

        itemsBySeller.putIfAbsent(sellerId, () => []);
        itemsBySeller[sellerId]!.add(item);
      }

      int sellerIndex = 0;

      // Create separate order for each seller
      for (final entry in itemsBySeller.entries) {
        sellerIndex++;
        final sellerId = entry.key;
        final sellerItems = entry.value;

        final double sellerSubtotal = sellerItems.fold(0.0, (sum, item) {
          final product = item['products'] ?? {};
          final price = (product['price'] as num?)?.toDouble() ?? 0.0;
          final qty = (item['quantity'] as num?)?.toInt() ?? 1;
          return sum + (price * qty);
        });

        final double deliveryCharge = sellerIndex == 1 ? 99.0 : 0.0;
        final double orderTotal = sellerSubtotal + deliveryCharge;

        final String orderCode = itemsBySeller.length == 1
            ? baseOrderId
            : "$baseOrderId-S$sellerIndex";

        final orderData = {
          'user_id': userId,
          'order_id': orderCode,
          'seller_id': sellerId,
          'customer_name': customerNameController.text.trim(),
          'total_amount': orderTotal,
          'status': 'Pending',
          'address': addressController.text.trim(),
          'city': cityController.text.trim(),
          'phone': phoneController.text.trim(),
          'payment_method': selectedPaymentMethod,
        };

        final orderResult = await supabase
            .from('orders')
            .insert(orderData)
            .select('id, order_id')
            .single();

        final List<Map<String, dynamic>> orderItemsData = [];

        for (final item in sellerItems) {
          final product = item['products'] ?? {};
          final productId = product['id'];
          final price = (product['price'] as num?)?.toDouble() ?? 0.0;
          final qty = (item['quantity'] as num?)?.toInt() ?? 1;

          if (productId == null) throw Exception("Product ID missing");

          orderItemsData.add({
            'order_id': orderResult['id'],
            'product_id': productId,
            'buyer_id': userId,
            'seller_id': sellerId,
            'quantity': qty,
            'price': price,
          });
        }

        if (orderItemsData.isNotEmpty) {
          await supabase.from('order_items').insert(orderItemsData);
        }

        await _sendOrderConfirmedNotification(
          userId: userId,
          orderCode: orderResult['order_id']?.toString() ?? orderCode,
          orderAmount: orderTotal,
          sellerItems: sellerItems,
        );
      }

      // Clear cart
      await supabase.from('cart').delete().eq('user_id', userId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🎉 Order Placed Successfully!"),
          backgroundColor: AppColors.primary,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrderPlacedScreen(
            orderId: baseOrderId,
            totalAmount: totalAmount + 99,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Place Order Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to place order: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) setState(() => isLoading = false);
  }

  // ================= BUILD UI =================
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 650;

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
          "Checkout",
          style: TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : cartItems.isEmpty
              ? _emptyCartView()
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 16 : 28,
                          vertical: 18,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1050),
                            child: Form(
                              key: _formKey,
                              child: isMobile
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _headerSection(isMobile: true),
                                        const SizedBox(height: 18),
                                        _customerDetailsCard(),
                                        const SizedBox(height: 18),
                                        _orderItemsCard(),
                                        const SizedBox(height: 18),
                                        _promoCouponCard(),
                                        const SizedBox(height: 18),
                                        _orderSummaryCard(),
                                      ],
                                    )
                                  : Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 6,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _headerSection(isMobile: false),
                                              const SizedBox(height: 18),
                                              _customerDetailsCard(),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 22),
                                        Expanded(
                                          flex: 5,
                                          child: Column(
                                            children: [
                                              _orderItemsCard(),
                                              const SizedBox(height: 18),
                                              _promoCouponCard(),
                                              const SizedBox(height: 18),
                                              _orderSummaryCard(),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _bottomPlaceOrderBar(),
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

  // ================= HEADER SECTION =================
  Widget _headerSection({required bool isMobile}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isMobile ? 52 : 64,
            height: isMobile ? 52 : 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Icon(
              Icons.shopping_cart_checkout_rounded,
              color: Colors.white,
              size: isMobile ? 28 : 34,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Complete Your Order",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 20 : 26,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "Add customer details and delivery address before placing order.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: isMobile ? 12.5 : 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= CUSTOMER DETAILS =================
  Widget _customerDetailsCard() {
    return _whiteCard(
      title: "Customer Details",
      icon: Icons.person_outline_rounded,
      child: Column(
        children: [
          TextFormField(
            controller: customerNameController,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              hint: "Enter customer full name",
              icon: Icons.person_outline_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return "Customer name is required";
              if (value.trim().length < 3) return "Enter a valid name";
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              hint: "Enter phone number",
              icon: Icons.phone_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return "Phone number is required";
              if (value.trim().length < 10) return "Enter valid phone number";
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: cityController,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              hint: "Enter city name",
              icon: Icons.location_city_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return "City is required";
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: addressController,
            maxLines: 3,
            decoration: _inputDecoration(
              hint: "Enter complete delivery address",
              icon: Icons.location_on_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return "Address is required";
              if (value.trim().length < 8) return "Enter complete address";
              return null;
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: selectedPaymentMethod,
            decoration: _inputDecoration(
              hint: "Select payment method",
              icon: Icons.payment_outlined,
            ),
            items: paymentMethods.map((method) {
              return DropdownMenuItem(
                value: method,
                child: Text(method, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => selectedPaymentMethod = value);
            },
          ),
        ],
      ),
    );
  }

  // ================= ORDER ITEMS =================
  Widget _orderItemsCard() {
    return _whiteCard(
      title: "Order Items",
      icon: Icons.inventory_2_outlined,
      child: Column(
        children: cartItems.map((item) {
          final product = item['products'] ?? {};
          final price = (product['price'] as num?)?.toDouble() ?? 0.0;
          final qty = (item['quantity'] as num?)?.toInt() ?? 1;

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

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => _placeholder(),
                        )
                      : _placeholder(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name']?.toString() ?? 'Product',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.slateDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Qty: $qty",
                        style: const TextStyle(
                          color: AppColors.slateMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  "Rs. ${(price * qty).toStringAsFixed(0)}",
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(Icons.shopping_bag_outlined, color: AppColors.slateMuted, size: 24),
      ),
    );
  }

  // ================= PROMO COUPON CARD =================
  Widget _promoCouponCard() {
    return _whiteCard(
      title: "Promo Coupon & Voucher",
      icon: Icons.local_offer_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activeCoupon != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Coupon '$appliedCouponCode' Applied!",
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                        Text(
                          "Saved Rs. ${discountAmount.toStringAsFixed(0)} on this order",
                          style: const TextStyle(color: AppColors.slateMuted, fontSize: 11.5, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.roseRed, size: 18),
                    onPressed: () {
                      setState(() {
                        activeCoupon = null;
                        appliedCouponCode = '';
                        discountAmount = 0.0;
                        couponController.clear();
                        calculateTotal();
                      });
                    },
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TextField(
                      controller: couponController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: "Enter Code (e.g. INDEPENDENCE14)",
                        hintStyle: const TextStyle(color: AppColors.slateMuted, fontSize: 12.5),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => applyCoupon(couponController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(80, 48),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Apply", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                ),
              ],
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _showAvailableCouponsSheet(context),
            icon: const Icon(Icons.confirmation_number_outlined, color: AppColors.primary, size: 18),
            label: const Text("View Available Promo Vouchers", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _showAvailableCouponsSheet(BuildContext context) {
    final availableList = [
      {
        "code": "INDEPENDENCE14",
        "title": "14th August Special",
        "desc": "FLAT 14% OFF on All Seller Collections",
        "tag": "FLAT 14% OFF",
      },
      {
        "code": "SUMMER50",
        "title": "Summer Clearance Luxe",
        "desc": "UPTO 50% OFF | Min. Order Rs. 1,500",
        "tag": "UPTO 50% OFF",
      },
      {
        "code": "FLASHSALE500",
        "title": "Flash Voucher",
        "desc": "FLAT Rs. 500 OFF | Min. Order Rs. 2,000",
        "tag": "FLAT Rs. 500 OFF",
      },
      {
        "code": "FREESHIP",
        "title": "Free Delivery Voucher",
        "desc": "Free Shipping Nationwide on Clothes",
        "tag": "FREE SHIPPING",
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              const Text("Available Promo Vouchers", style: TextStyle(color: AppColors.slateDark, fontSize: 18, fontWeight: FontWeight.w900)),
              const Text("Tap 'Apply' to get instant discount on your order", style: TextStyle(color: AppColors.slateMuted, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
              ...availableList.map((item) {
                final String code = item['code']!;
                final bool isAlreadyApplied = appliedCouponCode == code;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isAlreadyApplied ? AppColors.primary.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isAlreadyApplied ? AppColors.primary : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.local_offer_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['title']!, style: const TextStyle(color: AppColors.slateDark, fontWeight: FontWeight.w800, fontSize: 13.5)),
                            const SizedBox(height: 2),
                            Text(item['desc']!, style: const TextStyle(color: AppColors.slateMuted, fontSize: 11.5)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          applyCoupon(code);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAlreadyApplied ? AppColors.slateMuted : AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          isAlreadyApplied ? "Applied" : "Apply",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ================= PAYMENT SUMMARY =================
  Widget _orderSummaryCard() {
    const double deliveryCharge = 99.0;
    final double subtotal = totalAmount;
    final double grandTotal = (subtotal + deliveryCharge) - discountAmount;

    return _whiteCard(
      title: "Payment Summary",
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: [
          _summaryRow(
            title: "Subtotal",
            value: "Rs. ${subtotal.toStringAsFixed(0)}",
          ),
          const SizedBox(height: 10),
          _summaryRow(
            title: "Delivery Charges",
            value: "Rs. ${deliveryCharge.toStringAsFixed(0)}",
          ),
          if (discountAmount > 0) ...[
            const SizedBox(height: 10),
            _summaryRow(
              title: "Promo Discount ($appliedCouponCode)",
              value: "- Rs. ${discountAmount.toStringAsFixed(0)}",
              isDiscount: true,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Color(0xFFE2E8F0)),
          ),
          _summaryRow(
            title: "Total Amount",
            value: "Rs. ${grandTotal < 0 ? 0 : grandTotal.toStringAsFixed(0)}",
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow({
    required String title,
    required String value,
    bool isTotal = false,
    bool isDiscount = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: isDiscount
                  ? AppColors.primary
                  : isTotal
                      ? AppColors.slateDark
                      : AppColors.slateMuted,
              fontSize: isTotal ? 15.5 : 13.5,
              fontWeight: isTotal || isDiscount ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isDiscount
                ? AppColors.primary
                : isTotal
                    ? AppColors.primary
                    : AppColors.slateDark,
            fontSize: isTotal ? 19 : 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // ================= BOTTOM PLACE ORDER BAR =================
  Widget _bottomPlaceOrderBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        12 + MediaQuery.of(context).padding.bottom,
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
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: isLoading ? null : placeOrder,
          icon: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 18),
          label: const Text(
            "PLACE ORDER",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.slateMuted,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  // ================= REUSABLE WHITE CARD =================
  Widget _whiteCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.slateDark,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: AppColors.slateMuted,
        fontWeight: FontWeight.w400,
        fontSize: 13.5,
      ),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.roseRed, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.roseRed, width: 1.5),
      ),
    );
  }

  Widget _emptyCartView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 45),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 64, color: AppColors.slateMuted),
              SizedBox(height: 14),
              Text(
                "Your Cart is Empty",
                style: TextStyle(
                  color: AppColors.slateDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Add products to cart before checkout.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.slateMuted, fontSize: 13.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}