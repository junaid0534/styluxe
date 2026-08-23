import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/session_service.dart';
import '../../chat/inbox_screen.dart';

class SellerHomeScreen extends StatefulWidget {
  const SellerHomeScreen({super.key});

  @override
  State<SellerHomeScreen> createState() => _SellerHomeScreenState();
}

class _SellerHomeScreenState extends State<SellerHomeScreen> {
  final supabase = Supabase.instance.client;
  late final ScrollController _scrollController;

  StreamSubscription<List<Map<String, dynamic>>>? _ordersSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _productsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _storesSubscription;

  bool isStoreActive = true;

  String sellerName = "Muhammad Junaid";
  String sellerEmail = "mrj25346@gmail.com";

  double todaysRevenue = 0.0;
  double totalRevenue = 0.0;
  int totalProducts = 0;
  int activeOrdersCount = 0;
  int totalCustomers = 0;
  bool isLoading = true;
  bool _isNavVisible = true;

  String selectedGraphFilter = "Weekly";
  String selectedOrderFilter = "All";
  int? hoveredGraphIndex;

  List<Map<String, dynamic>> recentOrders = [];

  List<double> weeklyGraphPoints = [0, 0, 0, 0, 0, 0, 0];
  List<String> weeklyLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  List<double> monthlyGraphPoints = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
  List<String> monthlyLabels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  List<double> yearlyGraphPoints = [0, 0, 0, 0, 0];
  List<String> yearlyLabels = ['2022', '2023', '2024', '2025', '2026'];

  // Theme Constants: Royal Sapphire Blue & Pure White Studio
  static const Color sapphireBlue = Color(0xFF2563EB);
  static const Color sapphireLight = Color(0xFFEFF6FF);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color cardBorderColor = Color(0xFF93C5FD);
  static const Color bgColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    _fetchSellerProfile();
    _setupRealtimeSubscriptions();
    fetchDashboardData();
  }

  void _scrollListener() {
    if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (_isNavVisible) {
        setState(() => _isNavVisible = false);
      }
    } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
      if (!_isNavVisible) {
        setState(() => _isNavVisible = true);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _ordersSubscription?.cancel();
    _productsSubscription?.cancel();
    _storesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchSellerProfile() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final nameMeta = user.userMetadata?['name']?.toString() ?? user.userMetadata?['full_name']?.toString();

      if (mounted) {
        setState(() {
          if (nameMeta != null && nameMeta.trim().isNotEmpty) {
            sellerName = nameMeta.trim();
          } else if (user.email != null && user.email!.isNotEmpty) {
            sellerName = user.email!.split('@')[0];
          }
          sellerEmail = user.email ?? sellerEmail;
        });
      }

      try {
        final storeRes = await supabase.from('seller_stores').select('is_active').eq('seller_id', user.id).maybeSingle();
        if (storeRes != null && mounted) {
          setState(() {
            isStoreActive = storeRes['is_active'] == true;
          });
        }
      } catch (e) {
        debugPrint("Seller store status fetch error: $e");
      }
    }
  }

  // ================= SUPABASE REALTIME STREAM SUBSCRIPTIONS =================
  void _setupRealtimeSubscriptions() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      _ordersSubscription = supabase
          .from('orders')
          .stream(primaryKey: ['id'])
          .eq('seller_id', user.id)
          .order('created_at', ascending: false)
          .listen((data) {
            _processOrdersData(data);
          }, onError: (err) {
            debugPrint("Orders Realtime Stream Error: $err");
          });
    } catch (e) {
      debugPrint("Realtime stream setup error: $e");
    }

    try {
      _productsSubscription = supabase
          .from('products')
          .stream(primaryKey: ['id'])
          .eq('seller_id', user.id)
          .listen((data) {
            if (mounted) {
              setState(() {
                totalProducts = data.length;
              });
            }
          }, onError: (err) {
            debugPrint("Products Realtime Stream Error: $err");
          });
    } catch (_) {}

    try {
      _storesSubscription = supabase
          .from('seller_stores')
          .stream(primaryKey: ['id'])
          .eq('seller_id', user.id)
          .listen((data) {
            if (data.isNotEmpty && mounted) {
              setState(() {
                isStoreActive = data.first['is_active'] == true;
              });
            }
          }, onError: (err) {
            debugPrint("Seller store Realtime Stream Error: $err");
          });
    } catch (_) {}
  }

  void _processOrdersData(List<Map<String, dynamic>> ordersList) {
    if (!mounted) return;

    double todaySum = 0.0;
    double totalSum = 0.0;
    int activeCount = 0;
    final uniqueCustomers = <String>{};

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final currentYear = now.year;

    final List<double> wPoints = [0, 0, 0, 0, 0, 0, 0];
    final List<double> mPoints = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    final List<double> yPoints = [0, 0, 0, 0, 0];

    final List<int> yearList = [currentYear - 4, currentYear - 3, currentYear - 2, currentYear - 1, currentYear];
    yearlyLabels = yearList.map((y) => "$y").toList();

    for (final order in ordersList) {
      final amount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
      final status = (order['status']?.toString() ?? 'Pending').toLowerCase();
      final createdAtStr = order['created_at']?.toString();

      if (status != 'cancelled') {
        totalSum += amount;
      }

      if (status == 'pending' || status == 'processing' || status == 'shipped') {
        activeCount++;
      }

      if (createdAtStr != null) {
        try {
          final dt = DateTime.parse(createdAtStr).toLocal();
          if (dt.isAfter(startOfToday) && status != 'cancelled') {
            todaySum += amount;
          }

          if (status != 'cancelled') {
            // Weekly: 0=Mon, ..., 6=Sun
            final weekdayIdx = (dt.weekday - 1) % 7;
            wPoints[weekdayIdx] += amount;

            // Monthly: 12 Months of current year
            if (dt.year == currentYear) {
              final monthIdx = (dt.month - 1).clamp(0, 11);
              mPoints[monthIdx] += amount;
            }

            // Yearly: Last 5 Years
            final yearIdx = yearList.indexOf(dt.year);
            if (yearIdx >= 0 && yearIdx < 5) {
              yPoints[yearIdx] += amount;
            }
          }
        } catch (_) {}
      }

      final uid = order['user_id']?.toString();
      if (uid != null && uid.trim().isNotEmpty) {
        uniqueCustomers.add(uid);
      }
    }

    setState(() {
      todaysRevenue = todaySum;
      totalRevenue = totalSum;
      activeOrdersCount = activeCount;
      totalCustomers = uniqueCustomers.length;
      weeklyGraphPoints = wPoints;
      monthlyGraphPoints = mPoints;
      yearlyGraphPoints = yPoints;
      recentOrders = ordersList.take(8).toList();
      isLoading = false;
    });
  }

  Future<void> fetchDashboardData() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      final sellerId = currentUser.id;

      final productsRes = await supabase.from('products').select('id').eq('seller_id', sellerId);
      final ordersRes = await supabase.from('orders').select('*').eq('seller_id', sellerId).order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          totalProducts = (productsRes as List).length;
        });
        _processOrdersData(List<Map<String, dynamic>>.from(ordersRes as List));
      }
    } catch (e) {
      debugPrint("Dashboard Fetch Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _formattedAmount(double amount) {
    if (amount >= 100000) {
      return "${(amount / 1000).toStringAsFixed(1)}k";
    }
    return amount.toStringAsFixed(0);
  }

  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // If drawer is open, close it first
        final isDrawerOpen = Scaffold.maybeOf(context)?.isDrawerOpen ?? false;
        if (isDrawerOpen) {
          Navigator.pop(context);
          return;
        }

        // Double press back to exit gracefully
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                "Press back again to exit Seller Center",
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
        drawer: _buildDrawer(),
        backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        toolbarHeight: 46.0,
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: slateDark, size: 22),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          "StyLuxe",
          style: TextStyle(color: slateDark, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.4),
        ),
        actions: [
          IconButton(
            tooltip: "Customer Messages",
            icon: const Icon(Icons.forum_outlined, color: slateDark, size: 23),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InboxScreen(isCustomer: false)),
              );
            },
          ),
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded, color: slateDark, size: 24),
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: sapphireBlue))
          : RefreshIndicator(
              onRefresh: fetchDashboardData,
              color: sapphireBlue,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 700;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ================= SUSPENDED STORE WARNING BANNER =================
                            if (!isStoreActive)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: const Color(0xFFFECACA)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            "Store Account Suspended",
                                            style: TextStyle(color: Color(0xFFDC2626), fontSize: 14, fontWeight: FontWeight.w800),
                                          ),
                                          SizedBox(height: 3),
                                          Text(
                                            "Your store has been deactivated by the Admin. Your products are currently hidden from customer listings. Contact support to reactivate.",
                                            style: TextStyle(color: Color(0xFF991B1B), fontSize: 12, height: 1.4, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.05),

                            // ================= 1. ROYAL SAPPHIRE BLUE HERO CARD =================
                            _revenueHeroCard().animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),

                            const SizedBox(height: 18),

                            // ================= 2. 4 METRIC CARDS (RESPONSIVE & TINTED) =================
                            _metricsGridScreenshotStyle(isWide).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                            const SizedBox(height: 22),

                            // ================= 3. REALTIME LINE GRAPH WITH DROPDOWN =================
                            _realtimeLineGraphWidget().animate().fadeIn(delay: 200.ms, duration: 400.ms),

                            const SizedBox(height: 26),

                            // ================= 4. RECENT ORDERS WITH STATUS FILTERS =================
                            _recentOrdersHeader(),
                            const SizedBox(height: 12),
                            _recentOrdersList().animate().fadeIn(delay: 300.ms, duration: 400.ms),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
        bottomNavigationBar: AnimatedSlide(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          offset: _isNavVisible ? Offset.zero : const Offset(0, 1.5),
          child: _buildSellerBottomNav(0),
        ),
      ),
    );
  }

  // ================= 1. REVENUE HERO CARD WITH STORE HEALTH BADGE =================
  Widget _revenueHeroCard() {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/seller_revenue'),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: sapphireBlue.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Sales Revenue",
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_rounded, color: Colors.white, size: 13),
                      SizedBox(width: 4),
                      Text("VERIFIED STORE", style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: todaysRevenue),
              duration: const Duration(milliseconds: 800),
              builder: (context, val, child) {
                return Text(
                  "Rs. ${_formattedAmount(val)}",
                  style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                );
              },
            ),
            const SizedBox(height: 14),
            Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Total Store Earnings: Rs. ${_formattedAmount(totalRevenue)}",
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================= DRAWER MENU =================
  Widget _buildDrawer() {
    final drawerWidth = (MediaQuery.of(context).size.width * 0.72).clamp(255.0, 285.0);
    return Drawer(
      width: drawerWidth,
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: sapphireBlue,
            ),
            accountName: Text(sellerName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            accountEmail: Text(sellerEmail, style: const TextStyle(fontSize: 13)),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                sellerName.isNotEmpty ? sellerName[0].toUpperCase() : 'S',
                style: const TextStyle(color: sapphireBlue, fontWeight: FontWeight.w900, fontSize: 22),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_rounded, color: sapphireBlue),
            title: const Text("Dashboard", style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined, color: sapphireBlue),
            title: const Text("My Products", style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/my_products');
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline_rounded, color: sapphireBlue),
            title: const Text("Add New Product", style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/add_product');
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_mall_outlined, color: sapphireBlue),
            title: const Text("Active Orders", style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/active_orders');
            },
          ),
          ListTile(
            leading: const Icon(Icons.history_rounded, color: sapphireBlue),
            title: const Text("All Orders History", style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/seller_all_orders');
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_rounded, color: sapphireBlue),
            title: const Text("Sales Analytics", style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/seller_analytics');
            },
          ),
          ListTile(
            leading: const Icon(Icons.people_outline_rounded, color: sapphireBlue),
            title: const Text("Total Customers", style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/total_customers');
            },
          ),
          ListTile(
            leading: const Icon(Icons.rate_review_outlined, color: sapphireBlue),
            title: const Text("Customer Reviews & Replies", style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/seller_reviews');
            },
          ),
          ListTile(
            leading: const Icon(Icons.forum_outlined, color: sapphireBlue),
            title: const Text("Chat", style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InboxScreen(isCustomer: false)),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined, color: sapphireBlue),
            title: const Text("Manage Store / Settings", style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/manage_store');
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
            onTap: () async {
              await SessionService.clearSession();
              if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
    );
  }

  // ================= 2. 4 METRICS GRID (RESPONSIVE & TINTED) =================
  Widget _metricsGridScreenshotStyle(bool isWide) {
    if (isWide) {
      return Row(
        children: [
          Expanded(
            child: _screenshotStyleCard(
              title: "Today Revenue",
              showRsBadge: true,
              value: "Rs. ${_formattedAmount(todaysRevenue)}",
              bgColor: const Color(0xFFF0F6FF),
              borderColor: const Color(0xFFBFDBFE),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _screenshotStyleCard(
              title: "Active Orders",
              showRsBadge: false,
              value: "$activeOrdersCount",
              bgColor: const Color(0xFFF0FDF4),
              borderColor: const Color(0xFFA7F3D0),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _screenshotStyleCard(
              title: "Listed Products",
              showRsBadge: false,
              value: "$totalProducts",
              bgColor: const Color(0xFFFFFBEB),
              borderColor: const Color(0xFFFDE68A),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _screenshotStyleCard(
              title: "Total Customers",
              showRsBadge: false,
              value: "$totalCustomers",
              bgColor: const Color(0xFFF5F3FF),
              borderColor: const Color(0xFFDDD6FE),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _screenshotStyleCard(
                title: "Today Revenue",
                showRsBadge: true,
                value: "Rs. ${_formattedAmount(todaysRevenue)}",
                bgColor: const Color(0xFFF0F6FF),
                borderColor: const Color(0xFFBFDBFE),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _screenshotStyleCard(
                title: "Active Orders",
                showRsBadge: false,
                value: "$activeOrdersCount",
                bgColor: const Color(0xFFF0FDF4),
                borderColor: const Color(0xFFA7F3D0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _screenshotStyleCard(
                title: "Listed Products",
                showRsBadge: false,
                value: "$totalProducts",
                bgColor: const Color(0xFFFFFBEB),
                borderColor: const Color(0xFFFDE68A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _screenshotStyleCard(
                title: "Total Customers",
                showRsBadge: false,
                value: "$totalCustomers",
                bgColor: const Color(0xFFF5F3FF),
                borderColor: const Color(0xFFDDD6FE),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _screenshotStyleCard({
    required String title,
    required bool showRsBadge,
    required String value,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              if (showRsBadge)
                Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: const BoxDecoration(
                    color: sapphireBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    "Rs",
                    style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(color: slateDark, fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.4),
            ),
          ),
        ],
      ),
    );
  }

  // ================= 3. REALTIME LINE GRAPH WITH STYLISH DROPDOWN =================
  Widget _realtimeLineGraphWidget() {
    List<double> points = weeklyGraphPoints;
    List<String> labels = weeklyLabels;

    if (selectedGraphFilter == 'Monthly') {
      points = monthlyGraphPoints;
      labels = monthlyLabels;
    } else if (selectedGraphFilter == 'Yearly') {
      points = yearlyGraphPoints;
      labels = yearlyLabels;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Row(
                children: [
                  Icon(Icons.show_chart_rounded, color: sapphireBlue, size: 20),
                  SizedBox(width: 8),
                  Text("Sales Line Trajectory", style: TextStyle(color: slateDark, fontSize: 15.5, fontWeight: FontWeight.w900)),
                ],
              ),
              _buildGraphFilterDropdown(),
            ],
          ),
          const SizedBox(height: 20),

          // Smooth Line Canvas
          SizedBox(
            height: 140,
            width: double.infinity,
            child: CustomPaint(
              painter: _LineGraphPainter(
                dataPoints: points,
                lineColors: sapphireBlue,
                fillColor: sapphireBlue,
                selectedIndex: hoveredGraphIndex,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(labels.length, (idx) {
              return Text(
                labels[idx],
                style: const TextStyle(color: slateMuted, fontSize: 10.5, fontWeight: FontWeight.w600),
              );
            }),
          ),
        ],
      ),
    );
  }

  // STYLISH DROPDOWN SELECTOR FOR GRAPH FILTER (ZERO OVERFLOW)
  Widget _buildGraphFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedGraphFilter,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: sapphireBlue, size: 18),
          style: const TextStyle(color: sapphireBlue, fontSize: 12, fontWeight: FontWeight.w800),
          isDense: true,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: ['Weekly', 'Monthly', 'Yearly'].map((String filter) {
            return DropdownMenuItem<String>(
              value: filter,
              child: Text(filter, style: const TextStyle(color: sapphireBlue, fontSize: 12, fontWeight: FontWeight.w800)),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() => selectedGraphFilter = newValue);
            }
          },
        ),
      ),
    );
  }

  // ================= 4. RECENT ORDERS HEADER WITH FILTER CHIPS =================
  Widget _recentOrdersHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "RECENT ORDERS",
              style: TextStyle(color: slateMuted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
            ),
            InkWell(
              onTap: () => Navigator.pushNamed(context, '/seller_all_orders'),
              child: const Row(
                children: [
                  Text("View All", style: TextStyle(color: sapphireBlue, fontSize: 12.5, fontWeight: FontWeight.w800)),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_forward_rounded, color: sapphireBlue, size: 14),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Pending', 'Processing', 'Shipped', 'Delivered'].map((filter) {
              final isSelected = selectedOrderFilter == filter;
              return InkWell(
                onTap: () => setState(() => selectedOrderFilter = filter),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? sapphireBlue : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    filter,
                    style: TextStyle(
                      color: isSelected ? Colors.white : slateMuted,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ================= 5. RECENT ORDERS TICKER LIST =================
  Widget _recentOrdersList() {
    final filtered = recentOrders.where((o) {
      if (selectedOrderFilter == 'All') return true;
      final st = (o['status']?.toString() ?? 'Pending').toLowerCase();
      return st == selectedOrderFilter.toLowerCase();
    }).toList();

    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorderColor),
        ),
        child: const Column(
          children: [
            Icon(Icons.inbox_outlined, color: slateMuted, size: 36),
            SizedBox(height: 8),
            Text("No Orders Match Filter", style: TextStyle(color: slateDark, fontWeight: FontWeight.w800, fontSize: 14)),
            SizedBox(height: 2),
            Text("Try selecting a different status filter or check back later.", style: TextStyle(color: slateMuted, fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return Column(
      children: filtered.map((order) {
        final orderIdStr = order['id']?.toString() ?? 'ORD';
        final displayId = orderIdStr.length > 8 ? orderIdStr.substring(0, 8).toUpperCase() : orderIdStr.toUpperCase();
        final amount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
        final status = order['status']?.toString() ?? 'Pending';

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
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cardBorderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: sapphireLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.shopping_bag_outlined, color: sapphireBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Order #$displayId", style: const TextStyle(color: slateDark, fontSize: 13.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      order['address']?.toString() ?? 'Customer Order',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: slateMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("Rs. ${amount.toStringAsFixed(0)}", style: const TextStyle(color: slateDark, fontSize: 14, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                    child: Text(status.toUpperCase(), style: TextStyle(color: statusText, fontSize: 9.5, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ================= 5-TAB SELLER BOTTOM NAV BAR WITH ROUNDED TOP CORNERS =================
  Widget _buildSellerBottomNav(int currentIndex) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border.all(color: cardBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            if (index == 0) return;
            if (index == 1) Navigator.pushNamed(context, '/active_orders');
            if (index == 2) Navigator.pushNamed(context, '/my_products');
            if (index == 3) Navigator.pushNamed(context, '/seller_analytics');
            if (index == 4) Navigator.pushNamed(context, '/manage_store');
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: sapphireBlue,
          unselectedItemColor: slateMuted,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_mall_outlined),
              activeIcon: Icon(Icons.local_mall_rounded),
              label: "Orders",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2_rounded),
              label: "Products",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded),
              label: "Analytics",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: "Settings",
            ),
          ],
        ),
      ),
    );
  }
}

// ================= CUSTOM SMOOTH CURVED LINE CHART PAINTER =================
class _LineGraphPainter extends CustomPainter {
  final List<double> dataPoints;
  final Color lineColors;
  final Color fillColor;
  final int? selectedIndex;

  _LineGraphPainter({
    required this.dataPoints,
    required this.lineColors,
    required this.fillColor,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final double maxVal = dataPoints.reduce((a, b) => a > b ? a : b);
    final double safeMax = maxVal == 0 ? 1.0 : maxVal;

    final List<Offset> points = [];
    final double dx = size.width / (dataPoints.length > 1 ? dataPoints.length - 1 : 1);

    for (int i = 0; i < dataPoints.length; i++) {
      final double x = i * dx;
      final double normalized = (dataPoints[i] / safeMax).clamp(0.08, 0.95);
      final double y = size.height - (normalized * (size.height - 20)) - 10;
      points.add(Offset(x, y));
    }

    if (points.length < 2) return;

    final Path linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlPoint1 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p1.dy);
      final controlPoint2 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p2.dy);
      linePath.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p2.dx, p2.dy);
    }

    final Path fillPath = Path.from(linePath);
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.lineTo(points.first.dx, size.height);
    fillPath.close();

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [fillColor.withValues(alpha: 0.30), fillColor.withValues(alpha: 0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    final Paint strokePaint = Paint()
      ..color = lineColors
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(linePath, strokePaint);

    final Paint outerPointPaint = Paint()..color = lineColors.withValues(alpha: 0.25);
    final Paint innerPointPaint = Paint()..color = lineColors;
    final Paint centerWhitePaint = Paint()..color = Colors.white;

    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      canvas.drawCircle(pt, 6, outerPointPaint);
      canvas.drawCircle(pt, 4, innerPointPaint);
      canvas.drawCircle(pt, 2, centerWhitePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineGraphPainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints || oldDelegate.lineColors != lineColors || oldDelegate.selectedIndex != selectedIndex;
  }
}