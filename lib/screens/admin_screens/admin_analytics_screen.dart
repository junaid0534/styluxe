import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  final bool isStandalone;
  const AdminAnalyticsScreen({super.key, this.isStandalone = false});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  String selectedTimeframe = "Monthly"; // "Weekly", "Monthly", "Yearly"
  String selectedPieView = "Order Status"; // "Order Status", "Store Category"

  // Real-time Subscriptions
  StreamSubscription? _ordersSub;
  StreamSubscription? _storesSub;

  // Real Metrics Data
  double totalRevenue = 0.0;
  int totalOrders = 0;
  double avgOrderValue = 0.0;
  int activeStoresCount = 0;
  int totalStoresCount = 0;

  // Orders Raw Data
  List<Map<String, dynamic>> rawOrders = [];
  List<Map<String, dynamic>> rawStores = [];

  // Line Chart Data Points
  List<FlSpot> lineSpots = [];
  List<String> lineLabels = [];
  double lineMaxY = 100.0;

  // Bar Chart Data Points (Order Count per interval)
  List<BarChartGroupData> barGroups = [];
  List<String> barLabels = [];
  double barMaxY = 10.0;

  // Pie Chart Data (Order Status / Categories)
  Map<String, int> statusCounts = {};
  Map<String, double> statusRevenue = {};
  Map<String, int> categoryCounts = {};

  int? touchedPieIndex;
  int? touchedBarGroupIndex;

  static const Color primaryTeal = Color(0xFF10B981);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color bgLight = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    _storesSub?.cancel();
    super.dispose();
  }

  // ================= REAL-TIME STREAMS =================
  void _subscribeRealtime() {
    try {
      _ordersSub = supabase
          .from('orders')
          .stream(primaryKey: ['id'])
          .listen((data) {
            if (mounted) {
              rawOrders = List<Map<String, dynamic>>.from(data);
              _processAnalyticsData();
            }
          }, onError: (err) {
            debugPrint("Admin Analytics orders stream error: $err");
          });
    } catch (_) {}

    try {
      _storesSub = supabase
          .from('seller_stores')
          .stream(primaryKey: ['id'])
          .listen((data) {
            if (mounted) {
              rawStores = List<Map<String, dynamic>>.from(data);
              _processStoresData();
            }
          }, onError: (err) {
            debugPrint("Admin Analytics stores stream error: $err");
          });
    } catch (_) {}
  }

  Future<void> _fetchInitialData() async {
    setState(() => isLoading = true);
    try {
      final ordersRes = await supabase.from('orders').select('*').order('created_at', ascending: true);
      final storesRes = await supabase.from('seller_stores').select('*');

      rawOrders = List<Map<String, dynamic>>.from(ordersRes);
      rawStores = List<Map<String, dynamic>>.from(storesRes);

      _processStoresData();
      _processAnalyticsData();
    } catch (e) {
      debugPrint("Admin Analytics initial fetch error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _processStoresData() {
    int active = 0;
    final Map<String, int> catCounts = {};

    for (final s in rawStores) {
      if (s['is_active'] == true) active++;
      final cat = s['store_category']?.toString().trim();
      final validCat = (cat != null && cat.isNotEmpty) ? cat : 'General';
      catCounts[validCat] = (catCounts[validCat] ?? 0) + 1;
    }

    if (mounted) {
      setState(() {
        totalStoresCount = rawStores.length;
        activeStoresCount = active;
        categoryCounts = catCounts;
      });
    }
  }

  void _processAnalyticsData() {
    double totalSum = 0.0;
    int ordersCount = 0;
    final Map<String, int> stCounts = {
      'completed': 0,
      'pending': 0,
      'processing': 0,
      'shipped': 0,
      'cancelled': 0,
    };
    final Map<String, double> stRevenue = {
      'completed': 0.0,
      'pending': 0.0,
      'processing': 0.0,
      'shipped': 0.0,
      'cancelled': 0.0,
    };

    final now = DateTime.now();

    // 1. Process Totals & Pie Data
    for (final o in rawOrders) {
      final amount = (o['total_amount'] as num?)?.toDouble() ?? 0.0;
      final st = (o['status']?.toString() ?? 'pending').toLowerCase().trim();

      ordersCount++;
      if (st != 'cancelled') {
        totalSum += amount;
      }

      if (stCounts.containsKey(st)) {
        stCounts[st] = stCounts[st]! + 1;
        stRevenue[st] = stRevenue[st]! + amount;
      } else {
        stCounts[st] = 1;
        stRevenue[st] = amount;
      }
    }

    // 2. Build Timeframe Trend Data for Line Chart & Bar Chart
    List<FlSpot> spots = [];
    List<String> labels = [];
    List<double> barValues = [];
    double highestRev = 0.0;
    double highestBar = 0.0;

    if (selectedTimeframe == "Weekly") {
      // Last 7 Days (Mon to Sun)
      labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final revMap = List<double>.filled(7, 0.0);
      final countMap = List<double>.filled(7, 0.0);

      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final zeroHourStart = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

      for (final o in rawOrders) {
        final amount = (o['total_amount'] as num?)?.toDouble() ?? 0.0;
        final st = (o['status']?.toString() ?? 'pending').toLowerCase();
        final dtStr = o['created_at']?.toString();
        if (dtStr == null) continue;

        try {
          final dt = DateTime.parse(dtStr).toLocal();
          if (dt.isAfter(zeroHourStart) && dt.isBefore(zeroHourStart.add(const Duration(days: 7)))) {
            final dayIndex = (dt.weekday - 1).clamp(0, 6);
            if (st != 'cancelled') {
              revMap[dayIndex] += amount;
            }
            countMap[dayIndex] += 1;
          }
        } catch (_) {}
      }

      for (int i = 0; i < 7; i++) {
        spots.add(FlSpot(i.toDouble(), revMap[i]));
        barValues.add(countMap[i]);
        if (revMap[i] > highestRev) highestRev = revMap[i];
        if (countMap[i] > highestBar) highestBar = countMap[i];
      }
    } else if (selectedTimeframe == "Yearly") {
      // Last 5 Years
      final currentYear = now.year;
      final yearList = [currentYear - 4, currentYear - 3, currentYear - 2, currentYear - 1, currentYear];
      labels = yearList.map((y) => "$y").toList();
      final revMap = List<double>.filled(5, 0.0);
      final countMap = List<double>.filled(5, 0.0);

      for (final o in rawOrders) {
        final amount = (o['total_amount'] as num?)?.toDouble() ?? 0.0;
        final st = (o['status']?.toString() ?? 'pending').toLowerCase();
        final dtStr = o['created_at']?.toString();
        if (dtStr == null) continue;

        try {
          final dt = DateTime.parse(dtStr).toLocal();
          final idx = yearList.indexOf(dt.year);
          if (idx != -1) {
            if (st != 'cancelled') {
              revMap[idx] += amount;
            }
            countMap[idx] += 1;
          }
        } catch (_) {}
      }

      for (int i = 0; i < 5; i++) {
        spots.add(FlSpot(i.toDouble(), revMap[i]));
        barValues.add(countMap[i]);
        if (revMap[i] > highestRev) highestRev = revMap[i];
        if (countMap[i] > highestBar) highestBar = countMap[i];
      }
    } else {
      // "Monthly" - 12 Months
      labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final revMap = List<double>.filled(12, 0.0);
      final countMap = List<double>.filled(12, 0.0);
      final currentYear = now.year;

      for (final o in rawOrders) {
        final amount = (o['total_amount'] as num?)?.toDouble() ?? 0.0;
        final st = (o['status']?.toString() ?? 'pending').toLowerCase();
        final dtStr = o['created_at']?.toString();
        if (dtStr == null) continue;

        try {
          final dt = DateTime.parse(dtStr).toLocal();
          if (dt.year == currentYear) {
            final monthIndex = (dt.month - 1).clamp(0, 11);
            if (st != 'cancelled') {
              revMap[monthIndex] += amount;
            }
            countMap[monthIndex] += 1;
          }
        } catch (_) {}
      }

      for (int i = 0; i < 12; i++) {
        spots.add(FlSpot(i.toDouble(), revMap[i]));
        barValues.add(countMap[i]);
        if (revMap[i] > highestRev) highestRev = revMap[i];
        if (countMap[i] > highestBar) highestBar = countMap[i];
      }
    }

    // Build Bar Chart Groups
    final List<BarChartGroupData> bGroups = [];
    for (int i = 0; i < barValues.length; i++) {
      bGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: barValues[i],
              color: touchedBarGroupIndex == i ? primaryTeal : primaryTeal.withValues(alpha: 0.75),
              width: selectedTimeframe == "Monthly" ? 14 : 22,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: highestBar > 0 ? highestBar * 1.2 : 10,
                color: const Color(0xFFF1F5F9),
              ),
            ),
          ],
        ),
      );
    }

    if (mounted) {
      setState(() {
        totalRevenue = totalSum;
        totalOrders = ordersCount;
        avgOrderValue = ordersCount > 0 ? (totalSum / ordersCount) : 0.0;
        statusCounts = stCounts;
        statusRevenue = stRevenue;
        lineSpots = spots;
        lineLabels = labels;
        lineMaxY = highestRev > 0 ? (highestRev * 1.25) : 1000.0;
        barGroups = bGroups;
        barLabels = labels;
        barMaxY = highestBar > 0 ? (highestBar * 1.3) : 10.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent = RefreshIndicator(
      onRefresh: _fetchInitialData,
      color: primaryTeal,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Timeframe Filter Dropdown Row
                _buildHeaderFilterRow(),

                const SizedBox(height: 12),

                // 2. 4-KPI Metric Stats Cards Grid
                _buildKpiSummaryGrid(),

                const SizedBox(height: 12),

                // 3. Dynamic Line Chart: Revenue Trends
                _buildLineChartSection(),

                const SizedBox(height: 12),

                // 4. Dynamic Bar Chart: Order Volume Trends
                _buildBarChartSection(),

                const SizedBox(height: 12),

                // 5. Dynamic Pie / Donut Chart: Distribution Breakdown
                _buildPieChartSection(),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.isStandalone) {
      return Scaffold(
        backgroundColor: bgLight,
        appBar: AppBar(
          toolbarHeight: 46.0,
          title: Text(
            "StyLuxe",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: slateDark, fontSize: 16),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slateDark, size: 16),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(child: bodyContent),
      );
    }

    return bodyContent;
  }

  // ================= 1. HEADER FILTER ROW =================
  Widget _buildHeaderFilterRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Platform Analytics",
                style: GoogleFonts.poppins(
                  color: slateDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                "Realtime Sales & Insights",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: slateMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedTimeframe,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: primaryTeal, size: 16),
              style: GoogleFonts.poppins(color: slateDark, fontSize: 11, fontWeight: FontWeight.w700),
              borderRadius: BorderRadius.circular(10),
              dropdownColor: Colors.white,
              items: ["Weekly", "Monthly", "Yearly"].map((tf) {
                return DropdownMenuItem(value: tf, child: Text(tf));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => selectedTimeframe = val);
                  _processAnalyticsData();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  // ================= 2. KPI SUMMARY METRIC CARDS =================
  Widget _buildKpiSummaryGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 650;
        final formattedRev = "Rs. ${totalRevenue.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}";
        final formattedAov = "Rs. ${avgOrderValue.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}";

        final kpis = [
          _kpiItem(
            title: "Total Platform GMV",
            value: formattedRev,
            icon: Icons.account_balance_wallet_rounded,
            color: primaryTeal,
            bgColor: const Color(0xFFE6F4EA),
          ),
          _kpiItem(
            title: "Total Orders",
            value: "$totalOrders",
            icon: Icons.shopping_bag_rounded,
            color: const Color(0xFF3B82F6),
            bgColor: const Color(0xFFEFF6FF),
          ),
          _kpiItem(
            title: "Avg Order Value",
            value: formattedAov,
            icon: Icons.insights_rounded,
            color: const Color(0xFF8B5CF6),
            bgColor: const Color(0xFFF3E8FF),
          ),
          _kpiItem(
            title: "Active Stores",
            value: "$activeStoresCount / $totalStoresCount",
            icon: Icons.storefront_rounded,
            color: const Color(0xFFF59E0B),
            bgColor: const Color(0xFFFEF3C7),
          ),
        ];

        if (isSmall) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: kpis[0]),
                  const SizedBox(width: 8),
                  Expanded(child: kpis[1]),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: kpis[2]),
                  const SizedBox(width: 8),
                  Expanded(child: kpis[3]),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: kpis[0]),
            const SizedBox(width: 8),
            Expanded(child: kpis[1]),
            const SizedBox(width: 8),
            Expanded(child: kpis[2]),
            const SizedBox(width: 8),
            Expanded(child: kpis[3]),
          ],
        );
      },
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04);
  }

  Widget _kpiItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: slateDark,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: slateMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ================= 3. LINE CHART SECTION (REVENUE TREND) =================
  Widget _buildLineChartSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 1),
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
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: primaryTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.show_chart_rounded, color: primaryTeal, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Revenue Trend (GMV)",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: slateDark,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            "Sales growth ($selectedTimeframe)",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(color: slateMuted, fontSize: 10.5, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  "LIVE",
                  style: GoogleFonts.poppins(color: primaryTeal, fontSize: 9.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 170,
            child: lineSpots.isEmpty
                ? const Center(child: Text("No sales data available", style: TextStyle(fontSize: 12)))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: lineMaxY > 0 ? (lineMaxY / 4) : 25,
                        getDrawingHorizontalLine: (value) => const FlLine(
                          color: Color(0xFFF1F5F9),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < lineLabels.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    lineLabels[index],
                                    style: GoogleFonts.poppins(
                                      color: slateMuted,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            interval: lineMaxY > 0 ? (lineMaxY / 4) : 25,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) return const SizedBox.shrink();
                              String formatted = value >= 1000 ? "${(value / 1000).toStringAsFixed(0)}k" : value.toStringAsFixed(0);
                              return Text(
                                formatted,
                                style: GoogleFonts.poppins(
                                  color: slateMuted,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: (lineLabels.length - 1).toDouble(),
                      minY: 0,
                      maxY: lineMaxY,
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final label = lineLabels[spot.x.toInt()];
                              return LineTooltipItem(
                                "$label\nRs. ${spot.y.toStringAsFixed(0)}",
                                GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10.5,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: lineSpots,
                          isCurved: true,
                          curveSmoothness: 0.35,
                          color: primaryTeal,
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 3,
                                color: Colors.white,
                                strokeWidth: 2,
                                strokeColor: primaryTeal,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                primaryTeal.withValues(alpha: 0.25),
                                primaryTeal.withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 350.ms);
  }

  // ================= 4. BAR CHART SECTION (ORDER VOLUME) =================
  Widget _buildBarChartSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 1),
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
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.bar_chart_rounded, color: Color(0xFF3B82F6), size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Order Volumes",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: slateDark,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            "Total orders placed per interval",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(color: slateMuted, fontSize: 10.5, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "Orders: $totalOrders",
                style: GoogleFonts.poppins(color: const Color(0xFF3B82F6), fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 160,
            child: barGroups.isEmpty
                ? const Center(child: Text("No order volume data available", style: TextStyle(fontSize: 12)))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: barMaxY,
                      barTouchData: BarTouchData(
                        touchCallback: (event, response) {
                          if (response?.spot != null && event is! FlTapUpEvent && event is! FlPanEndEvent) {
                            setState(() {
                              touchedBarGroupIndex = response!.spot!.touchedBarGroupIndex;
                            });
                          } else {
                            setState(() {
                              touchedBarGroupIndex = null;
                            });
                          }
                        },
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final label = barLabels[group.x.toInt()];
                            return BarTooltipItem(
                              "$label\n${rod.toY.toInt()} orders",
                              GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 10.5,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: barMaxY > 4 ? (barMaxY / 4).roundToDouble() : 2,
                            getTitlesWidget: (val, meta) {
                              if (val == 0) return const SizedBox.shrink();
                              return Text(
                                "${val.toInt()}",
                                style: GoogleFonts.poppins(color: slateMuted, fontSize: 9.5, fontWeight: FontWeight.w600),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < barLabels.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    barLabels[index],
                                    style: GoogleFonts.poppins(
                                      color: slateMuted,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: barMaxY > 4 ? (barMaxY / 4).roundToDouble() : 2,
                        getDrawingHorizontalLine: (value) => const FlLine(
                          color: Color(0xFFF1F5F9),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: barGroups,
                    ),
                  ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 350.ms);
  }

  // ================= 5. PIE / DONUT CHART SECTION (DISTRIBUTION) =================
  Widget _buildPieChartSection() {
    final List<PieChartSectionData> sections = [];
    final List<Widget> legendItems = [];

    if (selectedPieView == "Order Status") {
      final totalValid = statusCounts.values.fold<int>(0, (a, b) => a + b);
      final colors = {
        'completed': const Color(0xFF10B981),
        'pending': const Color(0xFFF59E0B),
        'processing': const Color(0xFF3B82F6),
        'shipped': const Color(0xFF8B5CF6),
        'cancelled': const Color(0xFFEF4444),
      };

      int idx = 0;
      statusCounts.forEach((status, count) {
        if (count > 0 || totalValid == 0) {
          final isTouched = touchedPieIndex == idx;
          final double percentage = totalValid > 0 ? ((count / totalValid) * 100) : 20.0;
          final color = colors[status] ?? Colors.grey;

          sections.add(
            PieChartSectionData(
              color: color,
              value: count > 0 ? count.toDouble() : 1,
              title: isTouched ? "${percentage.toStringAsFixed(1)}%" : "${percentage.toStringAsFixed(0)}%",
              radius: isTouched ? 38.0 : 32.0,
              titleStyle: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          );

          legendItems.add(
            _pieLegendItem(
              color: color,
              label: status.toUpperCase(),
              count: "$count orders",
              percentage: "${percentage.toStringAsFixed(1)}%",
            ),
          );
          idx++;
        }
      });
    } else {
      // Store Categories Distribution
      final totalCat = categoryCounts.values.fold<int>(0, (a, b) => a + b);
      final palette = [
        const Color(0xFF0D9488),
        const Color(0xFF3B82F6),
        const Color(0xFFF59E0B),
        const Color(0xFFEC4899),
        const Color(0xFF8B5CF6),
        const Color(0xFF10B981),
      ];

      int idx = 0;
      categoryCounts.forEach((category, count) {
        final isTouched = touchedPieIndex == idx;
        final double percentage = totalCat > 0 ? ((count / totalCat) * 100) : 100.0;
        final color = palette[idx % palette.length];

        sections.add(
          PieChartSectionData(
            color: color,
            value: count.toDouble(),
            title: isTouched ? "${percentage.toStringAsFixed(1)}%" : "${percentage.toStringAsFixed(0)}%",
            radius: isTouched ? 38.0 : 32.0,
            titleStyle: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        );

        legendItems.add(
          _pieLegendItem(
            color: color,
            label: category,
            count: "$count stores",
            percentage: "${percentage.toStringAsFixed(1)}%",
          ),
        );
        idx++;
      });
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 1),
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
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.pie_chart_rounded, color: Color(0xFF8B5CF6), size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Distribution Breakdown",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: slateDark,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            "Breakdown by $selectedPieView",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(color: slateMuted, fontSize: 10.5, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: bgLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedPieView,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF8B5CF6), size: 14),
                    style: GoogleFonts.poppins(color: slateDark, fontSize: 10.5, fontWeight: FontWeight.w700),
                    borderRadius: BorderRadius.circular(8),
                    dropdownColor: Colors.white,
                    items: ["Order Status", "Store Category"].map((v) {
                      return DropdownMenuItem(value: v, child: Text(v));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => selectedPieView = val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 600;
              final pieWidget = SizedBox(
                height: 150,
                child: sections.isEmpty
                    ? const Center(child: Text("No distribution data available", style: TextStyle(fontSize: 12)))
                    : PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (event, pieTouchResponse) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    pieTouchResponse == null ||
                                    pieTouchResponse.touchedSection == null) {
                                  touchedPieIndex = -1;
                                  return;
                                }
                                touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                          borderData: FlBorderData(show: false),
                          sectionsSpace: 2,
                          centerSpaceRadius: 34,
                          sections: sections,
                        ),
                      ),
              );

              final legendWidget = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: legendItems,
              );

              if (isSmall) {
                return Column(
                  children: [
                    pieWidget,
                    const SizedBox(height: 12),
                    legendWidget,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 5, child: pieWidget),
                  const SizedBox(width: 16),
                  Expanded(flex: 5, child: legendWidget),
                ],
              );
            },
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 350.ms);
  }

  Widget _pieLegendItem({
    required Color color,
    required String label,
    required String count,
    required String percentage,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: slateDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count,
                style: GoogleFonts.poppins(
                  color: slateMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                percentage,
                style: GoogleFonts.poppins(
                  color: slateDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
