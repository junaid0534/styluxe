import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/inventory_service.dart';
import '../../../services/realtime_notification_service.dart';

class SellerOrderFulfillmentScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const SellerOrderFulfillmentScreen({
    super.key,
    required this.order,
  });

  @override
  State<SellerOrderFulfillmentScreen> createState() => _SellerOrderFulfillmentScreenState();
}

class _SellerOrderFulfillmentScreenState extends State<SellerOrderFulfillmentScreen> {
  final supabase = Supabase.instance.client;

  late Map<String, dynamic> order;
  List<Map<String, dynamic>> items = [];
  final Set<int> approvedItemIndices = {};
  bool isLoading = true;
  bool isUpdating = false;

  static const Color sapphireBlue = Color(0xFF2563EB);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color emeraldGreen = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    order = Map<String, dynamic>.from(widget.order);
    _loadOrderItems();
  }

  Future<void> _loadOrderItems() async {
    setState(() => isLoading = true);

    try {
      final orderId = order['id']?.toString();
      if (orderId == null) return;

      // 1. Try order_items with product join
      final res = await supabase
          .from('order_items')
          .select('*, products(*)')
          .eq('order_id', orderId);

      final List<Map<String, dynamic>> loadedItems = List<Map<String, dynamic>>.from(res);

      if (loadedItems.isNotEmpty) {
        if (mounted) {
          setState(() {
            items = loadedItems;
            isLoading = false;
          });
        }
        return;
      }

      // 2. Fallback to existing embedded items in order
      final rawItems = order['order_items'] ?? order['items'];
      if (rawItems is List && rawItems.isNotEmpty) {
        if (mounted) {
          setState(() {
            items = List<Map<String, dynamic>>.from(rawItems);
            isLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint("Error loading fulfillment order items: $e");
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  void _toggleItemApproval(int index) {
    setState(() {
      if (approvedItemIndices.contains(index)) {
        approvedItemIndices.remove(index);
      } else {
        approvedItemIndices.add(index);
      }
    });
  }

  void _approveAllItems() {
    setState(() {
      for (int i = 0; i < items.length; i++) {
        approvedItemIndices.add(i);
      }
    });
  }

  Future<void> _acceptAndMoveToProcessing() async {
    final orderId = order['id']?.toString();
    if (orderId == null || isUpdating) return;

    setState(() => isUpdating = true);

    try {
      await supabase
          .from('orders')
          .update({'status': 'Processing'})
          .eq('id', orderId);

      // Notify Buyer in Real-Time
      final buyerId = order['user_id']?.toString() ?? order['buyer_id']?.toString();
      final orderCode = _displayOrderId();

      if (buyerId != null && buyerId.isNotEmpty) {
        await RealtimeNotificationService.sendNotification(
          userId: buyerId,
          title: "🧵 Order In Processing!",
          message: "Seller has verified all items in order #$orderCode and started packaging.",
          type: 'status_change',
          additionalData: {'order_id': orderId, 'status': 'Processing'},
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("All items verified! Order moved to Processing."),
          backgroundColor: sapphireBlue,
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.pop(context, true); // Return true to refresh caller
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update status: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => isUpdating = false);
    }
  }

  Future<void> _cancelOrder() async {
    final orderId = order['id']?.toString();
    if (orderId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Decline Order?", style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text("Are you sure you want to decline this order? Customer will be notified and stock will be restored."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Yes, Decline", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isUpdating = true);

    try {
      await supabase
          .from('orders')
          .update({'status': 'Cancelled'})
          .eq('id', orderId);

      await InventoryService.restoreStockForOrder(orderId);

      final buyerId = order['user_id']?.toString() ?? order['buyer_id']?.toString();
      final orderCode = _displayOrderId();

      if (buyerId != null && buyerId.isNotEmpty) {
        await RealtimeNotificationService.sendNotification(
          userId: buyerId,
          title: "Order Update",
          message: "Seller was unable to fulfill order #$orderCode due to stock unavailability.",
          type: 'status_change',
          additionalData: {'order_id': orderId, 'status': 'Cancelled'},
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to decline order: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => isUpdating = false);
    }
  }

  String _displayOrderId() {
    final orderId = order['order_id']?.toString();
    if (orderId != null && orderId.trim().isNotEmpty) return orderId;
    final id = order['id']?.toString() ?? '00000000';
    return id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
  }

  void _callCustomer(String? phone) async {
    if (phone == null || phone.isEmpty || phone == 'N/A') return;
    final uri = Uri.parse("tel:$phone");
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _whatsappCustomer(String? phone) async {
    if (phone == null || phone.isEmpty || phone == 'N/A') return;
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse("https://wa.me/$cleanPhone?text=Hello%2C%20regarding%20your%20StyLuxe%20Order%20%23${_displayOrderId()}");
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final customerName = order['customer_name']?.toString() ?? 'Customer';
    final customerPhone = order['phone']?.toString() ?? 'N/A';
    final customerAddress = order['address']?.toString() ?? 'No address provided';
    final paymentMethod = order['payment_method']?.toString() ?? 'Cash on Delivery';
    final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;

    final int totalCount = items.length;
    final int approvedCount = approvedItemIndices.length;
    final bool allApproved = totalCount > 0 && approvedCount == totalCount;
    final double progress = totalCount > 0 ? (approvedCount / totalCount) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slateDark, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Order #${_displayOrderId()}",
          style: const TextStyle(color: slateDark, fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: sapphireBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================= CUSTOMER & SHIPPING CARD =================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: sapphireBlue.withValues(alpha: 0.10),
                              child: Text(
                                customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C',
                                style: const TextStyle(color: sapphireBlue, fontWeight: FontWeight.w900, fontSize: 15),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customerName,
                                    style: const TextStyle(color: slateDark, fontSize: 15, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Payment: $paymentMethod • Total: Rs. ${totalAmount.toStringAsFixed(0)}",
                                    style: const TextStyle(color: slateMuted, fontSize: 11.5, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_outlined, color: slateMuted, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                customerAddress,
                                style: const TextStyle(color: slateDark, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  side: const BorderSide(color: Color(0xFF2563EB)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => _callCustomer(customerPhone),
                                icon: const Icon(Icons.call_rounded, size: 14, color: Color(0xFF2563EB)),
                                label: const Text("Call Buyer", style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w700, fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  side: const BorderSide(color: Color(0xFF10B981)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => _whatsappCustomer(customerPhone),
                                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF10B981)),
                                label: const Text("WhatsApp", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w700, fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05),

                  const SizedBox(height: 18),

                  // ================= ITEM INSPECTION HEADER & PROGRESS =================
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: allApproved
                            ? [const Color(0xFF059669), const Color(0xFF10B981)]
                            : [const Color(0xFF1E293B), const Color(0xFF334155)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: (allApproved ? emeraldGreen : slateDark).withValues(alpha: 0.20),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  allApproved ? Icons.check_circle_rounded : Icons.fact_check_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "Item-by-Item Verification",
                                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                            if (!allApproved && totalCount > 1)
                              GestureDetector(
                                onTap: _approveAllItems,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.20),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    "Approve All",
                                    style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              allApproved ? "All $totalCount items verified & ready!" : "Verify stock & quality of each item",
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              "$approvedCount / $totalCount Approved",
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: Colors.white.withValues(alpha: 0.25),
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),

                  const SizedBox(height: 18),

                  const Text(
                    "Ordered Products Checklist",
                    style: TextStyle(color: slateDark, fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),

                  // ================= ITEMS LIST =================
                  if (items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Center(
                        child: Text("No item details found for this order", style: TextStyle(color: slateMuted)),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, idx) {
                        final item = items[idx];
                        final prod = (item['products'] is Map) ? item['products'] as Map<String, dynamic> : <String, dynamic>{};

                        final title = item['product_name']?.toString() ?? prod['name']?.toString() ?? 'Apparel Item';
                        final price = (item['price'] as num?)?.toDouble() ?? (prod['price'] as num?)?.toDouble() ?? 0.0;
                        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                        final size = item['size']?.toString() ?? item['selected_size']?.toString() ?? 'Standard';
                        final color = item['color']?.toString() ?? item['selected_color']?.toString() ?? 'Original';
                        final imgUrl = item['image_url']?.toString() ?? (prod['images'] is List && (prod['images'] as List).isNotEmpty ? prod['images'][0].toString() : null);

                        final isApproved = approvedItemIndices.contains(idx);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isApproved ? emeraldGreen : const Color(0xFFE2E8F0),
                              width: isApproved ? 1.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isApproved ? emeraldGreen.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Image
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      color: const Color(0xFFF1F5F9),
                                      child: imgUrl != null && imgUrl.isNotEmpty
                                          ? Image.network(imgUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported_outlined, color: slateMuted))
                                          : const Icon(Icons.checkroom_rounded, color: sapphireBlue, size: 28),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: slateDark, fontSize: 13.5, fontWeight: FontWeight.w800),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text("Size: $size", style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 10.5, fontWeight: FontWeight.w700)),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFAF5FF),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text("Color: $color", style: const TextStyle(color: Color(0xFF7E22CE), fontSize: 10.5, fontWeight: FontWeight.w700)),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text("Qty: $qty", style: const TextStyle(color: slateDark, fontSize: 10.5, fontWeight: FontWeight.w700)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Rs. ${(price * qty).toStringAsFixed(0)} (${qty}x Rs. ${price.toStringAsFixed(0)})",
                                    style: const TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w900),
                                  ),
                                  InkWell(
                                    onTap: () => _toggleItemApproval(idx),
                                    borderRadius: BorderRadius.circular(10),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isApproved ? emeraldGreen : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isApproved ? emeraldGreen : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isApproved ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                            size: 15,
                                            color: isApproved ? Colors.white : slateMuted,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isApproved ? "Verified & In Stock" : "Verify Item",
                                            style: TextStyle(
                                              color: isApproved ? Colors.white : slateDark,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: (150 + idx * 50).ms).slideY(begin: 0.05);
                      },
                    ),
                ],
              ),
            ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: isUpdating ? null : _cancelOrder,
                child: const Text(
                  "Decline",
                  style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: allApproved ? sapphireBlue : const Color(0xFFCBD5E1),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: (allApproved && !isUpdating) ? _acceptAndMoveToProcessing : null,
                icon: isUpdating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(allApproved ? Icons.check_circle_rounded : Icons.lock_outline_rounded, color: Colors.white, size: 18),
                label: Text(
                  allApproved
                      ? "Accept & Start Processing"
                      : "Verify Items ($approvedCount/$totalCount)",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
