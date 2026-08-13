// ignore_for_file: unnecessary_cast

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'order_tracking_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailScreen({
    super.key,
    required this.order,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final supabase = Supabase.instance.client;

  late Map<String, dynamic> order;
  StreamSubscription<List<Map<String, dynamic>>>? _orderSubscription;

  @override
  void initState() {
    super.initState();
    order = Map<String, dynamic>.from(widget.order);

    fetchLatestOrder();
    setupRealtimeOrder();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }

  // ================= FETCH LATEST ORDER =================
  Future<void> fetchLatestOrder() async {
    try {
      final orderId = order['id'];

      if (orderId == null) return;

      final data = await supabase
          .from('orders')
          .select('*')
          .eq('id', orderId)
          .maybeSingle();

      if (!mounted || data == null) return;

      setState(() {
        order = Map<String, dynamic>.from(data);
      });
    } catch (e) {
      debugPrint("Fetch latest order error: $e");
    }
  }

  // ================= REALTIME ORDER STATUS =================
  void setupRealtimeOrder() {
    try {
      final orderId = order['id'];

      if (orderId == null) return;

      _orderSubscription = supabase
          .from('orders')
          .stream(primaryKey: ['id'])
          .eq('id', orderId)
          .listen(
            (data) {
              if (!mounted) return;

              if (data.isNotEmpty) {
                setState(() {
                  order = Map<String, dynamic>.from(data.first);
                });
              }
            },
            onError: (error) {
              debugPrint("Order detail realtime error: $error");
            },
          );
    } catch (e) {
      debugPrint("Realtime setup error: $e");
    }
  }

  // ================= HELPERS =================
  String _orderNumber() {
    final orderId = order['order_id']?.toString();

    if (orderId != null && orderId.trim().isNotEmpty) {
      return orderId;
    }

    final id = order['id']?.toString() ?? '00000000';

    return id.length >= 8 ? id.substring(0, 8) : id;
  }

  String _status() {
    return order['status']?.toString() ?? 'Pending';
  }

  Color _statusColor(String status) {
    final value = status.toLowerCase();

    if (value == 'delivered') return const Color(0xFF16A34A);
    if (value == 'shipped') return const Color(0xFF2563EB);
    if (value == 'processing') return const Color(0xFF7C3AED);
    if (value == 'cancelled' || value == 'canceled') {
      return const Color(0xFFDC2626);
    }

    return const Color(0xFFF59E0B);
  }

  IconData _statusIcon(String status) {
    final value = status.toLowerCase();

    if (value == 'delivered') return Icons.check_circle_rounded;
    if (value == 'shipped') return Icons.local_shipping_rounded;
    if (value == 'processing') return Icons.sync_rounded;
    if (value == 'cancelled' || value == 'canceled') {
      return Icons.cancel_rounded;
    }

    return Icons.access_time_filled_rounded;
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString();

    if (raw == null || raw.isEmpty) return "N/A";

    final date = DateTime.tryParse(raw);

    if (date == null) {
      return raw.length >= 16 ? raw.substring(0, 16) : raw;
    }

    return "${date.day.toString().padLeft(2, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.year}  "
        "${date.hour.toString().padLeft(2, '0')}:"
        "${date.minute.toString().padLeft(2, '0')}";
  }

  double _amount(dynamic value) {
    return (value as num?)?.toDouble() ?? 0.0;
  }

  List<Map<String, dynamic>> _orderItems() {
    final items = order['items'];

    if (items is List) {
      return items
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final status = _status();
    final statusColor = _statusColor(status);
    final items = _orderItems();
    final totalAmount = _amount(order['total_amount']);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      // ================= SAME PREVIOUS APP BAR =================
      appBar: AppBar(
        backgroundColor: const Color(0xFFA8E063),
        surfaceTintColor: const Color(0xFFA8E063),
        elevation: 0,
        centerTitle: false,
        toolbarHeight: kToolbarHeight,
        iconTheme: const IconThemeData(
          color: Color(0xFF111827),
        ),
        title: const Text(
          "Order Details",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Color(0xFF111827),
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
              color: Color(0xFF111827),
            ),
            onPressed: fetchLatestOrder,
          ),
          const SizedBox(width: 6),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: fetchLatestOrder,
        color: const Color(0xFF22C55E),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= ORDER HEADER =================
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 52,
                          width: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF6366F1),
                                Color(0xFF8B5CF6),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Order #${_orderNumber()}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF111827),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "Placed on ${_formatDate(order['created_at'])}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _statusIcon(status),
                            color: statusColor,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Current Status: $status",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              _sectionTitle("Delivery Address"),

              const SizedBox(height: 10),

              _sectionCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFF22C55E),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        order['address']?.toString() ?? "No address provided",
                        softWrap: true,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 14.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              _sectionTitle("Payment Information"),

              const SizedBox(height: 10),

              _sectionCard(
                child: Row(
                  children: [
                    Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.payments_outlined,
                        color: Color(0xFF22C55E),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order['payment_method']?.toString() ??
                                "Cash on Delivery",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Payment Status: ${order['payment_status']?.toString() ?? 'Paid'}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              _sectionTitle("Order Items"),

              const SizedBox(height: 10),

              if (items.isEmpty)
                _sectionCard(
                  child: Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "No items found",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...items.map((item) {
                  return _OrderItemTile(item: item);
                }),

              const SizedBox(height: 20),

              // ================= TOTAL CARD =================
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF22C55E),
                      Color(0xFF16A34A),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.26),
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Total Amount",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      "PKR ${totalAmount.toStringAsFixed(0)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderTrackingScreen(
                          order: order,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.track_changes_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: const Text(
                    "Track Order",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF111827),
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _sectionCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ================= ORDER ITEM TILE =================
class _OrderItemTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _OrderItemTile({
    required this.item,
  });

  double _amount(dynamic value) {
    return (value as num?)?.toDouble() ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final name = item['product_name']?.toString() ??
        item['name']?.toString() ??
        'Product';

    final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
    final price = _amount(item['price']);
    final total = price * quantity;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFF6366F1),
              size: 24,
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
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Qty: $quantity × PKR ${price.toStringAsFixed(0)}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Text(
            "PKR ${total.toStringAsFixed(0)}",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF16A34A),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}