import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellerAllOrdersScreen extends StatefulWidget {
  const SellerAllOrdersScreen({super.key});

  @override
  State<SellerAllOrdersScreen> createState() => _SellerAllOrdersScreenState();
}

class _SellerAllOrdersScreenState extends State<SellerAllOrdersScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  String selectedStatus = "All";

  List<Map<String, dynamic>> orders = [];

  final List<String> statusFilters = [
    "All",
    "Pending",
    "Processing",
    "Shipped",
    "Delivered",
    "Cancelled",
  ];

  @override
  void initState() {
    super.initState();
    fetchSellerOrders();
  }

  // ================= FETCH SELLER ORDERS =================
  Future<void> fetchSellerOrders() async {
    setState(() => isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception("User not logged in");
      }

      final sellerId = currentUser.id;

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
            updated_at,
            order_items (
              id,
              order_id,
              product_id,
              buyer_id,
              seller_id,
              quantity,
              price,
              products (
                id,
                name,
                price,
                image_url
              )
            )
          ''')
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        orders = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Seller Orders Error: $e");

      if (!mounted) return;

      setState(() {
        orders = [];
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to load orders: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================= FILTERED ORDERS =================
  List<Map<String, dynamic>> get filteredOrders {
    if (selectedStatus == "All") {
      return orders;
    }

    return orders.where((order) {
      return order['status'] == selectedStatus;
    }).toList();
  }

  // ================= TOTAL REVENUE =================
  double get totalRevenue {
    return orders.fold(0.0, (sum, order) {
      final amount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
      return sum + amount;
    });
  }

  // ================= ACTIVE ORDERS COUNT =================
  int get activeOrdersCount {
    return orders.where((order) {
      final status = order['status'];
      return status == "Pending" ||
          status == "Processing" ||
          status == "Shipped";
    }).length;
  }

  // ================= FORMAT DATE =================
  String formatDate(dynamic value) {
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

  // ================= STATUS COLOR =================
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
        elevation: 0,
        surfaceTintColor: Colors.white,
        iconTheme: const IconThemeData(
          color: Color(0xFF111827),
        ),
        title: const Text(
          "All Orders",
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: fetchSellerOrders,
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
              onRefresh: fetchSellerOrders,
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : 28,
                        vertical: 18,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 1200,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ================= HEADER =================
                              Text(
                                "Seller Orders",
                                style: TextStyle(
                                  fontSize: isMobile ? 26 : 34,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF111827),
                                ),
                              ),

                              const SizedBox(height: 8),

                              Text(
                                "Track all orders placed for your products.",
                                style: TextStyle(
                                  fontSize: isMobile ? 14 : 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),

                              const SizedBox(height: 22),

                              // ================= SUMMARY CARDS =================
                              isMobile
                                  ? Column(
                                      children: [
                                        _summaryCard(
                                          title: "Total Orders",
                                          value: orders.length.toString(),
                                          icon: Icons.receipt_long_outlined,
                                          color: const Color(0xFF4F46E5),
                                        ),
                                        const SizedBox(height: 12),
                                        _summaryCard(
                                          title: "Active Orders",
                                          value: activeOrdersCount.toString(),
                                          icon: Icons.shopping_bag_outlined,
                                          color: const Color(0xFFF59E0B),
                                        ),
                                        const SizedBox(height: 12),
                                        _summaryCard(
                                          title: "Total Revenue",
                                          value:
                                              "PKR ${totalRevenue.toStringAsFixed(0)}",
                                          icon:
                                              Icons.account_balance_wallet_outlined,
                                          color: const Color(0xFF22C55E),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Expanded(
                                          child: _summaryCard(
                                            title: "Total Orders",
                                            value: orders.length.toString(),
                                            icon: Icons.receipt_long_outlined,
                                            color: const Color(0xFF4F46E5),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: _summaryCard(
                                            title: "Active Orders",
                                            value:
                                                activeOrdersCount.toString(),
                                            icon: Icons.shopping_bag_outlined,
                                            color: const Color(0xFFF59E0B),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: _summaryCard(
                                            title: "Total Revenue",
                                            value:
                                                "PKR ${totalRevenue.toStringAsFixed(0)}",
                                            icon: Icons
                                                .account_balance_wallet_outlined,
                                            color: const Color(0xFF22C55E),
                                          ),
                                        ),
                                      ],
                                    ),

                              const SizedBox(height: 24),

                              // ================= FILTER CHIPS =================
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: statusFilters.map((status) {
                                    final bool isSelected =
                                        selectedStatus == status;

                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(right: 10),
                                      child: ChoiceChip(
                                        selected: isSelected,
                                        label: Text(status),
                                        backgroundColor: Colors.white,
                                        selectedColor:
                                            const Color(0xFF4F46E5),
                                        labelStyle: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF374151),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        side: BorderSide(
                                          color: isSelected
                                              ? const Color(0xFF4F46E5)
                                              : Colors.grey.shade300,
                                        ),
                                        onSelected: (_) {
                                          setState(() {
                                            selectedStatus = status;
                                          });
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),

                              const SizedBox(height: 22),

                              // ================= ORDERS LIST =================
                              if (filteredOrders.isEmpty)
                                _emptyOrdersView()
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  itemCount: filteredOrders.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 14),
                                  itemBuilder: (context, index) {
                                    final order = filteredOrders[index];
                                    return _orderCard(
                                      order: order,
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

  // ================= SUMMARY CARD =================
  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: color,
              size: 26,
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
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= ORDER CARD =================
  Widget _orderCard({
    required Map<String, dynamic> order,
    required bool isMobile,
  }) {
    final String orderCode = order['order_id']?.toString() ?? 'N/A';
    final String status = order['status']?.toString() ?? 'Pending';
    final Color statusColor = getStatusColor(status);

    final double totalAmount =
        (order['total_amount'] as num?)?.toDouble() ?? 0.0;

    final String address = order['address']?.toString() ?? 'N/A';
    final String city = order['city']?.toString() ?? 'N/A';
    final String phone = order['phone']?.toString() ?? 'N/A';
    final String paymentMethod =
        order['payment_method']?.toString() ?? 'N/A';
    final String createdAt = formatDate(order['created_at']);

    final List<Map<String, dynamic>> items =
        List<Map<String, dynamic>>.from(order['order_items'] ?? []);

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
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
          // ================= ORDER TOP =================
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Order #$orderCode",
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
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
                        "Order #$orderCode",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
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

          const SizedBox(height: 18),

          // ================= ORDER DETAILS =================
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _detailBox(
                title: "Total",
                value: "PKR ${totalAmount.toStringAsFixed(0)}",
                icon: Icons.payments_outlined,
              ),
              _detailBox(
                title: "Payment",
                value: paymentMethod,
                icon: Icons.payment_outlined,
              ),
              _detailBox(
                title: "Phone",
                value: phone,
                icon: Icons.phone_outlined,
              ),
              _detailBox(
                title: "City",
                value: city,
                icon: Icons.location_city_outlined,
              ),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.shade200,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    address,
                    style: const TextStyle(
                      color: Color(0xFF374151),
                      fontSize: 14.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ================= ORDER ITEMS =================
          Text(
            "Order Items (${items.length})",
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),

          const SizedBox(height: 12),

          if (items.isEmpty)
            Text(
              "No items found",
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            )
          else
            Column(
              children: items.map((item) {
                return _orderItemTile(item);
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ================= STATUS BADGE =================
  Widget _statusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
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

  // ================= DETAIL BOX =================
  Widget _detailBox({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: 150,
        maxWidth: 260,
      ),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: const Color(0xFF4F46E5),
            size: 20,
          ),
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

  // ================= ORDER ITEM TILE =================
  Widget _orderItemTile(Map<String, dynamic> item) {
    final product = item['products'] ?? {};

    final String name = product['name']?.toString() ?? 'Product';
    final String imageUrl = product['image_url']?.toString() ?? '';
    final int quantity = (item['quantity'] as num?)?.toInt() ?? 1;
    final double price = (item['price'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Image.network(
              imageUrl,
              width: 58,
              height: 58,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) {
                return Container(
                  width: 58,
                  height: 58,
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

                const SizedBox(height: 5),

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
              fontSize: 14.5,
            ),
          ),
        ],
      ),
    );
  }

  // ================= EMPTY VIEW =================
  Widget _emptyOrdersView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 50,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 70,
            color: Colors.grey.shade400,
          ),

          const SizedBox(height: 16),

          const Text(
            "No Orders Found",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            selectedStatus == "All"
                ? "Orders for your products will appear here."
                : "No $selectedStatus orders found.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}