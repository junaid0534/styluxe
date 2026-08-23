import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../theme/app_theme.dart';
import 'order_detail_screen.dart';
import 'order_tracking_screen.dart';
import 'order_invoice_bill_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;
  String selectedFilter = 'All';
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<List<Map<String, dynamic>>>? _ordersSubscription;

  @override
  void initState() {
    super.initState();
    fetchOrders();
    setupRealtimeOrders();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ================= FETCH ORDERS =================
  Future<void> fetchOrders() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception("Please login first");
      }

      final data = await supabase
          .from('orders')
          .select('*, order_items(*, products(*))')
          .eq('user_id', currentUser.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        orders = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      // Fallback query if relation fails
      try {
        final currentUser = supabase.auth.currentUser;
        if (currentUser != null) {
          final data = await supabase
              .from('orders')
              .select('*')
              .eq('user_id', currentUser.id)
              .order('created_at', ascending: false);

          if (mounted) {
            setState(() {
              orders = List<Map<String, dynamic>>.from(data);
              isLoading = false;
            });
            return;
          }
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  // ================= REALTIME ORDERS =================
  void setupRealtimeOrders() {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      _ordersSubscription = supabase
          .from('orders')
          .stream(primaryKey: ['id'])
          .eq('user_id', currentUser.id)
          .listen(
            (data) {
              if (!mounted) return;

              final updatedOrders = List<Map<String, dynamic>>.from(data);
              updatedOrders.sort((a, b) {
                final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(2000);
                final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(2000);
                return bDate.compareTo(aDate);
              });

              setState(() {
                orders = updatedOrders;
                isLoading = false;
              });
            },
            onError: (error) {
              debugPrint("Orders realtime error: $error");
            },
          );
    } catch (e) {
      debugPrint("Realtime setup error: $e");
    }
  }

  String _getOrderNumber(Map<String, dynamic> order) {
    final orderId = order['order_id']?.toString();
    if (orderId != null && orderId.trim().isNotEmpty) {
      return orderId;
    }
    final id = order['id']?.toString() ?? '00000000';
    return id.length >= 8 ? id.substring(0, 8) : id;
  }

  List<Map<String, dynamic>> get filteredOrders {
    return orders.where((order) {
      final status = (order['status']?.toString() ?? 'Pending').toLowerCase();
      final orderNo = _getOrderNumber(order).toLowerCase();

      // Filter by status tab
      bool matchesStatus = true;
      if (selectedFilter == 'Pending') {
        matchesStatus = status == 'pending';
      } else if (selectedFilter == 'Processing') {
        matchesStatus = status == 'processing';
      } else if (selectedFilter == 'Shipped') {
        matchesStatus = status == 'shipped';
      } else if (selectedFilter == 'Delivered') {
        matchesStatus = status == 'delivered';
      } else if (selectedFilter == 'Cancelled') {
        matchesStatus = status == 'cancelled' || status == 'canceled';
      }

      // Filter by search text
      bool matchesSearch = true;
      if (searchQuery.trim().isNotEmpty) {
        final query = searchQuery.trim().toLowerCase();
        matchesSearch = orderNo.contains(query) || status.contains(query);
      }

      return matchesStatus && matchesSearch;
    }).toList();
  }

  int _countByStatus(String statusKey) {
    if (statusKey == 'All') return orders.length;
    return orders.where((o) {
      final st = (o['status']?.toString() ?? 'Pending').toLowerCase();
      if (statusKey == 'Cancelled') return st == 'cancelled' || st == 'canceled';
      return st == statusKey.toLowerCase();
    }).length;
  }

  double get _totalSpent {
    double total = 0;
    for (var o in orders) {
      final st = (o['status']?.toString() ?? '').toLowerCase();
      if (st != 'cancelled' && st != 'canceled') {
        total += ((o['total_amount'] as num?)?.toDouble() ?? 0.0);
      }
    }
    return total;
  }

  int get _activeOrdersCount {
    return orders.where((o) {
      final st = (o['status']?.toString() ?? '').toLowerCase();
      return st == 'pending' || st == 'processing' || st == 'shipped';
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final displayOrders = filteredOrders;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        toolbarHeight: 46.0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.slateDark, size: 17),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "My Orders",
          style: TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 16.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.slateDark,
              size: 20,
            ),
            onPressed: fetchOrders,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                // ================= TOP METRICS HERO CARD (STYLUXE EMERALD THEME) =================
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.28),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: Header & Active Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.22),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.local_mall_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "Orders Activity",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      "$_activeOrdersCount Active",
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Stats Row: 2 Glassmorphic Stat Boxes
                          Row(
                            children: [
                              // Stat 1: Total Orders
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.receipt_long_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Total Orders",
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.85),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            "${orders.length}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(width: 10),

                              // Stat 2: Total Spent
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.account_balance_wallet_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Total Spent",
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.85),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              "Rs. ${_totalSpent.toStringAsFixed(0)}",
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
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
                    ).animate().fadeIn(duration: 300.ms),
                  ),
                ),

                // ================= SEARCH BAR & FILTER DROPDOWN ROW =================
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                    child: Row(
                      children: [
                        // 1. Search Bar (Expanded)
                        Expanded(
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) {
                                setState(() {
                                  searchQuery = val;
                                });
                              },
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.slateDark,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: "Search order by ID...",
                                hintStyle: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.slateMuted,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 17,
                                  color: AppColors.slateMuted,
                                ),
                                suffixIcon: searchQuery.isNotEmpty
                                    ? GestureDetector(
                                        onTap: () {
                                          _searchController.clear();
                                          setState(() {
                                            searchQuery = '';
                                          });
                                        },
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 15,
                                          color: AppColors.slateMuted,
                                        ),
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // 2. Filter Dropdown Button
                        PopupMenuButton<String>(
                          onSelected: (String status) {
                            setState(() {
                              selectedFilter = status;
                            });
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          elevation: 8,
                          color: Colors.white,
                          surfaceTintColor: Colors.white,
                          offset: const Offset(0, 44),
                          itemBuilder: (BuildContext context) {
                            final filterOptions = ['All', 'Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled'];
                            return filterOptions.map((String status) {
                              final isSelected = selectedFilter == status;
                              final count = _countByStatus(status);
                              return PopupMenuItem<String>(
                                value: status,
                                height: 40,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                          size: 16,
                                          color: isSelected ? AppColors.primary : AppColors.slateMuted,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          status,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                            color: isSelected ? AppColors.primary : AppColors.slateDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 14),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary.withValues(alpha: 0.12)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "$count",
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? AppColors.primary : AppColors.slateMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList();
                          },
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: selectedFilter == 'All' ? Colors.white : AppColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selectedFilter == 'All' ? const Color(0xFFE2E8F0) : AppColors.primary,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.tune_rounded,
                                  size: 16,
                                  color: selectedFilter == 'All' ? AppColors.slateDark : AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  selectedFilter,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: selectedFilter == 'All' ? AppColors.slateDark : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 16,
                                  color: selectedFilter == 'All' ? AppColors.slateMuted : AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ================= ORDERS LIST OR EMPTY STATE =================
                displayOrders.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: _emptyOrdersView(),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final order = displayOrders[index];
                              return OrderCard(
                                order: order,
                                orderNumber: _getOrderNumber(order),
                                onRefresh: fetchOrders,
                              )
                                  .animate()
                                  .fadeIn(
                                    duration: 250.ms,
                                    delay: (index * 40).ms,
                                  );
                            },
                            childCount: displayOrders.length,
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      bottomNavigationBar: _buildFullWidthBottomNav(4),
    );
  }

  Widget _emptyOrdersView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 40,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                selectedFilter == 'All' && searchQuery.isEmpty
                    ? "No Orders Yet"
                    : "No $selectedFilter Orders Found",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.slateDark,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                searchQuery.isNotEmpty
                    ? "No order matches '$searchQuery'."
                    : "When you place orders, they will show up here.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (searchQuery.isNotEmpty || selectedFilter != 'All') {
                      _searchController.clear();
                      setState(() {
                        searchQuery = '';
                        selectedFilter = 'All';
                      });
                    } else {
                      Navigator.pushNamed(context, '/shop_now');
                    }
                  },
                  icon: Icon(
                    searchQuery.isNotEmpty || selectedFilter != 'All'
                        ? Icons.filter_alt_off_rounded
                        : Icons.shopping_bag_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: Text(
                    searchQuery.isNotEmpty || selectedFilter != 'All'
                        ? "Reset Filters"
                        : "Start Shopping",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= FULL WIDTH BOTTOM NAV BAR =================
  Widget _buildFullWidthBottomNav(int activeIndex) {
    return Container(
      height: 50,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(icon: Icons.home_rounded, label: "Home", index: 0, route: '/customer_home', activeIndex: activeIndex),
            _navItem(icon: Icons.explore_outlined, label: "Explore", index: 1, route: '/shop_now', activeIndex: activeIndex),
            _navItem(icon: Icons.favorite_border_rounded, label: "Wishlist", index: 2, route: '/wishlist', activeIndex: activeIndex),
            _navItem(icon: Icons.shopping_cart_outlined, label: "Cart", index: 3, route: '/cart', activeIndex: activeIndex),
            _navItem(icon: Icons.person_outline_rounded, label: "Profile", index: 4, route: '/my_profile', activeIndex: activeIndex),
          ],
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required int index,
    required String route,
    required int activeIndex,
  }) {
    final bool isSelected = activeIndex == index;

    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          Navigator.pushReplacementNamed(context, route);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppColors.primary : AppColors.slateMuted,
            ),
            if (isSelected) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ================= AMAZON-STYLE MODERN PROFESSIONAL ORDER CARD =================
class OrderCard extends StatefulWidget {
  final Map<String, dynamic> order;
  final String orderNumber;
  final VoidCallback? onRefresh;

  const OrderCard({
    super.key,
    required this.order,
    required this.orderNumber,
    this.onRefresh,
  });

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  final supabase = Supabase.instance.client;
  bool isReordering = false;

  Color _statusColor(String status) {
    final value = status.toLowerCase();
    if (value == 'delivered' || value == 'completed') return const Color(0xFF16A34A); // Green
    if (value == 'shipped' || value == 'dispatched') return const Color(0xFF65A30D); // Olive green / Dispatched
    if (value == 'cancelled' || value == 'canceled') return const Color(0xFFDC2626); // Red
    if (value == 'processing') return const Color(0xFF7C3AED); // Purple
    return const Color(0xFFD97706); // Amber
  }

  String _statusLabel(String status) {
    final value = status.toLowerCase();
    if (value == 'delivered' || value == 'completed') return "Delivered";
    if (value == 'shipped' || value == 'dispatched') return "Dispatched";
    if (value == 'cancelled' || value == 'canceled') return "Cancelled";
    if (value == 'processing') return "Processing";
    return "Order Placed";
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return "N/A";
    final date = DateTime.tryParse(raw);
    if (date == null) {
      return raw.length >= 10 ? raw.substring(0, 10) : raw;
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }

  double _amount(dynamic value) {
    return (value as num?)?.toDouble() ?? 0.0;
  }

  // ================= REPEAT ORDER LOGIC =================
  Future<void> _handleRepeatOrder(List<dynamic> itemsList) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to repeat order")),
      );
      return;
    }

    setState(() => isReordering = true);

    try {
      List<Map<String, dynamic>> itemsToReorder = [];

      if (itemsList.isNotEmpty) {
        itemsToReorder = List<Map<String, dynamic>>.from(itemsList);
      } else {
        final data = await supabase
            .from('order_items')
            .select('*, products(*)')
            .eq('order_id', widget.order['id'] ?? '');
        itemsToReorder = List<Map<String, dynamic>>.from(data);
      }

      if (itemsToReorder.isEmpty) {
        throw Exception("No items found in this order to reorder");
      }

      int addedCount = 0;
      for (final item in itemsToReorder) {
        final productId = item['product_id']?.toString() ??
            item['products']?['id']?.toString();
        final int qty = (item['quantity'] as num?)?.toInt() ?? 1;

        if (productId != null && productId.isNotEmpty) {
          final existing = await supabase
              .from('cart')
              .select('id, quantity')
              .eq('user_id', currentUser.id)
              .eq('product_id', productId)
              .maybeSingle();

          if (existing != null) {
            final int currentQty = (existing['quantity'] as num?)?.toInt() ?? 1;
            await supabase
                .from('cart')
                .update({'quantity': currentQty + qty})
                .eq('id', existing['id']);
          } else {
            await supabase.from('cart').insert({
              'user_id': currentUser.id,
              'product_id': productId,
              'quantity': qty,
            });
          }
          addedCount++;
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "$addedCount item${addedCount > 1 ? 's' : ''} added to cart!",
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: "VIEW CART",
            textColor: Colors.white,
            onPressed: () => Navigator.pushNamed(context, '/cart'),
          ),
        ),
      );
    } catch (e) {
      debugPrint("Repeat Order Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to re-order: $e"),
            backgroundColor: AppColors.roseRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isReordering = false);
    }
  }

  // ================= CANCEL ORDER DIALOG =================
  Future<void> _showCancelOrderDialog() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: AppColors.roseRed, size: 22),
            SizedBox(width: 8),
            Text("Cancel Order?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Text(
          "Are you sure you want to cancel this order? This action cannot be undone.",
          style: TextStyle(fontSize: 13, color: AppColors.slateMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Keep Order", style: TextStyle(color: AppColors.slateDark, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.roseRed,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Yes, Cancel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase
            .from('orders')
            .update({'status': 'cancelled'})
            .eq('id', widget.order['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Order has been cancelled"),
              backgroundColor: AppColors.roseRed,
            ),
          );
          widget.onRefresh?.call();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to cancel order: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.order['status']?.toString() ?? 'Pending';
    final statusColor = _statusColor(status);
    final statusText = _statusLabel(status);
    final isDelivered = status.toLowerCase() == 'delivered' || status.toLowerCase() == 'completed';
    final isCancelled = status.toLowerCase() == 'cancelled' || status.toLowerCase() == 'canceled';
    final isPending = status.toLowerCase() == 'pending';

    final totalAmount = _amount(widget.order['total_amount']);
    final paymentMethod = widget.order['payment_method']?.toString() ?? 'COD';
    final formattedDate = _formatDate(widget.order['created_at']);

    // Extract item preview list
    final rawItems = widget.order['order_items'];
    List<dynamic> itemsList = [];
    if (rawItems is List) {
      itemsList = rawItems;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= TOP ACCENT LINE (STYLUXE EMERALD ACCENT) =================
          Container(
            height: 3.5,
            width: double.infinity,
            color: AppColors.primary,
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ================= 1. STATUS LINE WITH LIVE DOT =================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          statusText,
                          style: const TextStyle(
                            color: AppColors.slateDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "Order #${widget.orderNumber}",
                      style: const TextStyle(
                        color: AppColors.slateMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ================= 2. INNER WHITE PRODUCT BOX (As in Reference Image) =================
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: itemsList.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Icon(Icons.shopping_bag_outlined, color: AppColors.slateMuted, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isDelivered
                                          ? "Delivered on $formattedDate"
                                          : isCancelled
                                              ? "Order Cancelled"
                                              : "Expected in 3-5 days",
                                      style: const TextStyle(
                                        color: AppColors.slateDark,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      "Standard Delivery • 7am - 9pm",
                                      style: TextStyle(color: AppColors.slateMuted, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: itemsList.take(2).map((item) {
                            final idx = itemsList.indexOf(item);
                            final itemMap = item as Map<String, dynamic>? ?? {};
                            final prod = itemMap['products'] as Map<String, dynamic>? ?? {};
                            final name = prod['name']?.toString() ?? 'Product Item';
                            final imageUrl = prod['image_url']?.toString() ?? '';
                            final qty = (itemMap['quantity'] as num?)?.toInt() ?? 1;
                            final price = (itemMap['price'] as num?)?.toDouble() ?? 0.0;

                            // Title headline based on status
                            String itemHeadline = "";
                            if (isDelivered) {
                              itemHeadline = "Delivered on $formattedDate";
                            } else if (status.toLowerCase() == 'shipped' || status.toLowerCase() == 'dispatched') {
                              itemHeadline = "Arrives tomorrow";
                            } else if (isCancelled) {
                              itemHeadline = "Order Cancelled";
                            } else {
                              itemHeadline = "Expected in 3-5 days";
                            }

                            return Column(
                              children: [
                                if (idx > 0)
                                  const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      // Product thumbnail with +N badge if first item and multiple items
                                      Row(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(7),
                                              child: imageUrl.isNotEmpty
                                                  ? Image.network(
                                                      imageUrl,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) => const Icon(
                                                        Icons.checkroom_rounded,
                                                        size: 20,
                                                        color: AppColors.slateMuted,
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons.checkroom_rounded,
                                                      size: 20,
                                                      color: AppColors.slateMuted,
                                                    ),
                                            ),
                                          ),
                                          if (idx == 0 && itemsList.length > 2) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1E293B),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  "+${itemsList.length - 1}",
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              itemHeadline,
                                              style: TextStyle(
                                                color: isCancelled ? AppColors.roseRed : AppColors.slateDark,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "$name (x$qty)",
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppColors.slateDark,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 11.5,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "7am - 9pm • Rs. ${(price * qty).toStringAsFixed(0)}",
                                              style: const TextStyle(
                                                color: AppColors.slateMuted,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                ),

                const SizedBox(height: 10),

                // ================= 3. ORDER METADATA SUMMARY =================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Payment: $paymentMethod",
                        style: const TextStyle(
                          color: AppColors.slateMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "Total: Rs. ${totalAmount.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ================= 4. FULL-WIDTH STACKED ACTION BUTTONS =================
                // Primary Action Button (Styluxe Emerald)
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () {
                      if (isDelivered) {
                        if (!isReordering) _handleRepeatOrder(itemsList);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderTrackingScreen(order: widget.order),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: isReordering
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            isDelivered ? "Repeat order" : "Track order",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 8),

                // Secondary Action Button (Outlined - View order details)
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OrderDetailScreen(order: widget.order),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.primary, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "View order details",
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ================= 5. BOTTOM FOOTER LINKS (Get invoice | Edit order / Cancel) =================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderInvoiceBillScreen(order: widget.order),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        child: Text(
                          "Get invoice",
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: isPending
                          ? _showCancelOrderDialog
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OrderDetailScreen(order: widget.order),
                                ),
                              );
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        child: Text(
                          isPending ? "Cancel order" : "Edit order",
                          style: TextStyle(
                            color: isPending ? AppColors.roseRed : const Color(0xFF2563EB),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}