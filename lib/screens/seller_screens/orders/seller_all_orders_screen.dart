import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'seller_order_invoice_screen.dart';

class SellerAllOrdersScreen extends StatefulWidget {
  const SellerAllOrdersScreen({super.key});

  @override
  State<SellerAllOrdersScreen> createState() => _SellerAllOrdersScreenState();
}

class _SellerAllOrdersScreenState extends State<SellerAllOrdersScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  String selectedStatus = "All";
  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> allOrders = [];
  List<Map<String, dynamic>> filteredOrders = [];

  final List<String> statusFilters = [
    "All",
    "Pending",
    "Processing",
    "Shipped",
    "Delivered",
    "Cancelled",
  ];

  static const Color sapphireBlue = Color(0xFF2563EB);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color cardBorderColor = Color(0xFF93C5FD);
  static const Color bgColor = Colors.white;

  @override
  void initState() {
    super.initState();
    fetchSellerOrders();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ================= FETCH SELLER ORDERS =================
  Future<void> fetchSellerOrders() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) throw Exception("User not logged in");

      final sellerId = currentUser.id;

      final response = await supabase
          .from('orders')
          .select('''
            id,
            order_id,
            user_id,
            seller_id,
            total_amount,
            status,
            address,
            city,
            phone,
            customer_name,
            payment_method,
            created_at,
            updated_at,
            order_items (
              id,
              order_id,
              product_id,
              quantity,
              price,
              products (
                id,
                name,
                price,
                image_url,
                category,
                size
              )
            )
          ''')
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false);

      final fetched = List<Map<String, dynamic>>.from(response);

      if (!mounted) return;

      setState(() {
        allOrders = fetched;
        filteredOrders = fetched;
        isLoading = false;
      });

      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        allOrders = [];
        filteredOrders = [];
        isLoading = false;
      });
    }
  }

  // ================= APPLY STATUS & SEARCH FILTERS =================
  void _applyFilters() {
    final query = searchController.text.toLowerCase().trim();

    setState(() {
      filteredOrders = allOrders.where((ord) {
        // Status filter
        final status = (ord['status']?.toString() ?? 'Pending').trim();
        final matchesStatus = selectedStatus == "All" || status.toLowerCase() == selectedStatus.toLowerCase();

        // Search filter
        final orderId = (ord['order_id'] ?? ord['id'] ?? '').toString().toLowerCase();
        final phone = (ord['phone'] ?? '').toString().toLowerCase();
        final address = (ord['address'] ?? '').toString().toLowerCase();
        final city = (ord['city'] ?? '').toString().toLowerCase();
        final customerName = (ord['customer_name'] ?? '').toString().toLowerCase();

        final matchesSearch = query.isEmpty ||
            orderId.contains(query) ||
            phone.contains(query) ||
            address.contains(query) ||
            city.contains(query) ||
            customerName.contains(query);

        return matchesStatus && matchesSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // KPI counts
    final totalCount = allOrders.length;
    final deliveredCount = allOrders.where((o) => (o['status']?.toString() ?? '').toLowerCase() == 'delivered').length;
    final activeCount = allOrders.where((o) {
      final s = (o['status']?.toString() ?? '').toLowerCase();
      return s == 'pending' || s == 'processing' || s == 'shipped';
    }).length;
    final cancelledCount = allOrders.where((o) => (o['status']?.toString() ?? '').toLowerCase() == 'cancelled').length;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "All Orders History",
          style: TextStyle(color: slateDark, fontSize: 18, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: sapphireBlue),
            tooltip: "Refresh Orders",
            onPressed: fetchSellerOrders,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: sapphireBlue))
          : RefreshIndicator(
              onRefresh: fetchSellerOrders,
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
                        // ================= 1. ONE-LINE COMPACT KPI METRIC PILLS (NO TEXT BELOW) =================
                        _buildCompactOneLineKpis(totalCount, deliveredCount, activeCount, cancelledCount),

                        const SizedBox(height: 14),

                        // ================= 2. ULTRA-COMPACT SEARCH BAR (height: 38) + DROPDOWN FILTER ROW =================
                        Row(
                          children: [
                            // Compact Search Bar
                            Expanded(
                              child: SizedBox(
                                height: 38,
                                child: TextField(
                                  controller: searchController,
                                  onChanged: (_) => _applyFilters(),
                                  style: const TextStyle(fontSize: 12.5, color: slateDark),
                                  decoration: InputDecoration(
                                    hintText: "Search order",
                                    hintStyle: const TextStyle(color: slateMuted, fontSize: 12),
                                    prefixIcon: const Icon(Icons.search_rounded, color: sapphireBlue, size: 18),
                                    suffixIcon: searchController.text.isNotEmpty
                                        ? InkWell(
                                            onTap: () {
                                              searchController.clear();
                                              _applyFilters();
                                            },
                                            child: const Icon(Icons.clear_rounded, color: slateMuted, size: 16),
                                          )
                                        : null,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: cardBorderColor)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: sapphireBlue, width: 1.5)),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Compact Dropdown Filter
                            Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedStatus,
                                  icon: const Icon(Icons.filter_list_rounded, color: sapphireBlue, size: 16),
                                  style: const TextStyle(color: slateDark, fontSize: 12, fontWeight: FontWeight.w800),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => selectedStatus = val);
                                      _applyFilters();
                                    }
                                  },
                                  items: statusFilters.map((st) {
                                    return DropdownMenuItem<String>(
                                      value: st,
                                      child: Text(st == "All" ? "All Status" : st),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ================= 3. ORDERS LIST TITLE =================
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Orders Directory (${filteredOrders.length})",
                              style: const TextStyle(color: slateDark, fontSize: 15, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              selectedStatus == "All" ? "All Statuses" : "Filter: $selectedStatus",
                              style: const TextStyle(color: slateMuted, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // ================= 4. ULTRA-MODERN ORDER CARDS =================
                        if (filteredOrders.isEmpty)
                          _buildEmptyOrdersView()
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredOrders.length,
                            separatorBuilder: (ctx, idx) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final ord = filteredOrders[index];
                              return _ultraModernOrderCard(ord);
                            },
                          ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: _buildSellerBottomNav(1),
    );
  }

  // ================= SINGLE ROW WITH 4 BIG ICONS & NUMBERS BELOW =================
  Widget _buildCompactOneLineKpis(int total, int delivered, int active, int cancelled) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          _singleRowKpiItem(total.toString(), Icons.receipt_long_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
          _kpiDivider(),
          _singleRowKpiItem(delivered.toString(), Icons.check_circle_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5)),
          _kpiDivider(),
          _singleRowKpiItem(active.toString(), Icons.local_shipping_rounded, const Color(0xFF6366F1), const Color(0xFFEEF2FF)),
          _kpiDivider(),
          _singleRowKpiItem(cancelled.toString(), Icons.cancel_rounded, const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
        ],
      ),
    );
  }

  Widget _singleRowKpiItem(String value, IconData icon, Color mainColor, Color bgColor) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: mainColor, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(color: slateDark, fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _kpiDivider() {
    return Container(height: 36, width: 1, color: const Color(0xFFE2E8F0));
  }

  // ================= ULTRA-MODERN ORDER CARD =================
  Widget _ultraModernOrderCard(Map<String, dynamic> ord) {
    final rawId = (ord['order_id'] ?? ord['id'] ?? '').toString();
    final displayId = rawId.length > 8 ? rawId.substring(0, 8).toUpperCase() : rawId.toUpperCase();

    final status = (ord['status']?.toString() ?? 'Pending').trim();
    final totalAmt = (ord['total_amount'] as num?)?.toDouble() ?? 0.0;
    final address = ord['address']?.toString() ?? 'N/A';
    final city = ord['city']?.toString() ?? '';
    final phone = ord['phone']?.toString() ?? 'N/A';
    final custName = ord['customer_name']?.toString() ?? 'Customer';
    final payMethod = ord['payment_method']?.toString() ?? 'COD';
    final dateStr = ord['created_at']?.toString() ?? '';

    final items = (ord['order_items'] as List?) ?? [];

    Color badgeBg = const Color(0xFFEFF6FF);
    Color badgeColor = sapphireBlue;

    final sLower = status.toLowerCase();
    if (sLower == 'delivered') {
      badgeBg = const Color(0xFFECFDF5);
      badgeColor = const Color(0xFF10B981);
    } else if (sLower == 'shipped') {
      badgeBg = const Color(0xFFEFF6FF);
      badgeColor = sapphireBlue;
    } else if (sLower == 'processing') {
      badgeBg = const Color(0xFFEEF2FF);
      badgeColor = const Color(0xFF6366F1);
    } else if (sLower == 'cancelled' || sLower == 'canceled') {
      badgeBg = const Color(0xFFFEF2F2);
      badgeColor = const Color(0xFFEF4444);
    } else {
      badgeBg = const Color(0xFFFFFBEB);
      badgeColor = const Color(0xFFF59E0B);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. CARD HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: slateDark, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        "#$displayId",
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr,
                      style: const TextStyle(color: slateMuted, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 2. CUSTOMER & SHIPPING SPECS
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_rounded, color: sapphireBlue, size: 15),
                    const SizedBox(width: 6),
                    Text(custName, style: const TextStyle(color: slateDark, fontSize: 13.5, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                      child: Text(payMethod.toUpperCase(), style: const TextStyle(color: slateDark, fontSize: 9.5, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, color: slateMuted, size: 13),
                    const SizedBox(width: 5),
                    Text(phone, style: const TextStyle(color: slateMuted, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    const Icon(Icons.location_on_outlined, color: slateMuted, size: 13),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        city.isNotEmpty ? "$address, $city" : address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: slateMuted, fontSize: 11.5),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // 3. ORDER ITEMS
                if (items.isEmpty)
                  const Text("Item details available upon dispatch.", style: TextStyle(color: slateMuted, fontSize: 11, fontStyle: FontStyle.italic))
                else
                  Column(
                    children: items.map((it) {
                      final pMap = it['products'] is Map ? Map<String, dynamic>.from(it['products']) : <String, dynamic>{};
                      final pName = pMap['name']?.toString() ?? 'Product Item';
                      final imgUrl = pMap['image_url']?.toString();
                      final qty = (it['quantity'] as num?)?.toInt() ?? 1;
                      final price = (it['price'] as num?)?.toDouble() ?? 0.0;
                      final pSize = pMap['size']?.toString() ?? 'N/A';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: (imgUrl != null && imgUrl.isNotEmpty)
                                    ? Image.network(imgUrl, fit: BoxFit.contain)
                                    : const Icon(Icons.inventory_2_outlined, color: slateMuted, size: 18),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(pName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: slateDark, fontSize: 12.5, fontWeight: FontWeight.w800)),
                                  Text("Qty: $qty  •  Size: $pSize", style: const TextStyle(color: slateMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                            Text("Rs. ${(price * qty).toStringAsFixed(0)}", style: const TextStyle(color: slateDark, fontSize: 12.5, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 4. FOOTER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Total Order Value", style: TextStyle(color: slateMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                    Text("Rs. ${totalAmt.toStringAsFixed(0)}", style: const TextStyle(color: slateDark, fontSize: 16, fontWeight: FontWeight.w900)),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sapphireBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => SellerOrderInvoiceScreen(order: ord),
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_rounded, color: Colors.white, size: 14),
                  label: const Text("View Invoice", style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOrdersView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor),
      ),
      child: const Column(
        children: [
          Icon(Icons.inventory_outlined, size: 48, color: slateMuted),
          SizedBox(height: 12),
          Text("No Orders Found", style: TextStyle(color: slateDark, fontSize: 16, fontWeight: FontWeight.w900)),
          SizedBox(height: 4),
          Text("No orders match the selected status or search query.", style: TextStyle(color: slateMuted, fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ================= 5-TAB SELLER BOTTOM NAV BAR =================
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
            if (index == 0) Navigator.pushReplacementNamed(context, '/seller');
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