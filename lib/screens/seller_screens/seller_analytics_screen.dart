import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  static const Color appGreen = Color(0xFFA8E063);
  static const Color darkText = Color(0xFF111827);
  static const Color mutedText = Color(0xFF6B7280);
  static const Color borderColor = Color(0xFFE5E7EB);
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

      // ================= FETCH SELLER ORDERS =================
      final ordersData = await supabase
          .from('orders')
          .select('*')
          .eq('seller_id', sellerId)
          .gte('created_at', start.toUtc().toIso8601String())
          .lt('created_at', end.toUtc().toIso8601String())
          .order('created_at', ascending: true);

      final fetchedOrders = List<Map<String, dynamic>>.from(ordersData);

      // ================= FETCH SELLER PRODUCTS =================
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

      // ================= FETCH ORDER ITEMS =================
      final orderItemsByOrderId = await _fetchOrderItemsForOrders(
        fetchedOrders,
      );

      // Attach fetched items inside orders locally
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
      // First try: order_items + products relation
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

        if (orderId == null || orderId.trim().isEmpty) continue;

        grouped.putIfAbsent(orderId, () => []);
        grouped[orderId]!.add(item);
      }

      return grouped;
    } catch (e) {
      debugPrint("Order items relation fetch failed: $e");
    }

    try {
      // Second try: simple order_items table without relation
      final data = await supabase
          .from('order_items')
          .select('*')
          .inFilter('order_id', orderIds);

      final items = List<Map<String, dynamic>>.from(data);

      for (final item in items) {
        final orderId = item['order_id']?.toString();

        if (orderId == null || orderId.trim().isEmpty) continue;

        grouped.putIfAbsent(orderId, () => []);
        grouped[orderId]!.add(item);
      }

      return grouped;
    } catch (e) {
      debugPrint("Simple order_items fetch failed: $e");
    }

    return grouped;
  }

  // ================= CALCULATE ANALYTICS =================
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
      final amount = _amount(order['total_amount']);
      revenue += amount;

      final date = DateTime.tryParse(order['created_at']?.toString() ?? '');
      final label = _trendLabel(date);

      revenueMap[label] = (revenueMap[label] ?? 0) + amount;
      ordersMap[label] = (ordersMap[label] ?? 0) + 1;

      final extractedItems = _extractOrderItems(order);

      if (extractedItems.isEmpty) {
        final qty = _quantity(order['quantity']);
        itemsSold += qty;

        final productId = order['product_id']?.toString();
        final product = productId == null ? null : productMap[productId];

        final productType = _inferProductType(
          order: order,
          item: const {},
          product: product,
        );

        final audienceType = _inferAudience(
          order: order,
          item: const {},
          product: product,
        );

        final productName = _inferProductName(
          order: order,
          item: const {},
          product: product,
        );

        typeMap[productType] = (typeMap[productType] ?? 0) + qty;
        audienceMap[audienceType] = (audienceMap[audienceType] ?? 0) + qty;
        productSalesMap[productName] = (productSalesMap[productName] ?? 0) + qty;
      } else {
        for (final item in extractedItems) {
          final qty = _quantity(
            item['quantity'] ??
                item['qty'] ??
                item['product_quantity'] ??
                item['count'],
          );

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
          productSalesMap[productName] =
              (productSalesMap[productName] ?? 0) + qty;
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

    if (text.contains('t-shirt') ||
        text.contains('tshirt') ||
        text.contains('t shirt') ||
        text.contains('tee')) {
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

    return "Other";
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

    if (text.contains('women') ||
        text.contains('woman') ||
        text.contains('female') ||
        text.contains('girl') ||
        text.contains('girls') ||
        text.contains('ladies') ||
        text.contains('lady')) {
      return "Women";
    }

    if (text.contains('kids') ||
        text.contains('kid') ||
        text.contains('child') ||
        text.contains('children') ||
        text.contains('baby')) {
      return "Kids";
    }

    if (text.contains('unisex')) {
      return "Unisex";
    }

    if (text.contains('men') ||
        text.contains('man') ||
        text.contains('male') ||
        text.contains('boy') ||
        text.contains('boys') ||
        text.contains('gents')) {
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
      return "Unknown Product";
    }

    return name.toString();
  }

  // ================= BASIC HELPERS =================
  bool _isCancelledStatus(String status) {
    final value = status.toLowerCase().trim();

    return value == 'cancelled' ||
        value == 'canceled' ||
        value == 'refunded' ||
        value == 'returned';
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
      for (int i = 0; i < 24; i++) {
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

      for (int i = 1; i <= daysInMonth; i++) {
        labels.add(i.toString().padLeft(2, '0'));
      }

      return labels;
    }

    return const [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
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
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];

    return months[month - 1];
  }

  List<Color> _chartColors() {
    return const [
      Color(0xFF2563EB),
      Color(0xFF16A34A),
      Color(0xFF7C3AED),
      Color(0xFFDB2777),
      Color(0xFFF59E0B),
      Color(0xFF0891B2),
      Color(0xFFEF4444),
      Color(0xFF64748B),
      Color(0xFF0F766E),
      Color(0xFF9333EA),
    ];
  }

  double _bottomInterval(int length) {
    if (length <= 8) return 1.0;
    if (length <= 16) return 2.0;
    if (length <= 31) return 5.0;
    return 1.0;
  }

  // ================= BUILD UI =================
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    int kpiGrid = 2;

    if (width >= 1100) {
      kpiGrid = 4;
    }

    return Scaffold(
      backgroundColor: bgColor,

      appBar: AppBar(
        backgroundColor: appGreen,
        surfaceTintColor: appGreen,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: kToolbarHeight,
        iconTheme: const IconThemeData(
          color: darkText,
        ),
        title: const Text(
          "Analytics Dashboard",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: darkText,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(
              Icons.refresh_rounded,
              color: darkText,
            ),
            onPressed: fetchAnalytics,
          ),
          const SizedBox(width: 6),
        ],
      ),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF22C55E),
              ),
            )
          : RefreshIndicator(
              onRefresh: fetchAnalytics,
              color: const Color(0xFF22C55E),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1300),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _headerCard()
                            .animate()
                            .fadeIn(duration: 350.ms)
                            .slideY(begin: 0.08),

                        const SizedBox(height: 18),

                        _filterBar(),

                        const SizedBox(height: 18),

                        GridView.count(
                          crossAxisCount: kpiGrid,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: width >= 1100
                              ? 2.1
                              : width >= 700
                                  ? 1.85
                                  : 1.35,
                          children: [
                            _kpiCard(
                              title: "Total Revenue",
                              value: "PKR ${totalRevenue.toStringAsFixed(0)}",
                              icon: Icons.payments_rounded,
                              accentColor: const Color(0xFF16A34A),
                              bgTint: const Color(0xFFF0FDF4),
                            ),
                            _kpiCard(
                              title: "Orders",
                              value: totalOrders.toString(),
                              icon: Icons.shopping_bag_outlined,
                              accentColor: const Color(0xFF2563EB),
                              bgTint: const Color(0xFFEFF6FF),
                            ),
                            _kpiCard(
                              title: "Items Sold",
                              value: totalItemsSold.toString(),
                              icon: Icons.inventory_2_outlined,
                              accentColor: const Color(0xFF7C3AED),
                              bgTint: const Color(0xFFF5F3FF),
                            ),
                            _kpiCard(
                              title: "Avg Order Value",
                              value: "PKR ${averageOrderValue.toStringAsFixed(0)}",
                              icon: Icons.analytics_outlined,
                              accentColor: const Color(0xFFDB2777),
                              bgTint: const Color(0xFFFDF2F8),
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        if (orders.isEmpty)
                          _emptyAnalyticsView()
                        else ...[
                          _chartCard(
                            title: "Revenue Trend",
                            subtitle: "Revenue performance for $selectedFilter",
                            child: _revenueLineChart(),
                          ),

                          const SizedBox(height: 18),

                          _chartCard(
                            title: "Orders Trend",
                            subtitle: "Number of orders for $selectedFilter",
                            child: _ordersBarChart(),
                          ),

                          const SizedBox(height: 18),

                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 900;

                              if (isWide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _chartCard(
                                        title: "Sales by Product Type",
                                        subtitle:
                                            "Shirts, suits, dresses, trousers and more",
                                        child: _pieChart(productTypeSales),
                                      ),
                                    ),
                                    const SizedBox(width: 18),
                                    Expanded(
                                      child: _chartCard(
                                        title: "Sales by Audience",
                                        subtitle:
                                            "Men, women, kids and unisex breakdown",
                                        child: _pieChart(audienceSales),
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  _chartCard(
                                    title: "Sales by Product Type",
                                    subtitle:
                                        "Shirts, suits, dresses, trousers and more",
                                    child: _pieChart(productTypeSales),
                                  ),
                                  const SizedBox(height: 18),
                                  _chartCard(
                                    title: "Sales by Audience",
                                    subtitle:
                                        "Men, women, kids and unisex breakdown",
                                    child: _pieChart(audienceSales),
                                  ),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 18),

                          _topProductsCard(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // ================= HEADER CARD =================
  Widget _headerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkText,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -35,
            top: -42,
            child: _GlowCircle(
              size: 130,
              opacity: 0.08,
            ),
          ),
          Positioned(
            left: -42,
            bottom: -48,
            child: _GlowCircle(
              size: 145,
              opacity: 0.06,
            ),
          ),
          Row(
            children: [
              Container(
                height: 62,
                width: 62,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: appGreen,
                  size: 34,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Seller Performance",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Analyze revenue, orders, product demand, and audience mix.",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.74),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= FILTER BAR =================
  Widget _filterBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: filters.map((filter) {
          final isSelected = selectedFilter == filter;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedFilter = filter;
                });

                fetchAnalytics();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? darkText : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.white : mutedText,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.06);
  }

  // ================= KPI CARD =================
  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required Color bgTint,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -22,
            child: Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: bgTint.withValues(alpha: 0.90),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: bgTint,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.12),
                  ),
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: darkText,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: mutedText,
                        fontSize: 12.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.08);
  }

  // ================= CHART CARD =================
  Widget _chartCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: darkText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: mutedText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 280,
            child: child,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06);
  }

  // ================= REVENUE LINE CHART =================
  Widget _revenueLineChart() {
    final entries = revenueTrend.entries.toList();

    if (entries.isEmpty) return _noChartData();

    final double maxY = entries
        .map((e) => e.value)
        .fold<double>(0.0, (previous, current) {
      return math.max(previous, current);
    });

    final double safeMaxY = maxY <= 0 ? 100.0 : maxY * 1.25;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: safeMaxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: safeMaxY / 4,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: Color(0xFFE5E7EB),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, meta) {
                return Text(
                  "${value.toInt()}",
                  style: const TextStyle(
                    color: mutedText,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: _bottomInterval(entries.length),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();

                if (index < 0 || index >= entries.length) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    entries[index].key,
                    style: const TextStyle(
                      color: mutedText,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(entries.length, (index) {
              return FlSpot(index.toDouble(), entries[index].value);
            }),
            isCurved: true,
            barWidth: 3.2,
            color: const Color(0xFF16A34A),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF16A34A).withValues(alpha: 0.10),
            ),
            dotData: FlDotData(
              show: entries.length <= 12,
            ),
          ),
        ],
      ),
    );
  }

  // ================= ORDERS BAR CHART =================
  Widget _ordersBarChart() {
    final entries = ordersTrend.entries.toList();

    if (entries.isEmpty) return _noChartData();

    final double maxY = entries
        .map((e) => e.value)
        .fold<int>(0, (previous, current) {
      return math.max(previous, current);
    }).toDouble();

    final double safeMaxY = maxY <= 0 ? 5.0 : maxY + 2.0;

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: safeMaxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: math.max(1.0, safeMaxY / 4),
          getDrawingHorizontalLine: (_) => const FlLine(
            color: Color(0xFFE5E7EB),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: mutedText,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: _bottomInterval(entries.length),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();

                if (index < 0 || index >= entries.length) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    entries[index].key,
                    style: const TextStyle(
                      color: mutedText,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
                width: 13,
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF2563EB),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ================= PIE CHART =================
  Widget _pieChart(Map<String, int> dataMap) {
    if (dataMap.isEmpty) return _noChartData();

    final entries = dataMap.entries.where((e) => e.value > 0).toList();

    if (entries.isEmpty) return _noChartData();

    final total = entries.fold<int>(0, (sum, e) => sum + e.value);
    final colors = _chartColors();

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 42,
              sections: List.generate(entries.length, (index) {
                final item = entries[index];
                final percent = total == 0 ? 0 : (item.value / total) * 100;

                return PieChartSectionData(
                  value: item.value.toDouble(),
                  title: "${percent.toStringAsFixed(0)}%",
                  radius: 72,
                  color: colors[index % colors.length],
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            child: Column(
              children: List.generate(entries.length, (index) {
                final item = entries[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        height: 11,
                        width: 11,
                        decoration: BoxDecoration(
                          color: colors[index % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: darkText,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        item.value.toString(),
                        style: const TextStyle(
                          color: mutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  // ================= TOP PRODUCTS CARD =================
  Widget _topProductsCard() {
    final entries = topProductSales.entries.toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Top Selling Products",
            style: TextStyle(
              color: darkText,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            "Best performing products in selected time period",
            style: TextStyle(
              color: mutedText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            _noChartData()
          else
            Column(
              children: List.generate(entries.length, (index) {
                final item = entries[index];
                final maxValue = entries.first.value == 0 ? 1 : entries.first.value;
                final progress = item.value / maxValue;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: borderColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 38,
                        width: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          "#${index + 1}",
                          style: const TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
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
                              style: const TextStyle(
                                color: darkText,
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(100),
                              child: LinearProgressIndicator(
                                value: progress.toDouble(),
                                minHeight: 7,
                                backgroundColor: borderColor,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        item.value.toString(),
                        style: const TextStyle(
                          color: darkText,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06);
  }

  Widget _noChartData() {
    return Center(
      child: Text(
        "No chart data available",
        style: TextStyle(
          color: Colors.grey.shade500,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _emptyAnalyticsView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 46,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        children: [
          Container(
            height: 92,
            width: 92,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFBBF7D0),
              ),
            ),
            child: const Icon(
              Icons.insights_outlined,
              size: 50,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            "No Analytics Found",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: darkText,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "No orders found for the selected time filter.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: mutedText,
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// ================= GLOW CIRCLE =================
class _GlowCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _GlowCircle({
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}