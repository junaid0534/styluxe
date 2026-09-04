import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/courier_service.dart';
import '../../../services/inventory_service.dart';
import '../../../services/realtime_notification_service.dart';
import '../../../widgets/seller_bottom_nav.dart';
import '../../../widgets/seller_shimmer_loading.dart';
import 'seller_order_fulfillment_screen.dart';
import 'seller_ship_order_screen.dart';

class ActiveOrdersScreen extends StatefulWidget {
  const ActiveOrdersScreen({super.key});

  @override
  State<ActiveOrdersScreen> createState() => _ActiveOrdersScreenState();
}

class _ActiveOrdersScreenState extends State<ActiveOrdersScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> allOrders = [];
  List<Map<String, dynamic>> returnRequests = [];
  bool isLoading = true;
  bool _isNavVisible = true;

  String selectedFilter = "All Active";
  String searchQuery = "";

  StreamSubscription<List<Map<String, dynamic>>>? _ordersSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _returnsSubscription;

  static const Color sapphireBlue = Color(0xFF2563EB);
  static const Color sapphireLight = Color(0xFFEFF6FF);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color cardBorderColor = Color(0xFFE2E8F0);
  static const Color bgColor = Colors.white;

  @override
  void initState() {
    super.initState();
    fetchOrdersAndReturns();
    setupRealtimeSubscriptions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _ordersSubscription?.cancel();
    _returnsSubscription?.cancel();
    super.dispose();
  }

  // ================= FETCH ORDERS & RETURNS =================
  Future<void> fetchOrdersAndReturns() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      final ordersData = await supabase
          .from('orders')
          .select('*')
          .eq('seller_id', user.id)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> returnsData = [];
      try {
        final res = await supabase
            .from('return_requests')
            .select('*')
            .order('created_at', ascending: false);
        returnsData = List<Map<String, dynamic>>.from(res);
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        allOrders = List<Map<String, dynamic>>.from(ordersData);
        returnRequests = returnsData;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ================= REALTIME LISTENERS =================
  void setupRealtimeSubscriptions() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      _ordersSubscription = supabase
          .from('orders')
          .stream(primaryKey: ['id'])
          .eq('seller_id', user.id)
          .order('created_at', ascending: false)
          .listen((data) {
            if (mounted) {
              setState(() {
                allOrders = data;
              });
            }
          });
    } catch (_) {}

    try {
      _returnsSubscription = supabase
          .from('return_requests')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .listen((data) {
            if (mounted) {
              setState(() {
                returnRequests = data;
              });
            }
          });
    } catch (_) {}
  }

  // ================= UPDATE ORDER STATUS =================
  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await supabase
          .from('orders')
          .update({'status': newStatus})
          .eq('id', orderId);

      // Notify Buyer in Real-Time
      try {
        final orderObj = allOrders.firstWhere(
          (o) => o['id']?.toString() == orderId,
          orElse: () => <String, dynamic>{},
        );
        final buyerId = orderObj['user_id']?.toString() ?? orderObj['buyer_id']?.toString();
        final orderCode = orderObj['order_id']?.toString() ?? 'ORD-$orderId';

        if (buyerId != null && buyerId.isNotEmpty) {
          String notifTitle = "Order Status Updated";
          String notifMsg = "Your order #$orderCode status is now '$newStatus'.";

          if (newStatus.toLowerCase() == 'shipped') {
            notifTitle = "🚚 Order Shipped!";
            notifMsg = "Your order #$orderCode has been shipped and is on its way.";
          } else if (newStatus.toLowerCase() == 'delivered') {
            notifTitle = "✅ Order Delivered!";
            notifMsg = "Your order #$orderCode has been successfully delivered. Enjoy!";
          } else if (newStatus.toLowerCase() == 'processing') {
            notifTitle = "⚙️ Order Processing";
            notifMsg = "The seller is preparing your order #$orderCode for dispatch.";
          } else if (newStatus.toLowerCase() == 'cancelled') {
            notifTitle = "❌ Order Cancelled";
            notifMsg = "Your order #$orderCode has been cancelled.";
          }

          await RealtimeNotificationService.sendNotification(
            userId: buyerId,
            title: notifTitle,
            message: notifMsg,
            type: 'status_change',
            additionalData: {'order_id': orderId, 'status': newStatus},
          );
        }
      } catch (e) {
        debugPrint("Buyer status notification error: $e");
      }

      // If order is cancelled/rejected/refunded, reverse-count / restore product stock
      final lower = newStatus.toLowerCase();
      if (lower == 'cancelled' || lower == 'canceled' || lower == 'rejected' || lower == 'refunded') {
        await InventoryService.restoreStockForOrder(orderId);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Order status updated to '$newStatus'"),
          backgroundColor: sapphireBlue,
          duration: const Duration(seconds: 2),
        ),
      );
      fetchOrdersAndReturns();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update status: $e"), backgroundColor: Colors.red),
      );
    }
  }





  // ================= UPDATE RETURN REQUEST STATUS =================
  Future<void> _updateReturnStatus(String requestId, String newStatus) async {
    try {
      await supabase
          .from('return_requests')
          .update({'status': newStatus})
          .eq('id', requestId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Return request '$newStatus' successfully!"),
          backgroundColor: newStatus == 'Approved' ? const Color(0xFF10B981) : Colors.red,
        ),
      );
      fetchOrdersAndReturns();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update return request: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        toolbarHeight: 42.0,
        centerTitle: true,
        title: const Text(
          "Orders",
          style: TextStyle(
            color: slateDark,
            fontSize: 17.5,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: isLoading
          ? const SellerOrdersShimmer()
          : NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is UserScrollNotification) {
                  if (notification.direction == ScrollDirection.reverse) {
                    if (_isNavVisible) setState(() => _isNavVisible = false);
                  } else if (notification.direction == ScrollDirection.forward) {
                    if (!_isNavVisible) setState(() => _isNavVisible = true);
                  }
                } else if (notification is ScrollEndNotification) {
                  if (!_isNavVisible) setState(() => _isNavVisible = true);
                }
                return false;
              },
              child: RefreshIndicator(
                onRefresh: fetchOrdersAndReturns,
                color: sapphireBlue,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      slivers: [
                        // ================= 1. SEARCH BAR SLIVER (Scrolls out to free screen space) =================
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                            child: Container(
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (val) => setState(() => searchQuery = val.trim().toLowerCase()),
                                style: const TextStyle(fontSize: 13, color: slateDark),
                                decoration: InputDecoration(
                                  hintText: "Search Order ID, Phone, or Address...",
                                  hintStyle: const TextStyle(color: slateMuted, fontSize: 12.5),
                                  prefixIcon: const Icon(Icons.search_rounded, color: slateMuted, size: 20),
                                  suffixIcon: searchQuery.isNotEmpty
                                      ? InkWell(
                                          onTap: () {
                                            _searchController.clear();
                                            setState(() => searchQuery = "");
                                          },
                                          child: const Icon(Icons.clear_rounded, color: slateMuted, size: 18),
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // ================= 2. FILTER BAR SLIVER =================
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildFilterBar(),
                          ),
                        ),

                        // ================= 3. ORDERS LIST / RETURNS LIST SLIVERS =================
                        if (selectedFilter == 'Return Requests')
                          ..._buildReturnRequestsSlivers()
                        else
                          ..._buildOrdersSlivers(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: _isNavVisible ? (58.0 + MediaQuery.of(context).padding.bottom) : 0.0,
        child: Wrap(
          children: [
            AnimatedSlide(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              offset: _isNavVisible ? Offset.zero : const Offset(0, 1.0),
              child: const SellerBottomNav(currentIndex: 1),
            ),
          ],
        ),
      ),
    );
  }

  // ================= FILTER BAR =================
  Widget _buildFilterBar() {
    final pendingReturnsCount = returnRequests.where((r) => (r['status']?.toString() ?? 'Pending').toLowerCase() == 'pending').length;

    final filters = [
      {'label': 'All Active', 'count': allOrders.where((o) => ['pending', 'processing', 'shipped'].contains((o['status']?.toString() ?? '').toLowerCase())).length},
      {'label': 'Pending', 'count': allOrders.where((o) => (o['status']?.toString() ?? '').toLowerCase() == 'pending').length},
      {'label': 'Processing', 'count': allOrders.where((o) => (o['status']?.toString() ?? '').toLowerCase() == 'processing').length},
      {'label': 'Shipped', 'count': allOrders.where((o) => (o['status']?.toString() ?? '').toLowerCase() == 'shipped').length},
      {'label': 'Delivered', 'count': allOrders.where((o) => (o['status']?.toString() ?? '').toLowerCase() == 'delivered').length},
      {'label': 'Return Requests', 'count': pendingReturnsCount},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: filters.map((f) {
          final label = f['label'] as String;
          final count = f['count'] as int;
          final isSelected = selectedFilter == label;

          return InkWell(
            onTap: () => setState(() => selectedFilter = label),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? sapphireBlue : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? sapphireBlue : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : slateMuted,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withValues(alpha: 0.25) : sapphireBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "$count",
                        style: TextStyle(
                          color: isSelected ? Colors.white : sapphireBlue,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ================= ORDERS SLIVERS =================
  List<Widget> _buildOrdersSlivers() {
    final filtered = allOrders.where((order) {
      final st = (order['status']?.toString() ?? 'Pending').toLowerCase();
      final matchesFilter = selectedFilter == 'All Active'
          ? (st == 'pending' || st == 'processing' || st == 'shipped')
          : st == selectedFilter.toLowerCase();

      if (!matchesFilter) return false;

      if (searchQuery.isNotEmpty) {
        final idStr = (order['id']?.toString() ?? '').toLowerCase();
        final phoneStr = (order['phone']?.toString() ?? '').toLowerCase();
        final addrStr = (order['address']?.toString() ?? '').toLowerCase();
        return idStr.contains(searchQuery) || phoneStr.contains(searchQuery) || addrStr.contains(searchQuery);
      }

      return true;
    }).toList();

    if (filtered.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inbox_outlined, color: slateMuted, size: 48),
                const SizedBox(height: 12),
                Text(
                  "No $selectedFilter Orders",
                  style: const TextStyle(color: slateDark, fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text("Orders matching this search/filter will appear here.", style: TextStyle(color: slateMuted, fontSize: 13)),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final order = filtered[index];
              return _orderCard(order).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05);
            },
            childCount: filtered.length,
          ),
        ),
      ),
    ];
  }

  // ================= ORDER STEPPER =================
  Widget _buildOrderProgressStepper(String currentStatus) {
    final statusMap = {
      'pending': 0,
      'processing': 1,
      'shipped': 2,
      'delivered': 3,
    };

    final currentIdx = statusMap[currentStatus.toLowerCase()] ?? 0;
    final steps = ['Placed', 'Processing', 'Shipped', 'Delivered'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (idx) {
          final isCompleted = idx <= currentIdx;
          final isCurrent = idx == currentIdx;

          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isCompleted ? sapphireBlue : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCurrent ? sapphireBlue : const Color(0xFFCBD5E1),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        isCompleted ? Icons.check_rounded : Icons.circle_outlined,
                        color: isCompleted ? Colors.white : slateMuted,
                        size: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[idx],
                      style: TextStyle(
                        color: isCompleted ? sapphireBlue : slateMuted,
                        fontSize: 9.5,
                        fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (idx < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 14),
                      color: idx < currentIdx ? sapphireBlue : const Color(0xFFE2E8F0),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final orderIdStr = order['id']?.toString() ?? 'ORD';
    final displayId = orderIdStr.length > 8 ? orderIdStr.substring(0, 8).toUpperCase() : orderIdStr.toUpperCase();
    final amount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final status = order['status']?.toString() ?? 'Pending';
    final address = order['address']?.toString() ?? 'Customer Address Not Specified';
    final phone = order['phone']?.toString() ?? 'N/A';
    final payMethod = order['payment_method']?.toString() ?? 'Cash on Delivery';

    Color statusBg = const Color(0xFFFEF3C7);
    Color statusText = const Color(0xFFD97706);

    if (status.toLowerCase() == 'processing') {
      statusBg = const Color(0xFFEFF6FF);
      statusText = sapphireBlue;
    } else if (status.toLowerCase() == 'shipped') {
      statusBg = const Color(0xFFF5F3FF);
      statusText = const Color(0xFF8B5CF6);
    } else if (status.toLowerCase() == 'delivered') {
      statusBg = const Color(0xFFECFDF5);
      statusText = const Color(0xFF10B981);
    } else if (status.toLowerCase() == 'cancelled') {
      statusBg = const Color(0xFFFEF2F2);
      statusText = const Color(0xFFEF4444);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: sapphireLight, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.shopping_bag_outlined, color: sapphireBlue, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text("Order #$displayId", style: const TextStyle(color: slateDark, fontSize: 15, fontWeight: FontWeight.w900)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                child: Text(status.toUpperCase(), style: TextStyle(color: statusText, fontSize: 10, fontWeight: FontWeight.w900)),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(begin: const Offset(0.92, 0.92), end: const Offset(1.08, 1.08), duration: 1000.ms, curve: Curves.easeInOut)
                  .shimmer(duration: 1500.ms, color: Colors.white.withValues(alpha: 0.35)),
            ],
          ),
          const SizedBox(height: 10),

          // VISUAL STEPPER TRACKER
          if (status.toLowerCase() != 'cancelled') _buildOrderProgressStepper(status),

          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, color: slateMuted, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  address,
                  style: const TextStyle(color: slateDark, fontSize: 12.5, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.phone_outlined, color: slateMuted, size: 16),
              const SizedBox(width: 6),
              Text(phone, style: const TextStyle(color: slateMuted, fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text("Payment: $payMethod", style: const TextStyle(color: slateMuted, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total Amount:", style: TextStyle(color: slateMuted, fontSize: 13, fontWeight: FontWeight.w600)),
              Text("Rs. ${amount.toStringAsFixed(0)}", style: const TextStyle(color: slateDark, fontSize: 18, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 14),

          // Action Stepper Buttons
          if (status.toLowerCase() == 'pending')
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sapphireBlue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    onPressed: () async {
                      final res = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SellerOrderFulfillmentScreen(order: order),
                        ),
                      );
                      if (res == true) fetchOrdersAndReturns();
                    },
                    icon: const Icon(Icons.fact_check_outlined, color: Colors.white, size: 16),
                    label: const Text("Review & Approve Items", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                  onPressed: () => _showCancelDialog(order['id'].toString()),
                ),
              ],
            )
          else if (status.toLowerCase() == 'processing')
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                elevation: 0,
                minimumSize: const Size(double.infinity, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final res = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SellerShipOrderScreen(order: order),
                  ),
                );
                if (res == true) fetchOrdersAndReturns();
              },
              icon: const Icon(Icons.local_shipping_outlined, color: Colors.white, size: 16),
              label: const Text("Ship with Courier (TCS / Leopards / Trax)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
            )
          else if (status.toLowerCase() == 'shipped')
            Column(
              children: [
                if (order['courier_name'] != null || order['tracking_number'] != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDDD6FE)),
                    ),
                    child: Row(
                      children: [
                        Icon(CourierService.getPartner(order['courier_name']).icon, color: const Color(0xFF7C3AED), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "${order['courier_name'] ?? 'Courier'} • Tracking: ${order['tracking_number'] ?? 'N/A'}",
                            style: const TextStyle(color: Color(0xFF6D28D9), fontSize: 11.5, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _updateOrderStatus(order['id'].toString(), 'Delivered'),
                  icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 16),
                  label: const Text("Mark as Delivered", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showCancelDialog(String orderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Order?", style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text("Are you sure you want to cancel this order? Customer will be notified."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("No")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateOrderStatus(orderId, 'Cancelled');
            },
            child: const Text("Yes, Cancel", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ================= RETURN REQUESTS SLIVERS =================
  List<Widget> _buildReturnRequestsSlivers() {
    if (returnRequests.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.assignment_return_outlined, color: slateMuted, size: 48),
                const SizedBox(height: 12),
                const Text("No Return Requests", style: TextStyle(color: slateDark, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text("Customer return or exchange requests will appear here.", style: TextStyle(color: slateMuted, fontSize: 13)),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final request = returnRequests[index];
              return _returnRequestCard(request).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05);
            },
            childCount: returnRequests.length,
          ),
        ),
      ),
    ];
  }

  Widget _returnRequestCard(Map<String, dynamic> req) {
    final id = req['id']?.toString() ?? '';
    final type = req['type']?.toString() ?? 'Return (Refund)';
    final reason = req['reason']?.toString() ?? 'No reason provided';
    final exchangeSize = req['exchange_size']?.toString();
    final status = req['status']?.toString() ?? 'Pending';
    final address = req['pickup_address']?.toString() ?? 'N/A';
    final city = req['pickup_city']?.toString() ?? '';
    final phone = req['pickup_phone']?.toString() ?? 'N/A';

    Color statusBg = const Color(0xFFFEF3C7);
    Color statusText = const Color(0xFFD97706);

    if (status.toLowerCase() == 'approved') {
      statusBg = const Color(0xFFECFDF5);
      statusText = const Color(0xFF10B981);
    } else if (status.toLowerCase() == 'rejected') {
      statusBg = const Color(0xFFFEF2F2);
      statusText = const Color(0xFFEF4444);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.assignment_return_rounded, color: Color(0xFFD97706), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(type, style: const TextStyle(color: slateDark, fontSize: 14.5, fontWeight: FontWeight.w900)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                child: Text(status.toUpperCase(), style: TextStyle(color: statusText, fontSize: 10, fontWeight: FontWeight.w900)),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(begin: const Offset(0.92, 0.92), end: const Offset(1.08, 1.08), duration: 1000.ms, curve: Curves.easeInOut)
                  .shimmer(duration: 1500.ms, color: Colors.white.withValues(alpha: 0.35)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Text("Reason: $reason", style: const TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w700)),
          if (exchangeSize != null && exchangeSize.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text("Requested Exchange Size: $exchangeSize", style: const TextStyle(color: sapphireBlue, fontSize: 12.5, fontWeight: FontWeight.w800)),
          ],
          const SizedBox(height: 8),
          Text("Pickup: $address${city.isNotEmpty ? ', $city' : ''}", style: const TextStyle(color: slateMuted, fontSize: 12)),
          Text("Contact: $phone", style: const TextStyle(color: slateMuted, fontSize: 12)),
          const SizedBox(height: 14),

          if (status.toLowerCase() == 'pending')
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _updateReturnStatus(id, 'Approved'),
                    icon: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                    label: const Text("Approve Request", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _updateReturnStatus(id, 'Rejected'),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                    label: const Text("Reject Request", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}