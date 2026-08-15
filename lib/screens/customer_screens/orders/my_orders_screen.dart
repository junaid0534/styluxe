import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../theme/app_theme.dart';
import 'order_detail_screen.dart';
import 'order_tracking_screen.dart';

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
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.slateDark, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "My Orders",
          style: TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.slateDark,
              size: 22,
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
                // ================= TOP METRICS HEADER CARD =================
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF0F172A),
                            Color(0xFF1E293B),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.25),
                            blurRadius: 16,
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
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.20),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.local_mall_rounded,
                                      color: AppColors.primary,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    "Order Overview",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.40),
                                  ),
                                ),
                                child: Text(
                                  "$_activeOrdersCount Active",
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _headerMetricTile(
                                  label: "Total Orders",
                                  value: "${orders.length}",
                                  icon: Icons.receipt_long_rounded,
                                ),
                              ),
                              Container(
                                height: 32,
                                width: 1,
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                              Expanded(
                                child: _headerMetricTile(
                                  label: "Total Spent",
                                  value: "Rs. ${_totalSpent.toStringAsFixed(0)}",
                                  icon: Icons.account_balance_wallet_rounded,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.05, end: 0),
                  ),
                ),

                // ================= SEARCH BAR =================
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            searchQuery = val;
                          });
                        },
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.slateDark,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: "Search order by ID...",
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: AppColors.slateMuted,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
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
                                    size: 18,
                                    color: AppColors.slateMuted,
                                  ),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ),

                // ================= STATUS FILTER TABS =================
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    child: Row(
                      children: [
                        _statusChip('All'),
                        _statusChip('Pending'),
                        _statusChip('Processing'),
                        _statusChip('Shipped'),
                        _statusChip('Delivered'),
                        _statusChip('Cancelled'),
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
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final order = displayOrders[index];
                              return OrderCard(
                                order: order,
                                orderNumber: _getOrderNumber(order),
                              )
                                  .animate()
                                  .fadeIn(
                                    duration: 300.ms,
                                    delay: (index * 50).ms,
                                  )
                                  .slideY(
                                    begin: 0.05,
                                    end: 0,
                                    duration: 300.ms,
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

  Widget _headerMetricTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 14),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final isSelected = selectedFilter == status;
    final count = _countByStatus(status);

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = status;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              status,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.slateDark,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                "$count",
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.slateMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
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
      height: 64,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppColors.primary : AppColors.slateMuted,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12.5,
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

// ================= ORDER CARD =================
class OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final String orderNumber;

  const OrderCard({
    super.key,
    required this.order,
    required this.orderNumber,
  });

  Color _statusColor(String status) {
    final value = status.toLowerCase();
    if (value == 'delivered') return AppColors.primary;
    if (value == 'shipped') return const Color(0xFF0EA5E9);
    if (value == 'cancelled' || value == 'canceled') return const Color(0xFFEF4444);
    if (value == 'processing') return const Color(0xFF8B5CF6);
    return const Color(0xFFF59E0B);
  }

  IconData _statusIcon(String status) {
    final value = status.toLowerCase();
    if (value == 'delivered') return Icons.check_circle_rounded;
    if (value == 'shipped') return Icons.local_shipping_rounded;
    if (value == 'cancelled' || value == 'canceled') return Icons.cancel_rounded;
    if (value == 'processing') return Icons.sync_rounded;
    return Icons.access_time_filled_rounded;
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return "N/A";
    final date = DateTime.tryParse(raw);
    if (date == null) {
      return raw.length >= 10 ? raw.substring(0, 10) : raw;
    }
    return "${date.day.toString().padLeft(2, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.year}";
  }

  double _amount(dynamic value) {
    return (value as num?)?.toDouble() ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final status = order['status']?.toString() ?? 'Pending';
    final statusColor = _statusColor(status);
    final totalAmount = _amount(order['total_amount']);

    // Extract item preview list if available
    final rawItems = order['order_items'];
    List<dynamic> itemsList = [];
    if (rawItems is List) {
      itemsList = rawItems;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= TOP ROW =================
            Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Order #$orderNumber",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.slateDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Placed on ${_formatDate(order['created_at'])}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.slateMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _statusIcon(status),
                        color: statusColor,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ================= ITEM PREVIEW THUMBNAILS (IF ANY) =================
            if (itemsList.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: itemsList.length,
                  itemBuilder: (context, idx) {
                    final itemMap = itemsList[idx] as Map<String, dynamic>? ?? {};
                    final product = itemMap['products'] as Map<String, dynamic>? ?? {};
                    final imageUrl = product['image_url']?.toString() ?? '';

                    return Container(
                      width: 48,
                      height: 48,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.checkroom_rounded,
                                  size: 22,
                                  color: AppColors.slateMuted,
                                ),
                              )
                            : const Icon(
                                Icons.checkroom_rounded,
                                size: 22,
                                color: AppColors.slateMuted,
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 12),

            // ================= SUMMARY TILE =================
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _InfoTile(
                      title: "Total Amount",
                      value: "Rs. ${totalAmount.toStringAsFixed(0)}",
                      color: AppColors.primary,
                    ),
                  ),
                  Container(
                    height: 32,
                    width: 1,
                    color: const Color(0xFFE2E8F0),
                  ),
                  Expanded(
                    child: _InfoTile(
                      title: "Items Count",
                      value: itemsList.isNotEmpty
                          ? "${itemsList.length} Item${itemsList.length > 1 ? 's' : ''}"
                          : "1 Item",
                      color: AppColors.slateDark,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ================= ACTION BUTTONS =================
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderDetailScreen(
                              order: order,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.receipt_long_outlined,
                        size: 16,
                        color: AppColors.slateDark,
                      ),
                      label: const Text(
                        "Details",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.slateDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFFE2E8F0),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderTrackingScreen(
                              order: order,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.track_changes_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Track",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ================= INFO TILE =================
class _InfoTile extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _InfoTile({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.slateMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}