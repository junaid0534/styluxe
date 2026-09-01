import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class AdminSellersScreen extends StatefulWidget {
  final bool isStandalone;
  const AdminSellersScreen({super.key, this.isStandalone = false});

  @override
  State<AdminSellersScreen> createState() => _AdminSellersScreenState();
}

class _AdminSellersScreenState extends State<AdminSellersScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  String searchQuery = '';
  int selectedFilter = 0; // 0: All, 1: Active, 2: Pending, 3: Suspended
  String? updatingSellerId;

  StreamSubscription? _storesSub;
  List<Map<String, dynamic>> sellersList = [];
  Map<String, double> sellerRevenueMap = {};
  Map<String, int> sellerOrdersCountMap = {};

  int totalCount = 0;
  int activeCount = 0;
  int suspendedCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchSellersData();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _storesSub?.cancel();
    super.dispose();
  }

  void _subscribeRealtime() {
    _storesSub?.cancel();
    try {
      _storesSub = supabase
          .from('seller_stores')
          .stream(primaryKey: ['id'])
          .listen((_) => _fetchSellersData(showSpinner: false), onError: (e) {
            debugPrint("Seller Stores Realtime Stream error: $e");
          });
    } catch (e) {
      debugPrint("Seller Stores Stream Init error: $e");
    }
  }

  Future<void> _fetchSellersData({bool showSpinner = false}) async {
    if (!mounted) return;
    if (showSpinner) {
      setState(() => isLoading = true);
    }

    // 1. Fetch Orders & Order Items to compute revenue & order counts per seller
    final Map<String, double> tempRevMap = {};
    final Map<String, int> tempOrdersMap = {};
    final Set<String> processedOrderIds = {};

    try {
      final ordersRes = await supabase.from('orders').select('*');
      for (final o in ordersRes) {
        final orderId = o['id']?.toString() ?? o['order_id']?.toString() ?? '';
        final st = o['status']?.toString().toLowerCase() ?? '';
        if (st == 'cancelled' || st == 'canceled' || st == 'rejected' || st == 'refunded') continue;

        final rawAmt = o['total_amount'] ?? o['total_price'] ?? o['total'] ?? o['amount'];
        double amt = 0.0;
        if (rawAmt is num) {
          amt = rawAmt.toDouble();
        } else if (rawAmt != null) {
          amt = double.tryParse(rawAmt.toString().replaceAll(',', '').trim()) ?? 0.0;
        }

        if (amt > 0) {
          if (orderId.isNotEmpty) processedOrderIds.add(orderId);
          final sellerId = o['seller_id']?.toString() ?? '';
          if (sellerId.isNotEmpty) {
            tempRevMap[sellerId] = (tempRevMap[sellerId] ?? 0.0) + amt;
            tempOrdersMap[sellerId] = (tempOrdersMap[sellerId] ?? 0) + 1;
          }
        }
      }
    } catch (e) {
      debugPrint("Admin sellers orders fetch note: $e");
    }

    try {
      final itemsRes = await supabase.from('order_items').select('*');
      for (final item in itemsRes) {
        final orderId = item['order_id']?.toString() ?? '';
        if (orderId.isNotEmpty && processedOrderIds.contains(orderId)) continue;

        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        final itemTotal = (price * qty) > 0 ? (price * qty) : ((item['total'] ?? item['amount']) as num?)?.toDouble() ?? 0.0;

        if (itemTotal > 0) {
          final sellerId = item['seller_id']?.toString() ?? '';
          if (sellerId.isNotEmpty) {
            tempRevMap[sellerId] = (tempRevMap[sellerId] ?? 0.0) + itemTotal;
            tempOrdersMap[sellerId] = (tempOrdersMap[sellerId] ?? 0) + 1;
          }
        }
      }
    } catch (e) {
      debugPrint("Admin sellers order_items fetch note: $e");
    }

    // 2. Fetch Seller Stores
    List<Map<String, dynamic>> fetched = [];
    int activeC = 0;
    int suspendedC = 0;

    try {
      final storesRes = await supabase
          .from('seller_stores')
          .select('*')
          .order('created_at', ascending: false);

      for (final s in storesRes) {
        final bool isActive = s['is_active'] == true;
        final String statusStr = isActive ? 'Active' : 'Suspended';

        if (isActive) {
          activeC++;
        } else {
          suspendedC++;
        }

        final storeId = s['id']?.toString() ?? '';
        final sId = s['seller_id']?.toString() ?? '';

        double storeRev = 0.0;
        int storeOrders = 0;

        if (sId.isNotEmpty && tempRevMap.containsKey(sId)) {
          storeRev += tempRevMap[sId]!;
          storeOrders += tempOrdersMap[sId] ?? 0;
        }
        if (storeId.isNotEmpty && storeId != sId && tempRevMap.containsKey(storeId)) {
          storeRev += tempRevMap[storeId]!;
          storeOrders += tempOrdersMap[storeId] ?? 0;
        }

        fetched.add({
          'id': storeId.isNotEmpty ? storeId : sId,
          'seller_id': sId,
          'store_name': s['store_name']?.toString() ?? s['name'] ?? 'Store',
          'store_category': s['store_category']?.toString() ?? s['category'] ?? 'General',
          'tagline': s['tagline']?.toString() ?? '',
          'description': s['description']?.toString() ?? '',
          'phone': s['phone']?.toString() ?? 'N/A',
          'address': s['address']?.toString() ?? '',
          'website': s['website']?.toString() ?? '',
          'logo_url': s['logo_url']?.toString() ?? '',
          'banner_url': s['banner_url']?.toString() ?? '',
          'status': statusStr,
          'is_active': isActive,
          'total_revenue': storeRev,
          'total_orders': storeOrders,
          'created_at': s['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint("Admin sellers seller_stores fetch error: $e");
    }

    if (!mounted) return;
    setState(() {
      sellersList = fetched;
      sellerRevenueMap = tempRevMap;
      sellerOrdersCountMap = tempOrdersMap;
      totalCount = fetched.length;
      activeCount = activeC;
      suspendedCount = suspendedC;
      isLoading = false;
    });
  }

  Future<void> _updateSellerStatus(String storeId, String newStatus) async {
    if (updatingSellerId != null) return;
    setState(() => updatingSellerId = storeId);

    final bool activeBool = newStatus.toLowerCase() == 'active';
    try {
      dynamic res = await supabase.from('seller_stores').update({
        'is_active': activeBool,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', storeId).select();

      if (res is List && res.isEmpty) {
        // Try fallback to seller_id
        res = await supabase.from('seller_stores').update({
          'is_active': activeBool,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('seller_id', storeId).select();
      }

      if (res is List && res.isEmpty) {
        throw Exception("Supabase RLS blocked UPDATE on 'seller_stores'. Please run the UPDATE policy in Supabase SQL Editor.");
      }

      await _fetchSellersData(showSpinner: false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                activeBool ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  activeBool ? "Store activated successfully!" : "Store suspended/deactivated successfully!",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: activeBool ? AppColors.primary : const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e", style: GoogleFonts.poppins()),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => updatingSellerId = null);
    }
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

  List<Map<String, dynamic>> _getFilteredSellers() {
    return sellersList.where((s) {
      final st = s['status']?.toString().toLowerCase() ?? '';
      final name = s['store_name']?.toString().toLowerCase() ?? '';
      final cat = s['store_category']?.toString().toLowerCase() ?? '';
      final phone = s['phone']?.toString().toLowerCase() ?? '';
      final query = searchQuery.toLowerCase().trim();

      bool matchesFilter = true;
      if (selectedFilter == 1) matchesFilter = st == 'active';
      if (selectedFilter == 2) matchesFilter = st == 'suspended' || st == 'inactive';

      bool matchesSearch = query.isEmpty ||
          name.contains(query) ||
          cat.contains(query) ||
          phone.contains(query);

      return matchesFilter && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredSellers();

    Widget bodyContent = RefreshIndicator(
      onRefresh: () => _fetchSellersData(showSpinner: true),
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Title & Actions (if standalone)
                if (widget.isStandalone) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Seller Management",
                            style: GoogleFonts.poppins(
                              color: AppColors.slateDark,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            "Realtime Store Oversight & Account Activation",
                            style: GoogleFonts.poppins(
                              color: AppColors.slateMuted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      IconButton.filledTonal(
                        onPressed: () => _fetchSellersData(showSpinner: true),
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],

                // 1. Metric Stats 1-Row without cards (Icon on top, numbers below)
                _buildMetricsStatsRow(),

                const SizedBox(height: 16),

                // 2. Search Bar + Filter Dropdown in 1 Row
                _buildSearchAndFilterRow(),

                const SizedBox(height: 16),

                // 3. Sellers List / Empty State
                if (isLoading)
                  _buildLoadingShimmer()
                else if (filtered.isEmpty)
                  _buildEmptyState()
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, idx) => const SizedBox(height: 14),
                    itemBuilder: (ctx, index) {
                      final s = filtered[index];
                      return _buildSellerCard(s, index);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.isStandalone) {
      return Scaffold(
        backgroundColor: AppColors.bgLight,
        appBar: AppBar(
          toolbarHeight: 46.0,
          title: Text(
            "StyLuxe",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: AppColors.slateDark, fontSize: 18),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.slateDark, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(child: bodyContent),
      );
    }

    return bodyContent;
  }

  // ================= 1-ROW METRICS STATS (EMERALD GRADIENT) =================
  Widget _buildMetricsStatsRow() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Total Stores
          Expanded(
            child: _metricStatItem(
              icon: Icons.storefront_rounded,
              count: "$totalCount",
              label: "Total Stores",
            ),
          ),
          Container(width: 1, height: 38, color: Colors.white.withValues(alpha: 0.25)),

          // 2. Active Stores
          Expanded(
            child: _metricStatItem(
              icon: Icons.check_circle_rounded,
              count: "$activeCount",
              label: "Active",
            ),
          ),
          Container(width: 1, height: 38, color: Colors.white.withValues(alpha: 0.25)),

          // 3. Suspended Stores
          Expanded(
            child: _metricStatItem(
              icon: Icons.block_rounded,
              count: "$suspendedCount",
              label: "Suspended",
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04);
  }

  Widget _metricStatItem({
    required IconData icon,
    required String count,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 4),
        Text(
          count,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ================= SEARCH BAR + FILTER DROPDOWN IN 1 ROW =================
  Widget _buildSearchAndFilterRow() {
    return Row(
      children: [
        // 1. Search Bar with Clean Radius & "search store" Placeholder
        Expanded(
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderColor),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onChanged: (v) => setState(() => searchQuery = v),
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.slateDark),
              decoration: InputDecoration(
                hintText: "search store",
                hintStyle: GoogleFonts.poppins(color: AppColors.slateLight, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppColors.slateMuted, size: 16),
                        onPressed: () => setState(() => searchQuery = ''),
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // 2. Filter Dropdown
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderColor),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: selectedFilter,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.slateDark, size: 20),
              style: GoogleFonts.poppins(color: AppColors.slateDark, fontSize: 12.5, fontWeight: FontWeight.w700),
              borderRadius: BorderRadius.circular(14),
              dropdownColor: Colors.white,
              items: [
                DropdownMenuItem(
                  value: 0,
                  child: Text("All ($totalCount)"),
                ),
                DropdownMenuItem(
                  value: 1,
                  child: Text("Active ($activeCount)"),
                ),
                DropdownMenuItem(
                  value: 2,
                  child: Text("Suspended ($suspendedCount)"),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => selectedFilter = val);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  // ================= MODERN SELLER CARD =================
  Widget _buildSellerCard(Map<String, dynamic> seller, int index) {
    final id = seller['id']?.toString() ?? '';
    final sellerId = seller['seller_id']?.toString() ?? id;
    final storeName = seller['store_name']?.toString() ?? 'Store';
    final category = seller['store_category']?.toString() ?? 'General';
    final phone = seller['phone']?.toString() ?? 'N/A';
    final rev = (seller['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final ordersCount = (seller['total_orders'] as num?)?.toInt() ?? 0;
    final createdAt = seller['created_at']?.toString();
    final status = seller['status']?.toString() ?? 'Pending';
    final logoUrl = seller['logo_url']?.toString() ?? '';

    final bool isActive = status.toLowerCase() == 'active';
    final bool isSuspended = status.toLowerCase() == 'suspended';
    final bool isPending = status.toLowerCase() == 'pending';
    final bool isThisUpdating = updatingSellerId == (id.isNotEmpty ? id : sellerId);

    Color badgeBg = const Color(0xFFFEF7E0);
    Color badgeColor = const Color(0xFFF59E0B);
    if (isActive) {
      badgeBg = const Color(0xFFE6F4EA);
      badgeColor = const Color(0xFF10B981);
    } else if (isSuspended) {
      badgeBg = const Color(0xFFFCE8E6);
      badgeColor = const Color(0xFFEF4444);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? AppColors.borderColor : (isPending ? const Color(0xFFFDE68A) : const Color(0xFFFECACA)),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showSellerDetailsSheet(seller),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Store Avatar, Name, Category & Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Store Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.15),
                            AppColors.primary.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: logoUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                logoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.storefront_rounded,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.storefront_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                    ),
                    const SizedBox(width: 12),

                    // Store Name & Category
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            storeName,
                            style: GoogleFonts.poppins(
                              color: AppColors.slateDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  category,
                                  style: GoogleFonts.poppins(
                                    color: AppColors.slateMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "• ${_timeAgo(createdAt)}",
                                style: GoogleFonts.poppins(
                                  color: AppColors.slateLight,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(radius: 3.5, backgroundColor: badgeColor),
                          const SizedBox(width: 5),
                          Text(
                            status.toUpperCase(),
                            style: GoogleFonts.poppins(
                              color: badgeColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Middle Stats Grid (Revenue, Orders, Phone)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      // Revenue
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "LIFETIME REVENUE",
                              style: GoogleFonts.poppins(
                                color: AppColors.slateLight,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Rs. ${rev.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}",
                              style: GoogleFonts.poppins(
                                color: AppColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),

                      // Orders Count
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "TOTAL ORDERS",
                                style: GoogleFonts.poppins(
                                  color: AppColors.slateLight,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "$ordersCount",
                                style: GoogleFonts.poppins(
                                  color: AppColors.slateDark,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),

                      // Phone
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "CONTACT",
                                style: GoogleFonts.poppins(
                                  color: AppColors.slateLight,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                phone,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: AppColors.slateDark,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Bottom Action Buttons
                if (isThisUpdating)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      // View Details button
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.slateDark,
                            side: const BorderSide(color: AppColors.borderColor),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _showSellerDetailsSheet(seller),
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: Text(
                            "Details",
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Approve / Activate Button
                      if (!isActive)
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () => _updateSellerStatus(id.isNotEmpty ? id : sellerId, 'Active'),
                            icon: const Icon(Icons.check_circle_rounded, size: 16),
                            label: Text(
                              "Activate Store",
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                        ),

                      // Suspend / Deactivate Button
                      if (isActive)
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () => _showConfirmSuspendDialog(id.isNotEmpty ? id : sellerId, storeName),
                            icon: const Icon(Icons.block_rounded, size: 16),
                            label: Text(
                              "Suspend Store",
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms, delay: (index * 40).ms).slideY(begin: 0.04);
  }

  // ================= CONFIRM SUSPEND DIALOG =================
  void _showConfirmSuspendDialog(String storeId, String storeName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Suspend Seller Store?",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: AppColors.slateDark, fontSize: 17),
        ),
        content: Text(
          "Are you sure you want to suspend '$storeName'? The store and its products will be temporarily deactivated on the customer app.",
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.slateMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.slateMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _updateSellerStatus(storeId, 'Suspended');
            },
            child: Text("Suspend Store", style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ================= SELLER DETAILS BOTTOM SHEET =================
  void _showSellerDetailsSheet(Map<String, dynamic> seller) {
    final id = seller['id']?.toString() ?? '';
    final sellerId = seller['seller_id']?.toString() ?? id;
    final storeName = seller['store_name']?.toString() ?? 'Store';
    final category = seller['store_category']?.toString() ?? 'General';
    final tagline = seller['tagline']?.toString() ?? '';
    final description = seller['description']?.toString() ?? '';
    final phone = seller['phone']?.toString() ?? 'N/A';
    final address = seller['address']?.toString() ?? 'N/A';
    final website = seller['website']?.toString() ?? 'N/A';
    final status = seller['status']?.toString() ?? 'Pending';
    final rev = (seller['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final ordersCount = (seller['total_orders'] as num?)?.toInt() ?? 0;
    final createdAt = seller['created_at']?.toString();

    final bool isActive = status.toLowerCase() == 'active';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storeName,
                          style: GoogleFonts.poppins(
                            color: AppColors.slateDark,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (tagline.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            tagline,
                            style: GoogleFonts.poppins(color: AppColors.slateMuted, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, color: AppColors.slateMuted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.borderColor),
              const SizedBox(height: 16),

              // Detail List Items
              _detailRow("Category", category, Icons.category_outlined),
              _detailRow("Status", status.toUpperCase(), Icons.shield_outlined),
              _detailRow("Seller ID", sellerId, Icons.badge_outlined),
              _detailRow("Contact Phone", phone, Icons.phone_outlined),
              _detailRow("Address", address.isNotEmpty ? address : "Not provided", Icons.location_on_outlined),
              _detailRow("Website", website.isNotEmpty ? website : "Not provided", Icons.language_outlined),
              _detailRow("Registered Date", createdAt != null ? createdAt.split('T').first : "N/A", Icons.calendar_today_outlined),
              _detailRow("Total Sales", "Rs. ${rev.toStringAsFixed(0)}", Icons.account_balance_wallet_outlined),
              _detailRow("Total Orders Count", "$ordersCount orders", Icons.shopping_bag_outlined),

              if (description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  "Store Description",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.slateDark, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.poppins(color: AppColors.slateMuted, fontSize: 12.5, height: 1.4),
                ),
              ],

              const SizedBox(height: 24),

              // Actions Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isActive ? const Color(0xFFEF4444) : AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _updateSellerStatus(id.isNotEmpty ? id : sellerId, isActive ? 'Suspended' : 'Active');
                      },
                      icon: Icon(isActive ? Icons.block_rounded : Icons.check_circle_rounded, size: 18),
                      label: Text(
                        isActive ? "Suspend Seller Account" : "Activate Seller Account",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.slateMuted),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.poppins(color: AppColors.slateMuted, fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(color: AppColors.slateDark, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ================= LOADING SHIMMER & EMPTY STATE =================
  Widget _buildLoadingShimmer() {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.storefront_outlined, size: 42, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          Text(
            sellersList.isEmpty ? "No Registered Sellers Found" : "No Sellers Matching Filter",
            style: GoogleFonts.poppins(
              color: AppColors.slateDark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sellersList.isEmpty
                ? "Stores registered by sellers will automatically populate here in real-time."
                : "Try clearing your search query or switching filter tabs.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: AppColors.slateMuted, fontSize: 12.5),
          ),
          if (searchQuery.isNotEmpty || selectedFilter != 0) ...[
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: () => setState(() {
                searchQuery = '';
                selectedFilter = 0;
              }),
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text("Reset Filters"),
            ),
          ],
        ],
      ),
    );
  }
}
