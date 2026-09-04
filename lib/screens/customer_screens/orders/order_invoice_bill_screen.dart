import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/invoice_service.dart';
import '../../../theme/app_theme.dart';

class OrderInvoiceBillScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderInvoiceBillScreen({
    super.key,
    required this.order,
  });

  @override
  State<OrderInvoiceBillScreen> createState() => _OrderInvoiceBillScreenState();
}

class _OrderInvoiceBillScreenState extends State<OrderInvoiceBillScreen> {
  final supabase = Supabase.instance.client;
  late Map<String, dynamic> order;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    order = Map<String, dynamic>.from(widget.order);
    fetchOrderItems();
  }

  Future<void> fetchOrderItems() async {
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
        debugPrint("Invoice select join error: $e");
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
          debugPrint("Invoice fetch order_items error: $e");
        }
      }

      if (!mounted) return;

      setState(() {
        order = updatedOrder!;
      });
    } catch (e) {
      debugPrint("Fetch invoice order items error: $e");
    }
  }

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
            'Fashion Item';

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

  bool isItemsExpanded = false;

  String _formatDeliveryDateWindow(dynamic value) {
    final raw = value?.toString();
    DateTime date = DateTime.now();
    if (raw != null && raw.isNotEmpty) {
      date = DateTime.tryParse(raw) ?? DateTime.now();
    }
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

  @override
  Widget build(BuildContext context) {
    final items = _orderItems();
    final subtotal = _calculateSubtotal(items);
    final total = _amount(order['total_amount']);
    final shippingFee = total > subtotal ? (total - subtotal) : 0.0;
    final status = _status();
    final statusColor = _statusColor(status);
    final paymentMethod = order['payment_method']?.toString() ?? 'Cash on Delivery';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      // ================= COMPACT WHITE APP BAR =================
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        toolbarHeight: 46.0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.slateDark, size: 21),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Tax Invoice & Receipt",
          style: TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 16.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Copy Receipt",
            icon: const Icon(Icons.copy_rounded, color: AppColors.slateDark, size: 19),
            onPressed: () => InvoiceService.copyInvoiceToClipboard(context, order),
          ),
          IconButton(
            tooltip: "Share via WhatsApp",
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF10B981), size: 21),
            onPressed: () => InvoiceService.shareViaWhatsApp(recipientPhone: order['phone'], order: order),
          ),
          IconButton(
            tooltip: "Print / Save PDF",
            icon: const Icon(Icons.print_rounded, color: AppColors.primary, size: 21),
            onPressed: () => InvoiceService.printOrSavePdfInvoice(context: context, order: order),
          ),
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Icons.refresh_rounded, color: AppColors.slateDark, size: 20),
            onPressed: fetchOrderItems,
          ),
          const SizedBox(width: 4),
        ],
      ),

      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================= 1. INVOICE OVERVIEW CARD (WITH STYLUXE BRANDING) =================
                  _customCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Brand Row: StyLuxe + Official Tax Invoice Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: const TextSpan(
                                    children: [
                                      TextSpan(
                                        text: "Sty",
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.slateDark,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      TextSpan(
                                        text: "Luxe",
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 1),
                                const Text(
                                  "OFFICIAL TAX INVOICE",
                                  style: TextStyle(
                                    color: AppColors.slateMuted,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),

                            // Live Status Badge
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

                        const SizedBox(height: 10),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 10),

                        // Order & Invoice Numbers
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Invoice #INV-${_orderNumber()}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.slateDark,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Order #${_orderNumber()}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.slateMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
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
                                "Rs. ${total.toStringAsFixed(0)}",
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

                        // Location
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: Color(0xFFE11D48),
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
                                    order['address']?.toString() ?? "No delivery address recorded",
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

                        // Delivery Date & Time
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              color: Color(0xFFE11D48),
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
                                      "Purchased Items (${items.length})",
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

                        // Collapsed Preview
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
                                  // Mini Thumbnails
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
                                "No items recorded on this invoice",
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
                                            "Qty: $qty × Rs. ${price.toStringAsFixed(0)}",
                                            style: const TextStyle(
                                              color: AppColors.slateMuted,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
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
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ================= 4. FINANCIAL SUMMARY CARD =================
                  _customCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Invoice Financial Summary",
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
                        _billSummaryRow("Sales Tax / VAT (0%)", "Rs. 0"),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Total Amount Paid",
                              style: TextStyle(
                                color: AppColors.slateDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              "Rs. ${total.toStringAsFixed(0)}",
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

                  const SizedBox(height: 12),

                  // ================= 5. OFFICIAL FOOTER STAMP =================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.20)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_rounded, size: 16, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text(
                          "StyLuxe Verified Tax Invoice • 7-Day Warranty",
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ================= 6. COMPACT ACTION BUTTONS =================
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: ElevatedButton.icon(
                            onPressed: () => InvoiceService.shareViaWhatsApp(recipientPhone: order['phone'], order: order),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 16),
                            label: const Text("WhatsApp", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: const Color(0xFF10B981),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: ElevatedButton.icon(
                            onPressed: () => InvoiceService.printOrSavePdfInvoice(context: context, order: order),
                            icon: const Icon(Icons.print_rounded, color: Colors.white, size: 16),
                            label: const Text("Print / Save PDF", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
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
                ],
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
          style: const TextStyle(
            color: AppColors.slateDark,
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
}
