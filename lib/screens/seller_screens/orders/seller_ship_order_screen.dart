import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/courier_service.dart';
import '../../../services/invoice_service.dart';
import '../../../services/realtime_notification_service.dart';

class SellerShipOrderScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const SellerShipOrderScreen({
    super.key,
    required this.order,
  });

  @override
  State<SellerShipOrderScreen> createState() => _SellerShipOrderScreenState();
}

class _SellerShipOrderScreenState extends State<SellerShipOrderScreen> {
  final supabase = Supabase.instance.client;

  late Map<String, dynamic> order;
  late TextEditingController _trackingController;
  late TextEditingController _notesController;

  String _selectedCourierCode = 'TCS';
  String _selectedCourierName = 'TCS Express';
  String _selectedDeliveryEstimate = '2-3 Working Days (Standard)';
  String _selectedWeight = '1.0 kg';
  bool _isDispatching = false;

  static const Color sapphireBlue = Color(0xFF2563EB);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);

  final List<String> _deliveryEstimates = [
    '1-2 Working Days (Express)',
    '2-3 Working Days (Standard)',
    '3-5 Working Days (Economy)',
  ];

  final List<String> _packageWeights = [
    '0.5 kg',
    '1.0 kg',
    '2.0 kg',
    '3.0+ kg',
  ];

  @override
  void initState() {
    super.initState();
    order = Map<String, dynamic>.from(widget.order);
    _selectedCourierCode = order['courier_name'] != null ? CourierService.getPartner(order['courier_name']).code : 'TCS';
    _selectedCourierName = CourierService.getPartner(_selectedCourierCode).name;

    final existingTrack = order['tracking_number']?.toString();
    final defaultTrack = existingTrack != null && existingTrack.isNotEmpty
        ? existingTrack
        : "$_selectedCourierCode-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";

    _trackingController = TextEditingController(text: defaultTrack);
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _trackingController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _selectCourier(CourierPartner partner) {
    setState(() {
      _selectedCourierCode = partner.code;
      _selectedCourierName = partner.name;
      if (partner.code != 'Other') {
        _trackingController.text = "${partner.code}-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";
      }
    });
  }

  void _autoGenerateTracking() {
    setState(() {
      _trackingController.text = "$_selectedCourierCode-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";
    });
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _trackingController.text = data.text!.trim();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tracking number pasted!"), duration: Duration(seconds: 1)),
        );
      }
    }
  }

  String _displayOrderId() {
    final orderId = order['order_id']?.toString();
    if (orderId != null && orderId.trim().isNotEmpty) return orderId;
    final id = order['id']?.toString() ?? '00000000';
    return id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
  }

  Future<void> _dispatchShipment() async {
    final trackingNumber = _trackingController.text.trim();
    if (trackingNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid tracking number")),
      );
      return;
    }

    final orderId = order['id']?.toString();
    if (orderId == null || _isDispatching) return;

    setState(() => _isDispatching = true);

    try {
      final updateData = {
        'status': 'Shipped',
        'courier_name': _selectedCourierName,
        'tracking_number': trackingNumber,
        'estimated_delivery': _selectedDeliveryEstimate,
        'shipped_at': DateTime.now().toIso8601String(),
      };

      try {
        await supabase.from('orders').update(updateData).eq('id', orderId);
      } catch (_) {
        try {
          await supabase.from('orders').update({
            'status': 'Shipped',
            'courier_name': _selectedCourierName,
            'tracking_number': trackingNumber,
          }).eq('id', orderId);
        } catch (_) {
          await supabase.from('orders').update({'status': 'Shipped'}).eq('id', orderId);
        }
      }

      // Send Realtime Push Notification with Sound & Vibration to Buyer
      final buyerId = order['user_id']?.toString() ?? order['buyer_id']?.toString();
      final orderCode = _displayOrderId();

      if (buyerId != null && buyerId.isNotEmpty) {
        await RealtimeNotificationService.sendNotification(
          userId: buyerId,
          title: "🚚 Order Shipped via $_selectedCourierName!",
          message: "Your order #$orderCode has been dispatched via $_selectedCourierName. Tracking: $trackingNumber.",
          type: 'status_change',
          additionalData: {
            'order_id': orderId,
            'status': 'Shipped',
            'courier_name': _selectedCourierName,
            'tracking_number': trackingNumber,
          },
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Order #$orderCode dispatched via $_selectedCourierName!"),
          backgroundColor: const Color(0xFF8B5CF6),
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.pop(context, true); // Return true to refresh list
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to dispatch: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isDispatching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerName = order['customer_name']?.toString() ?? 'Customer';
    final customerPhone = order['phone']?.toString() ?? 'N/A';
    final customerAddress = order['address']?.toString() ?? 'Address not specified';
    final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final partner = CourierService.getPartner(_selectedCourierCode);

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
          "Ship Order #${_displayOrderId()}",
          style: const TextStyle(color: slateDark, fontSize: 16, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: "Send Receipt to WhatsApp",
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF10B981), size: 20),
            onPressed: () => InvoiceService.shareViaWhatsApp(recipientPhone: customerPhone, order: order),
          ),
          IconButton(
            tooltip: "Print / Save Packing Slip",
            icon: const Icon(Icons.print_rounded, color: sapphireBlue, size: 20),
            onPressed: () => InvoiceService.printOrSavePdfInvoice(context: context, order: order),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= 1. ORDER & RECIPIENT CARD =================
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF8B5CF6), size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Delivery Destination",
                            style: TextStyle(color: slateDark, fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "Rs. ${totalAmount.toStringAsFixed(0)}",
                          style: const TextStyle(color: Color(0xFF059669), fontSize: 12, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    customerName,
                    style: const TextStyle(color: slateDark, fontSize: 14.5, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 14, color: slateMuted),
                      const SizedBox(width: 4),
                      Text(customerPhone, style: const TextStyle(color: slateMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: slateMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          customerAddress,
                          style: const TextStyle(color: slateDark, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05),

            const SizedBox(height: 20),

            // ================= 2. COURIER PARTNER SELECTION GRID =================
            const Text(
              "Select Courier Partner",
              style: TextStyle(color: slateDark, fontSize: 15, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              "Choose courier service for automated parcel tracking & API integration",
              style: TextStyle(color: slateMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: CourierService.supportedCouriers.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.35,
              ),
              itemBuilder: (context, idx) {
                final cp = CourierService.supportedCouriers[idx];
                final isSelected = _selectedCourierCode == cp.code;

                return InkWell(
                  onTap: () => _selectCourier(cp),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? cp.brandColor.withValues(alpha: 0.08) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? cp.brandColor : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.8 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected ? cp.brandColor.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: isSelected ? cp.brandColor : cp.brandColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            cp.icon,
                            color: isSelected ? Colors.white : cp.brandColor,
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                cp.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected ? cp.brandColor : slateDark,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                cp.hotline != 'N/A' ? cp.hotline : "Direct",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected ? cp.brandColor.withValues(alpha: 0.85) : slateMuted,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.check_circle_rounded, color: cp.brandColor, size: 16),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),

            const SizedBox(height: 22),

            // ================= 3. TRACKING & CONSIGNMENT NUMBER =================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Tracking / Consignment #",
                  style: TextStyle(color: slateDark, fontSize: 14, fontWeight: FontWeight.w800),
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: _autoGenerateTracking,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: sapphireBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.refresh_rounded, size: 12, color: sapphireBlue),
                            SizedBox(width: 4),
                            Text("Auto-Gen", style: TextStyle(color: sapphireBlue, fontSize: 10.5, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: _pasteFromClipboard,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.paste_rounded, size: 12, color: slateDark),
                            SizedBox(width: 4),
                            Text("Paste", style: TextStyle(color: slateDark, fontSize: 10.5, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _trackingController,
              decoration: InputDecoration(
                hintText: "Enter tracking number...",
                prefixIcon: Icon(Icons.qr_code_2_rounded, color: partner.brandColor, size: 22),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: partner.brandColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05),

            const SizedBox(height: 20),

            // ================= 4. DELIVERY WINDOW & WEIGHT =================
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Estimated Delivery",
                        style: TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedDeliveryEstimate,
                            isExpanded: true,
                            items: _deliveryEstimates.map((opt) {
                              return DropdownMenuItem<String>(
                                value: opt,
                                child: Text(opt, style: const TextStyle(color: slateDark, fontSize: 12.5, fontWeight: FontWeight.w600)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedDeliveryEstimate = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Parcel Weight",
                        style: TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedWeight,
                            isExpanded: true,
                            items: _packageWeights.map((w) {
                              return DropdownMenuItem<String>(
                                value: w,
                                child: Text(w, style: const TextStyle(color: slateDark, fontSize: 12.5, fontWeight: FontWeight.w600)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedWeight = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),

            const SizedBox(height: 22),

            // ================= 5. LIVE BUYER PREVIEW CARD =================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    partner.brandColor.withValues(alpha: 0.08),
                    partner.brandColor.withValues(alpha: 0.02),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: partner.brandColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.visibility_outlined, size: 16, color: partner.brandColor),
                      const SizedBox(width: 6),
                      Text(
                        "Live Buyer Tracking Preview",
                        style: TextStyle(color: partner.brandColor, fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Icon(partner.icon, color: partner.brandColor, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Shipped via ${partner.name}",
                                style: TextStyle(color: partner.brandColor, fontSize: 12.5, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                "Tracking: ${_trackingController.text} • $_selectedDeliveryEstimate",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: slateMuted, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.05),
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
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            onPressed: _isDispatching ? null : _dispatchShipment,
            icon: _isDispatching
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 20),
            label: Text(
              _isDispatching ? "Dispatching Parcel..." : "Confirm & Dispatch via ${partner.code}",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}
