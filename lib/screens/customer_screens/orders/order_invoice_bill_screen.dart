import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  @override
  Widget build(BuildContext context) {
    final items = _orderItems();
    final subtotal = _calculateSubtotal(items);
    final total = _amount(order['total_amount']);
    final shippingFee = total > subtotal ? (total - subtotal) : 0.0;
    final status = _status();
    final statusColor = _statusColor(status);

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
          "Tax Invoice & Bill",
          style: TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Copy Summary",
            icon: const Icon(Icons.copy_rounded, color: AppColors.slateDark, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(
                text: "StyLuxe Invoice #INV-${_orderNumber()}\n"
                    "Order Ref: #${_orderNumber()}\n"
                    "Date: ${_formatDate(order['created_at'])}\n"
                    "Total Amount: Rs. ${total.toStringAsFixed(0)}\n"
                    "Status: $status\n"
                    "Address: ${order['address'] ?? 'N/A'}"
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Invoice bill copied to clipboard!"),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
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
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                children: [
                  // ================= OFFICIAL INVOICE PAPER CARD =================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- 1. INVOICE HEADER BRAND BANNER ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.slateDark,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      TextSpan(
                                        text: "Luxe",
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  "OFFICIAL TAX INVOICE",
                                  style: TextStyle(
                                    color: AppColors.slateMuted,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),
                        const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
                        const SizedBox(height: 16),

                        // --- 2. INVOICE META DATA (BILL TO & ORDER INFO) ---
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _metaTitle("INVOICE NUMBER"),
                                  _metaValue("#INV-${_orderNumber()}"),
                                  const SizedBox(height: 10),
                                  _metaTitle("ORDER REFERENCE"),
                                  _metaValue("#ORD-${_orderNumber()}"),
                                  const SizedBox(height: 10),
                                  _metaTitle("DATE & TIME"),
                                  _metaValue(_formatDate(order['created_at'])),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _metaTitle("DELIVERY ADDRESS"),
                                  _metaValue(order['address']?.toString() ?? "N/A"),
                                  const SizedBox(height: 10),
                                  _metaTitle("PAYMENT METHOD"),
                                  _metaValue(order['payment_method']?.toString() ?? "Cash on Delivery"),
                                  const SizedBox(height: 10),
                                  _metaTitle("PAYMENT STATUS"),
                                  _metaValue(order['payment_status']?.toString() ?? "Completed / COD"),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),
                        const Text(
                          "PURCHASED ITEMS BREAKDOWN",
                          style: TextStyle(
                            color: AppColors.slateMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // --- 3. ITEMIZED MULTIPLICATION TABLE ---
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              // Table Header Row
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                                ),
                                child: const Row(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Text(
                                        "Item Name",
                                        style: TextStyle(
                                          color: AppColors.slateDark,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        "Qty × Price",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppColors.slateDark,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        "Total",
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: AppColors.slateDark,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Table Item Rows
                              if (items.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: Center(
                                    child: Text(
                                      "No item breakdown recorded",
                                      style: TextStyle(color: AppColors.slateMuted, fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                )
                              else
                                ...items.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final item = entry.value;

                                  final name = item['product_name']?.toString() ?? item['name']?.toString() ?? 'Product ${index + 1}';
                                  final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                                  final unitPrice = _amount(item['price']);
                                  final lineTotal = unitPrice * qty;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: index < items.length - 1
                                          ? const Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        // Item Name & Category
                                        Expanded(
                                          flex: 5,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "${index + 1}. $name",
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: AppColors.slateDark,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Qty x Unit Price Calculation Formula
                                        Expanded(
                                          flex: 4,
                                          child: Text(
                                            "$qty × Rs. ${unitPrice.toStringAsFixed(0)}",
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: AppColors.slateMuted,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),

                                        // Total Price
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            "Rs. ${lineTotal.toStringAsFixed(0)}",
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              color: AppColors.slateDark,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        // --- 4. FINANCIAL SUMMARY BREAKDOWN ---
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              _summaryRow("Subtotal", "Rs. ${subtotal.toStringAsFixed(0)}"),
                              const SizedBox(height: 8),
                              _summaryRow("Delivery Charges", shippingFee > 0 ? "Rs. ${shippingFee.toStringAsFixed(0)}" : "FREE"),
                              const SizedBox(height: 8),
                              _summaryRow("Sales Tax / VAT (0%)", "Rs. 0"),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Divider(color: Color(0xFFCBD5E1)),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "GRAND TOTAL PAID",
                                    style: TextStyle(
                                      color: AppColors.slateDark,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    "Rs. ${total.toStringAsFixed(0)}",
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
                        ),

                        const SizedBox(height: 24),
                        const Divider(color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 14),

                        // --- 5. OFFICIAL FOOTER STAMP & WARRANTY ---
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_rounded, size: 16, color: AppColors.primary),
                                    SizedBox(width: 6),
                                    Text(
                                      "StyLuxe Verified Tax Invoice",
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Thank you for shopping at StyLuxe Fashion! 7-Day Replacement Warranty applies.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.slateMuted,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05),

                  const SizedBox(height: 24),

                  // ================= BOTTOM ACTION BUTTONS =================
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(
                              text: "StyLuxe Tax Invoice #${_orderNumber()}\nTotal Amount: Rs. ${total.toStringAsFixed(0)}\nStatus: $status"
                            ));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Invoice bill copied to clipboard!"),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, color: AppColors.slateDark, size: 18),
                          label: const Text("Copy Bill", style: TextStyle(color: AppColors.slateDark, fontWeight: FontWeight.w800, fontSize: 14)),
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Downloading official Tax Invoice PDF..."),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          },
                          icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
                          label: const Text("Download PDF", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            elevation: 0,
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _metaTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.slateMuted,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _metaValue(String value) {
    return Text(
      value,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.slateDark,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.slateMuted, fontSize: 13.5, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(color: AppColors.slateDark, fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
