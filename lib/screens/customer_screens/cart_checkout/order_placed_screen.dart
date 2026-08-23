import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';

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
            fontSize: 16.5,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ================= COMPACT SUCCESS ICON =================
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.28), width: 1.5),
                    ),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ).animate().scale(duration: 350.ms, curve: Curves.easeOutBack),

                  const SizedBox(height: 8),

                  const Text(
                    "Order Placed Successfully!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.slateDark,
                      letterSpacing: -0.3,
                    ),
                  ).animate().fadeIn(duration: 300.ms),

                  const SizedBox(height: 3),

                  const Text(
                    "Thank you for shopping with StyLuxe. Your e-receipt is below.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.slateMuted,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ================= PROFESSIONAL E-RECEIPT SLIP =================
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          color: const Color(0xFF0F172A),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.receipt_rounded, color: Colors.white, size: 13),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "OFFICIAL E-RECEIPT",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Order ID & Payment Method Row
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
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        orderCode,
                                        style: const TextStyle(
                                          color: AppColors.slateDark,
                                          fontSize: 13,
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
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        paymentMethod,
                                        style: const TextStyle(
                                          color: AppColors.slateDark,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const _DashedLine(),

                              // Delivery Details
                              Row(
                                children: [
                                  const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 5),
                                  Text(
                                    customerName,
                                    style: const TextStyle(
                                      color: AppColors.slateDark,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.phone_outlined, size: 13, color: AppColors.slateMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    phone,
                                    style: const TextStyle(
                                      color: AppColors.slateDark,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      "$address, $city",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.slateDark,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              if (orderItems.isNotEmpty) ...[
                                const _DashedLine(),

                                ...orderItems.map((item) {
                                  final product = item['products'] ?? {};
                                  final name = product['name']?.toString() ?? 'Item';
                                  final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                                  final price = (item['price'] as num?)?.toDouble() ?? 0.0;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
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
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          "Rs. ${(price * qty).toStringAsFixed(0)}",
                                          style: const TextStyle(
                                            color: AppColors.slateDark,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],

                              const _DashedLine(),

                              // Grand Total Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Total Paid",
                                    style: TextStyle(
                                      color: AppColors.slateDark,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    "Rs. ${finalAmount.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 17,
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
                  ).animate().fadeIn(delay: 150.ms, duration: 350.ms),

                  const SizedBox(height: 16),

                  // ================= ACTION BUTTONS =================
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                OrderPlacedScreen.ordersRoute,
                                (route) => false,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            child: const Text(
                              "View Orders",
                              style: TextStyle(
                                color: AppColors.slateDark,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                OrderPlacedScreen.homeRoute,
                                (route) => false,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            child: const Text(
                              "Continue Shopping",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
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
        ),
      ),
      bottomNavigationBar: _buildFullWidthBottomNav(0),
    );
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
}

// ================= DASHED LINE DIVIDER =================
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: List.generate(
          28,
          (index) => Expanded(
            child: Container(
              height: 1.1,
              color: index % 2 == 0 ? const Color(0xFFCBD5E1) : Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }
}