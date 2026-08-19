import 'package:flutter/material.dart';

class SellerOrderInvoiceScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  const SellerOrderInvoiceScreen({
    super.key,
    required this.order,
  });

  static const Color sapphireBlue = Color(0xFF2563EB);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color cardBorderColor = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final rawId = (order['order_id'] ?? order['id'] ?? '').toString();
    final displayId = rawId.length > 10 ? rawId.substring(0, 10).toUpperCase() : rawId.toUpperCase();
    final totalAmt = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final status = (order['status']?.toString() ?? 'Pending').toUpperCase();
    final custName = (order['customer_name']?.toString() ?? 'Customer').trim();
    final phone = order['phone']?.toString() ?? 'N/A';
    final address = order['address']?.toString() ?? 'N/A';
    final city = order['city']?.toString() ?? '';
    final payMethod = (order['payment_method']?.toString() ?? 'Cash on Delivery').toUpperCase();
    final dateStr = order['created_at']?.toString() ?? '';
    final items = (order['order_items'] as List?) ?? [];

    double calculatedSubtotal = 0.0;
    for (var it in items) {
      final qty = (it['quantity'] as num?)?.toInt() ?? 1;
      final price = (it['price'] as num?)?.toDouble() ?? 0.0;
      calculatedSubtotal += (price * qty);
    }
    if (calculatedSubtotal <= 0) calculatedSubtotal = totalAmt;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slateDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Official Order Invoice",
          style: TextStyle(color: slateDark, fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardBorderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================= 1. INVOICE HEADER =================
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: sapphireBlue, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "StyLuxe Outlet",
                                  style: TextStyle(color: slateDark, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                                ),
                                Text("Official Tax & Order Invoice", style: TextStyle(color: slateMuted, fontSize: 11.5, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              "INVOICE #$displayId",
                              style: const TextStyle(color: slateDark, fontSize: 12, fontWeight: FontWeight.w900),
                            ),
                          ),
                          Text(
                            dateStr.length >= 16 ? dateStr.substring(0, 16).replaceAll('T', ' ') : dateStr,
                            style: const TextStyle(color: slateMuted, fontSize: 11.5, fontWeight: FontWeight.w500),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: status == 'DELIVERED' ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: status == 'DELIVERED' ? const Color(0xFF10B981) : sapphireBlue,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(height: 1, thickness: 1.5, color: cardBorderColor),
                  const SizedBox(height: 24),

                  // ================= 2. BILLED TO & SHIPPING INFO =================
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("BILLED TO / CUSTOMER", style: TextStyle(color: slateMuted, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            Text(custName, style: const TextStyle(color: slateDark, fontSize: 15, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 3),
                            Text("Phone: $phone", style: const TextStyle(color: slateDark, fontSize: 12.5, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("DELIVERY ADDRESS", style: TextStyle(color: slateMuted, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            Text(address, style: const TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w700)),
                            if (city.isNotEmpty) Text(city, style: const TextStyle(color: slateMuted, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text("Payment: $payMethod", style: const TextStyle(color: sapphireBlue, fontSize: 12, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ================= 3. ITEMIZED PRODUCTS TABLE =================
                  const Text("ITEMIZED ORDER SUMMARY", style: TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cardBorderColor),
                    ),
                    child: Column(
                      children: [
                        // Table Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(12.5)),
                          ),
                          child: const Row(
                            children: [
                              Expanded(flex: 5, child: Text("ITEM DESCRIPTION", style: TextStyle(color: slateMuted, fontSize: 10.5, fontWeight: FontWeight.w900))),
                              Expanded(flex: 2, child: Text("PRICE", style: TextStyle(color: slateMuted, fontSize: 10.5, fontWeight: FontWeight.w900), textAlign: TextAlign.right)),
                              Expanded(flex: 1, child: Text("QTY", style: TextStyle(color: slateMuted, fontSize: 10.5, fontWeight: FontWeight.w900), textAlign: TextAlign.center)),
                              Expanded(flex: 2, child: Text("TOTAL", style: TextStyle(color: slateMuted, fontSize: 10.5, fontWeight: FontWeight.w900), textAlign: TextAlign.right)),
                            ],
                          ),
                        ),

                        const Divider(height: 1),

                        // Table Rows
                        if (items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text("Standard store order package items.", style: TextStyle(color: slateMuted, fontSize: 12, fontStyle: FontStyle.italic)),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: items.length,
                            separatorBuilder: (ctx, idx) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final it = items[idx];
                              final pMap = it['products'] is Map ? Map<String, dynamic>.from(it['products']) : <String, dynamic>{};
                              final pName = pMap['name']?.toString() ?? 'Product Item';
                              final qty = (it['quantity'] as num?)?.toInt() ?? 1;
                              final price = (it['price'] as num?)?.toDouble() ?? 0.0;
                              final size = pMap['size']?.toString() ?? 'N/A';

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(pName, style: const TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w800)),
                                          if (size != 'N/A') Text("Size: $size", style: const TextStyle(color: slateMuted, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text("Rs. ${price.toStringAsFixed(0)}", style: const TextStyle(color: slateDark, fontSize: 12.5, fontWeight: FontWeight.w700), textAlign: TextAlign.right),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text("$qty", style: const TextStyle(color: slateDark, fontSize: 12.5, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text("Rs. ${(price * qty).toStringAsFixed(0)}", style: const TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w900), textAlign: TextAlign.right),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ================= 4. GRAND TOTAL BOX =================
                  Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorderColor),
                        ),
                        child: Column(
                          children: [
                            _summaryRow("Subtotal", "Rs. ${calculatedSubtotal.toStringAsFixed(0)}"),
                            const SizedBox(height: 6),
                            _summaryRow("Delivery Charge", "Free Shipping"),
                            const SizedBox(height: 10),
                            const Divider(height: 1),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("GRAND TOTAL", style: TextStyle(color: slateDark, fontSize: 14, fontWeight: FontWeight.w900)),
                                Text(
                                  "Rs. ${totalAmt.toStringAsFixed(0)}",
                                  style: const TextStyle(color: sapphireBlue, fontSize: 20, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Footer note
                  const Center(
                    child: Text(
                      "Thank you for shopping with StyLuxe! For support, contact +92 300 1234567",
                      style: TextStyle(color: slateMuted, fontSize: 11.5, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: cardBorderColor, width: 1.5)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: sapphireBlue, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: sapphireBlue, size: 18),
                  label: const Text("CLOSE INVOICE", style: TextStyle(color: sapphireBlue, fontSize: 13, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sapphireBlue,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Receipt saved / ready for printing! 🖨️"), backgroundColor: Color(0xFF10B981)),
                    );
                  },
                  icon: const Icon(Icons.print_rounded, color: Colors.white, size: 18),
                  label: const Text("PRINT RECEIPT", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String title, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: slateMuted, fontSize: 12, fontWeight: FontWeight.w600)),
        Text(val, style: const TextStyle(color: slateDark, fontSize: 12.5, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
