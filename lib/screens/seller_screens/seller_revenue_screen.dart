import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellerRevenueScreen extends StatefulWidget {
  const SellerRevenueScreen({super.key});

  @override
  State<SellerRevenueScreen> createState() => _SellerRevenueScreenState();
}

class _SellerRevenueScreenState extends State<SellerRevenueScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  DateTime selectedDate = DateTime.now();

  List<Map<String, dynamic>> orders = [];

  @override
  void initState() {
    super.initState();
    fetchRevenueByDate();
  }

  // ================= FETCH REVENUE BY DATE =================
  Future<void> fetchRevenueByDate() async {
    setState(() => isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception("User not logged in");
      }

      final sellerId = currentUser.id;

      final startDate = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );

      final endDate = startDate.add(const Duration(days: 1));

      final response = await supabase
          .from('orders')
          .select('''
            id,
            order_id,
            user_id,
            seller_id,
            total_amount,
            status,
            address,
            city,
            phone,
            payment_method,
            created_at,
            order_items (
              id,
              product_id,
              quantity,
              price,
              products (
                id,
                name,
                image_url
              )
            )
          ''')
          .eq('seller_id', sellerId)
          .gte('created_at', startDate.toUtc().toIso8601String())
          .lt('created_at', endDate.toUtc().toIso8601String())
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        orders = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Revenue Fetch Error: $e");

      if (!mounted) return;

      setState(() {
        orders = [];
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to load revenue: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================= TOTAL REVENUE =================
  double get totalRevenue {
    return orders.fold(0.0, (sum, order) {
      final amount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
      return sum + amount;
    });
  }

  int get totalOrders => orders.length;

  int get deliveredOrders {
    return orders.where((order) => order['status'] == "Delivered").length;
  }

  int get activeOrders {
    return orders.where((order) {
      final status = order['status'];
      return status == "Pending" ||
          status == "Processing" ||
          status == "Shipped";
    }).length;
  }

  int get cancelledOrders {
    return orders.where((order) => order['status'] == "Cancelled").length;
  }

  // ================= DATE PICKER =================
  Future<void> pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4F46E5),
              onPrimary: Colors.white,
              onSurface: Color(0xFF111827),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    setState(() {
      selectedDate = pickedDate;
    });

    await fetchRevenueByDate();
  }

  // ================= FORMAT DATE =================
  String formatDate(DateTime date) {
    final months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];

    return "${date.day} ${months[date.month - 1]}, ${date.year}";
  }

  String formatDateTime(dynamic value) {
    if (value == null) return "N/A";

    try {
      final date = DateTime.parse(value.toString()).toLocal();

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();

      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');

      return "$day/$month/$year • $hour:$minute";
    } catch (_) {
      return value.toString();
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case "Pending":
        return Colors.orange;
      case "Processing":
        return Colors.blue;
      case "Shipped":
        return Colors.purple;
      case "Delivered":
        return Colors.green;
      case "Cancelled":
        return Colors.red;
      default:
        return Colors.grey;
    }
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
          "Revenue",
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: fetchRevenueByDate,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final bool isMobile = width < 650;

            return RefreshIndicator(
              onRefresh: fetchRevenueByDate,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : 28,
                        vertical: 20,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _headerCard(isMobile: isMobile)
                                  .animate()
                                  .fadeIn()
                                  .slideY(begin: 0.08),

                              const SizedBox(height: 22),

                              isMobile
                                  ? Column(
                                      children: [
                                        _summaryCard(
                                          title: "Total Revenue",
                                          value:
                                              "PKR ${totalRevenue.toStringAsFixed(0)}",
                                          icon: FontAwesomeIcons.rupeeSign,
                                          color: const Color(0xFF22C55E),
                                        ),
                                        const SizedBox(height: 12),
                                        _summaryCard(
                                          title: "Total Orders",
                                          value: totalOrders.toString(),
                                          icon: Icons.receipt_long_outlined,
                                          color: const Color(0xFF4F46E5),
                                        ),
                                        const SizedBox(height: 12),
                                        _summaryCard(
                                          title: "Active Orders",
                                          value: activeOrders.toString(),
                                          icon: Icons.shopping_bag_outlined,
                                          color: const Color(0xFFF59E0B),
                                        ),
                                        const SizedBox(height: 12),
                                        _summaryCard(
                                          title: "Delivered",
                                          value: deliveredOrders.toString(),
                                          icon: Icons.check_circle_outline,
                                          color: const Color(0xFF16A34A),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Expanded(
                                          child: _summaryCard(
                                            title: "Total Revenue",
                                            value:
                                                "PKR ${totalRevenue.toStringAsFixed(0)}",
                                            icon: FontAwesomeIcons.rupeeSign,
                                            color: const Color(0xFF22C55E),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: _summaryCard(
                                            title: "Total Orders",
                                            value: totalOrders.toString(),
                                            icon: Icons.receipt_long_outlined,
                                            color: const Color(0xFF4F46E5),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: _summaryCard(
                                            title: "Active Orders",
                                            value: activeOrders.toString(),
                                            icon: Icons.shopping_bag_outlined,
                                            color: const Color(0xFFF59E0B),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: _summaryCard(
                                            title: "Delivered",
                                            value: deliveredOrders.toString(),
                                            icon: Icons.check_circle_outline,
                                            color: const Color(0xFF16A34A),
                                          ),
                                        ),
                                      ],
                                    ),

                              const SizedBox(height: 28),

                              Text(
                                "Orders on ${formatDate(selectedDate)}",
                                style: TextStyle(
                                  color: const Color(0xFF111827),
                                  fontSize: isMobile ? 22 : 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 14),

                              if (orders.isEmpty)
                                _emptyView()
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  itemCount: orders.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 14),
                                  itemBuilder: (context, index) {
                                    return _orderCard(
                                      orders[index],
                                      isMobile: isMobile,
                                    );
                                  },
                                ),

                              const SizedBox(height: 30),
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

  // ================= HEADER CARD =================
  Widget _headerCard({required bool isMobile}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF22C55E),
            Color(0xFF16A34A),
            Color(0xFF4F46E5),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22C55E).withValues(alpha: 0.20),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerText(isMobile: isMobile),
                const SizedBox(height: 18),
                _dateButton(),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: _headerText(isMobile: isMobile),
                ),
                const SizedBox(width: 20),
                _dateButton(),
              ],
            ),
    );
  }

  Widget _headerText({required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Revenue Overview",
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 27 : 36,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "See total revenue from all orders for your selected date.",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: isMobile ? 14 : 16,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _dateButton() {
    return InkWell(
      onTap: pickDate,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Text(
              formatDate(selectedDate),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  // ================= SUMMARY CARD =================
  Widget _summaryCard({
    required String title,
    required String value,
    required dynamic icon,
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
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Center(
              child: icon is IconData
                  ? Icon(icon, color: color, size: 27)
                  : FaIcon(icon, color: color, size: 23),
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
                    color: Color(0xFF111827),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.08);
  }

  // ================= ORDER CARD =================
  Widget _orderCard(
    Map<String, dynamic> order, {
    required bool isMobile,
  }) {
    final String orderId = order['order_id']?.toString() ?? "N/A";
    final String status = order['status']?.toString() ?? "Pending";
    final Color statusColor = getStatusColor(status);

    final double amount =
        (order['total_amount'] as num?)?.toDouble() ?? 0.0;

    final String paymentMethod =
        order['payment_method']?.toString() ?? "N/A";
    final String city = order['city']?.toString() ?? "N/A";
    final String createdAt = formatDateTime(order['created_at']);

    final List<Map<String, dynamic>> items =
        List<Map<String, dynamic>>.from(order['order_items'] ?? []);

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Order #$orderId",
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _statusBadge(status, statusColor),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Order #$orderId",
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _statusBadge(status, statusColor),
                  ],
                ),

          const SizedBox(height: 8),

          Text(
            createdAt,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 16),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _detailBox(
                title: "Revenue",
                value: "PKR ${amount.toStringAsFixed(0)}",
                icon: FontAwesomeIcons.rupeeSign,
                color: const Color(0xFF22C55E),
              ),
              _detailBox(
                title: "Payment",
                value: paymentMethod,
                icon: Icons.payment_outlined,
                color: const Color(0xFF4F46E5),
              ),
              _detailBox(
                title: "City",
                value: city,
                icon: Icons.location_city_outlined,
                color: const Color(0xFFF59E0B),
              ),
              _detailBox(
                title: "Items",
                value: items.length.toString(),
                icon: Icons.inventory_2_outlined,
                color: const Color(0xFF9333EA),
              ),
            ],
          ),

          if (items.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              "Products",
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Column(
              children: items.map((item) {
                return _productTile(item);
              }).toList(),
            ),
          ],
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.08);
  }

  Widget _statusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _detailBox({
    required String title,
    required String value,
    required dynamic icon,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: 145,
        maxWidth: 245,
      ),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon is IconData
              ? Icon(icon, color: color, size: 20)
              : FaIcon(icon, color: color, size: 17),
          const SizedBox(width: 9),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productTile(Map<String, dynamic> item) {
    final product = item['products'] ?? {};

    final String name = product['name']?.toString() ?? "Product";
    final String imageUrl = product['image_url']?.toString() ?? "";
    final int quantity = (item['quantity'] as num?)?.toInt() ?? 1;
    final double price = (item['price'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Image.network(
              imageUrl,
              width: 54,
              height: 54,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) {
                return Container(
                  width: 54,
                  height: 54,
                  color: Colors.grey.shade200,
                  child: Icon(
                    Icons.image_outlined,
                    color: Colors.grey.shade500,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Qty: $quantity",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            "PKR ${(price * quantity).toStringAsFixed(0)}",
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 55),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 72,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            "No Orders Found",
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "No orders were placed for your products on ${formatDate(selectedDate)}.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}