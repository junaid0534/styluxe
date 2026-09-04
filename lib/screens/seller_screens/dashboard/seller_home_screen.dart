import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/session_service.dart';
import '../../chat/inbox_screen.dart';
import '../../../widgets/seller_bottom_nav.dart';
import '../../../widgets/seller_shimmer_loading.dart';

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
  String? sellerAvatarUrl;

  double todaysRevenue = 0.0;
  double totalRevenue = 0.0;
  int totalProducts = 0;
  int activeOrdersCount = 0;
  int totalCustomers = 0;
  bool isLoading = true;
  bool _isNavVisible = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

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
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
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
    _searchController.dispose();
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
      final avatarMeta = user.userMetadata?['avatar_url']?.toString() ??
          user.userMetadata?['picture']?.toString() ??
          user.userMetadata?['logo_url']?.toString();

      if (mounted) {
        setState(() {
          if (nameMeta != null && nameMeta.trim().isNotEmpty) {
            sellerName = nameMeta.trim();
          } else if (user.email != null && user.email!.isNotEmpty) {
            sellerName = user.email!.split('@')[0];
          }
          sellerEmail = user.email ?? sellerEmail;
          if (avatarMeta != null && avatarMeta.trim().isNotEmpty) {
            sellerAvatarUrl = avatarMeta.trim();
          }
        });
      }

      // 1. Check sellers table
      try {
        final sellerRes = await supabase.from('sellers').select('avatar_url, store_name, name, logo_url').eq('id', user.id).maybeSingle();
        if (sellerRes != null && mounted) {
          final av = sellerRes['avatar_url']?.toString() ?? sellerRes['logo_url']?.toString();
          final sName = sellerRes['name']?.toString() ?? sellerRes['store_name']?.toString();
          setState(() {
            if (av != null && av.trim().isNotEmpty) sellerAvatarUrl = av.trim();
            if (sName != null && sName.trim().isNotEmpty) sellerName = sName.trim();
          });
        }
      } catch (_) {}

      // 2. Check profiles table
      try {
        final profileRes = await supabase.from('profiles').select('avatar_url, full_name, name, profile_image').eq('id', user.id).maybeSingle();
        if (profileRes != null && mounted) {
          final av = profileRes['avatar_url']?.toString() ?? profileRes['profile_image']?.toString();
          final pName = profileRes['full_name']?.toString() ?? profileRes['name']?.toString();
          setState(() {
            if (av != null && av.trim().isNotEmpty) sellerAvatarUrl = av.trim();
            if (pName != null && pName.trim().isNotEmpty) sellerName = pName.trim();
          });
        }
      } catch (_) {}

      // 3. Check seller_stores table
      try {
        final storeRes = await supabase.from('seller_stores').select('*').eq('seller_id', user.id).maybeSingle();
        if (storeRes != null && mounted) {
          final logo = storeRes['logo_url']?.toString() ?? storeRes['avatar_url']?.toString();
          setState(() {
            isStoreActive = storeRes['is_active'] == true;
            if (logo != null && logo.trim().isNotEmpty && (sellerAvatarUrl == null || sellerAvatarUrl!.isEmpty)) {
              sellerAvatarUrl = logo.trim();
            }
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

      final uid = (order['user_id'] ?? order['buyer_id'] ?? order['phone'] ?? order['customer_name'] ?? order['id'])?.toString();
      if (uid != null && uid.trim().isNotEmpty) {
        uniqueCustomers.add(uid.trim());
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
        toolbarHeight: 42.0,
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: slateDark, size: 21),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: "Sty",
                style: TextStyle(
                  color: slateDark,
                  fontSize: 17.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              TextSpan(
                text: "Luxe",
                style: TextStyle(
                  color: sapphireBlue,
                  fontSize: 17.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InboxScreen(isCustomer: false)),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.chat_bubble_outline_rounded, color: slateDark, size: 16),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => Navigator.pushNamed(context, '/notifications'),
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.notifications_none_rounded, color: slateDark, size: 17),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: isLoading
          ? const SellerDashboardShimmer()
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

                            // ================= 0. SEARCH BAR (CLEAN PHARMACY / DASHBOARD STYLE) =================
                            _buildDashboardSearchBar().animate().fadeIn(duration: 350.ms).slideY(begin: -0.05),

                            const SizedBox(height: 14),

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
                child: const SellerBottomNav(currentIndex: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= 0. DASHBOARD SEARCH BAR (CLEAN MODERN PILL) =================
  Widget _buildDashboardSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            _searchQuery = val.trim().toLowerCase();
          });
        },
        style: const TextStyle(
          color: slateDark,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: "Search orders, products, customers...",
          hintStyle: const TextStyle(
            color: slateMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: slateMuted, size: 21),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: slateMuted, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : Padding(
                  padding: const EdgeInsets.only(right: 8.0, top: 6.0, bottom: 6.0),
                  child: InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            "Type to instantly filter recent orders or select status filters below",
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.tune_rounded, color: slateDark, size: 17),
                    ),
                  ),
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  // ================= 1. REVENUE HERO CARD (ANIMATED LUXURY SAPPHIRE WITH 4 QUICK ACTIONS) =================
  Widget _revenueHeroCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1D4ED8).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background decorative glowing glass circles for texture & depth
            Positioned(
              top: -30,
              right: -25,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: 60,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),

            // Card Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded, color: Colors.white70, size: 12.5)
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .scale(begin: const Offset(0.85, 0.85), end: const Offset(1.15, 1.15), duration: 1200.ms),
                          const SizedBox(width: 5),
                          const Text(
                            "TODAY'S SALES REVENUE",
                            style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5.5,
                              height: 5.5,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            )
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.4, 1.4), duration: 800.ms),
                            const SizedBox(width: 4),
                            const Text(
                              "VERIFIED STORE",
                              style: TextStyle(
                                color: sapphireBlue,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => Navigator.pushNamed(context, '/seller_revenue'),
                          borderRadius: BorderRadius.circular(8),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: todaysRevenue),
                            duration: const Duration(milliseconds: 900),
                            builder: (context, val, child) {
                              return Text(
                                "Rs. ${_formattedAmount(val)}",
                                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                              );
                            },
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.45),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.trending_up_rounded, color: Colors.white, size: 12),
                            const SizedBox(width: 2),
                            Text(
                              todaysRevenue > 0 ? "+${((todaysRevenue / (totalRevenue == 0 ? 1 : totalRevenue)) * 100).toStringAsFixed(0)}%" : "+18%",
                              style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(begin: const Offset(0.92, 0.92), end: const Offset(1.08, 1.08), duration: 1000.ms, curve: Curves.easeInOut)
                          .shimmer(duration: 1500.ms, color: Colors.white.withValues(alpha: 0.35)),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ================= 4 PURE WHITE QUICK ACTION BUTTONS =================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _heroQuickActionButton(
                        icon: Icons.add_rounded,
                        label: "Add Product",
                        iconColor: sapphireBlue,
                        onTap: () => Navigator.pushNamed(context, '/add_product'),
                      ),
                      _heroQuickActionButton(
                        icon: Icons.inventory_2_rounded,
                        label: "My Products",
                        iconColor: sapphireBlue,
                        onTap: () => Navigator.pushNamed(context, '/my_products'),
                      ),
                      _heroQuickActionButton(
                        icon: Icons.receipt_long_rounded,
                        label: "Active Orders",
                        iconColor: sapphireBlue,
                        badge: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: Text(
                            activeOrdersCount > 0 ? "$activeOrdersCount" : "0",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        onTap: () => Navigator.pushNamed(context, '/active_orders'),
                      ),
                      _heroQuickActionButton(
                        icon: Icons.chat_bubble_rounded,
                        label: "Chat Inbox",
                        iconColor: sapphireBlue,
                        badge: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const InboxScreen(isCustomer: false)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(period: const Duration(seconds: 5)))
        .shimmer(duration: const Duration(seconds: 2), color: Colors.white.withValues(alpha: 0.10));
  }

  Widget _heroQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = sapphireBlue,
    Widget? badge,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withValues(alpha: 0.25),
          highlightColor: Colors.white.withValues(alpha: 0.15),
          hoverColor: Colors.white.withValues(alpha: 0.10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, color: iconColor, size: 19),
                    ),
                    if (badge != null)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: badge,
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= PROFESSIONAL DRAWER MENU =================
  Widget _buildDrawer() {
    final drawerWidth = (MediaQuery.of(context).size.width * 0.78).clamp(270.0, 310.0);
    final topPadding = MediaQuery.of(context).padding.top;

    return Drawer(
      width: drawerWidth,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 1. Sapphire Blue Header with Rounded Bottom Corners
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, topPadding + 14, 16, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x331D4ED8),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: (sellerAvatarUrl != null && sellerAvatarUrl!.trim().isNotEmpty)
                          ? Image.network(
                              sellerAvatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Text(
                                  sellerName.isNotEmpty ? sellerName[0].toUpperCase() : 'S',
                                  style: const TextStyle(
                                    color: sapphireBlue,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                sellerName.isNotEmpty ? sellerName[0].toUpperCase() : 'S',
                                style: const TextStyle(
                                  color: sapphireBlue,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5.5,
                            height: 5.5,
                            decoration: BoxDecoration(
                              color: isStoreActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isStoreActive ? "Active Store" : "Suspended",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  sellerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sellerEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // 2. Scrollable Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              children: [
                _drawerSectionTitle("MAIN MENU"),
                _drawerTile(
                  icon: Icons.dashboard_rounded,
                  title: "Dashboard",
                  onTap: () => Navigator.pop(context),
                  isSelected: true,
                ),
                _drawerTile(
                  icon: Icons.inventory_2_outlined,
                  title: "My Products",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/my_products');
                  },
                ),
                _drawerTile(
                  icon: Icons.add_circle_outline_rounded,
                  title: "Add New Product",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/add_product');
                  },
                ),
                _drawerTile(
                  icon: Icons.receipt_long_outlined,
                  title: "Active Orders",
                  badgeText: activeOrdersCount > 0 ? "$activeOrdersCount" : null,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/active_orders');
                  },
                ),
                _drawerTile(
                  icon: Icons.history_rounded,
                  title: "All Orders History",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/seller_all_orders');
                  },
                ),

                const SizedBox(height: 6),
                _drawerSectionTitle("ANALYTICS & ENGAGEMENT"),
                _drawerTile(
                  icon: Icons.bar_chart_rounded,
                  title: "Sales Analytics",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/seller_analytics');
                  },
                ),
                _drawerTile(
                  icon: Icons.people_alt_outlined,
                  title: "Total Customers",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/total_customers');
                  },
                ),
                _drawerTile(
                  icon: Icons.rate_review_outlined,
                  title: "Customer Reviews",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/seller_reviews');
                  },
                ),
                _drawerTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: "Customer Chat",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const InboxScreen(isCustomer: false)),
                    );
                  },
                ),

                const SizedBox(height: 6),
                _drawerSectionTitle("SETTINGS"),
                _drawerTile(
                  icon: Icons.storefront_outlined,
                  title: "Manage Store",
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/manage_store');
                  },
                ),
              ],
            ),
          ),

          // 3. Bottom Logout Tile with light red container
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: InkWell(
              onTap: () async {
                await SessionService.clearSession();
                if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 16),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "Logout Account",
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFFF87171), size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Text(
        title,
        style: const TextStyle(
          color: slateMuted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  Widget _drawerTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
    String? badgeText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? sapphireBlue.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected ? sapphireBlue : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : slateDark,
                  size: 16.5,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? sapphireBlue : slateDark,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              Icon(
                Icons.chevron_right_rounded,
                color: isSelected ? sapphireBlue.withValues(alpha: 0.5) : const Color(0xFFCBD5E1),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= 2. 3 METRIC CARDS ROW (CLEAN BORDERED - REFERENCE STYLE) =================
  Widget _metricsGridScreenshotStyle(bool isWide) {
    final totalOrderCount = activeOrdersCount + recentOrders.length;
    final orderPct = activeOrdersCount > 0
        ? ((activeOrdersCount / (totalOrderCount + 1)) * 100).toStringAsFixed(0)
        : '0';
    final salePct = todaysRevenue > 0
        ? ((todaysRevenue / (totalRevenue == 0 ? 1 : totalRevenue)) * 100).toStringAsFixed(0)
        : '0';

    return Row(
      children: [
        Expanded(
          child: _cleanMetricCard(
            title: "Total Orders",
            value: "$totalOrderCount",
            changeText: "+$orderPct%",
            changePositive: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _cleanMetricCard(
            title: "Total Sales",
            value: "Rs.${_formattedAmount(totalRevenue)}",
            changeText: "+$salePct%",
            changePositive: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _cleanMetricCard(
            title: "Products",
            value: "$totalProducts",
            changeText: "$totalCustomers buyers",
            changePositive: true,
          ),
        ),
      ],
    );
  }

  Widget _cleanMetricCard({
    required String title,
    required String value,
    required String changeText,
    required bool changePositive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: slateMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: slateDark,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            changeText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: changePositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text("Sales Overview", style: TextStyle(color: slateDark, fontSize: 16, fontWeight: FontWeight.w800)),
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

  // CLEAN DROPDOWN SELECTOR FOR GRAPH FILTER
  Widget _buildGraphFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedGraphFilter,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: slateDark, size: 18),
          style: const TextStyle(color: slateDark, fontSize: 12, fontWeight: FontWeight.w600),
          isDense: true,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: ['Weekly', 'Monthly', 'Yearly'].map((String filter) {
            return DropdownMenuItem<String>(
              value: filter,
              child: Text(filter, style: const TextStyle(color: slateDark, fontSize: 12, fontWeight: FontWeight.w600)),
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
              "Recent Orders",
              style: TextStyle(color: slateDark, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            InkWell(
              onTap: () => Navigator.pushNamed(context, '/seller_all_orders'),
              child: const Text("View All", style: TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.w700)),
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
      if (selectedOrderFilter != 'All') {
        final st = (o['status']?.toString() ?? 'Pending').toLowerCase();
        if (st != selectedOrderFilter.toLowerCase()) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final id = (o['id']?.toString() ?? '').toLowerCase();
        final addr = (o['address']?.toString() ?? '').toLowerCase();
        final status = (o['status']?.toString() ?? '').toLowerCase();
        final matchId = id.contains(_searchQuery);
        final matchAddr = addr.contains(_searchQuery);
        final matchStatus = status.contains(_searchQuery);
        if (!matchId && !matchAddr && !matchStatus) return false;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
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
          child: Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shopping_bag_outlined, color: slateDark, size: 18),
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
                  Text("Rs.${amount.toStringAsFixed(0)}", style: const TextStyle(color: slateDark, fontSize: 13.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
                    child: Text(status, style: TextStyle(color: statusText, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
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