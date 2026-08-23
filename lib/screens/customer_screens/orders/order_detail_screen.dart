import 'dart:async';
import 'package:flutter/material.dart';
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
  bool isItemsExpanded = false;
  bool isLoadingItems = false;

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

  // ================= FETCH LATEST ORDER WITH ROBUST FALLBACKS =================
  Future<void> fetchLatestOrder() async {
    try {
      final orderId = order['id']?.toString() ?? order['order_id']?.toString();
      if (orderId == null || orderId.isEmpty) return;

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

      // 3. Explicit order_items query if items list is empty
      final itemsList = updatedOrder['order_items'];
      if (itemsList == null || (itemsList is List && itemsList.isEmpty)) {
        try {
          final itemsData = await supabase
              .from('order_items')
              .select('*, products(*)')
              .eq('order_id', orderId);

          if (itemsData.isNotEmpty) {
            updatedOrder['order_items'] = itemsData;
          } else {
            // Fallback direct order_items with manual product lookup
            final rawItems = await supabase
                .from('order_items')
                .select('*')
                .eq('order_id', orderId);

            if (rawItems.isNotEmpty) {
              List<Map<String, dynamic>> enriched = [];
              for (final raw in rawItems) {
                final rMap = Map<String, dynamic>.from(raw);
                final prodId = rMap['product_id']?.toString();
                if (prodId != null && prodId.isNotEmpty) {
                  try {
                    final prodData = await supabase
                        .from('products')
                        .select('*')
                        .eq('id', prodId)
                        .maybeSingle();
                    if (prodData != null) {
                      rMap['products'] = prodData;
                    }
                  } catch (_) {}
                }
                enriched.add(rMap);
              }
              updatedOrder['order_items'] = enriched;
            }
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

  // ================= REALTIME ORDER STATUS (PRESERVES ITEMS) =================
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
                  final newOrder = Map<String, dynamic>.from(data.first);
                  // Preserve existing loaded order_items
                  if (order['order_items'] != null &&
                      (order['order_items'] is List) &&
                      (order['order_items'] as List).isNotEmpty) {
                    newOrder['order_items'] = order['order_items'];
                  }
                  order = newOrder;
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

  String _formatDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return "N/A";
    final date = DateTime.tryParse(raw);
    if (date == null) {
      return raw.length >= 16 ? raw.substring(0, 16) : raw;
    }
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    String daySuffix(int day) {
      if (day >= 11 && day <= 13) return 'th';
      switch (day % 10) {
        case 1: return 'st';
        case 2: return 'nd';
        case 3: return 'rd';
        default: return 'th';
      }
    }
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = date.minute.toString().padLeft(2, '0');
    final hourStr = hour.toString().padLeft(2, '0');

    return "${date.day}${daySuffix(date.day)} ${months[date.month - 1]} ${date.year}, $hourStr:$minuteStr $ampm";
  }

  String _formatDeliveryDateWindow(dynamic value) {
    final raw = value?.toString();
    DateTime date = DateTime.now();
    if (raw != null && raw.isNotEmpty) {
      date = DateTime.tryParse(raw) ?? DateTime.now();
    }
    // Estimated 3 days window
    final deliveryDate = date.add(const Duration(days: 3));
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    String daySuffix(int day) {
      if (day >= 11 && day <= 13) return 'th';
      switch (day % 10) {
        case 1: return 'st';
        case 2: return 'nd';
        case 3: return 'rd';
        default: return 'th';
      }
    }
    return "${deliveryDate.day}${daySuffix(deliveryDate.day)} ${months[deliveryDate.month - 1]} ${deliveryDate.year} (08:00PM - 09:00PM)";
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
    final paymentMethod = order['payment_method']?.toString() ?? 'Cash On Delivery';
    final isPending = status.toLowerCase() == 'pending' || status.toLowerCase() == 'processing';
    final isDelivered = status.toLowerCase() == 'delivered' || status.toLowerCase() == 'completed';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      // ================= COMPACT APP BAR =================
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        toolbarHeight: 46.0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.slateDark, size: 17),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Order Details",
          style: TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 16.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "View Bill",
            icon: const Icon(Icons.receipt_outlined, color: AppColors.primary, size: 20),
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
            constraints: const BoxConstraints(maxWidth: 800),
            child: RefreshIndicator(
              onRefresh: fetchLatestOrder,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================= 1. ORDER OVERVIEW TOP CARD =================
                    _customCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  "Order #${_orderNumber()}",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.slateDark,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              // Status pill badge with live colored dot
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formatDate(order['created_at']),
                            style: const TextStyle(
                              color: AppColors.slateMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 12),

                          // 3-Column Info Row
                          Row(
                            children: [
                              Expanded(
                                child: _overviewColumn(
                                  "Items",
                                  items.isNotEmpty
                                      ? items.length.toString().padLeft(2, '0')
                                      : "01",
                                ),
                              ),
                              Expanded(
                                child: _overviewColumn(
                                  "Total Paid",
                                  "Rs. ${totalAmount.toStringAsFixed(0)}",
                                  isAmount: true,
                                ),
                              ),
                              Expanded(
                                child: _overviewColumn(
                                  "Payment",
                                  paymentMethod,
                                  isAlignRight: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ================= 2. DELIVERY INFORMATION CARD =================
                    _customCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Delivery Information",
                            style: TextStyle(
                              color: AppColors.slateDark,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Location row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: Color(0xFFE11D48), // Red/coral location pin
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Location",
                                      style: TextStyle(
                                        color: Color(0xFFE11D48),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      order['address']?.toString() ?? "No delivery address provided",
                                      style: const TextStyle(
                                        color: AppColors.slateDark,
                                        fontSize: 12,
                                        height: 1.35,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Delivery Date & Time row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                color: Color(0xFFE11D48), // Calendar icon
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Delivery Date & Time",
                                      style: TextStyle(
                                        color: Color(0xFFE11D48),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDeliveryDateWindow(order['created_at']),
                                      style: const TextStyle(
                                        color: AppColors.slateDark,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ================= 3. ITEMS CARD (EXPANDABLE DROPDOWN) =================
                    _customCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dropdown Header Row
                          InkWell(
                            onTap: () {
                              setState(() {
                                isItemsExpanded = !isItemsExpanded;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        "Items (${items.length})",
                                        style: const TextStyle(
                                          color: AppColors.slateDark,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.10),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isItemsExpanded ? "Tap to hide" : "Tap to view",
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Icon(
                                    isItemsExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Collapsed Preview Bar
                          if (!isItemsExpanded && items.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => setState(() => isItemsExpanded = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFF1F5F9)),
                                ),
                                child: Row(
                                  children: [
                                    // Mini thumbnails
                                    SizedBox(
                                      height: 28,
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        scrollDirection: Axis.horizontal,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: items.length > 3 ? 3 : items.length,
                                        itemBuilder: (context, idx) {
                                          final img = items[idx]['image_url']?.toString() ?? '';
                                          return Container(
                                            width: 28,
                                            height: 28,
                                            margin: const EdgeInsets.only(right: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(5),
                                              child: img.isNotEmpty
                                                  ? Image.network(
                                                      img,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) => const Icon(
                                                        Icons.checkroom_rounded,
                                                        size: 14,
                                                        color: AppColors.slateMuted,
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons.checkroom_rounded,
                                                      size: 14,
                                                      color: AppColors.slateMuted,
                                                    ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        items.length > 1
                                            ? "${items.first['product_name']} +${items.length - 1} more"
                                            : "${items.first['product_name']}",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.slateDark,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.slateMuted),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          // Expanded Items List
                          if (isItemsExpanded) ...[
                            const SizedBox(height: 8),
                            if (items.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  "No items detailed for this order",
                                  style: TextStyle(color: AppColors.slateMuted, fontSize: 12),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: items.length,
                                separatorBuilder: (context, index) => const Divider(height: 12, thickness: 0.8, color: Color(0xFFF8FAFC)),
                                itemBuilder: (context, idx) {
                                  final itm = items[idx];
                                  final name = itm['product_name']?.toString() ?? 'Product Item';
                                  final qty = (itm['quantity'] as num?)?.toInt() ?? 1;
                                  final price = _amount(itm['price']);
                                  final lineTotal = price * qty;
                                  final img = itm['image_url']?.toString() ?? '';

                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Thumbnail
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(7),
                                          child: img.isNotEmpty
                                              ? Image.network(
                                                  img,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) => const Icon(
                                                    Icons.checkroom_rounded,
                                                    color: AppColors.slateMuted,
                                                    size: 18,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.checkroom_rounded,
                                                  color: AppColors.slateMuted,
                                                  size: 18,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      // Product details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppColors.slateDark,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                height: 1.25,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "x$qty",
                                              style: const TextStyle(
                                                color: AppColors.slateMuted,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Price
                                      Text(
                                        "Rs. ${lineTotal.toStringAsFixed(0)}",
                                        style: const TextStyle(
                                          color: Color(0xFFE11D48),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),

                            // Cancel Order centered link if pending
                            if (isPending) ...[
                              const SizedBox(height: 10),
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              const SizedBox(height: 8),
                              Center(
                                child: InkWell(
                                  onTap: () => _showCancelOrderModal(context),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                                    child: Text(
                                      "Cancel Order",
                                      style: TextStyle(
                                        color: Color(0xFFE11D48),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ================= 4. ORDER SUMMARY CARD =================
                    _customCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Order Summary",
                            style: TextStyle(
                              color: AppColors.slateDark,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _billSummaryRow("Subtotal", "Rs. ${subtotal.toStringAsFixed(0)}"),
                          const SizedBox(height: 6),
                          _billSummaryRow("Delivery Fee", shippingFee > 0 ? "Rs. ${shippingFee.toStringAsFixed(0)}" : "FREE"),
                          const SizedBox(height: 6),
                          _billSummaryRow("Sales Tax / VAT", "Rs. 0"),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Total",
                                style: TextStyle(
                                  color: AppColors.slateDark,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                "Rs. ${totalAmount.toStringAsFixed(0)}",
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ================= 5. COMPACT ACTION BUTTONS =================
                    if (isCancelled)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cancel_rounded, color: AppColors.roseRed, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                order['cancellation_reason'] != null
                                    ? "Cancelled: ${order['cancellation_reason']}"
                                    : "Order was cancelled. No payment was deducted.",
                                style: const TextStyle(color: Color(0xFF991B1B), fontSize: 11.5, fontWeight: FontWeight.w600),
                              ),
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
                              child: OutlinedButton.icon(
                                onPressed: () => _navigateToBillScreen(context),
                                icon: const Icon(Icons.receipt_long_rounded, color: AppColors.slateDark, size: 15),
                                label: const Text("View Bill", style: TextStyle(color: AppColors.slateDark, fontWeight: FontWeight.w700, fontSize: 12.5)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 38,
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
                                icon: const Icon(Icons.track_changes_rounded, color: Colors.white, size: 15),
                                label: const Text("Track Order", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                    // Return request button if delivered
                    if (isDelivered) ...[
                      const SizedBox(height: 8),
                      if (returnRequest != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            "${returnRequest!['type'] ?? 'Return'} Requested (${returnRequest!['status'] ?? 'Pending'})",
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 38,
                          child: OutlinedButton.icon(
                            onPressed: () => _showReturnExchangeModal(context),
                            icon: const Icon(Icons.published_with_changes_rounded, color: AppColors.primary, size: 15),
                            label: const Text("Request Return / Exchange", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _customCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _overviewColumn(String label, String value, {bool isAmount = false, bool isAlignRight = false}) {
    return Column(
      crossAxisAlignment: isAlignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.slateMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isAmount ? AppColors.slateDark : AppColors.slateDark,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _billSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.slateMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.slateDark,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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