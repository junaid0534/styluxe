import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/inventory_service.dart';
import '../../../services/realtime_notification_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/customer_shimmer_loading.dart';
import 'order_placed_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // 0: Address, 1: Payment & Voucher, 2: Review & Confirm
  int currentStep = 0;

  List<Map<String, dynamic>> cartItems = [];
  bool isLoading = true;
  double totalAmount = 0.0;

  // Address state
  List<Map<String, dynamic>> savedAddresses = [];
  Map<String, dynamic>? selectedAddress;
  bool isManualAddressMode = false;
  bool saveAddressToProfile = true;
  bool isLoadingAddresses = true;
  bool isReviewItemsExpanded = false;

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

  bool _isInit = true;

  @override
  void initState() {
    super.initState();
    fetchCart();
    fetchUserAddresses();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        if (args['appliedCoupon'] != null) {
          activeCoupon = Map<String, dynamic>.from(args['appliedCoupon']);
        }
        if (args['appliedCouponCode'] != null) {
          final codeStr = args['appliedCouponCode'].toString();
          appliedCouponCode = codeStr;
          couponController.text = codeStr;
        }
        calculateTotal();
      }
      _isInit = false;
    }
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

  // ================= FETCH USER SAVED ADDRESSES =================
  Future<void> fetchUserAddresses() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      final data = await supabase
          .from('shipping_addresses')
          .select('*')
          .eq('user_id', currentUser.id)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);

      final fetched = List<Map<String, dynamic>>.from(data);

      if (!mounted) return;

      setState(() {
        savedAddresses = fetched;
        isLoadingAddresses = false;
      });

      if (fetched.isNotEmpty) {
        if (selectedAddress == null && !isManualAddressMode) {
          final defaultAddr = fetched.firstWhere(
            (a) => a['is_default'] == true,
            orElse: () => fetched.first,
          );
          _applyAddress(defaultAddr);
        }
      } else {
        if (!isManualAddressMode && selectedAddress == null) {
          final userMeta = currentUser.userMetadata ?? {};
          if (customerNameController.text.isEmpty) {
            customerNameController.text = userMeta['name']?.toString() ?? '';
          }
          if (phoneController.text.isEmpty) {
            phoneController.text = userMeta['phone']?.toString() ?? '';
          }
          if (cityController.text.isEmpty) {
            cityController.text = userMeta['city']?.toString() ?? '';
          }
          setState(() {
            isManualAddressMode = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Fetch addresses error: $e");
      if (!mounted) return;
      setState(() {
        isLoadingAddresses = false;
        isManualAddressMode = true;
      });
    }
  }

  void _applyAddress(Map<String, dynamic> addr) {
    setState(() {
      selectedAddress = addr;
      isManualAddressMode = false;
      customerNameController.text = addr['full_name']?.toString() ?? '';
      phoneController.text = addr['phone']?.toString() ?? '';
      cityController.text = addr['city']?.toString() ?? '';
      addressController.text = addr['address']?.toString() ?? '';
    });
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
          activeCoupon = Map<String, dynamic>.from(data);
          appliedCouponCode = cleanCode;
          couponController.text = cleanCode;
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
    } catch (e) {
      debugPrint("DB Coupon Error: $e");
    }

    // Built-in backup promo codes
    final staticPromos = {
      'STYLUXE20': {'discount_type': 'percentage', 'discount_value': 20.0, 'min_order_amount': 0.0, 'title': 'Welcome 20% OFF'},
      'SUMMER50': {'discount_type': 'percentage', 'discount_value': 50.0, 'min_order_amount': 1500.0, 'title': 'Summer Clearance Luxe'},
      'FLASHSALE500': {'discount_type': 'fixed', 'discount_value': 500.0, 'min_order_amount': 2000.0, 'title': 'Flash Voucher 500'},
      'FREESHIP': {'discount_type': 'fixed', 'discount_value': 99.0, 'min_order_amount': 0.0, 'title': 'Free Shipping Voucher'},
      'INDEPENDENCE14': {'discount_type': 'percentage', 'discount_value': 14.0, 'min_order_amount': 0.0, 'title': '14th August Special'},
    };

    if (staticPromos.containsKey(cleanCode)) {
      final promo = staticPromos[cleanCode]!;
      final minOrder = promo['min_order_amount'] as double;
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
              content: Text("Minimum spend for $cleanCode is Rs. ${minOrder.toStringAsFixed(0)}"),
              backgroundColor: AppColors.roseRed,
            ),
          );
        }
        return;
      }

      setState(() {
        activeCoupon = {
          'code': cleanCode,
          'title': promo['title'],
          'discount_type': promo['discount_type'],
          'discount_value': promo['discount_value'],
          'min_order_amount': promo['min_order_amount'],
        };
        appliedCouponCode = cleanCode;
        couponController.text = cleanCode;
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

  void removeCoupon() {
    setState(() {
      activeCoupon = null;
      appliedCouponCode = '';
      couponController.clear();
      discountAmount = 0.0;
      calculateTotal();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Coupon removed"),
        backgroundColor: AppColors.slateMuted,
      ),
    );
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

      final finalOrderCode = orderCode.isNotEmpty ? orderCode : 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      await RealtimeNotificationService.sendNotification(
        userId: userId,
        title: '🎉 Order Confirmed!',
        message: 'Your order #$finalOrderCode has been confirmed successfully. Total: Rs. ${orderAmount.toStringAsFixed(0)} ($itemsText).',
        type: 'order',
        additionalData: {'order_code': finalOrderCode},
      );

      debugPrint("Order confirmed notification sent for $finalOrderCode");
    } catch (e) {
      debugPrint("Order confirmed notification error: $e");
    }
  }

  // ================= STEP NAVIGATION HANDLERS =================
  void _validateAndProceedToPayment() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please complete all required delivery details"),
          backgroundColor: AppColors.roseRed,
        ),
      );
      return;
    }
    setState(() => currentStep = 1);
  }

  void _proceedToReview() {
    if (selectedPaymentMethod.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a payment method"),
          backgroundColor: AppColors.roseRed,
        ),
      );
      return;
    }
    setState(() => currentStep = 2);
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
      setState(() => currentStep = 0);
      return;
    }

    setState(() => isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) throw Exception("User not logged in");

      final userId = currentUser.id;
      final baseOrderId = "ORD${DateTime.now().millisecondsSinceEpoch}";

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
          final selSize = item['selected_size']?.toString() ?? product['size']?.toString();
          final selColor = item['selected_color']?.toString() ?? product['color']?.toString();

          if (productId == null) throw Exception("Product ID missing");

          orderItemsData.add({
            'order_id': orderResult['id'],
            'product_id': productId,
            'buyer_id': userId,
            'seller_id': sellerId,
            'quantity': qty,
            'price': price,
            if (selSize != null && selSize.isNotEmpty) 'selected_size': selSize,
            if (selColor != null && selColor.isNotEmpty) 'selected_color': selColor,
          });
        }

        if (orderItemsData.isNotEmpty) {
          try {
            await supabase.from('order_items').insert(orderItemsData);
          } catch (insertErr) {
            final pruned = orderItemsData.map((m) => {
              'order_id': m['order_id'],
              'product_id': m['product_id'],
              'buyer_id': m['buyer_id'],
              'seller_id': m['seller_id'],
              'quantity': m['quantity'],
              'price': m['price'],
            }).toList();
            await supabase.from('order_items').insert(pruned);
          }
          // Reverse-count / deduct product stock for each item ordered
          await InventoryService.deductStockForOrderItems(orderItemsData);
        }

        await _sendOrderConfirmedNotification(
          userId: userId,
          orderCode: orderResult['order_id']?.toString() ?? orderCode,
          orderAmount: orderTotal,
          sellerItems: sellerItems,
        );

        // Send Realtime Push Notification to Seller
        if (sellerId.toString().isNotEmpty) {
          final custName = customerNameController.text.trim();
          final displayCust = custName.isNotEmpty ? custName : 'A customer';
          final placedOrderCode = orderResult['order_id']?.toString() ?? orderCode;

          await RealtimeNotificationService.sendNotification(
            userId: sellerId.toString(),
            title: '🛍️ New Order Received!',
            message: 'Order #$placedOrderCode received from $displayCust for Rs. ${orderTotal.toStringAsFixed(0)}.',
            type: 'new_order',
            additionalData: {'order_id': orderResult['id'], 'order_code': placedOrderCode},
          );
        }
      }

      if (isManualAddressMode && saveAddressToProfile) {
        try {
          await supabase.from('shipping_addresses').insert({
            'user_id': userId,
            'full_name': customerNameController.text.trim(),
            'phone': phoneController.text.trim(),
            'city': cityController.text.trim(),
            'address': addressController.text.trim(),
            'is_default': savedAddresses.isEmpty,
          });
        } catch (e) {
          debugPrint("Failed to auto-save address: $e");
        }
      }

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
            totalAmount: (totalAmount + 99.0) - discountAmount,
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
        toolbarHeight: 46.0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.slateDark, size: 21),
          onPressed: () {
            if (currentStep > 0) {
              setState(() => currentStep--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          "Checkout",
          style: TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 16.5,
          ),
        ),
      ),
      body: isLoading
          ? const CustomerProductDetailShimmer()
          : cartItems.isEmpty
              ? _emptyCartView()
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 28,
                    vertical: 14,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 850),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Step Indicator Stepper
                            _buildStepIndicator(),
                            const SizedBox(height: 12),

                            // 2. Step Views
                            if (currentStep == 0) ...[
                              _deliveryAddressCard(),
                            ] else if (currentStep == 1) ...[
                              _paymentMethodCard(),
                              const SizedBox(height: 12),
                              _promoCouponCard(),
                            ] else if (currentStep == 2) ...[
                              _reviewAddressCard(),
                              const SizedBox(height: 12),
                              _reviewPaymentAndVoucherCard(),
                              const SizedBox(height: 12),
                              _orderItemsCard(),
                              const SizedBox(height: 12),
                              _orderSummaryCard(),
                            ],

                            // 3. Action Buttons at the end of scrollable content
                            const SizedBox(height: 16),
                            _stepActionButtons(),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
      bottomNavigationBar: _buildFullWidthBottomNav(3),
    );
  }

  // ================= STEP INDICATOR STEPPER =================
  Widget _buildStepIndicator() {
    final List<Map<String, dynamic>> steps = [
      {"index": 0, "title": "Address", "icon": Icons.location_on_rounded},
      {"index": 1, "title": "Payment", "icon": Icons.payment_rounded},
      {"index": 2, "title": "Review", "icon": Icons.receipt_long_rounded},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final stepBefore = i ~/ 2;
            final isCompleted = currentStep > stepBefore;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.primary : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }

          final stepIndex = i ~/ 2;
          final step = steps[stepIndex];
          final bool isCurrent = currentStep == stepIndex;
          final bool isDone = currentStep > stepIndex;

          return InkWell(
            onTap: () {
              if (stepIndex < currentStep) {
                setState(() => currentStep = stepIndex);
              } else if (stepIndex == 1 && currentStep == 0) {
                _validateAndProceedToPayment();
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isDone || isCurrent ? AppColors.primary : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 1.5),
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                        : Text(
                            "${stepIndex + 1}",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isCurrent ? Colors.white : AppColors.slateMuted,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  step['title'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isCurrent ? FontWeight.w800 : (isDone ? FontWeight.w700 : FontWeight.w500),
                    color: isCurrent ? AppColors.primary : (isDone ? AppColors.slateDark : AppColors.slateMuted),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ================= FULL WIDTH BOTTOM NAV BAR =================
  Widget _buildFullWidthBottomNav(int activeIndex) {
    return Container(
      height: 50,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
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

  // ================= STEP 1: DELIVERY ADDRESS CARD =================
  Widget _deliveryAddressCard() {
    return _whiteCard(
      title: "Delivery Address",
      icon: Icons.location_on_outlined,
      trailing: savedAddresses.isNotEmpty
          ? TextButton.icon(
              onPressed: () async {
                await Navigator.pushNamed(context, '/shipping_addresses');
                fetchUserAddresses();
              },
              icon: const Icon(Icons.tune_rounded, size: 14, color: AppColors.primary),
              label: const Text("Manage", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Saved Addresses Horizontal Switcher
          if (savedAddresses.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Saved Addresses",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slateDark,
                  ),
                ),
                Text(
                  "${savedAddresses.length} saved",
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.slateMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 94,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: savedAddresses.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  // Last item is "+ Enter Manual Address" button
                  if (index == savedAddresses.length) {
                    final bool isSelected = isManualAddressMode;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          isManualAddressMode = true;
                          selectedAddress = null;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 118,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.4 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Icon(
                                Icons.add_location_alt_outlined,
                                size: 14,
                                color: isSelected ? Colors.white : AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "Manual Entry",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? AppColors.primary : AppColors.slateDark,
                              ),
                            ),
                            const Text(
                              "Type address",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9.5,
                                color: AppColors.slateMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final addr = savedAddresses[index];
                  final bool isSelected = !isManualAddressMode && selectedAddress?['id'] == addr['id'];

                  return InkWell(
                    onTap: () => _applyAddress(addr),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 185,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.4 : 1,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isSelected ? Icons.check_circle_rounded : Icons.location_on_outlined,
                                size: 13,
                                color: isSelected ? AppColors.primary : AppColors.slateMuted,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  addr['full_name']?.toString() ?? 'Saved Address',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? AppColors.primary : AppColors.slateDark,
                                  ),
                                ),
                              ),
                              if (addr['is_default'] == true)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    "DEFAULT",
                                    style: TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.w800),
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            "${addr['address'] ?? ''}, ${addr['city'] ?? ''}",
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.slateDark,
                              fontWeight: FontWeight.w500,
                              height: 1.15,
                            ),
                          ),
                          Text(
                            "📞 ${addr['phone'] ?? ''}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: AppColors.slateMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 10),
          ],

          // 2. Active Address Form
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isManualAddressMode ? "Enter Delivery Details" : "Delivery Details",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slateDark,
                ),
              ),
              if (!isManualAddressMode && selectedAddress != null)
                InkWell(
                  onTap: () {
                    setState(() => isManualAddressMode = true);
                  },
                  child: const Text(
                    "Edit Address",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Name Input
          TextFormField(
            controller: customerNameController,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 12.5, color: AppColors.slateDark),
            decoration: _inputDecoration(
              hint: "Customer full name",
              icon: Icons.person_outline_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return "Customer name is required";
              if (value.trim().length < 3) return "Enter a valid name";
              return null;
            },
          ),
          const SizedBox(height: 8),

          // Phone Input
          TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 12.5, color: AppColors.slateDark),
            decoration: _inputDecoration(
              hint: "Phone number (e.g. 03001234567)",
              icon: Icons.phone_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return "Phone number is required";
              if (value.trim().length < 10) return "Enter valid phone number";
              return null;
            },
          ),
          const SizedBox(height: 8),

          // City Input
          TextFormField(
            controller: cityController,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 12.5, color: AppColors.slateDark),
            decoration: _inputDecoration(
              hint: "City (e.g. Lahore, Karachi, Islamabad)",
              icon: Icons.location_city_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return "City is required";
              return null;
            },
          ),
          const SizedBox(height: 8),

          // Address Input
          TextFormField(
            controller: addressController,
            maxLines: 2,
            style: const TextStyle(fontSize: 12.5, color: AppColors.slateDark),
            decoration: _inputDecoration(
              hint: "Complete house #, street, building / area address",
              icon: Icons.home_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return "Address is required";
              if (value.trim().length < 8) return "Enter complete address";
              return null;
            },
          ),

          // Checkbox for saving address to profile
          if (isManualAddressMode) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () {
                setState(() => saveAddressToProfile = !saveAddressToProfile);
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      height: 16,
                      width: 16,
                      child: Checkbox(
                        value: saveAddressToProfile,
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (val) {
                          setState(() => saveAddressToProfile = val ?? false);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Save this address to profile for future orders",
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.slateDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ================= STEP 2: PAYMENT METHOD CARD =================
  Widget _paymentMethodCard() {
    final List<Map<String, dynamic>> methods = [
      {"name": "Cash on Delivery", "desc": "Pay cash when order arrives", "icon": Icons.local_atm_rounded},
      {"name": "EasyPaisa", "desc": "Mobile account / wallet transfer", "icon": Icons.account_balance_wallet_rounded},
      {"name": "JazzCash", "desc": "Instant wallet / mobile transfer", "icon": Icons.phone_android_rounded},
      {"name": "Bank Transfer", "desc": "Direct online bank transfer", "icon": Icons.account_balance_rounded},
    ];

    return _whiteCard(
      title: "Select Payment Method",
      icon: Icons.payment_outlined,
      child: Column(
        children: methods.map((m) {
          final String name = m['name'] as String;
          final String desc = m['desc'] as String;
          final IconData icon = m['icon'] as IconData;
          final bool isSelected = selectedPaymentMethod == name;

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () {
                setState(() => selectedPaymentMethod = name);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.07) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.4 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: isSelected ? Colors.white : AppColors.slateDark,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? AppColors.primary : AppColors.slateDark,
                            ),
                          ),
                          Text(
                            desc,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.slateMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
                          width: 1.8,
                        ),
                        color: isSelected ? AppColors.primary : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Center(
                              child: Icon(Icons.check, size: 10, color: Colors.white),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ================= STEP 2: PROMO COUPON CARD =================
  Widget _promoCouponCard() {
    return _whiteCard(
      title: "Promo Coupon & Voucher",
      icon: Icons.local_offer_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activeCoupon != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Applied: $appliedCouponCode",
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 12.5),
                        ),
                        Text(
                          "Discount: - Rs. ${discountAmount.toStringAsFixed(0)}",
                          style: const TextStyle(color: AppColors.slateDark, fontWeight: FontWeight.w600, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: removeCoupon,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text("Remove", style: TextStyle(color: AppColors.roseRed, fontWeight: FontWeight.w700, fontSize: 11.5)),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: couponController,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.slateDark),
                      decoration: InputDecoration(
                        hintText: "Enter voucher code",
                        hintStyle: const TextStyle(color: AppColors.slateMuted, fontSize: 12),
                        prefixIcon: const Icon(Icons.confirmation_number_outlined, color: AppColors.primary, size: 15),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    onPressed: () => applyCoupon(couponController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Apply", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => _showAvailableCouponsSheet(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.confirmation_number_outlined, color: AppColors.primary, size: 15),
            label: const Text("View Available Promo Vouchers", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 11.5)),
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
      },
      {
        "code": "SUMMER50",
        "title": "Summer Clearance Luxe",
        "desc": "UPTO 50% OFF | Min. Order Rs. 1,500",
      },
      {
        "code": "FLASHSALE500",
        "title": "Flash Voucher",
        "desc": "FLAT Rs. 500 OFF | Min. Order Rs. 2,000",
      },
      {
        "code": "FREESHIP",
        "title": "Free Delivery Voucher",
        "desc": "Free Shipping Nationwide on Clothes",
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        final bottomPadding = MediaQuery.of(context).padding.bottom;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(18, 16, 18, 16 + bottomPadding + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Available Promo Vouchers",
                    style: TextStyle(
                      color: AppColors.slateDark,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "Tap 'Apply' to get instant discount on your order",
                    style: TextStyle(
                      color: AppColors.slateMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: availableList.map((item) {
                          final String code = item['code']!;
                          final bool isAlreadyApplied = appliedCouponCode == code;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isAlreadyApplied ? AppColors.primary.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isAlreadyApplied ? AppColors.primary : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.local_offer_rounded, color: AppColors.primary, size: 16),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['title']!,
                                        style: const TextStyle(
                                          color: AppColors.slateDark,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item['desc']!,
                                        style: const TextStyle(
                                          color: AppColors.slateMuted,
                                          fontSize: 10.5,
                                        ),
                                      ),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text(
                                    isAlreadyApplied ? "Applied" : "Apply",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
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
  }

  // ================= STEP 3: REVIEW ADDRESS CARD (MATCHES ORDER DETAIL) =================
  Widget _reviewAddressCard() {
    final name = customerNameController.text.trim().isNotEmpty ? customerNameController.text.trim() : "Recipient Name";
    final phone = phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : "Phone Number";
    final fullAddr = addressController.text.trim().isNotEmpty ? "${addressController.text.trim()}, ${cityController.text.trim()}" : "Delivery Address";

    return _whiteCard(
      title: "Delivery Information",
      icon: Icons.local_shipping_outlined,
      trailing: TextButton(
        onPressed: () => setState(() => currentStep = 0),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          "Edit",
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Location Details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on_rounded, size: 13, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slateDark,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "• $phone",
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slateMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fullAddr,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.slateDark,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2. Delivery Window
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.schedule_rounded, size: 14, color: AppColors.primary),
                SizedBox(width: 6),
                Text(
                  "Estimated Delivery: ",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slateMuted,
                  ),
                ),
                Text(
                  "3 - 5 Business Days",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slateDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= STEP 3: REVIEW PAYMENT & VOUCHER CARD =================
  Widget _reviewPaymentAndVoucherCard() {
    return _whiteCard(
      title: "Payment & Voucher",
      icon: Icons.account_balance_wallet_outlined,
      trailing: TextButton(
        onPressed: () => setState(() => currentStep = 1),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          "Edit",
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.payment_rounded, size: 13, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Text(
                selectedPaymentMethod,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slateDark,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "Pay on Arrival",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.slateMuted),
                ),
              ),
            ],
          ),
          if (activeCoupon != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_offer_rounded, size: 13, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    "Voucher: $appliedCouponCode",
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                  const Spacer(),
                  Text(
                    "- Rs. ${discountAmount.toStringAsFixed(0)}",
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ================= STEP 3: ORDER ITEMS (COLLAPSIBLE ACCORDION MATCHING ORDER DETAIL) =================
  Widget _orderItemsCard() {
    final int count = cartItems.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accordion Header
          InkWell(
            onTap: () {
              setState(() {
                isReviewItemsExpanded = !isReviewItemsExpanded;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 15),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Purchased Items ($count)",
                      style: const TextStyle(
                        color: AppColors.slateDark,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      isReviewItemsExpanded ? "Collapse" : "View Items",
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      isReviewItemsExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Collapsed Preview
          if (!isReviewItemsExpanded && cartItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => setState(() => isReviewItemsExpanded = true),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    // Mini thumbnail preview row (up to 3 items)
                    SizedBox(
                      height: 30,
                      child: Row(
                        children: cartItems.take(3).map((item) {
                          final product = item['products'] ?? {};
                          String img = (product['image_url'] ??
                                  product['image'] ??
                                  product['photo_url'] ??
                                  product['cover_image'])
                              ?.toString() ??
                              '';
                          if (img.isEmpty && product['image_urls'] is List && (product['image_urls'] as List).isNotEmpty) {
                            img = product['image_urls'][0].toString();
                          }
                          return Container(
                            width: 30,
                            height: 30,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: img.isNotEmpty
                                ? Image.network(img, fit: BoxFit.contain, errorBuilder: (_, _, _) => _placeholderMini())
                                : _placeholderMini(),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cartItems.length == 1
                            ? "${cartItems.first['products']?['name'] ?? '1 item'}"
                            : "${cartItems.first['products']?['name'] ?? 'Item'} + ${cartItems.length - 1} more",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slateDark,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppColors.slateMuted),
                  ],
                ),
              ),
            ),
          ],

          // Expanded Items List
          if (isReviewItemsExpanded) ...[
            const SizedBox(height: 10),
            ...cartItems.map((item) {
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
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
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
                    const SizedBox(width: 8),
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
                              fontSize: 12,
                            ),
                          ),
                          if ((item['selected_color'] != null && item['selected_color'].toString().isNotEmpty) || (item['selected_size'] != null && item['selected_size'].toString().isNotEmpty)) ...[
                            const SizedBox(height: 1.5),
                            Text(
                              [
                                if (item['selected_color'] != null && item['selected_color'].toString().isNotEmpty) item['selected_color'].toString(),
                                if (item['selected_size'] != null && item['selected_size'].toString().isNotEmpty) "Size: ${item['selected_size']}",
                              ].join(" • "),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            "Qty: $qty × Rs. ${price.toStringAsFixed(0)}",
                            style: const TextStyle(
                              color: AppColors.slateMuted,
                              fontSize: 10.5,
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
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _placeholderMini() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(Icons.shopping_bag_outlined, color: AppColors.slateMuted, size: 14),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(Icons.shopping_bag_outlined, color: AppColors.slateMuted, size: 18),
      ),
    );
  }

  // ================= STEP 3: PAYMENT SUMMARY =================
  Widget _orderSummaryCard() {
    const double deliveryCharge = 99.0;
    final double subtotal = totalAmount;
    final double grandTotal = (subtotal + deliveryCharge) - discountAmount;

    return _whiteCard(
      title: "Price Breakdown",
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: [
          _summaryRow(
            label: "Subtotal (${cartItems.length} items)",
            value: "Rs. ${subtotal.toStringAsFixed(0)}",
          ),
          const SizedBox(height: 6),
          _summaryRow(
            label: "Standard Delivery Fee",
            value: "Rs. ${deliveryCharge.toStringAsFixed(0)}",
          ),
          if (discountAmount > 0) ...[
            const SizedBox(height: 6),
            _summaryRow(
              label: "Promo Voucher Discount ($appliedCouponCode)",
              value: "- Rs. ${discountAmount.toStringAsFixed(0)}",
              isDiscount: true,
            ),
          ],
          const SizedBox(height: 6),
          _summaryRow(
            label: "Sales Tax / VAT (0%)",
            value: "Rs. 0",
          ),
          const SizedBox(height: 10),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 10),
          _summaryRow(
            label: "Grand Total",
            value: "Rs. ${(grandTotal > 0 ? grandTotal : 0).toStringAsFixed(0)}",
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow({
    required String label,
    required String value,
    bool isDiscount = false,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isDiscount
                  ? AppColors.primary
                  : isTotal
                      ? AppColors.slateDark
                      : AppColors.slateMuted,
              fontSize: isTotal ? 13.5 : 12,
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
            fontSize: isTotal ? 15.5 : 12.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // ================= STEP ACTION BUTTONS (COMPACT 40PX) =================
  Widget _stepActionButtons() {
    if (currentStep == 0) {
      return SizedBox(
        width: double.infinity,
        height: 40,
        child: ElevatedButton.icon(
          onPressed: _validateAndProceedToPayment,
          icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
          label: const Text(
            "Continue to Payment",
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    } else if (currentStep == 1) {
      return Row(
        children: [
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 40,
              child: OutlinedButton(
                onPressed: () => setState(() => currentStep = 0),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "← Back",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slateDark,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: SizedBox(
              height: 40,
              child: ElevatedButton(
                onPressed: _proceedToReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Review Order",
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 40,
              child: OutlinedButton(
                onPressed: () => setState(() => currentStep = 1),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "← Back",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slateDark,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 7,
            child: SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : placeOrder,
                icon: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 15),
                label: const Text(
                  "Confirm & Place Order",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.slateMuted,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  // ================= REUSABLE WHITE CARD =================
  Widget _whiteCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 15),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.slateDark,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
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
        fontSize: 12,
      ),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 16),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.roseRed, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 54, color: AppColors.slateMuted),
              SizedBox(height: 12),
              Text(
                "Your Cart is Empty",
                style: TextStyle(
                  color: AppColors.slateDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6),
              Text(
                "Add products to cart before checkout.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.slateMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}