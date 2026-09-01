import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  DateTime? _lastBackPressTime;

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

  static const Color primaryEmerald = Color(0xFF10B981);
  static const Color primaryDark = Color(0xFF047857);
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
            : primaryEmerald,
      });
    }

    for (final p in fetchedPayouts) {
      activityFeed.add({
        'title': "${p['method'] ?? 'Payout'} request of Rs. ${(p['amount'] as num?)?.toStringAsFixed(0) ?? '0'} (${p['status'] ?? 'Pending'})",
        'time': _timeAgo(p['created_at']?.toString()),
        'icon': Icons.account_balance_wallet_rounded,
        'color': (p['status']?.toString().toLowerCase() == 'completed') ? const Color(0xFF10B981) : primaryEmerald,
      });
    }
    for (final s in fetchedSellers) {
      activityFeed.add({
        'title': "Store '${s['store_name']}' registered (${s['status']})",
        'time': _timeAgo(s['created_at']?.toString()),
        'icon': Icons.storefront_rounded,
        'color': primaryEmerald,
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // If on secondary tab, return to Dashboard tab
        if (_selectedTab != 0) {
          setState(() => _selectedTab = 0);
          return;
        }

        // Double press back to exit gracefully
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                "Press back again to exit StyLuxe Admin",
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13),
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: slateDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              // 1. TOP WHITE APP BAR HEADER
              _buildWhiteAdminHeader(),

              // 2. MAIN CONTENT BODY
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: primaryEmerald))
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
      ),
    );
  }

  // ================= 1. TOP WHITE APP BAR HEADER (COMPACT 46PX) =================
  Widget _buildWhiteAdminHeader() {
    return Container(
      width: double.infinity,
      height: 46.0,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Badge: Super Admin Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: BoxDecoration(
              color: primaryEmerald.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primaryEmerald.withValues(alpha: 0.25)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_rounded, color: primaryEmerald, size: 12),
                SizedBox(width: 4),
                Text(
                  "ADMIN",
                  style: TextStyle(
                    color: primaryEmerald,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),

          // Center: StyLuxe Title
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: "Sty",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: slateDark,
                    letterSpacing: -0.4,
                  ),
                ),
                TextSpan(
                  text: "luxe",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: primaryEmerald,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),

          // Right: Broadcast Notification Icon
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.campaign_outlined, color: slateDark, size: 18),
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
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: Text(
                      "$pendingPayoutsCount",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
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

              // Quick Action Shortcuts (4 Compact Grid Items)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.3,
                children: [
                  _quickActionTile(
                    icon: Icons.view_carousel_rounded,
                    title: "Home Sliders",
                    subtitle: "Manage banners",
                    iconColor: const Color(0xFF6366F1),
                    bgColor: const Color(0xFFEEF2FF),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminBannersScreen(isStandalone: true)),
                      );
                    },
                  ),
                  _quickActionTile(
                    icon: Icons.campaign_rounded,
                    title: "Broadcast Hub",
                    subtitle: "Push alerts",
                    iconColor: primaryEmerald,
                    bgColor: const Color(0xFFE6F4EA),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminNotificationsScreen(isStandalone: true)),
                      );
                    },
                  ),
                  _quickActionTile(
                    icon: Icons.storefront_rounded,
                    title: "Seller Stores",
                    subtitle: "$activeSellersCount active",
                    iconColor: const Color(0xFF0284C7),
                    bgColor: const Color(0xFFE0F2FE),
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                  _quickActionTile(
                    icon: Icons.tune_rounded,
                    title: "Platform Rules",
                    subtitle: "Commissions & mode",
                    iconColor: const Color(0xFFF59E0B),
                    bgColor: const Color(0xFFFEF3C7),
                    onTap: () => setState(() => _selectedTab = 4),
                  ),
                ],
              ).animate().fadeIn(delay: 100.ms, duration: 300.ms).slideY(begin: 0.04),

              const SizedBox(height: 14),

              _revenueTrendChartCard(),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: _statusCountCard(
                      icon: Icons.verified_rounded,
                      count: "$activeSellersCount",
                      title: "Active",
                      color: const Color(0xFF10B981),
                      bgTint: const Color(0xFFE6F4EA),
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statusCountCard(
                      icon: Icons.hourglass_top_rounded,
                      count: "$pendingSellersCount",
                      title: "Pending",
                      color: const Color(0xFFF59E0B),
                      bgTint: const Color(0xFFFEF7E0),
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statusCountCard(
                      icon: Icons.block_rounded,
                      count: "$suspendedSellersCount",
                      title: "Suspended",
                      color: const Color(0xFFEF4444),
                      bgTint: const Color(0xFFFCE8E6),
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              _recentActivityCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: slateDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: slateMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: slateMuted, size: 11),
          ],
        ),
      ),
    );
  }

  Widget _platformGmvHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryEmerald, primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryEmerald.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Colors.white70, size: 13),
                  SizedBox(width: 5),
                  Text(
                    "PLATFORM REVENUE & GMV",
                    style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      monthlyGrowthPct >= 0 ? Icons.north_east_rounded : Icons.south_east_rounded,
                      color: Colors.white,
                      size: 11,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      "${monthlyGrowthPct >= 0 ? '+' : ''}${monthlyGrowthPct.toStringAsFixed(1)}%",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Rs. ${totalPlatformGMV.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}",
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.6),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(child: _gmvSubMetric(count: "$totalOrdersCount", label: "Orders")),
                Container(width: 1, height: 26, color: Colors.white24),
                Expanded(child: _gmvSubMetric(count: "$totalSellersCount", label: "Sellers")),
                Container(width: 1, height: 26, color: Colors.white24),
                Expanded(child: _gmvSubMetric(count: "$activeSellersCount", label: "Active")),
                Container(width: 1, height: 26, color: Colors.white24),
                Expanded(child: _gmvSubMetric(count: "$pendingPayoutsCount", label: "Payouts")),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gmvSubMetric({required String count, required String label}) {
    return Column(
      children: [
        Text(count, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(height: 1),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _revenueTrendChartCard() {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    List<FlSpot> spots = [];

    for (int i = 0; i < months.length; i++) {
      final mName = months[i];
      final valPkr = monthlyRevenueMap[mName] ?? 0.0;
      spots.add(FlSpot(i.toDouble(), valPkr > 0 ? valPkr / 1000 : 0));
    }

    final double maxValK = spots.map((s) => s.y).fold<double>(0.0, (a, b) => a > b ? a : b);
    final double safeMaxY = maxValK <= 0 ? 10.0 : maxValK * 1.25;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Platform Revenue Trend", style: TextStyle(color: slateDark, fontSize: 14.5, fontWeight: FontWeight.w900)),
                  SizedBox(height: 2),
                  Text("Realtime monthly sales curve (PKR 'k')", style: TextStyle(color: slateMuted, fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: primaryEmerald.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.show_chart_rounded, color: primaryEmerald, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      "${monthlyGrowthPct >= 0 ? '+' : ''}${monthlyGrowthPct.toStringAsFixed(1)}%",
                      style: const TextStyle(color: primaryEmerald, fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 160,
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
                      reservedSize: 34,
                      getTitlesWidget: (val, meta) {
                        if (val == 0) return const Text("0", style: TextStyle(color: slateMuted, fontSize: 9.5));
                        return Text(
                          "${val.toStringAsFixed(val < 10 ? 1 : 0)}k",
                          style: const TextStyle(color: slateMuted, fontSize: 9.5, fontWeight: FontWeight.w700),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < months.length) {
                          return Text(months[idx], style: const TextStyle(color: slateMuted, fontSize: 9.5, fontWeight: FontWeight.w600));
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
                    curveSmoothness: 0.35,
                    barWidth: 3.0,
                    color: primaryEmerald,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          primaryEmerald.withValues(alpha: 0.22),
                          primaryEmerald.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: primaryEmerald,
                      ),
                    ),
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
    required IconData icon,
    required String count,
    required String title,
    required Color color,
    required Color bgTint,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: bgTint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              count,
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentActivityCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
              const Row(
                children: [
                  Icon(Icons.history_rounded, color: primaryEmerald, size: 18),
                  SizedBox(width: 6),
                  Text("Recent Platform Activity", style: TextStyle(color: slateDark, fontSize: 14.5, fontWeight: FontWeight.w900)),
                ],
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.refresh_rounded, color: slateMuted, size: 18),
                onPressed: _fetchRealtimeAdminData,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (recentActivities.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text("No recent platform activity logged", style: TextStyle(color: slateMuted, fontSize: 12)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentActivities.length > 5 ? 5 : recentActivities.length,
              separatorBuilder: (ctx, idx) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, index) {
                final act = recentActivities[index];
                final title = act['title']?.toString() ?? 'Activity';
                final subtitle = act['subtitle']?.toString() ?? '';
                final time = act['time']?.toString() ?? '';
                final isOrder = act['is_order'] == true;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isOrder ? primaryEmerald.withValues(alpha: 0.10) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          isOrder ? Icons.shopping_bag_outlined : Icons.store_outlined,
                          color: isOrder ? primaryEmerald : const Color(0xFF3B82F6),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(color: slateDark, fontSize: 12.5, fontWeight: FontWeight.w800)),
                            if (subtitle.isNotEmpty)
                              Text(subtitle, style: const TextStyle(color: slateMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                      Text(time, style: const TextStyle(color: slateMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ================= TAB 2: PAYOUTS TAB =================
  Widget _buildPayoutsTab() {
    return RefreshIndicator(
      onRefresh: () => _fetchRealtimeAdminData(showSpinner: false),
      color: primaryEmerald,
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
                    const Text("Payout Requests Management", style: TextStyle(color: slateDark, fontSize: 16, fontWeight: FontWeight.w900)),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: slateMuted, size: 18),
                      onPressed: () => _fetchRealtimeAdminData(showSpinner: false),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (payoutRequestsList.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: borderColor)),
                    child: const Center(
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline_rounded, color: primaryEmerald, size: 36),
                          SizedBox(height: 8),
                          Text("No Pending Payout Requests", style: TextStyle(color: slateDark, fontSize: 14, fontWeight: FontWeight.w800)),
                          SizedBox(height: 2),
                          Text("All seller withdrawal claims are up to date", style: TextStyle(color: slateMuted, fontSize: 11.5)),
                        ],
                      ),
                    ),
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
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF3B82F6), size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("$method • $title", style: const TextStyle(color: slateDark, fontSize: 13.5, fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 2),
                                      Text("A/C: $numStr", style: const TextStyle(color: slateMuted, fontSize: 11.5)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text("Rs. ${amt.toStringAsFixed(0)}", style: const TextStyle(color: slateDark, fontSize: 14.5, fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 3),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: st.toLowerCase() == 'completed' ? const Color(0xFFE6F4EA) : const Color(0xFFFEF7E0),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        st.toUpperCase(),
                                        style: TextStyle(
                                          color: st.toLowerCase() == 'completed' ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (st.toLowerCase() == 'pending' && pId.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 34,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryEmerald,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => _updatePayoutStatus(pId, 'Completed'),
                                        child: const Text("APPROVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SizedBox(
                                      height: 34,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Color(0xFFEF4444)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => _updatePayoutStatus(pId, 'Rejected'),
                                        child: const Text("REJECT", style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w900, fontSize: 11)),
                                      ),
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

  // ================= 5-TAB COMPACT BOTTOM NAVIGATION BAR =================
  Widget _buildAdminBottomNav() {
    return Container(
      height: 50,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _adminNavItem(icon: Icons.grid_view_rounded, label: "Dashboard", index: 0),
            _adminNavItem(icon: Icons.storefront_rounded, label: "Sellers", index: 1, badgeCount: pendingSellersCount),
            _adminNavItem(icon: Icons.account_balance_wallet_rounded, label: "Payouts", index: 2, badgeCount: pendingPayoutsCount),
            _adminNavItem(icon: Icons.bar_chart_rounded, label: "Analytics", index: 3),
            _adminNavItem(icon: Icons.settings_rounded, label: "Settings", index: 4),
          ],
        ),
      ),
    );
  }

  Widget _adminNavItem({
    required IconData icon,
    required String label,
    required int index,
    int badgeCount = 0,
  }) {
    final bool isSelected = _selectedTab == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? primaryEmerald.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? primaryEmerald : slateMuted,
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -3,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
                      child: Text(
                        "$badgeCount",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: primaryEmerald,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
