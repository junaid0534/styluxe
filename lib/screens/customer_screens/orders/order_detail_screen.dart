// ignore_for_file: unnecessary_cast

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/app_theme.dart';
import 'order_invoice_bill_screen.dart';
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

  Map<String, dynamic>? returnRequest;

  @override
  void initState() {
    super.initState();
    order = Map<String, dynamic>.from(widget.order);

    fetchLatestOrder();
    _fetchReturnRequest();
    setupRealtimeOrder();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchReturnRequest() async {
    try {
      final orderId = order['id'];
      if (orderId == null) return;

      final data = await supabase
          .from('return_requests')
          .select('*')
          .eq('order_id', orderId)
          .maybeSingle();

      if (mounted && data != null) {
        setState(() {
          returnRequest = Map<String, dynamic>.from(data);
        });
      }
    } catch (_) {}
  }

  // ================= FETCH LATEST ORDER =================
  Future<void> fetchLatestOrder() async {
    try {
      final orderId = order['id'];
      if (orderId == null) return;

      Map<String, dynamic>? updatedOrder;

      // 1. Attempt join query
      try {
        final data = await supabase
            .from('orders')
            .select('*, order_items(*, products(*))')
            .eq('id', orderId)
            .maybeSingle();
        if (data != null) {
          updatedOrder = Map<String, dynamic>.from(data);
        }
      } catch (e) {
        debugPrint("Join select error: $e");
      }

      // 2. Fallback single order query
      if (updatedOrder == null) {
        final data = await supabase
            .from('orders')
            .select('*')
            .eq('id', orderId)
            .maybeSingle();
        if (data != null) {
          updatedOrder = Map<String, dynamic>.from(data);
        }
      }

      if (updatedOrder == null) return;

      // 3. Fetch explicit order_items if list is empty
      final itemsList = updatedOrder['order_items'];
      if (itemsList == null || (itemsList is List && itemsList.isEmpty)) {
        try {
          final itemsData = await supabase
              .from('order_items')
              .select('*, products(*)')
              .eq('order_id', orderId);

          if (itemsData.isNotEmpty) {
            updatedOrder['order_items'] = itemsData;
          }
        } catch (e) {
          debugPrint("Fetch order_items error: $e");
        }
      }

      if (!mounted) return;

      setState(() {
        order = updatedOrder!;
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
    return id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
  }

  String _status() {
    return order['status']?.toString() ?? 'Pending';
  }

  Color _statusColor(String status) {
    final value = status.toLowerCase();
    if (value == 'delivered') return const Color(0xFF10B981);
    if (value == 'shipped') return const Color(0xFF3B82F6);
    if (value == 'processing') return const Color(0xFF8B5CF6);
    if (value == 'cancelled' || value == 'canceled') return const Color(0xFFEF4444);
    return const Color(0xFFF59E0B);
  }

  IconData _statusIcon(String status) {
    final value = status.toLowerCase();
    if (value == 'delivered') return Icons.check_circle_rounded;
    if (value == 'shipped') return Icons.local_shipping_rounded;
    if (value == 'processing') return Icons.sync_rounded;
    if (value == 'cancelled' || value == 'canceled') return Icons.cancel_rounded;
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
    final rawItems = order['order_items'] ?? order['items'];
    if (rawItems is List && rawItems.isNotEmpty) {
      return rawItems.whereType<Map>().map((item) {
        final map = Map<String, dynamic>.from(item);
        final product = map['products'] is Map
            ? Map<String, dynamic>.from(map['products'])
            : <String, dynamic>{};

        final productName = map['product_name'] ??
            map['name'] ??
            product['name'] ??
            'Fashion Product';

        final qty = (map['quantity'] as num?)?.toInt() ?? 1;
        final price = (map['price'] as num?)?.toDouble() ??
            (product['price'] as num?)?.toDouble() ??
            0.0;

        final imageUrl = map['image_url'] ??
            map['image'] ??
            product['image_url'] ??
            product['image'] ??
            '';

        return {
          'product_name': productName,
          'quantity': qty,
          'price': price,
          'image_url': imageUrl,
        };
      }).toList();
    }
    return [];
  }

  double _calculateSubtotal(List<Map<String, dynamic>> items) {
    double sub = 0.0;
    for (final item in items) {
      final price = _amount(item['price']);
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      sub += (price * qty);
    }
    if (sub == 0.0) {
      sub = _amount(order['total_amount']);
    }
    return sub;
  }



  bool _isCancelled(String status) {
    final value = status.toLowerCase();
    return value == 'cancelled' || value == 'canceled';
  }

  void _navigateToBillScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderInvoiceBillScreen(order: order),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _status();
    final statusColor = _statusColor(status);
    final isCancelled = _isCancelled(status);
    final items = _orderItems();
    final totalAmount = _amount(order['total_amount']);
    final subtotal = _calculateSubtotal(items);
    final shippingFee = totalAmount > subtotal ? (totalAmount - subtotal) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      // ================= PURE WHITE STYLUXE APP BAR =================
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
          "Order Details & Invoice",
          style: TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "View Tax Invoice",
            icon: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 22),
            onPressed: () => _navigateToBillScreen(context),
          ),
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Icons.refresh_rounded, color: AppColors.slateDark, size: 20),
            onPressed: fetchLatestOrder,
          ),
          const SizedBox(width: 4),
        ],
      ),

      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: RefreshIndicator(
              onRefresh: fetchLatestOrder,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================= STYLUXE THEME EMERALD HEADER CARD =================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.28),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.20),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Order #${_orderNumber()}",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatDate(order['created_at']),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.88),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_statusIcon(status), size: 13, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06),

                    const SizedBox(height: 20),

                    // ================= OFFICIAL INVOICE BILL CARD =================
                    _sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Bill Header Title
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.request_quote_outlined, color: AppColors.primary, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    "Tax Invoice & Bill Receipt",
                                    style: TextStyle(
                                      color: AppColors.slateDark,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: () => _navigateToBillScreen(context),
                                icon: const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.primary),
                                label: const Text("View Bill", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13)),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          const Divider(color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 12),

                          // Customer & Delivery Address Info
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "DELIVERY ADDRESS",
                                      style: TextStyle(
                                        color: AppColors.slateMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      order['address']?.toString() ?? "No delivery address provided",
                                      style: const TextStyle(
                                        color: AppColors.slateDark,
                                        fontSize: 13.5,
                                        height: 1.4,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "PAYMENT METHOD",
                                      style: TextStyle(
                                        color: AppColors.slateMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      order['payment_method']?.toString() ?? "Cash on Delivery",
                                      style: const TextStyle(
                                        color: AppColors.slateDark,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Status: ${order['payment_status']?.toString() ?? 'Paid'}",
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.06),

                    const SizedBox(height: 20),

                    // ================= ORDER ITEMS LIST =================
                    _sectionTitle("Purchased Items (${items.length})"),

                    const SizedBox(height: 12),

                    if (items.isEmpty)
                      _sectionCard(
                        child: const Row(
                          children: [
                            Icon(Icons.inventory_2_outlined, color: AppColors.slateMuted),
                            SizedBox(width: 10),
                            Text(
                              "No item details available",
                              style: TextStyle(color: AppColors.slateMuted, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    else
                      ...items.map((item) {
                        return _OrderItemTile(item: item);
                      }),

                    const SizedBox(height: 20),

                    // ================= BILL FINANCIAL BREAKDOWN =================
                    _sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "BILL FINANCIAL SUMMARY",
                            style: TextStyle(
                              color: AppColors.slateMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _billRow("Items Subtotal", "Rs. ${subtotal.toStringAsFixed(0)}"),
                          const SizedBox(height: 8),
                          _billRow("Delivery Fee", shippingFee > 0 ? "Rs. ${shippingFee.toStringAsFixed(0)}" : "FREE"),
                          const SizedBox(height: 8),
                          _billRow("Sales Tax / VAT", "Rs. 0"),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(color: Color(0xFFF1F5F9)),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Grand Total Amount",
                                style: TextStyle(
                                  color: AppColors.slateDark,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                "Rs. ${totalAmount.toStringAsFixed(0)}",
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.06),

                    const SizedBox(height: 24),

                    // ================= BOTTOM ACTION BUTTONS =================
                    if (isCancelled)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cancel_rounded, color: AppColors.roseRed, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Order Cancelled", style: TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w800, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(
                                    order['cancellation_reason'] != null
                                        ? "Reason: ${order['cancellation_reason']}"
                                        : "This order was cancelled. No payment was deducted.",
                                    style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12, height: 1.35),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.06)
                    else
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _navigateToBillScreen(context),
                                  icon: const Icon(Icons.receipt_long_rounded, color: AppColors.slateDark, size: 18),
                                  label: const Text("Print Bill", style: TextStyle(color: AppColors.slateDark, fontWeight: FontWeight.w800, fontSize: 14)),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
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
                                  icon: const Icon(Icons.track_changes_rounded, color: Colors.white, size: 18),
                                  label: const Text("Track Order", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                    elevation: 0,
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (status.toLowerCase() == 'pending' || status.toLowerCase() == 'processing') ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => _showCancelOrderModal(context),
                              icon: const Icon(Icons.cancel_outlined, color: AppColors.roseRed, size: 18),
                              label: const Text("Cancel This Order", style: TextStyle(color: AppColors.roseRed, fontWeight: FontWeight.w800, fontSize: 14)),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                side: const BorderSide(color: Color(0xFFFCA5A5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ] else if (status.toLowerCase() == 'delivered') ...[
                            const SizedBox(height: 12),
                            if (returnRequest != null)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.published_with_changes_rounded, color: AppColors.primary, size: 22),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${returnRequest!['type'] ?? 'Return/Exchange'} Requested (${returnRequest!['status'] ?? 'Pending'})",
                                            style: const TextStyle(color: AppColors.slateDark, fontWeight: FontWeight.w800, fontSize: 13.5),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "Reason: ${returnRequest!['reason'] ?? 'Not specified'}"
                                            "${returnRequest!['exchange_size'] != null ? ' | New Size: ${returnRequest!['exchange_size']}' : ''}",
                                            style: const TextStyle(color: AppColors.slateMuted, fontSize: 11.5, height: 1.3),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              OutlinedButton.icon(
                                onPressed: () => _showReturnExchangeModal(context),
                                icon: const Icon(Icons.published_with_changes_rounded, color: AppColors.primary, size: 18),
                                label: const Text("Request Return / Exchange", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 14)),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(50),
                                  side: const BorderSide(color: AppColors.primary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                          ],
                        ],
                      ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.06),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _billRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.slateMuted,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.slateDark,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.slateDark,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  void _showCancelOrderModal(BuildContext context) {
    final status = _status().toLowerCase();
    if (status == 'shipped' || status == 'delivered') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: 8),
              Text("Shipment In Transit", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ],
          ),
          content: const Text(
            "This order has already been shipped or delivered. Direct cancellation is no longer available. You can request Return or Exchange after receiving the package.",
            style: TextStyle(color: AppColors.slateMuted, fontSize: 13.5, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Got it", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      return;
    }

    String selectedReason = "Changed my mind";
    final commentController = TextEditingController();
    bool isCancelling = false;

    final reasonsList = [
      "Changed my mind",
      "Ordered wrong size / color",
      "Found better price elsewhere",
      "Delivery time is too long",
      "Incorrect delivery address",
      "Other reason",
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.roseRed.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.cancel_outlined, color: AppColors.roseRed, size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Cancel Order", style: TextStyle(color: AppColors.slateDark, fontSize: 18, fontWeight: FontWeight.w900)),
                                Text("Select a reason for order cancellation", style: TextStyle(color: AppColors.slateMuted, fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: AppColors.slateDark),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      const Text("Why are you cancelling?", style: TextStyle(color: AppColors.slateDark, fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),

                      // Reasons Radio List
                      ...reasonsList.map((reason) {
                        final isSelected = selectedReason == reason;
                        return InkWell(
                          onTap: () {
                            setModalState(() => selectedReason = reason);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.roseRed.withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppColors.roseRed : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                  color: isSelected ? AppColors.roseRed : AppColors.slateMuted,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    reason,
                                    style: TextStyle(
                                      color: isSelected ? AppColors.slateDark : AppColors.slateMuted,
                                      fontSize: 13.5,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      if (selectedReason == "Other reason") ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: commentController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: "Please describe your reason...",
                            hintStyle: const TextStyle(color: AppColors.slateMuted, fontSize: 13),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.roseRed)),
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

                      // Submit Cancel Action Button
                      ElevatedButton.icon(
                        onPressed: isCancelling
                            ? null
                            : () async {
                                setModalState(() => isCancelling = true);

                                try {
                                  final orderId = order['id'];
                                  final finalReason = selectedReason == "Other reason" && commentController.text.trim().isNotEmpty
                                      ? commentController.text.trim()
                                      : selectedReason;

                                  try {
                                    await supabase.from('orders').update({
                                      'status': 'Cancelled',
                                      'cancellation_reason': finalReason,
                                      'cancelled_at': DateTime.now().toIso8601String(),
                                    }).eq('id', orderId).select();
                                  } catch (e) {
                                    // Fallback: update status only if optional columns don't exist yet
                                    await supabase.from('orders').update({
                                      'status': 'Cancelled',
                                    }).eq('id', orderId).select();
                                  }

                                  if (mounted) {
                                    setState(() {
                                      order['status'] = 'Cancelled';
                                      order['cancellation_reason'] = finalReason;
                                    });
                                  }

                                  // Add Notification safely with ultra-fallback
                                  final currentUser = supabase.auth.currentUser;
                                  if (currentUser != null) {
                                    try {
                                      await supabase.from('notifications').insert({
                                        'user_id': currentUser.id,
                                        'order_id': orderId,
                                        'title': 'Order Cancelled',
                                        'message': 'Your order #${_orderNumber()} was successfully cancelled.',
                                        'type': 'order',
                                        'is_read': false,
                                      });
                                    } catch (_) {
                                      try {
                                        await supabase.from('notifications').insert({
                                          'user_id': currentUser.id,
                                          'title': 'Order Cancelled',
                                          'message': 'Your order #${_orderNumber()} was successfully cancelled.',
                                          'is_read': false,
                                        });
                                      } catch (_) {
                                        try {
                                          await supabase.from('notifications').insert({
                                            'user_id': currentUser.id,
                                            'title': 'Order Cancelled',
                                            'message': 'Your order #${_orderNumber()} was successfully cancelled.',
                                          });
                                        } catch (finalErr) {
                                          debugPrint("Notification silent fallback: $finalErr");
                                        }
                                      }
                                    }
                                  }

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Order Cancelled Successfully."),
                                        backgroundColor: AppColors.roseRed,
                                      ),
                                    );
                                  }
                                  fetchLatestOrder();
                                } catch (e) {
                                  setModalState(() => isCancelling = false);
                                  debugPrint("Cancel order error: $e");
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Error cancelling order: $e"), backgroundColor: AppColors.roseRed),
                                    );
                                  }
                                }
                              },
                        icon: isCancelling
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.cancel_rounded, color: Colors.white, size: 18),
                        label: Text(isCancelling ? "Cancelling Order..." : "Confirm Cancellation", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: AppColors.roseRed,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showReturnExchangeModal(BuildContext context) {
    String requestType = "Exchange";
    String selectedReason = "Wrong Size / Fitting Issue";
    String selectedSize = "L";
    final addressController = TextEditingController(text: order['address']?.toString() ?? '');
    final cityController = TextEditingController(text: order['city']?.toString() ?? '');
    final phoneController = TextEditingController(text: order['phone']?.toString() ?? '');
    bool isSubmitting = false;

    final reasonsList = [
      "Wrong Size / Fitting Issue",
      "Damaged or Defective Item",
      "Color / Fabric Not As Shown",
      "Received Wrong Product",
      "Quality Not As Expected",
      "Changed Mind",
    ];

    final sizesList = ["XS", "S", "M", "L", "XL", "XXL"];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.published_with_changes_rounded, color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Return / Exchange Request", style: TextStyle(color: AppColors.slateDark, fontSize: 18, fontWeight: FontWeight.w900)),
                                Text("7-Day Hassle Free Return Policy", style: TextStyle(color: AppColors.slateMuted, fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: AppColors.slateDark),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => requestType = "Exchange"),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: requestType == "Exchange" ? AppColors.primary : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: requestType == "Exchange" ? AppColors.primary : const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.swap_horiz_rounded, color: requestType == "Exchange" ? Colors.white : AppColors.slateDark, size: 20),
                                    const SizedBox(height: 4),
                                    Text("Exchange Size", style: TextStyle(color: requestType == "Exchange" ? Colors.white : AppColors.slateDark, fontWeight: FontWeight.w800, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => requestType = "Return"),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: requestType == "Return" ? AppColors.roseRed : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: requestType == "Return" ? AppColors.roseRed : const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.assignment_return_rounded, color: requestType == "Return" ? Colors.white : AppColors.slateDark, size: 20),
                                    const SizedBox(height: 4),
                                    Text("Return (Refund)", style: TextStyle(color: requestType == "Return" ? Colors.white : AppColors.slateDark, fontWeight: FontWeight.w800, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (requestType == "Exchange") ...[
                        const SizedBox(height: 16),
                        const Text("Select New Size:", style: TextStyle(color: AppColors.slateDark, fontSize: 13, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: sizesList.map((sz) {
                            final isSel = selectedSize == sz;
                            return ChoiceChip(
                              label: Text(sz, style: TextStyle(color: isSel ? Colors.white : AppColors.slateDark, fontWeight: FontWeight.w800)),
                              selected: isSel,
                              selectedColor: AppColors.primary,
                              backgroundColor: const Color(0xFFF8FAFC),
                              onSelected: (_) => setModalState(() => selectedSize = sz),
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 16),
                      const Text("Reason for Request:", style: TextStyle(color: AppColors.slateDark, fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),

                      ...reasonsList.map((reason) {
                        final isSelected = selectedReason == reason;
                        return InkWell(
                          onTap: () => setModalState(() => selectedReason = reason),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                  color: isSelected ? AppColors.primary : AppColors.slateMuted,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    reason,
                                    style: TextStyle(
                                      color: isSelected ? AppColors.slateDark : AppColors.slateMuted,
                                      fontSize: 13.5,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 12),
                      const Text("Pickup Address & Contact:", style: TextStyle(color: AppColors.slateDark, fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: addressController,
                        decoration: InputDecoration(
                          hintText: "Pickup Address",
                          hintStyle: const TextStyle(color: AppColors.slateMuted, fontSize: 12.5),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: cityController,
                              decoration: InputDecoration(
                                hintText: "City",
                                hintStyle: const TextStyle(color: AppColors.slateMuted, fontSize: 12.5),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: phoneController,
                              decoration: InputDecoration(
                                hintText: "Phone Number",
                                hintStyle: const TextStyle(color: AppColors.slateMuted, fontSize: 12.5),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      ElevatedButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setModalState(() => isSubmitting = true);

                                try {
                                  final currentUser = supabase.auth.currentUser;
                                  final orderId = order['id'];
                                  final sellerId = order['seller_id'];

                                  final requestData = {
                                    'order_id': orderId,
                                    'user_id': currentUser?.id,
                                    'seller_id': sellerId,
                                    'type': requestType,
                                    'reason': selectedReason,
                                    'exchange_size': requestType == "Exchange" ? selectedSize : null,
                                    'pickup_address': addressController.text.trim(),
                                    'pickup_city': cityController.text.trim(),
                                    'pickup_phone': phoneController.text.trim(),
                                    'status': 'Pending',
                                    'created_at': DateTime.now().toIso8601String(),
                                  };

                                  try {
                                    await supabase.from('return_requests').insert(requestData);
                                    debugPrint("Return request inserted successfully into Supabase!");
                                  } catch (insertErr) {
                                    debugPrint("Return requests table insert error: $insertErr");
                                    try {
                                      await supabase.from('orders').update({
                                        'return_status': '$requestType Requested',
                                      }).eq('id', orderId);
                                    } catch (_) {}
                                  }

                                  if (mounted) {
                                    setState(() {
                                      returnRequest = requestData;
                                    });
                                  }

                                  if (currentUser != null) {
                                    try {
                                      await supabase.from('notifications').insert({
                                        'user_id': currentUser.id,
                                        'title': '$requestType Request Submitted',
                                        'message': 'Your $requestType request for order #${_orderNumber()} has been received.',
                                        'type': 'order',
                                        'is_read': false,
                                      });
                                    } catch (_) {}
                                  }

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("$requestType Request Submitted Successfully!"),
                                        backgroundColor: AppColors.primary,
                                      ),
                                    );
                                  }
                                  _fetchReturnRequest();
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  debugPrint("Return error: $e");
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Error submitting request: $e"), backgroundColor: AppColors.roseRed),
                                    );
                                  }
                                }
                              },
                        icon: isSubmitting
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                        label: Text(isSubmitting ? "Submitting..." : "Submit $requestType Request", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: requestType == "Exchange" ? AppColors.primary : AppColors.roseRed,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ================= ORDER ITEM TILE =================
class _OrderItemTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _OrderItemTile({required this.item});

  double _amount(dynamic value) {
    return (value as num?)?.toDouble() ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final name = item['product_name']?.toString() ?? item['name']?.toString() ?? 'Product';
    final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
    final price = _amount(item['price']);
    final total = price * quantity;
    final String? imageUrl = item['image_url']?.toString() ?? item['image']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 22),
                    )
                  : const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 22),
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
                    color: AppColors.slateDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Qty: $quantity  ×  Rs. ${price.toStringAsFixed(0)}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.slateMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Text(
            "Rs. ${total.toStringAsFixed(0)}",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}