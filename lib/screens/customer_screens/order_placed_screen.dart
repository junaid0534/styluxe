import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class OrderPlacedScreen extends StatefulWidget {
  final String orderId;
  final double totalAmount;

  const OrderPlacedScreen({
    super.key,
    required this.orderId,
    required this.totalAmount,
  });

  static const String homeRoute = '/customer_home';
  static const String ordersRoute = '/my_orders';

  @override
  State<OrderPlacedScreen> createState() => _OrderPlacedScreenState();
}

class _OrderPlacedScreenState extends State<OrderPlacedScreen> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? orderDetails;
  List<Map<String, dynamic>> orderItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchOrderReceipt();
  }

  // ================= FETCH ORDER DETAILS FROM SUPABASE =================
  Future<void> fetchOrderReceipt() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      // Query order by order_id or base order prefix
      final data = await supabase
          .from('orders')
          .select('*, order_items(*, products(*))')
          .eq('user_id', currentUser.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;

      if (data != null) {
        final items = List<Map<String, dynamic>>.from(data['order_items'] ?? []);
        setState(() {
          orderDetails = data;
          orderItems = items;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Fetch Order Receipt Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String customerName = orderDetails?['customer_name']?.toString() ?? 'Valued Customer';
    final String phone = orderDetails?['phone']?.toString() ?? 'N/A';
    final String address = orderDetails?['address']?.toString() ?? 'N/A';
    final String city = orderDetails?['city']?.toString() ?? 'N/A';
    final String paymentMethod = orderDetails?['payment_method']?.toString() ?? 'Cash on Delivery';
    final String status = orderDetails?['status']?.toString() ?? 'Pending';
    final String orderCode = orderDetails?['order_id']?.toString() ?? widget.orderId;
    final double finalAmount = (orderDetails?['total_amount'] as num?)?.toDouble() ?? widget.totalAmount;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          "Order Confirmation",
          style: TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Column(
                children: [
                  // ================= SUCCESS ICON =================
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.30), width: 2),
                    ),
                    child: Center(
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                        child: Icon(Icons.check_rounded, color: Colors.white, size: 40),
                      ),
                    ),
                  ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

                  const SizedBox(height: 20),

                  const Text(
                    "Order Placed Successfully!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.slateDark,
                      letterSpacing: -0.5,
                    ),
                  ).animate().fadeIn(duration: 350.ms),

                  const SizedBox(height: 8),

                  const Text(
                    "Thank you for shopping with StyLuxe. Your e-receipt has been generated below.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.slateMuted,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ================= E-RECEIPT SLIP CARD =================
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Receipt Header Banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          color: const Color(0xFF0F172A),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.receipt_rounded, color: Colors.white, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    "OFFICIAL E-RECEIPT",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.20),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Order ID & Date
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "ORDER NUMBER",
                                        style: TextStyle(
                                          color: AppColors.slateMuted,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        orderCode,
                                        style: const TextStyle(
                                          color: AppColors.slateDark,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        "PAYMENT METHOD",
                                        style: TextStyle(
                                          color: AppColors.slateMuted,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        paymentMethod,
                                        style: const TextStyle(
                                          color: AppColors.slateDark,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const _DashedLine(),

                              // Customer & Delivery Address Details
                              const Text(
                                "DELIVERY DETAILS",
                                style: TextStyle(
                                  color: AppColors.slateMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 12),

                              _receiptDetailRow(
                                icon: Icons.person_outline_rounded,
                                label: "Customer Name",
                                value: customerName,
                              ),
                              const SizedBox(height: 10),

                              _receiptDetailRow(
                                icon: Icons.phone_outlined,
                                label: "Phone Number",
                                value: phone,
                              ),
                              const SizedBox(height: 10),

                              _receiptDetailRow(
                                icon: Icons.location_on_outlined,
                                label: "Delivery Address",
                                value: "$address, $city",
                              ),

                              if (orderItems.isNotEmpty) ...[
                                const _DashedLine(),

                                const Text(
                                  "ORDERED ITEMS",
                                  style: TextStyle(
                                    color: AppColors.slateMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                ...orderItems.map((item) {
                                  final product = item['products'] ?? {};
                                  final name = product['name']?.toString() ?? 'Item';
                                  final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                                  final price = (item['price'] as num?)?.toDouble() ?? 0.0;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            "$name (x$qty)",
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppColors.slateDark,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          "Rs. ${(price * qty).toStringAsFixed(0)}",
                                          style: const TextStyle(
                                            color: AppColors.slateDark,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],

                              const _DashedLine(),

                              // Grand Total
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Total Paid",
                                    style: TextStyle(
                                      color: AppColors.slateDark,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    "Rs. ${finalAmount.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                  const SizedBox(height: 28),

                  // ================= ACTION BUTTONS =================
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          OrderPlacedScreen.homeRoute,
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 18),
                      label: const Text(
                        "CONTINUE SHOPPING",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
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
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          OrderPlacedScreen.ordersRoute,
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.receipt_long_outlined, color: AppColors.slateDark, size: 18),
                      label: const Text(
                        "View My Orders",
                        style: TextStyle(
                          color: AppColors.slateDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
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
        ),
      ),
      bottomNavigationBar: _buildFullWidthBottomNav(0),
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

  Widget _receiptDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.slateDark,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ================= DASHED LINE DIVIDER =================
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: List.generate(
          30,
          (index) => Expanded(
            child: Container(
              height: 1.2,
              color: index % 2 == 0 ? const Color(0xFFCBD5E1) : Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }
}