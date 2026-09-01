import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../widgets/seller_bottom_nav.dart';

class SellerAnalyticsScreen extends StatefulWidget {
  const SellerAnalyticsScreen({super.key});

  @override
  State<SellerAnalyticsScreen> createState() => _SellerAnalyticsScreenState();
}

class _SellerAnalyticsScreenState extends State<SellerAnalyticsScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  String selectedFilter = "Monthly";

  final List<String> filters = [
    "Daily",
    "Weekly",
    "Monthly",
    "Yearly",
  ];

  double totalRevenue = 0;
  int totalOrders = 0;
  int totalItemsSold = 0;
  double averageOrderValue = 0;

  List<Map<String, dynamic>> orders = [];
  Map<String, Map<String, dynamic>> productsById = {};

  Map<String, double> revenueTrend = {};
  Map<String, int> ordersTrend = {};
  Map<String, int> productTypeSales = {};
  Map<String, int> audienceSales = {};
  Map<String, int> topProductSales = {};

  // Theme Constants: Royal Sapphire Blue Executive Theme
  static const Color sapphireBlue = Color(0xFF2563EB);
  static const Color sapphireLight = Color(0xFFEFF6FF);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color bgColor = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    fetchAnalytics();
  }

  // ================= DATE RANGE =================
  DateTime _startDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (selectedFilter == "Daily") {
      return today;
    }

    if (selectedFilter == "Weekly") {
      return today.subtract(const Duration(days: 6));
    }

    if (selectedFilter == "Monthly") {
      return DateTime(now.year, now.month, 1);
    }

    return DateTime(now.year, 1, 1);
  }

  DateTime _endDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(
      const Duration(days: 1),
    );
  }

  // ================= FETCH ANALYTICS =================
  Future<void> fetchAnalytics() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception("Seller not logged in");
      }

      final sellerId = currentUser.id;
      final start = _startDate();
      final end = _endDate();

      // 1. Fetch Orders for Seller
      final ordersData = await supabase
          .from('orders')
          .select('*')
          .eq('seller_id', sellerId)
          .gte('created_at', start.toUtc().toIso8601String())
          .lt('created_at', end.toUtc().toIso8601String())
          .order('created_at', ascending: true);

      final fetchedOrders = List<Map<String, dynamic>>.from(ordersData);

      // 2. Fetch Seller Products
      final productsData = await supabase
          .from('products')
          .select('id, name, category, size, color, price')
          .eq('seller_id', sellerId);

      final fetchedProducts = List<Map<String, dynamic>>.from(productsData);

      final productMap = <String, Map<String, dynamic>>{};

      for (final product in fetchedProducts) {
        final id = product['id']?.toString();
        if (id != null && id.trim().isNotEmpty) {
          productMap[id] = product;
        }
      }

      // 3. Fetch Order Items
      final orderItemsByOrderId = await _fetchOrderItemsForOrders(
        fetchedOrders,
      );

      for (final order in fetchedOrders) {
        final orderId = order['id']?.toString();
        order['_fetched_order_items'] =
            orderId == null ? [] : orderItemsByOrderId[orderId] ?? [];
      }

      _calculateAnalytics(
        fetchedOrders: fetchedOrders,
        productMap: productMap,
      );

      final validOrders = fetchedOrders.where((order) {
        final status = order['status']?.toString() ?? '';
        return !_isCancelledStatus(status);
      }).toList();

      if (!mounted) return;

      setState(() {
        orders = validOrders;
        productsById = productMap;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Analytics Error: $e");

      if (!mounted) return;

      setState(() {
        isLoading = false;
        orders = [];
        productsById = {};
        totalRevenue = 0;
        totalOrders = 0;
        totalItemsSold = 0;
        averageOrderValue = 0;
        revenueTrend = {};
        ordersTrend = {};
        productTypeSales = {};
        audienceSales = {};
        topProductSales = {};
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Analytics error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================= FETCH ORDER ITEMS SAFELY =================
  Future<Map<String, List<Map<String, dynamic>>>> _fetchOrderItemsForOrders(
    List<Map<String, dynamic>> fetchedOrders,
  ) async {
    final grouped = <String, List<Map<String, dynamic>>>{};

    final orderIds = fetchedOrders
        .map((order) => order['id']?.toString())
        .where((id) => id != null && id.trim().isNotEmpty)
        .cast<String>()
        .toList();

    if (orderIds.isEmpty) return grouped;

    try {
      final data = await supabase
          .from('order_items')
          .select('''
            *,
            products(
              id,
              name,
              category,
              size,
              color,
              price
            )
          ''')
          .inFilter('order_id', orderIds);

      final items = List<Map<String, dynamic>>.from(data);

      for (final item in items) {
        final orderId = item['order_id']?.toString();
        if (orderId != null && orderId.trim().isNotEmpty) {
          grouped.putIfAbsent(orderId, () => []).add(item);
        }
      }

      return grouped;
    } catch (e1) {
      try {
        final data = await supabase
            .from('order_items')
            .select('*')
            .inFilter('order_id', orderIds);

        final items = List<Map<String, dynamic>>.from(data);

        for (final item in items) {
          final orderId = item['order_id']?.toString();
          if (orderId != null && orderId.trim().isNotEmpty) {
            grouped.putIfAbsent(orderId, () => []).add(item);
          }
        }

        return grouped;
      } catch (e2) {
        return grouped;
      }
    }
  }

  // ================= CALCULATE ANALYTICS METRICS =================
  void _calculateAnalytics({
    required List<Map<String, dynamic>> fetchedOrders,
    required Map<String, Map<String, dynamic>> productMap,
  }) {
    double revenue = 0;
    int itemsSold = 0;

    final revenueMap = <String, double>{};
    final ordersMap = <String, int>{};
    final typeMap = <String, int>{};
    final audienceMap = <String, int>{};
    final productSalesMap = <String, int>{};

    final validOrders = fetchedOrders.where((order) {
      final status = order['status']?.toString() ?? '';
      return !_isCancelledStatus(status);
    }).toList();

    for (final order in validOrders) {
      final orderAmount = _amount(order['total_amount'] ?? order['amount']);
      revenue += orderAmount;

      final createdAtRaw = order['created_at']?.toString();
      final date = DateTime.tryParse(createdAtRaw ?? '')?.toLocal();

      final label = _trendLabel(date);

      revenueMap[label] = (revenueMap[label] ?? 0.0) + orderAmount;
      ordersMap[label] = (ordersMap[label] ?? 0) + 1;

      final items = _extractOrderItems(order);

      if (items.isEmpty) {
        itemsSold += 1;

        final product = _getProductFromItem(
          item: order,
          productMap: productMap,
        );

        final productType = _inferProductType(
          order: order,
          item: order,
          product: product,
        );

        final audienceType = _inferAudience(
          order: order,
          item: order,
          product: product,
        );

        final productName = _inferProductName(
          order: order,
          item: order,
          product: product,
        );

        typeMap[productType] = (typeMap[productType] ?? 0) + 1;
        audienceMap[audienceType] = (audienceMap[audienceType] ?? 0) + 1;
        productSalesMap[productName] = (productSalesMap[productName] ?? 0) + 1;
      } else {
        for (final item in items) {
          final qty = _quantity(item['quantity'] ?? item['qty']);
          itemsSold += qty;

          final product = _getProductFromItem(
            item: item,
            productMap: productMap,
          );

          final productType = _inferProductType(
            order: order,
            item: item,
            product: product,
          );

          final audienceType = _inferAudience(
            order: order,
            item: item,
            product: product,
          );

          final productName = _inferProductName(
            order: order,
            item: item,
            product: product,
          );

          typeMap[productType] = (typeMap[productType] ?? 0) + qty;
          audienceMap[audienceType] = (audienceMap[audienceType] ?? 0) + qty;
          productSalesMap[productName] = (productSalesMap[productName] ?? 0) + qty;
        }
      }
    }

    totalRevenue = revenue;
    totalOrders = validOrders.length;
    totalItemsSold = itemsSold;
    averageOrderValue = totalOrders == 0 ? 0 : revenue / totalOrders;

    revenueTrend = _completeRevenueTrendMap(revenueMap);
    ordersTrend = _completeOrderTrendMap(ordersMap);

    productTypeSales = _sortIntMap(typeMap);
    audienceSales = _sortIntMap(audienceMap);
    topProductSales = _takeTop(_sortIntMap(productSalesMap), 6);
  }

  // ================= GET PRODUCT FROM ITEM =================
  Map<String, dynamic>? _getProductFromItem({
    required Map<String, dynamic> item,
    required Map<String, Map<String, dynamic>> productMap,
  }) {
    final nestedProduct = item['products'] ?? item['product'];

    if (nestedProduct is Map) {
      return Map<String, dynamic>.from(nestedProduct);
    }

    final productId = item['product_id']?.toString() ??
        item['productId']?.toString() ??
        item['id']?.toString();

    if (productId == null || productId.trim().isEmpty) return null;

    return productMap[productId];
  }

  // ================= EXTRACT ITEMS FROM ORDER =================
  List<Map<String, dynamic>> _extractOrderItems(Map<String, dynamic> order) {
    dynamic rawItems = order['_fetched_order_items'];

    if (rawItems is List && rawItems.isNotEmpty) {
      return rawItems
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    rawItems = order['order_items'] ?? order['items'] ?? order['products'];

    if (rawItems == null) return [];

    if (rawItems is String) {
      try {
        rawItems = jsonDecode(rawItems);
      } catch (_) {
        return [];
      }
    }

    if (rawItems is List) {
      return rawItems
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return [];
  }

  // ================= INFER PRODUCT TYPE =================
  String _inferProductType({
    required Map<String, dynamic> order,
    required Map<String, dynamic> item,
    required Map<String, dynamic>? product,
  }) {
    final text = [
      item['category'],
      item['product_category'],
      item['type'],
      item['name'],
      item['product_name'],
      product?['category'],
      product?['name'],
      order['category'],
      order['product_category'],
      order['product_name'],
      order['name'],
    ].where((v) => v != null).join(" ").toLowerCase();

    if (text.contains('t-shirt') || text.contains('tshirt') || text.contains('tee')) {
      return "T-Shirt";
    }

    if (text.contains('shirt')) return "Shirt";
    if (text.contains('hoodie')) return "Hoodie";
    if (text.contains('jeans') || text.contains('jean')) return "Jeans";
    if (text.contains('jacket')) return "Jacket";
    if (text.contains('trouser') || text.contains('pant')) return "Trouser";
    if (text.contains('kurta')) return "Kurta";
    if (text.contains('dress') || text.contains('dresses')) return "Dresses";
    if (text.contains('suit') || text.contains('suite')) return "Suits";
    if (text.contains('shoe') || text.contains('sneaker')) return "Shoes";
    if (text.contains('bag')) return "Bags";
    if (text.contains('watch')) return "Watches";
    if (text.contains('accessor')) return "Accessories";

    return "Apparel";
  }

  // ================= INFER AUDIENCE =================
  String _inferAudience({
    required Map<String, dynamic> order,
    required Map<String, dynamic> item,
    required Map<String, dynamic>? product,
  }) {
    final text = [
      item['gender'],
      item['audience'],
      item['target_audience'],
      item['category'],
      item['name'],
      item['product_name'],
      product?['category'],
      product?['name'],
      order['gender'],
      order['audience'],
      order['target_audience'],
      order['category'],
      order['product_name'],
      order['name'],
    ].where((v) => v != null).join(" ").toLowerCase();

    if (text.contains('women') || text.contains('woman') || text.contains('female') || text.contains('girl') || text.contains('ladies')) {
      return "Women";
    }

    if (text.contains('kids') || text.contains('kid') || text.contains('child') || text.contains('baby')) {
      return "Kids";
    }

    if (text.contains('men') || text.contains('man') || text.contains('male') || text.contains('boy') || text.contains('gents')) {
      return "Men";
    }

    return "Unisex";
  }

  String _inferProductName({
    required Map<String, dynamic> order,
    required Map<String, dynamic> item,
    required Map<String, dynamic>? product,
  }) {
    final name = product?['name'] ??
        item['product_name'] ??
        item['name'] ??
        order['product_name'] ??
        order['name'];

    if (name == null || name.toString().trim().isEmpty) {
      return "Apparel Item";
    }

    return name.toString();
  }

  bool _isCancelledStatus(String status) {
    final value = status.toLowerCase().trim();
    return value == 'cancelled' || value == 'canceled' || value == 'refunded' || value == 'returned';
  }

  double _amount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  int _quantity(dynamic value) {
    if (value is num) {
      final qty = value.toInt();
      return qty <= 0 ? 1 : qty;
    }
    final qty = int.tryParse(value?.toString() ?? '') ?? 1;
    return qty <= 0 ? 1 : qty;
  }

  Map<String, int> _sortIntMap(Map<String, int> map) {
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries);
  }

  Map<String, int> _takeTop(Map<String, int> map, int limit) {
    final entries = map.entries.take(limit).toList();
    return Map.fromEntries(entries);
  }

  // ================= TREND LABELS =================
  String _trendLabel(DateTime? date) {
    final d = date?.toLocal() ?? DateTime.now();

    if (selectedFilter == "Daily") {
      final hour = d.hour.toString().padLeft(2, '0');
      return "$hour:00";
    }

    if (selectedFilter == "Weekly") {
      return "${_monthName(d.month)} ${d.day}";
    }

    if (selectedFilter == "Monthly") {
      return d.day.toString().padLeft(2, '0');
    }

    return _monthName(d.month);
  }

  List<String> _trendLabels() {
    final labels = <String>[];

    if (selectedFilter == "Daily") {
      for (int i = 0; i < 24; i += 3) {
        labels.add("${i.toString().padLeft(2, '0')}:00");
      }
      return labels;
    }

    if (selectedFilter == "Weekly") {
      final start = _startDate();
      for (int i = 0; i < 7; i++) {
        final d = start.add(Duration(days: i));
        labels.add("${_monthName(d.month)} ${d.day}");
      }
      return labels;
    }

    if (selectedFilter == "Monthly") {
      final now = DateTime.now();
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      for (int i = 1; i <= daysInMonth; i += 3) {
        labels.add(i.toString().padLeft(2, '0'));
      }
      return labels;
    }

    return const ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  }

  double _bottomInterval(int length) {
    if (length <= 8) return 1.0;
    if (length <= 16) return 2.0;
    if (length <= 31) return 5.0;
    return 1.0;
  }

  Map<String, double> _completeRevenueTrendMap(Map<String, double> map) {
    final completed = <String, double>{};
    for (final label in _trendLabels()) {
      completed[label] = map[label] ?? 0.0;
    }
    return completed;
  }

  Map<String, int> _completeOrderTrendMap(Map<String, int> map) {
    final completed = <String, int>{};
    for (final label in _trendLabels()) {
      completed[label] = map[label] ?? 0;
    }
    return completed;
  }

  String _monthName(int month) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return months[month - 1];
  }

  List<Color> _chartColors() {
    return const [
      Color(0xFF2563EB),
      Color(0xFF10B981),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFFF59E0B),
      Color(0xFF06B6D4),
    ];
  }

  // ================= BUILD UI =================
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    int kpiGrid = width >= 1100 ? 4 : 2;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: slateDark),
        title: const Text(
          "Sales Analytics",
          style: TextStyle(
            color: slateDark,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh Data",
            icon: const Icon(Icons.refresh_rounded, color: sapphireBlue),
            onPressed: fetchAnalytics,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: sapphireBlue))
          : RefreshIndicator(
              onRefresh: fetchAnalytics,
              color: sapphireBlue,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. HERO REVENUE SUMMARY BANNER
                        _executiveHeroBanner().animate().fadeIn(duration: 350.ms).slideY(begin: 0.05),

                        const SizedBox(height: 18),

                        // 2. SEGMENTED FILTER BAR (Daily, Weekly, Monthly, Yearly)
                        _segmentedFilterBar(),

                        const SizedBox(height: 18),

                        // 3. KPI METRICS GRID
                        GridView.count(
                          crossAxisCount: kpiGrid,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: width >= 1100 ? 2.8 : (width >= 700 ? 2.4 : 1.85),
                          children: [
                            _kpiCard(
                              title: "Total Revenue",
                              value: "Rs. ${totalRevenue.toStringAsFixed(0)}",
                            ),
                            _kpiCard(
                              title: "Total Orders",
                              value: totalOrders.toString(),
                            ),
                            _kpiCard(
                              title: "Items Sold",
                              value: totalItemsSold.toString(),
                            ),
                            _kpiCard(
                              title: "Avg Order Value",
                              value: "Rs. ${averageOrderValue.toStringAsFixed(0)}",
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        if (orders.isEmpty)
                          _emptyAnalyticsView()
                        else ...[
                          // 4. REVENUE TREND LINE CHART
                          _chartCard(
                            title: "Revenue Trend",
                            subtitle: "Real-time earnings curve for $selectedFilter period",
                            child: _revenueLineChart(),
                          ),

                          const SizedBox(height: 18),

                          // 5. ORDERS TREND BAR CHART
                          _chartCard(
                            title: "Orders Volume Trend",
                            subtitle: "Completed order volume breakdown",
                            child: _ordersBarChart(),
                          ),

                          const SizedBox(height: 18),

                          // 6. DISTRIBUTION DONUT CHARTS (TYPES & AUDIENCE)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 850;

                              if (isWide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _chartCard(
                                        title: "Product Category Mix",
                                        subtitle: "Sales breakdown by apparel type",
                                        child: _donutChart(productTypeSales, "Type Mix"),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _chartCard(
                                        title: "Audience Demographics",
                                        subtitle: "Men, Women, Kids & Unisex mix",
                                        child: _donutChart(audienceSales, "Audience"),
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  _chartCard(
                                    title: "Product Category Mix",
                                    subtitle: "Sales breakdown by apparel type",
                                    child: _donutChart(productTypeSales, "Type Mix"),
                                  ),
                                  const SizedBox(height: 18),
                                  _chartCard(
                                    title: "Audience Demographics",
                                    subtitle: "Men, Women, Kids & Unisex mix",
                                    child: _donutChart(audienceSales, "Audience"),
                                  ),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 18),

                          // 7. TOP SELLING PRODUCTS LEADERBOARD
                          _topProductsLeaderboard(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: const SellerBottomNav(currentIndex: 3),
    );
  }

  // ================= EXECUTIVE HERO BANNER =================
  // ================= EXECUTIVE HERO BANNER =================
  Widget _executiveHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: sapphireBlue.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    "ANALYTICS OVERVIEW",
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Sales & Performance",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.4),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF34D399), width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 3, backgroundColor: Color(0xFF34D399)),
                SizedBox(width: 5),
                Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= SEGMENTED FILTER BAR =================
  Widget _segmentedFilterBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: filters.map((filter) {
          final isSelected = selectedFilter == filter;

          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() => selectedFilter = filter);
                fetchAnalytics();
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? sapphireBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : slateMuted,
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ================= SLEEK ICON-FREE COMPACT KPI CARD =================
  Widget _kpiCard({
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: slateMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.4),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: slateDark, fontSize: 16.5, fontWeight: FontWeight.w900, letterSpacing: -0.4),
          ),
        ],
      ),
    );
  }

  // ================= CHART CARD CONTAINER =================
  Widget _chartCard({
    required String title,
    required String subtitle,
    required Widget child,
    double height = 210,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(color: slateDark, fontSize: 15.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: slateMuted, fontSize: 11.5, fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),
          SizedBox(
            height: height,
            child: child,
          ),
        ],
      ),
    );
  }

  // ================= REVENUE SPLINE LINE CHART =================
  Widget _revenueLineChart() {
    final entries = revenueTrend.entries.toList();
    if (entries.isEmpty) return _emptyAnalyticsView();

    final double maxY = entries.map((e) => e.value).fold<double>(0.0, math.max);
    final double safeMaxY = maxY <= 0 ? 1000.0 : maxY * 1.2;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: safeMaxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                final label = (idx >= 0 && idx < entries.length) ? entries[idx].key : '';
                return LineTooltipItem(
                  "$label\nRs. ${spot.y.toStringAsFixed(0)}",
                  const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900),
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: math.max(100.0, safeMaxY / 4),
          getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF1F5F9), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                String txt = value >= 1000 ? "${(value / 1000).toStringAsFixed(0)}k" : value.toStringAsFixed(0);
                return Text(txt, style: const TextStyle(color: slateMuted, fontSize: 10, fontWeight: FontWeight.w700));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: _bottomInterval(entries.length),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(entries[index].key, style: const TextStyle(color: slateMuted, fontSize: 10, fontWeight: FontWeight.w700)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(entries.length, (index) => FlSpot(index.toDouble(), entries[index].value)),
            isCurved: true,
            barWidth: 3.5,
            color: sapphireBlue,
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  sapphireBlue.withValues(alpha: 0.25),
                  sapphireBlue.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            dotData: FlDotData(show: entries.length <= 12),
          ),
        ],
      ),
    );
  }

  // ================= ORDERS VOLUME BAR CHART =================
  Widget _ordersBarChart() {
    final entries = ordersTrend.entries.toList();
    if (entries.isEmpty) return _emptyAnalyticsView();

    final double maxY = entries.map((e) => e.value).fold<int>(0, math.max).toDouble();
    final double safeMaxY = maxY <= 0 ? 5.0 : maxY + 2.0;

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: safeMaxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = (groupIndex >= 0 && groupIndex < entries.length) ? entries[groupIndex].key : '';
              return BarTooltipItem(
                "$label\n${rod.toY.toInt()} Orders",
                const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900),
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: math.max(1.0, safeMaxY / 4),
          getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF1F5F9), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                return Text(value.toInt().toString(), style: const TextStyle(color: slateMuted, fontSize: 10, fontWeight: FontWeight.w700));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: _bottomInterval(entries.length),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(entries[index].key, style: const TextStyle(color: slateMuted, fontSize: 10, fontWeight: FontWeight.w700)),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(entries.length, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: entries[index].value.toDouble(),
                width: 14,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ================= DONUT DISTRIBUTION CHART WITH LEFT/SIDE LEGEND (NO PERCENTAGES IN LEGEND) =================
  Widget _donutChart(Map<String, int> dataMap, String centerLabel) {
    if (dataMap.isEmpty) return _emptyAnalyticsView();

    final entries = dataMap.entries.toList();
    final totalUnits = entries.fold<int>(0, (sum, item) => sum + item.value);
    final colors = _chartColors();

    return Row(
      children: [
        // 1. Left / Side Legend List (Color Dot + Name ONLY - NO PERCENTAGE)
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(entries.length, (index) {
              final item = entries[index];
              final color = colors[index % colors.length];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: slateDark, fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),

        const SizedBox(width: 8),

        // 2. Donut Pie Chart (PERCENTAGES STAY IN THE SLICES HERE)
        Expanded(
          flex: 5,
          child: SizedBox(
            height: 175,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 36,
                    sections: List.generate(entries.length, (index) {
                      final item = entries[index];
                      final color = colors[index % colors.length];
                      final pct = totalUnits > 0 ? (item.value / totalUnits * 100).round() : 0;

                      return PieChartSectionData(
                        color: color,
                        value: item.value.toDouble(),
                        title: "$pct%",
                        radius: 32,
                        titleStyle: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                      );
                    }),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("$totalUnits", style: const TextStyle(color: slateDark, fontSize: 16, fontWeight: FontWeight.w900)),
                    Text(centerLabel, style: const TextStyle(color: slateMuted, fontSize: 9, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ================= TOP SELLING PRODUCTS LEADERBOARD =================
  Widget _topProductsLeaderboard() {
    final entries = topProductSales.entries.toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Top Selling Products", style: TextStyle(color: slateDark, fontSize: 16, fontWeight: FontWeight.w900)),
              Text("Units Sold", style: TextStyle(color: slateMuted, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),

          if (entries.isEmpty)
            _emptyAnalyticsView()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = entries[index];
                final rank = index + 1;
                final qty = item.value;
                final maxQty = entries.first.value > 0 ? entries.first.value : 1;
                final progress = qty / maxQty;

                return Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: rank == 1 ? const Color(0xFFFEF3C7) : sapphireLight,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          "#$rank",
                          style: TextStyle(
                            color: rank == 1 ? const Color(0xFFD97706) : sapphireBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 5,
                              backgroundColor: const Color(0xFFF1F5F9),
                              color: rank == 1 ? const Color(0xFFF59E0B) : sapphireBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      "$qty units",
                      style: const TextStyle(color: slateDark, fontSize: 12.5, fontWeight: FontWeight.w900),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _emptyAnalyticsView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.bar_chart_rounded, size: 42, color: slateMuted),
          SizedBox(height: 10),
          Text("No Analytics Data for this Period", style: TextStyle(color: slateDark, fontSize: 14, fontWeight: FontWeight.w900)),
          SizedBox(height: 4),
          Text("Select another filter period or wait for new orders to generate insights.", style: TextStyle(color: slateMuted, fontSize: 11.5), textAlign: TextAlign.center),
        ],
      ),
    );
  }

}