import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ActiveOrdersScreen extends StatefulWidget {
  const ActiveOrdersScreen({super.key});

  @override
  State<ActiveOrdersScreen> createState() => _ActiveOrdersScreenState();
}

class _ActiveOrdersScreenState extends State<ActiveOrdersScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> activeOrders = [];
  bool isLoading = true;

  StreamSubscription<List<Map<String, dynamic>>>? _ordersSubscription;

  static const Color appGreen = Color(0xFFA8E063);
  static const Color darkText = Color(0xFF111827);
  static const Color mutedText = Color(0xFF6B7280);
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color bgColor = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    fetchActiveOrders();
    setupRealtimeOrders();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }

  bool _isActiveStatus(String status) {
    final value = status.toLowerCase().trim();

    return value == 'pending' ||
        value == 'processing' ||
        value == 'shipped';
  }

  // ================= FETCH ACTIVE ORDERS =================
  Future<void> fetchActiveOrders() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception("User not logged in");
      }

      final sellerId = currentUser.id;

      final data = await supabase
          .from('orders')
          .select('*')
          .eq('seller_id', sellerId)
          .inFilter('status', [
            'Pending',
            'Processing',
            'Shipped',
          ])
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        activeOrders = List<Map<String, dynamic>>.from(data);
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

  // ================= REALTIME ORDERS =================
  void setupRealtimeOrders() {
    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) return;

      _ordersSubscription = supabase
          .from('orders')
          .stream(primaryKey: ['id'])
          .eq('seller_id', currentUser.id)
          .listen(
        (data) {
          final filtered = List<Map<String, dynamic>>.from(data).where((order) {
            final status = order['status']?.toString() ?? 'Pending';
            return _isActiveStatus(status);
          }).toList();

          filtered.sort((a, b) {
            final aDate = DateTime.tryParse(
                  a['created_at']?.toString() ?? '',
                ) ??
                DateTime(2000);

            final bDate = DateTime.tryParse(
                  b['created_at']?.toString() ?? '',
                ) ??
                DateTime(2000);

            return bDate.compareTo(aDate);
          });

          if (!mounted) return;

          setState(() {
            activeOrders = filtered;
            isLoading = false;
          });
        },
        onError: (error) {
          debugPrint("Active orders realtime error: $error");
        },
      );
    } catch (e) {
      debugPrint("Realtime setup error: $e");
    }
  }

  // ================= FETCH ORDER ITEMS TEXT FOR NOTIFICATION =================
  Future<String> _fetchOrderItemsText(dynamic orderId) async {
    if (orderId == null) return "";

    try {
      final data = await supabase
          .from('order_items')
          .select('quantity, products(name)')
          .eq('order_id', orderId);

      final items = List<Map<String, dynamic>>.from(data);

      if (items.isEmpty) return "";

      final productNames = items.map((item) {
        final product = item['products'] ?? {};
        final name = product['name']?.toString() ?? 'Product';
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;

        return "$name x$qty";
      }).toList();

      final firstTwo = productNames.take(2).join(", ");
      final extraCount = productNames.length - 2;

      if (extraCount > 0) {
        return "$firstTwo and $extraCount more item(s)";
      }

      return firstTwo;
    } catch (e) {
      debugPrint("Fetch order items text error: $e");
      return "";
    }
  }

  // ================= CUSTOMER NOTIFICATION =================
  Future<bool> _sendStatusNotification({
    required Map<String, dynamic> order,
    required String oldStatus,
    required String newStatus,
  }) async {
    try {
      final customerId = order['user_id']?.toString();

      if (customerId == null || customerId.trim().isEmpty) {
        throw Exception("Customer ID not found");
      }

      final orderNo = _orderNumber(order);
      final amount = _amount(order['total_amount']);
      final itemsText = await _fetchOrderItemsText(order['id']);

      String title = "Order Status Updated";
      String message =
          "Your order #$orderNo status has been updated from $oldStatus to $newStatus.";

      if (newStatus.toLowerCase() == "processing") {
        title = "Order is Processing";
        message =
            "Your order #$orderNo has moved from $oldStatus to Processing. The seller has started preparing your order.";
      } else if (newStatus.toLowerCase() == "shipped") {
        title = "Order Shipped";
        message =
            "Your order #$orderNo has been shipped. Previous status: $oldStatus.";
      } else if (newStatus.toLowerCase() == "delivered") {
        title = "Order Delivered";
        message =
            "Your order #$orderNo has been marked as Delivered. Thank you for shopping with us.";
      }

      if (itemsText.trim().isNotEmpty) {
        message = "$message Items: $itemsText.";
      }

      message = "$message Total amount: PKR ${amount.toStringAsFixed(0)}.";

      await supabase.from('notifications').insert({
        'user_id': customerId,
        'title': title,
        'message': message,
        'is_read': false,
      });

      debugPrint("Customer notification inserted for order #$orderNo");
      return true;
    } catch (e) {
      debugPrint("Send status notification error: $e");
      return false;
    }
  }

  // ================= UPDATE STATUS =================
  Future<void> updateOrderStatus(
    Map<String, dynamic> order,
    String newStatus,
  ) async {
    try {
      final orderId = order['id'];

      if (orderId == null) {
        throw Exception("Order ID not found");
      }

      final oldStatus = order['status']?.toString() ?? 'Pending';

      await supabase.from('orders').update({
        'status': newStatus,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', orderId);

      final notificationSent = await _sendStatusNotification(
        order: order,
        oldStatus: oldStatus,
        newStatus: newStatus,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notificationSent
                ? "Order updated to $newStatus and customer notified"
                : "Order updated to $newStatus, but notification was not sent",
          ),
          backgroundColor:
              notificationSent ? const Color(0xFF22C55E) : Colors.orange,
        ),
      );

      fetchActiveOrders();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Status update error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _orderNumber(Map<String, dynamic> order) {
    final orderId = order['order_id'];

    if (orderId != null && orderId.toString().trim().isNotEmpty) {
      return orderId.toString();
    }

    final id = order['id']?.toString() ?? '';

    if (id.length >= 8) {
      return id.substring(0, 8).toUpperCase();
    }

    return id.isEmpty ? "N/A" : id.toUpperCase();
  }

  String _shortCustomerId(dynamic value) {
    final id = value?.toString() ?? '';

    if (id.isEmpty) return "Unknown";

    if (id.length <= 8) return id;

    return "${id.substring(0, 8)}...";
  }

  double _amount(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');

    if (date == null) return "N/A";

    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();

    return "$day-$month-$year";
  }

  Color _statusColor(String status) {
    final value = status.toLowerCase().trim();

    if (value == 'shipped') {
      return const Color(0xFF2563EB);
    }

    if (value == 'processing') {
      return const Color(0xFF7C3AED);
    }

    return const Color(0xFFF59E0B);
  }

  Color _statusBgColor(String status) {
    final value = status.toLowerCase().trim();

    if (value == 'shipped') {
      return const Color(0xFFEFF6FF);
    }

    if (value == 'processing') {
      return const Color(0xFFF5F3FF);
    }

    return const Color(0xFFFFFBEB);
  }

  IconData _statusIcon(String status) {
    final value = status.toLowerCase().trim();

    if (value == 'shipped') {
      return Icons.local_shipping_outlined;
    }

    if (value == 'processing') {
      return Icons.sync_rounded;
    }

    return Icons.schedule_rounded;
  }

  String _nextStatus(String status) {
    final value = status.toLowerCase().trim();

    if (value == 'pending') return 'Processing';
    if (value == 'processing') return 'Shipped';
    if (value == 'shipped') return 'Delivered';

    return 'Processing';
  }

  String _nextButtonText(String status) {
    final next = _nextStatus(status);

    if (next == 'Delivered') {
      return "Mark Delivered";
    }

    return "Move to $next";
  }

  // ================= BUILD UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,

      appBar: AppBar(
        backgroundColor: appGreen,
        surfaceTintColor: appGreen,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: kToolbarHeight,
        iconTheme: const IconThemeData(
          color: darkText,
        ),
        title: const Text(
          "Active Orders",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: darkText,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(
              Icons.refresh_rounded,
              color: darkText,
            ),
            onPressed: fetchActiveOrders,
          ),
          const SizedBox(width: 6),
        ],
      ),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF22C55E),
              ),
            )
          : activeOrders.isEmpty
              ? _emptyView()
              : RefreshIndicator(
                  onRefresh: fetchActiveOrders,
                  color: const Color(0xFF22C55E),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      _summaryCard()
                          .animate()
                          .fadeIn(duration: 350.ms)
                          .slideY(begin: 0.08),
                      const SizedBox(height: 18),
                      const Text(
                        "Orders In Progress",
                        style: TextStyle(
                          color: darkText,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(activeOrders.length, (index) {
                        final order = activeOrders[index];

                        return _buildOrderCard(order)
                            .animate()
                            .fadeIn(
                              duration: 350.ms,
                              delay: (index * 70).ms,
                            )
                            .slideY(
                              begin: 0.08,
                              end: 0,
                              duration: 350.ms,
                            );
                      }),
                    ],
                  ),
                ),
    );
  }

  Widget _summaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: darkText,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -38,
            top: -44,
            child: _GlowCircle(
              size: 130,
              opacity: 0.08,
            ),
          ),
          Positioned(
            left: -44,
            bottom: -50,
            child: _GlowCircle(
              size: 145,
              opacity: 0.06,
            ),
          ),
          Row(
            children: [
              Container(
                height: 58,
                width: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: appGreen,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Active Order Queue",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${activeOrders.length} order${activeOrders.length == 1 ? '' : 's'} need your attention",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.74),
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

  Widget _emptyView() {
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
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: borderColor,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.045),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 92,
                width: 92,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFBBF7D0),
                  ),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  size: 50,
                  color: Color(0xFF16A34A),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "No Active Orders",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: darkText,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Pending, processing, and shipped orders will appear here.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: mutedText,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 350.ms).scale(),
      ),
    );
  }

  // ================= ORDER CARD =================
  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status']?.toString() ?? 'Pending';
    final statusColor = _statusColor(status);
    final statusBg = _statusBgColor(status);
    final amount = _amount(order['total_amount']);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Icon(
                  _statusIcon(status),
                  color: statusColor,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Order #${_orderNumber(order)}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: darkText,
                        fontWeight: FontWeight.w900,
                        fontSize: 16.2,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Customer: ${_shortCustomerId(order['user_id'])}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: mutedText,
                        fontSize: 12.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.16),
                  ),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: borderColor,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _infoItem(
                    icon: Icons.payments_outlined,
                    title: "Amount",
                    value: "PKR ${amount.toStringAsFixed(0)}",
                    color: const Color(0xFF16A34A),
                  ),
                ),
                Container(
                  width: 1,
                  height: 42,
                  color: borderColor,
                ),
                Expanded(
                  child: _infoItem(
                    icon: Icons.calendar_today_outlined,
                    title: "Placed",
                    value: _formatDate(order['created_at']),
                    color: const Color(0xFF4F46E5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () {
                final next = _nextStatus(status);
                updateOrderStatus(order, next);
              },
              icon: Icon(
                _nextStatus(status) == 'Delivered'
                    ? Icons.check_circle_outline_rounded
                    : Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 19,
              ),
              label: Text(
                _nextButtonText(status),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: statusColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: color,
            size: 19,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: mutedText,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: darkText,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ================= GLOW CIRCLE =================
class _GlowCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _GlowCircle({
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}