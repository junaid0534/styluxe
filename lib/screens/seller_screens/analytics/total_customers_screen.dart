import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../widgets/seller_bottom_nav.dart';
import '../../../widgets/seller_shimmer_loading.dart';

class TotalCustomersScreen extends StatefulWidget {
  const TotalCustomersScreen({super.key});

  @override
  State<TotalCustomersScreen> createState() => _TotalCustomersScreenState();
}

class _TotalCustomersScreenState extends State<TotalCustomersScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> allCustomers = [];
  List<Map<String, dynamic>> filteredCustomers = [];
  bool isLoading = true;

  final TextEditingController searchController = TextEditingController();
  String selectedFilter = "All"; // All, VIP, Repeat, New
  String selectedSort = "Highest Spend"; // Highest Spend, Most Orders, Most Recent, Name (A-Z)
  final List<String> sortOptions = [
    "Highest Spend",
    "Most Orders",
    "Most Recent",
    "Name (A-Z)",
  ];

  int totalUniqueBuyers = 0;
  int repeatBuyersCount = 0;
  int vipBuyersCount = 0;
  double avgSpendPerBuyer = 0.0;
  double totalRevenueFromBuyers = 0.0;

  // Executive Theme Constants
  static const Color sapphireBlue = Color(0xFF2563EB);
  static const Color sapphireLight = Color(0xFFEFF6FF);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color cardBorderColor = Color(0xFFE2E8F0);
  static const Color bgColor = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    fetchCustomers();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _launchCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;
    final Uri uri = Uri(scheme: 'tel', path: clean);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        Clipboard.setData(ClipboardData(text: phone));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Phone $phone copied to clipboard!"), duration: const Duration(seconds: 2)),
          );
        }
      }
    } catch (_) {
      Clipboard.setData(ClipboardData(text: phone));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Phone $phone copied to clipboard!"), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return;
    if (clean.startsWith('0')) {
      clean = '92${clean.substring(1)}';
    }
    final Uri uri = Uri.parse("https://wa.me/$clean");
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Clipboard.setData(ClipboardData(text: phone));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Phone $phone copied to clipboard!"), duration: const Duration(seconds: 2)),
          );
        }
      }
    } catch (_) {
      Clipboard.setData(ClipboardData(text: phone));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Phone $phone copied to clipboard!"), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  // ================= FETCH CUSTOMERS & AGGREGATE STATS =================
  Future<void> fetchCustomers() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("Seller not logged in");

      List<dynamic> ordersList = [];

      // 1. Fetch from orders table by seller_id
      try {
        final data = await supabase
            .from('orders')
            .select('*')
            .eq('seller_id', user.id)
            .order('created_at', ascending: false);
        ordersList.addAll(data);
      } catch (e) {
        debugPrint("Error fetching orders: $e");
      }

      // 2. Also check order_items table in case orders are keyed through order_items
      try {
        final orderItemsData = await supabase
            .from('order_items')
            .select('order_id, orders(*)')
            .eq('seller_id', user.id);

        for (final item in orderItemsData) {
          final ord = item['orders'];
          if (ord is Map && ord.isNotEmpty) {
            final exists = ordersList.any((o) => o['id']?.toString() == ord['id']?.toString());
            if (!exists) {
              ordersList.add(ord);
            }
          }
        }
      } catch (_) {}

      final Map<String, Map<String, dynamic>> customerMap = {};

      for (var order in ordersList) {
        final rawPhone = order['phone']?.toString() ?? order['contact']?.toString() ?? '';
        final cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
        final rawUid = order['user_id']?.toString() ?? order['buyer_id']?.toString() ?? '';

        // Unified key: normalized phone if available (last 10 digits), else user_id, else order id
        final String uid = cleanPhone.length >= 7
            ? (cleanPhone.length > 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone)
            : (rawUid.isNotEmpty ? rawUid : (order['id']?.toString() ?? 'unknown'));

        final amount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
        final rawName = order['customer_name']?.toString() ??
            order['name']?.toString() ??
            order['buyer_name']?.toString() ??
            order['full_name']?.toString() ??
            '';
        final name = rawName.trim().isEmpty ? 'Customer' : rawName.trim();
        final phone = rawPhone.trim().isNotEmpty ? rawPhone.trim() : 'N/A';
        final address = order['address']?.toString() ??
            order['shipping_address']?.toString() ??
            order['delivery_address']?.toString() ??
            'N/A';
        final city = order['city']?.toString() ?? '';
        final fullAddress = (city.isNotEmpty && address != 'N/A') ? "$address, $city" : address;
        final dateStr = order['created_at']?.toString() ?? '';

        if (!customerMap.containsKey(uid)) {
          customerMap[uid] = {
            'user_id': rawUid.isNotEmpty ? rawUid : uid,
            'name': name,
            'phone': phone,
            'address': fullAddress,
            'city': city,
            'order_count': 1,
            'total_spent': amount,
            'last_order_date': dateStr,
            'orders': [order],
          };
        } else {
          customerMap[uid]!['order_count'] = (customerMap[uid]!['order_count'] as int) + 1;
          customerMap[uid]!['total_spent'] = (customerMap[uid]!['total_spent'] as double) + amount;
          (customerMap[uid]!['orders'] as List).add(order);

          if (customerMap[uid]!['name'] == 'Customer' && name != 'Customer') {
            customerMap[uid]!['name'] = name;
          }
          if (customerMap[uid]!['phone'] == 'N/A' && phone != 'N/A') {
            customerMap[uid]!['phone'] = phone;
          }
          if (customerMap[uid]!['address'] == 'N/A' && fullAddress != 'N/A') {
            customerMap[uid]!['address'] = fullAddress;
          }
          if (rawUid.isNotEmpty && (customerMap[uid]!['user_id'] == null || customerMap[uid]!['user_id'] == uid)) {
            customerMap[uid]!['user_id'] = rawUid;
          }
        }
      }

      // Enrich with Profiles Table
      final userIds = customerMap.keys.where((k) => k.isNotEmpty && !k.startsWith('+') && !k.startsWith('0') && k.length > 10).toList();
      if (userIds.isNotEmpty) {
        try {
          final profilesData = await supabase
              .from('profiles')
              .select('id, full_name, name, email, avatar_url, phone')
              .filter('id', 'in', userIds);

          for (final prof in profilesData) {
            final pId = prof['id']?.toString();
            if (pId != null && customerMap.containsKey(pId)) {
              final rawPName = (prof['full_name'] ?? prof['name'])?.toString();
              final pName = rawPName?.trim();
              final rawPEmail = prof['email']?.toString();
              final pEmail = rawPEmail?.trim();
              final rawPAvatar = prof['avatar_url']?.toString();
              final pAvatar = rawPAvatar?.trim();
              final rawPPhone = prof['phone']?.toString();
              final pPhone = rawPPhone?.trim();

              if (pName != null && pName.isNotEmpty && (customerMap[pId]!['name'] == 'Customer' || customerMap[pId]!['name'].toString().isEmpty)) {
                customerMap[pId]!['name'] = pName;
              }
              if (pEmail != null && pEmail.isNotEmpty) {
                customerMap[pId]!['email'] = pEmail;
              }
              if (pAvatar != null && pAvatar.isNotEmpty) {
                customerMap[pId]!['avatar_url'] = pAvatar;
              }
              if (pPhone != null && pPhone.isNotEmpty && customerMap[pId]!['phone'] == 'N/A') {
                customerMap[pId]!['phone'] = pPhone;
              }
            }
          }
        } catch (_) {}
      }

      final list = customerMap.values.toList();

      // Sort by highest spending first
      list.sort((a, b) => (b['total_spent'] as double).compareTo(a['total_spent'] as double));

      int repeatCount = 0;
      int vipCount = 0;
      double sumSpend = 0.0;

      for (var c in list) {
        final count = c['order_count'] as int;
        final spent = c['total_spent'] as double;
        if (count >= 2) repeatCount++;
        if (spent >= 5000 || count >= 3) vipCount++;
        sumSpend += spent;
      }

      if (!mounted) return;

      setState(() {
        allCustomers = list;
        totalUniqueBuyers = list.length;
        repeatBuyersCount = repeatCount;
        vipBuyersCount = vipCount;
        totalRevenueFromBuyers = sumSpend;
        avgSpendPerBuyer = list.isNotEmpty ? (sumSpend / list.length) : 0.0;
        isLoading = false;
      });

      _applyFilters();
    } catch (e) {
      debugPrint("Error in fetchCustomers: $e");
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  // ================= FILTER & SEARCH CUSTOMERS =================
  void _applyFilters() {
    final query = searchController.text.toLowerCase().trim();
    List<Map<String, dynamic>> result = allCustomers.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? '').toString().toLowerCase();
      final address = (c['address'] ?? '').toString().toLowerCase();
      final email = (c['email'] ?? '').toString().toLowerCase();
      final orderCount = (c['order_count'] as int?) ?? 1;
      final totalSpent = (c['total_spent'] as double?) ?? 0.0;

      final matchesSearch = query.isEmpty ||
          name.contains(query) ||
          phone.contains(query) ||
          address.contains(query) ||
          email.contains(query);

      if (!matchesSearch) return false;

      if (selectedFilter == "VIP") {
        return totalSpent >= 5000 || orderCount >= 3;
      } else if (selectedFilter == "Repeat") {
        return orderCount >= 2;
      } else if (selectedFilter == "New") {
        return orderCount == 1;
      }

      return true;
    }).toList();

    // Dynamic Multi-Option Sorting
    if (selectedSort == "Highest Spend") {
      result.sort((a, b) => ((b['total_spent'] as num?)?.toDouble() ?? 0.0)
          .compareTo((a['total_spent'] as num?)?.toDouble() ?? 0.0));
    } else if (selectedSort == "Most Orders") {
      result.sort((a, b) => ((b['order_count'] as num?)?.toInt() ?? 0)
          .compareTo((a['order_count'] as num?)?.toInt() ?? 0));
    } else if (selectedSort == "Most Recent") {
      result.sort((a, b) => (b['last_order_date']?.toString() ?? '')
          .compareTo(a['last_order_date']?.toString() ?? ''));
    } else if (selectedSort == "Name (A-Z)") {
      result.sort((a, b) => (a['name']?.toString() ?? '')
          .toLowerCase()
          .compareTo((b['name']?.toString() ?? '').toLowerCase()));
    }

    setState(() {
      filteredCustomers = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Customer Directory",
          style: TextStyle(color: slateDark, fontSize: 17.5, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: sapphireLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.refresh_rounded, color: sapphireBlue, size: 20),
            ),
            tooltip: "Refresh Customers",
            onPressed: fetchCustomers,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? const SellerOrdersShimmer()
          : RefreshIndicator(
              onRefresh: fetchCustomers,
              color: sapphireBlue,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 950),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ================= 1. MODERN KPI SUMMARY CARDS =================
                        _buildKpiHeader(),

                        const SizedBox(height: 16),

                        // ================= 2. SEARCH & FILTER PILLS ROW =================
                        _buildSearchAndFilters(),

                        const SizedBox(height: 16),

                        // ================= 3. SECTION HEADER =================
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Buyers List (${filteredCustomers.length})",
                              style: const TextStyle(color: slateDark, fontSize: 15, fontWeight: FontWeight.w900),
                            ),
                            _buildSortDropdown(),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // ================= 4. CUSTOMERS CARDS LIST =================
                        if (filteredCustomers.isEmpty)
                          _buildEmptyCustomersView()
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredCustomers.length,
                            separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final cust = filteredCustomers[index];
                              return _customerCard(cust);
                            },
                          ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: const SellerBottomNav(currentIndex: 3),
    );
  }

  // ================= 1. KPI SUMMARY HEADER =================
  Widget _buildKpiHeader() {
    return Row(
      children: [
        Expanded(
          child: _kpiCard(
            title: "Buyers",
            value: totalUniqueBuyers.toString(),
            icon: Icons.people_alt_rounded,
            color: const Color(0xFF1D4ED8),
            borderColor: const Color(0xFFBFDBFE),
            bgColor: const Color(0xFFEFF6FF),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _kpiCard(
            title: "Repeat",
            value: repeatBuyersCount.toString(),
            icon: Icons.repeat_rounded,
            color: const Color(0xFF047857),
            borderColor: const Color(0xFFA7F3D0),
            bgColor: const Color(0xFFECFDF5),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _kpiCard(
            title: "Avg Spend",
            value: "Rs. ${avgSpendPerBuyer >= 1000 ? '${(avgSpendPerBuyer / 1000).toStringAsFixed(1)}k' : avgSpendPerBuyer.toStringAsFixed(0)}",
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFF6D28D9),
            borderColor: const Color(0xFFDDD6FE),
            bgColor: const Color(0xFFF5F3FF),
          ),
        ),
      ],
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color borderColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
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
              style: const TextStyle(
                color: slateDark,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= 2. SEARCH & FILTER ROW =================
  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        // Search Bar
        SizedBox(
          height: 42,
          child: TextField(
            controller: searchController,
            onChanged: (_) => _applyFilters(),
            style: const TextStyle(fontSize: 13, color: slateDark, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: "Search by Name, Phone, City, or Email...",
              hintStyle: const TextStyle(color: slateMuted, fontSize: 12.5),
              prefixIcon: const Icon(Icons.search_rounded, color: sapphireBlue, size: 20),
              suffixIcon: searchController.text.isNotEmpty
                  ? InkWell(
                      onTap: () {
                        searchController.clear();
                        _applyFilters();
                      },
                      child: const Icon(Icons.clear_rounded, color: slateMuted, size: 18),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cardBorderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cardBorderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: sapphireBlue, width: 1.5)),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Filter Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _filterChipItem("All", "All (${allCustomers.length})"),
              const SizedBox(width: 8),
              _filterChipItem("VIP", "VIP ($vipBuyersCount)"),
              const SizedBox(width: 8),
              _filterChipItem("Repeat", "Repeat ($repeatBuyersCount)"),
              const SizedBox(width: 8),
              _filterChipItem("New", "1-Time Buyers (${allCustomers.length - repeatBuyersCount})"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChipItem(String key, String label) {
    final bool isSel = selectedFilter == key;
    return InkWell(
      onTap: () {
        setState(() => selectedFilter = key);
        _applyFilters();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? sapphireBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSel ? sapphireBlue : cardBorderColor),
          boxShadow: isSel
              ? [BoxShadow(color: sapphireBlue.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSel ? Colors.white : slateDark,
            fontSize: 11.5,
            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cardBorderColor, width: 1.2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedSort,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: sapphireBlue),
          style: const TextStyle(color: slateDark, fontSize: 11.5, fontWeight: FontWeight.w700),
          borderRadius: BorderRadius.circular(12),
          items: sortOptions.map((opt) {
            IconData optIcon = Icons.attach_money_rounded;
            if (opt == "Most Orders") optIcon = Icons.shopping_bag_outlined;
            if (opt == "Most Recent") optIcon = Icons.access_time_rounded;
            if (opt == "Name (A-Z)") optIcon = Icons.sort_by_alpha_rounded;

            return DropdownMenuItem<String>(
              value: opt,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(optIcon, size: 13, color: sapphireBlue),
                  const SizedBox(width: 5),
                  Text(opt, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => selectedSort = val);
              _applyFilters();
            }
          },
        ),
      ),
    );
  }

  // ================= 3. CUSTOMER CARD ITEM =================
  Widget _customerCard(Map<String, dynamic> cust) {
    final name = cust['name']?.toString() ?? 'Customer';
    final phone = cust['phone']?.toString() ?? 'N/A';
    final address = cust['address']?.toString() ?? 'N/A';
    final email = cust['email']?.toString() ?? '';
    final orderCount = (cust['order_count'] as int?) ?? 1;
    final totalSpent = (cust['total_spent'] as double?) ?? 0.0;
    final lastDateStr = cust['last_order_date']?.toString() ?? '';
    final avatarUrl = cust['avatar_url']?.toString();

    String badgeLabel = "NEW BUYER";
    Color badgeColor = const Color(0xFF2563EB);
    Color badgeBg = const Color(0xFFEFF6FF);

    if (totalSpent >= 5000 || orderCount >= 3) {
      badgeLabel = "VIP BUYER";
      badgeColor = const Color(0xFF7C3AED);
      badgeBg = const Color(0xFFF5F3FF);
    } else if (orderCount >= 2) {
      badgeLabel = "REPEAT BUYER";
      badgeColor = const Color(0xFF10B981);
      badgeBg = const Color(0xFFECFDF5);
    }

    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';

    return InkWell(
      onTap: () => _showCustomerOrdersBottomSheet(cust),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorderColor, width: 1.2),
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
            // ================= TIER 1: AVATAR, FULL NAME, BADGE & LIFETIME SPEND =================
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar (50x50)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: sapphireLight,
                    border: Border.all(color: sapphireBlue.withValues(alpha: 0.25), width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Text(
                              initial,
                              style: const TextStyle(color: sapphireBlue, fontSize: 20, fontWeight: FontWeight.w900),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initial,
                            style: const TextStyle(color: sapphireBlue, fontSize: 20, fontWeight: FontWeight.w900),
                          ),
                        ),
                ),

                const SizedBox(width: 12),

                // Name & Badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: slateDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: badgeColor.withValues(alpha: 0.25), width: 0.8),
                            ),
                            child: Text(
                              badgeLabel,
                              style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: sapphireLight,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: sapphireBlue.withValues(alpha: 0.2), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shopping_bag_outlined, color: sapphireBlue, size: 11),
                                const SizedBox(width: 3.5),
                                Text(
                                  "$orderCount Orders",
                                  style: const TextStyle(color: sapphireBlue, fontSize: 9.5, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Spend Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Rs. ${totalSpent.toStringAsFixed(0)}",
                      style: const TextStyle(color: slateDark, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastDateStr.length >= 10 ? lastDateStr.substring(0, 10) : "Lifetime",
                      style: const TextStyle(color: slateMuted, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            Container(height: 1, color: const Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // ================= TIER 2: CONTACT & ADDRESS DETAILS =================
            Row(
              children: [
                const Icon(Icons.phone_outlined, color: slateMuted, size: 14),
                const SizedBox(width: 5),
                Text(
                  phone,
                  style: const TextStyle(color: slateDark, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                if (address != 'N/A' && address.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.location_on_outlined, color: slateMuted, size: 14),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: slateMuted, fontSize: 11.5, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ],
            ),

            if (email.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.email_outlined, color: slateMuted, size: 13),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: slateMuted, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ],

            if (phone != 'N/A') ...[
              const SizedBox(height: 12),

              // ================= TIER 3: FULL WIDTH PROMINENT QUICK ACTIONS =================
              Row(
                children: [
                  // Call Action Button
                  Expanded(
                    child: InkWell(
                      onTap: () => _launchCall(phone),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.call_rounded, color: sapphireBlue, size: 14),
                            SizedBox(width: 6),
                            Text(
                              "Call",
                              style: TextStyle(color: sapphireBlue, fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // WhatsApp Action Button
                  Expanded(
                    child: InkWell(
                      onTap: () => _launchWhatsApp(phone),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_rounded, color: Color(0xFF047857), size: 13),
                            SizedBox(width: 6),
                            Text(
                              "WhatsApp",
                              style: TextStyle(color: Color(0xFF047857), fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ================= 4. CUSTOMER ORDERS BOTTOM SHEET =================
  void _showCustomerOrdersBottomSheet(Map<String, dynamic> cust) {
    final name = cust['name']?.toString() ?? 'Customer';
    final phone = cust['phone']?.toString() ?? 'N/A';
    final address = cust['address']?.toString() ?? 'N/A';
    final email = cust['email']?.toString() ?? '';
    final ordersList = (cust['orders'] as List?) ?? [];
    final totalSpent = (cust['total_spent'] as double?) ?? 0.0;
    final avatarUrl = cust['avatar_url']?.toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(width: 44, height: 4.5, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(3))),
            ),
            const SizedBox(height: 16),

            // Customer Header
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: sapphireLight,
                    border: Border.all(color: sapphireBlue, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Text(initial, style: const TextStyle(color: sapphireBlue, fontSize: 20, fontWeight: FontWeight.w900)),
                          ),
                        )
                      : Center(
                          child: Text(initial, style: const TextStyle(color: sapphireBlue, fontSize: 20, fontWeight: FontWeight.w900)),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: slateDark, fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 12, color: slateMuted),
                          const SizedBox(width: 4),
                          Text(phone, style: const TextStyle(color: slateMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                          if (phone != 'N/A') ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _launchCall(phone),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                                child: const Icon(Icons.call_rounded, size: 12, color: sapphireBlue),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => _launchWhatsApp(phone),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
                                child: const Icon(Icons.chat_bubble_outline_rounded, size: 12, color: Color(0xFF047857)),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: phone));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Phone copied to clipboard!"), duration: Duration(seconds: 1)),
                                );
                              },
                              child: const Icon(Icons.copy_rounded, size: 12, color: sapphireBlue),
                            ),
                          ],
                        ],
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined, size: 12, color: slateMuted),
                            const SizedBox(width: 4),
                            Text(email, style: const TextStyle(color: slateMuted, fontSize: 11.5)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: slateMuted),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Summary Stats Pill in Modal
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text("Orders Placed", style: TextStyle(color: slateMuted, fontSize: 10.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text("${ordersList.length}", style: const TextStyle(color: sapphireBlue, fontSize: 15, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                  Column(
                    children: [
                      const Text("Total Spend", style: TextStyle(color: slateMuted, fontSize: 10.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text("Rs. ${totalSpent.toStringAsFixed(0)}", style: const TextStyle(color: slateDark, fontSize: 15, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ],
              ),
            ),

            if (address != 'N/A' && address.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: slateMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "Shipping Address: $address",
                      style: const TextStyle(color: slateMuted, fontSize: 11.5, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            const Text("Order History", style: TextStyle(color: slateDark, fontSize: 14, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),

            Expanded(
              child: ListView.separated(
                itemCount: ordersList.length,
                separatorBuilder: (c, i) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final ord = ordersList[idx];
                  final orderId = (ord['order_id'] ?? ord['id'])?.toString() ?? '';
                  final amt = (ord['total_amount'] as num?)?.toDouble() ?? 0.0;
                  final status = ord['status']?.toString() ?? 'Pending';
                  final dt = ord['created_at']?.toString() ?? '';
                  final pay = ord['payment_method']?.toString() ?? 'COD';

                  Color stColor = sapphireBlue;
                  Color stBg = sapphireLight;
                  if (status.toLowerCase() == 'delivered') {
                    stColor = const Color(0xFF10B981);
                    stBg = const Color(0xFFECFDF5);
                  } else if (status.toLowerCase() == 'cancelled') {
                    stColor = const Color(0xFFEF4444);
                    stBg = const Color(0xFFFEF2F2);
                  }

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardBorderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "#${orderId.length > 12 ? orderId.substring(0, 12) : orderId}",
                              style: const TextStyle(color: slateDark, fontSize: 12.5, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dt.length >= 10 ? dt.substring(0, 10) : dt,
                              style: const TextStyle(color: slateMuted, fontSize: 11),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "Rs. ${amt.toStringAsFixed(0)}",
                              style: const TextStyle(color: slateDark, fontSize: 13.5, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(pay, style: const TextStyle(color: slateMuted, fontSize: 9.5, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(color: stBg, borderRadius: BorderRadius.circular(4)),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(color: stColor, fontSize: 8.5, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= EMPTY STATE =================
  Widget _buildEmptyCustomersView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: sapphireLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_outline_rounded, size: 40, color: sapphireBlue),
          ),
          const SizedBox(height: 14),
          const Text("No Customer Accounts Found", style: TextStyle(color: slateDark, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text(
            "As customers place orders with your store, their profiles, spend statistics, and order histories will appear here.",
            style: TextStyle(color: slateMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: fetchCustomers,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text("Refresh List", style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: sapphireBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}