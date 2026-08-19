import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_sellers_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_banners_screen.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  final supabase = Supabase.instance.client;

  int _selectedTab = 0; // 0: Dashboard, 1: Sellers, 2: Payouts, 3: Analytics, 4: Settings
  bool isLoading = true;
  bool isInitialLoad = true;
  String? _fetchError;

  StreamSubscription? _ordersSub;
  StreamSubscription? _storesSub;
  StreamSubscription? _orderItemsSub;

  double totalPlatformGMV = 0.0;
  double monthlyGrowthPct = 0.0;
  int totalOrdersCount = 0;

  int totalSellersCount = 0;
  int activeSellersCount = 0;
  int pendingSellersCount = 0;
  int suspendedSellersCount = 0;

  int pendingPayoutsCount = 0;
  List<Map<String, dynamic>> payoutRequestsList = [];

  List<Map<String, dynamic>> sellersList = [];
  List<Map<String, dynamic>> recentActivities = [];

  // Monthly Revenue Map for dynamic line chart
  Map<String, double> monthlyRevenueMap = {};

  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color bgColor = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _fetchRealtimeAdminData(showSpinner: true);
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    _storesSub?.cancel();
    _orderItemsSub?.cancel();
    super.dispose();
  }

  // ================= SAFE REALTIME SUPABASE SUBSCRIPTION =================
  void _subscribeRealtime() {
    _ordersSub?.cancel();
    _storesSub?.cancel();
    _orderItemsSub?.cancel();

    try {
      _ordersSub = supabase
          .from('orders')
          .stream(primaryKey: ['id'])
          .listen((_) => _fetchRealtimeAdminData(showSpinner: false), onError: (e) {
            debugPrint("Orders Stream Note: $e");
          });
    } catch (e) {
      debugPrint("Orders stream init error: $e");
    }

    try {
      _orderItemsSub = supabase
          .from('order_items')
          .stream(primaryKey: ['id'])
          .listen((_) => _fetchRealtimeAdminData(showSpinner: false), onError: (e) {
            debugPrint("Order Items Stream Note: $e");
          });
    } catch (e) {
      debugPrint("Order items stream init error: $e");
    }

    try {
      _storesSub = supabase
          .from('seller_stores')
          .stream(primaryKey: ['id'])
          .listen((_) => _fetchRealtimeAdminData(showSpinner: false), onError: (e) {
            debugPrint("Seller Stores Stream Note: $e");
          });
    } catch (e) {
      debugPrint("Stores stream init error: $e");
    }
  }

  // ================= CORE DATA FETCH: ORDERS + ORDER_ITEMS + STORES + PAYOUTS =================
  Future<void> _fetchRealtimeAdminData({bool showSpinner = false}) async {
    if (!mounted) return;
    if (isInitialLoad || showSpinner) {
      setState(() => isLoading = true);
    }

    double sumGMV = 0.0;
    double currentMonthSum = 0.0;
    double lastMonthSum = 0.0;
    int ordersCount = 0;
    Map<String, double> tempMonthlyMap = {};
    Map<String, double> sellerRevenueMap = {};
    Set<String> processedOrderIds = {};
    String? errorMsg;

    final now = DateTime.now();
    final currentMonthKey = "${now.year}-${now.month.toString().padLeft(2, '0')}";
    final lastMonthDt = DateTime(now.year, now.month - 1);
    final lastMonthKey = "${lastMonthDt.year}-${lastMonthDt.month.toString().padLeft(2, '0')}";

    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      debugPrint("DEBUG: Admin Dashboard note - No active Supabase session (auth.currentUser is null). Please log in via Login Screen with aliraza4025346@gmail.com to pass RLS policies.");
      errorMsg = "Not Logged In: Please log in via Login Screen with aliraza4025346@gmail.com to fetch orders under Supabase RLS policies.";
    } else {
      debugPrint("DEBUG: Admin Dashboard active session for ${currentUser.email}");
    }

    // ── 1. PRIMARY SOURCE: `orders` table (total_amount per order) ──
    List<Map<String, dynamic>> allOrders = [];
    try {
      final ordersRes = await supabase.from('orders').select('*');
      allOrders = List<Map<String, dynamic>>.from(ordersRes);
      debugPrint("DEBUG: Admin Dashboard fetched ${allOrders.length} orders from Supabase");
      if (allOrders.isNotEmpty) errorMsg = null;

      for (final o in allOrders) {
        final orderId = o['id']?.toString() ?? o['order_id']?.toString() ?? '';
        final st = o['status']?.toString().toLowerCase() ?? '';

        if (st == 'cancelled' || st == 'canceled' || st == 'rejected' || st == 'refunded') continue;

        double amt = _parseAmount(o['total_amount'] ?? o['total_price'] ?? o['total'] ?? o['amount'] ?? o['grand_total'] ?? o['subtotal']);

        if (amt > 0) {
          sumGMV += amt;
          ordersCount++;
          if (orderId.isNotEmpty) processedOrderIds.add(orderId);

          final sellerId = o['seller_id']?.toString() ?? '';
          if (sellerId.isNotEmpty) {
            sellerRevenueMap[sellerId] = (sellerRevenueMap[sellerId] ?? 0.0) + amt;
          }

          final dt = _parseDate(o['created_at'] ?? o['date'] ?? o['order_date']);
          if (dt != null) {
            final mKey = _monthLabel(dt.month);
            tempMonthlyMap[mKey] = (tempMonthlyMap[mKey] ?? 0.0) + amt;
            final ym = "${dt.year}-${dt.month.toString().padLeft(2, '0')}";
            if (ym == currentMonthKey) currentMonthSum += amt;
            if (ym == lastMonthKey) lastMonthSum += amt;
          }
        }
      }
    } catch (e) {
      debugPrint("ERROR fetching orders: $e");
      errorMsg = "Orders: $e";
    }

    // ── 2. SUPPLEMENTARY SOURCE: `order_items` table (price * quantity) ──
    try {
      final itemsRes = await supabase.from('order_items').select('*');
      debugPrint("DEBUG: Admin Dashboard fetched ${itemsRes.length} order_items from Supabase");

      for (final item in itemsRes) {
        final orderId = item['order_id']?.toString() ?? '';
        if (orderId.isNotEmpty && processedOrderIds.contains(orderId)) continue;

        final price = _parseAmount(item['price']);
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        double itemTotal = price * qty;
        if (itemTotal <= 0) itemTotal = _parseAmount(item['total'] ?? item['amount']);

        if (itemTotal > 0) {
          sumGMV += itemTotal;
          final sellerId = item['seller_id']?.toString() ?? '';
          if (sellerId.isNotEmpty) {
            sellerRevenueMap[sellerId] = (sellerRevenueMap[sellerId] ?? 0.0) + itemTotal;
          }
          final dt = _parseDate(item['created_at'] ?? item['date']);
          if (dt != null) {
            final mKey = _monthLabel(dt.month);
            tempMonthlyMap[mKey] = (tempMonthlyMap[mKey] ?? 0.0) + itemTotal;
            final ym = "${dt.year}-${dt.month.toString().padLeft(2, '0')}";
            if (ym == currentMonthKey) currentMonthSum += itemTotal;
            if (ym == lastMonthKey) lastMonthSum += itemTotal;
          }
        }
      }
    } catch (e) {
      debugPrint("ERROR fetching order_items: $e");
      errorMsg = (errorMsg != null) ? "$errorMsg | OrderItems: $e" : "OrderItems: $e";
    }

    double growth = 0.0;
    if (lastMonthSum > 0) {
      growth = ((currentMonthSum - lastMonthSum) / lastMonthSum) * 100;
    } else if (currentMonthSum > 0) {
      growth = 100.0;
    }

    // ── 3. STORES from `seller_stores` table ──
    List<Map<String, dynamic>> fetchedSellers = [];
    int activeS = 0, pendingS = 0, suspendedS = 0;

    try {
      final storesRes = await supabase.from('seller_stores').select('*').order('created_at', ascending: false);

      for (final s in storesRes) {
        final String rawStatus = s['status']?.toString() ?? '';
        final bool isActive = (s['is_active'] == true) || (rawStatus.toLowerCase() == 'active');
        final bool isSuspended = rawStatus.toLowerCase() == 'suspended';
        final String statusStr = isSuspended ? 'Suspended' : (isActive ? 'Active' : 'Pending');

        if (isSuspended) { suspendedS++; } else if (isActive) { activeS++; } else { pendingS++; }

        final storeId = s['id']?.toString() ?? '';
        final sId = s['seller_id']?.toString() ?? '';

        double storeRev = 0.0;
        if (sId.isNotEmpty && sellerRevenueMap.containsKey(sId)) storeRev += sellerRevenueMap[sId]!;
        if (storeId.isNotEmpty && storeId != sId && sellerRevenueMap.containsKey(storeId)) storeRev += sellerRevenueMap[storeId]!;

        fetchedSellers.add({
          'id': storeId.isNotEmpty ? storeId : sId,
          'seller_id': sId,
          'store_name': s['store_name']?.toString() ?? s['name'] ?? 'Store',
          'seller_name': s['store_category']?.toString() ?? s['seller_name'] ?? 'Seller',
          'phone': s['phone']?.toString() ?? 'N/A',
          'status': statusStr,
          'total_revenue': storeRev,
          'created_at': s['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint("ERROR fetching seller_stores: $e");
      errorMsg = (errorMsg != null) ? "$errorMsg | Stores: $e" : "Stores: $e";
    }

    // ── 4. PAYOUT REQUESTS ──
    List<Map<String, dynamic>> fetchedPayouts = [];
    int pendingP = 0;
    try {
      final pRes = await supabase.from('payout_requests').select('*').order('created_at', ascending: false);
      fetchedPayouts = List<Map<String, dynamic>>.from(pRes);
      pendingP = fetchedPayouts.where((p) => (p['status']?.toString().toLowerCase() ?? '') == 'pending').length;
    } catch (e) {
      debugPrint("payout_requests fetch note: $e");
    }

    // ── 5. ACTIVITY FEED (orders + payouts + stores) ──
    List<Map<String, dynamic>> activityFeed = [];

    // Recent orders in activity feed
    final recentOrds = List<Map<String, dynamic>>.from(allOrders);
    recentOrds.sort((a, b) {
      final aD = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000);
      final bD = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000);
      return bD.compareTo(aD);
    });
    for (final o in recentOrds.take(5)) {
      final amt = _parseAmount(o['total_amount'] ?? o['total_price'] ?? o['total'] ?? o['amount']);
      activityFeed.add({
        'title': "Order ${o['order_id'] ?? o['id'] ?? 'N/A'} • Rs. ${amt.toStringAsFixed(0)} (${o['status'] ?? 'Pending'})",
        'time': _timeAgo(o['created_at']?.toString()),
        'icon': Icons.shopping_bag_rounded,
        'color': (o['status']?.toString().toLowerCase() == 'completed' || o['status']?.toString().toLowerCase() == 'delivered')
            ? const Color(0xFF10B981)
            : primaryTeal,
      });
    }

    for (final p in fetchedPayouts) {
      activityFeed.add({
        'title': "${p['method'] ?? 'Payout'} request of Rs. ${(p['amount'] as num?)?.toStringAsFixed(0) ?? '0'} (${p['status'] ?? 'Pending'})",
        'time': _timeAgo(p['created_at']?.toString()),
        'icon': Icons.account_balance_wallet_rounded,
        'color': (p['status']?.toString().toLowerCase() == 'completed') ? const Color(0xFF10B981) : primaryTeal,
      });
    }
    for (final s in fetchedSellers) {
      activityFeed.add({
        'title': "Store '${s['store_name']}' registered (${s['status']})",
        'time': _timeAgo(s['created_at']?.toString()),
        'icon': Icons.storefront_rounded,
        'color': primaryTeal,
      });
    }

    if (!mounted) return;
    setState(() {
      totalPlatformGMV = sumGMV;
      totalOrdersCount = ordersCount;
      monthlyGrowthPct = growth;
      sellersList = fetchedSellers;
      totalSellersCount = fetchedSellers.length;
      activeSellersCount = activeS;
      pendingSellersCount = pendingS;
      suspendedSellersCount = suspendedS;
      payoutRequestsList = fetchedPayouts;
      pendingPayoutsCount = pendingP;
      monthlyRevenueMap = tempMonthlyMap;
      recentActivities = activityFeed.take(8).toList();
      _fetchError = errorMsg;
      isLoading = false;
      isInitialLoad = false;
    });
  }

  // ── HELPERS ──
  double _parseAmount(dynamic raw) {
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString().replaceAll(',', '').trim()) ?? 0.0;
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  String _monthLabel(int m) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    if (m >= 1 && m <= 12) return months[m - 1];
    return "Jan";
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "Just now";
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return "Just now";
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return "${diff.inDays}d ago";
    if (diff.inHours > 0) return "${diff.inHours}h ago";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
    return "Just now";
  }

  Future<void> _updatePayoutStatus(String payoutId, String newStatus) async {
    try {
      await supabase.from('payout_requests').update({'status': newStatus}).eq('id', payoutId);
      await _fetchRealtimeAdminData(showSpinner: false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Payout status updated to '$newStatus'"),
          backgroundColor: newStatus.toLowerCase() == 'completed' ? const Color(0xFF10B981) : Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // 1. TOP WHITE APP BAR HEADER
            _buildWhiteAdminHeader(),

            // 2. MAIN CONTENT BODY
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: primaryTeal))
                  : IndexedStack(
                      index: _selectedTab,
                      children: [
                        _buildDashboardTab(),
                        const AdminSellersScreen(isStandalone: false),
                        _buildPayoutsTab(),
                        const AdminAnalyticsScreen(isStandalone: false),
                        const AdminSettingsScreen(isStandalone: false),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildAdminBottomNav(),
    );
  }

  // ================= 1. TOP WHITE APP BAR HEADER =================
  Widget _buildWhiteAdminHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 40),
          const Text(
            "StyLuxe",
            style: TextStyle(
              color: slateDark,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: -0.5,
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: slateDark, size: 20),
                  tooltip: "Broadcast Notifications",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminNotificationsScreen(isStandalone: true),
                      ),
                    );
                  },
                ),
              ),
              if (pendingPayoutsCount > 0)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      "$pendingPayoutsCount",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }


  // ================= TAB 0: DASHBOARD TAB =================
  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _platformGmvHeroCard().animate().fadeIn(duration: 350.ms).slideY(begin: 0.04),

              if (_fetchError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Data fetch issue: $_fetchError",
                          style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // Quick Action Shortcuts (Home Sliders & Broadcast Alerts)
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminBannersScreen(isStandalone: true)),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.view_carousel_rounded, color: Color(0xFF6366F1), size: 16),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Home Sliders",
                                    style: TextStyle(
                                      color: slateDark,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    "Manage banners",
                                    style: TextStyle(
                                      color: slateMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: slateMuted, size: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminNotificationsScreen(isStandalone: true)),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F4EA),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.campaign_rounded, color: primaryTeal, size: 16),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Broadcast Hub",
                                    style: TextStyle(
                                      color: slateDark,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    "Push notifications",
                                    style: TextStyle(
                                      color: slateMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: slateMuted, size: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 100.ms, duration: 300.ms).slideY(begin: 0.04),

              const SizedBox(height: 14),

              _revenueTrendChartCard(),

              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: _statusCountCard(
                      count: "$activeSellersCount",
                      title: "Active",
                      color: const Color(0xFF10B981),
                      bgTint: const Color(0xFFE6F4EA),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statusCountCard(
                      count: "$pendingSellersCount",
                      title: "Pending",
                      color: const Color(0xFFF59E0B),
                      bgTint: const Color(0xFFFEF7E0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statusCountCard(
                      count: "$suspendedSellersCount",
                      title: "Suspended",
                      color: const Color(0xFFEF4444),
                      bgTint: const Color(0xFFFCE8E6),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              _recentActivityCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _platformGmvHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryTeal,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primaryTeal.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "PLATFORM GMV",
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.6),
          ),
          const SizedBox(height: 6),
          Text(
            "Rs. ${totalPlatformGMV.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}",
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.6),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                monthlyGrowthPct >= 0 ? Icons.north_east_rounded : Icons.south_east_rounded,
                color: monthlyGrowthPct >= 0 ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                "${monthlyGrowthPct >= 0 ? '+' : ''}${monthlyGrowthPct.toStringAsFixed(1)}% vs last month",
                style: TextStyle(
                  color: monthlyGrowthPct >= 0 ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Colors.white24),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _gmvSubMetric(count: "$totalOrdersCount", label: "Orders"),
              ),
              Container(width: 1, height: 32, color: Colors.white24),
              Expanded(
                child: _gmvSubMetric(count: "$totalSellersCount", label: "Sellers"),
              ),
              Container(width: 1, height: 32, color: Colors.white24),
              Expanded(
                child: _gmvSubMetric(count: "$activeSellersCount", label: "Active"),
              ),
              Container(width: 1, height: 32, color: Colors.white24),
              Expanded(
                child: _gmvSubMetric(count: "$pendingPayoutsCount", label: "Payouts"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gmvSubMetric({required String count, required String label}) {
    return Column(
      children: [
        Text(count, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _revenueTrendChartCard() {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    List<FlSpot> spots = [];

    for (int i = 0; i < months.length; i++) {
      final mName = months[i];
      final valPkr = monthlyRevenueMap[mName] ?? 0.0;
      // Convert to thousands ('k') for chart plotting
      spots.add(FlSpot(i.toDouble(), valPkr > 0 ? valPkr / 1000 : 0));
    }

    final double maxValK = spots.map((s) => s.y).fold<double>(0.0, (a, b) => a > b ? a : b);
    final double safeMaxY = maxValK <= 0 ? 10.0 : maxValK * 1.25;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Revenue Trend", style: TextStyle(color: slateDark, fontSize: 16, fontWeight: FontWeight.w900)),
                  SizedBox(height: 2),
                  Text("Realtime Supabase Sales Curve", style: TextStyle(color: slateMuted, fontSize: 11.5, fontWeight: FontWeight.w600)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.north_east_rounded, color: primaryTeal, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      "${monthlyGrowthPct >= 0 ? '+' : ''}${monthlyGrowthPct.toStringAsFixed(1)}%",
                      style: const TextStyle(color: primaryTeal, fontSize: 11.5, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: safeMaxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: safeMaxY / 4 > 0 ? safeMaxY / 4 : 2.5,
                  getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF1F5F9), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      getTitlesWidget: (val, meta) {
                        if (val == 0) return const Text("0", style: TextStyle(color: slateMuted, fontSize: 10));
                        return Text(
                          "${val.toStringAsFixed(val < 10 ? 1 : 0)}k",
                          style: const TextStyle(color: slateMuted, fontSize: 10, fontWeight: FontWeight.w700),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < months.length) {
                          return Text(months[idx], style: const TextStyle(color: slateMuted, fontSize: 10, fontWeight: FontWeight.w700));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    barWidth: 3.5,
                    color: primaryTeal,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          primaryTeal.withValues(alpha: 0.2),
                          primaryTeal.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCountCard({
    required String count,
    required String title,
    required Color color,
    required Color bgTint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: bgTint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _recentActivityCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Recent Activity", style: TextStyle(color: slateDark, fontSize: 16, fontWeight: FontWeight.w900)),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: slateMuted, size: 18),
                onPressed: _fetchRealtimeAdminData,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recentActivities.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text("No Recent Platform Activity", style: TextStyle(color: slateMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentActivities.length,
              separatorBuilder: (ctx, idx) => const Divider(height: 16, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, index) {
                final item = recentActivities[index];
                return _activityItem(
                  icon: item['icon'] as IconData,
                  iconColor: item['color'] as Color,
                  bgColor: (item['color'] as Color).withValues(alpha: 0.12),
                  title: item['title'].toString(),
                  time: item['time'].toString(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _activityItem({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String time,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: const TextStyle(color: slateMuted, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================= TAB 2: PAYOUTS TAB =================
  Widget _buildPayoutsTab() {
    return RefreshIndicator(
      onRefresh: () => _fetchRealtimeAdminData(showSpinner: false),
      color: primaryTeal,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Payout Requests Management", style: TextStyle(color: slateDark, fontSize: 17, fontWeight: FontWeight.w900)),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: slateMuted, size: 20),
                      onPressed: () => _fetchRealtimeAdminData(showSpinner: false),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (payoutRequestsList.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: borderColor)),
                    child: const Center(child: Text("No Payout Requests Pending", style: TextStyle(color: slateMuted, fontSize: 13, fontWeight: FontWeight.w700))),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: payoutRequestsList.length,
                    separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                    itemBuilder: (ctx, index) {
                      final p = payoutRequestsList[index];
                      final pId = p['id']?.toString() ?? '';
                      final amt = (p['amount'] as num?)?.toDouble() ?? 0.0;
                      final method = p['method']?.toString() ?? 'EasyPaisa';
                      final title = p['account_title']?.toString() ?? 'Seller';
                      final numStr = p['account_number']?.toString() ?? '';
                      final st = p['status']?.toString() ?? 'Pending';

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: borderColor)),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("$method • $title", style: const TextStyle(color: slateDark, fontSize: 14, fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 2),
                                      Text("Account: $numStr", style: const TextStyle(color: slateMuted, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text("Rs. ${amt.toStringAsFixed(0)}", style: const TextStyle(color: slateDark, fontSize: 15, fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: st.toLowerCase() == 'completed' ? const Color(0xFFE6F4EA) : const Color(0xFFFEF7E0),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        st.toUpperCase(),
                                        style: TextStyle(
                                          color: st.toLowerCase() == 'completed' ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (st.toLowerCase() == 'pending' && pId.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: primaryTeal, elevation: 0),
                                      onPressed: () => _updatePayoutStatus(pId, 'Completed'),
                                      child: const Text("APPROVE PAYOUT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11.5)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), elevation: 0),
                                      onPressed: () => _updatePayoutStatus(pId, 'Rejected'),
                                      child: const Text("REJECT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11.5)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }





  // ================= 5-TAB BOTTOM NAVIGATION BAR =================
  Widget _buildAdminBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (idx) => setState(() => _selectedTab = idx),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: primaryTeal,
        unselectedItemColor: slateMuted,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        elevation: 0,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.storefront_rounded),
                if (pendingSellersCount > 0)
                  Positioned(
                    right: -4,
                    top: -2,
                    child: CircleAvatar(
                      radius: 6,
                      backgroundColor: const Color(0xFFEF4444),
                      child: Text("$pendingSellersCount", style: const TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.w900)),
                    ),
                  ),
              ],
            ),
            label: "Sellers",
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.account_balance_wallet_rounded),
                if (pendingPayoutsCount > 0)
                  Positioned(
                    right: -4,
                    top: -2,
                    child: CircleAvatar(
                      radius: 6,
                      backgroundColor: const Color(0xFFEF4444),
                      child: Text("$pendingPayoutsCount", style: const TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.w900)),
                    ),
                  ),
              ],
            ),
            label: "Payouts",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: "Analytics",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: "Settings",
          ),
        ],
      ),
    );
  }
}
