import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../widgets/seller_bottom_nav.dart';

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

  int totalUniqueBuyers = 0;
  int repeatBuyersCount = 0;
  double avgSpendPerBuyer = 0.0;

  static const Color sapphireBlue = Color(0xFF2563EB);
  static const Color sapphireLight = Color(0xFFEFF6FF);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color cardBorderColor = Color(0xFF93C5FD);
  static const Color bgColor = Colors.white;

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

  // ================= FETCH CUSTOMERS & AGGREGATE STATS =================
  Future<void> fetchCustomers() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("Seller not logged in");

      final data = await supabase
          .from('orders')
          .select('id, user_id, customer_name, phone, shipping_address, total_amount, created_at, status')
          .eq('seller_id', user.id)
          .order('created_at', ascending: false);

      final Map<String, Map<String, dynamic>> customerMap = {};

      for (var order in data) {
        final uid = (order['user_id'] ?? order['phone'] ?? order['id']).toString();
        final amount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
        final rawName = order['customer_name']?.toString() ?? '';
        final name = rawName.trim().isEmpty ? 'Customer' : rawName.trim();
        final phone = order['phone']?.toString() ?? 'N/A';
        final address = order['shipping_address']?.toString() ?? 'N/A';
        final dateStr = order['created_at']?.toString() ?? '';

        if (!customerMap.containsKey(uid)) {
          customerMap[uid] = {
            'user_id': uid,
            'name': name,
            'phone': phone,
            'address': address,
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
        }
      }

      final list = customerMap.values.toList();

      // Sort by highest spending first
      list.sort((a, b) => (b['total_spent'] as double).compareTo(a['total_spent'] as double));

      int repeatCount = 0;
      double sumSpend = 0.0;

      for (var c in list) {
        final count = c['order_count'] as int;
        final spent = c['total_spent'] as double;
        if (count >= 2) repeatCount++;
        sumSpend += spent;
      }

      if (!mounted) return;

      setState(() {
        allCustomers = list;
        filteredCustomers = list;
        totalUniqueBuyers = list.length;
        repeatBuyersCount = repeatCount;
        avgSpendPerBuyer = list.isNotEmpty ? (sumSpend / list.length) : 0.0;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  // ================= FILTER CUSTOMERS BY SEARCH =================
  void _filterSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() => filteredCustomers = allCustomers);
      return;
    }

    final q = query.toLowerCase().trim();
    setState(() {
      filteredCustomers = allCustomers.where((c) {
        final name = (c['name'] ?? '').toString().toLowerCase();
        final phone = (c['phone'] ?? '').toString().toLowerCase();
        final address = (c['address'] ?? '').toString().toLowerCase();
        return name.contains(q) || phone.contains(q) || address.contains(q);
      }).toList();
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
          "Customer Directory & Buyers",
          style: TextStyle(color: slateDark, fontSize: 18, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: sapphireBlue),
            tooltip: "Refresh Customers",
            onPressed: fetchCustomers,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: sapphireBlue))
          : RefreshIndicator(
              onRefresh: fetchCustomers,
              color: sapphireBlue,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ================= 1. KPI SUMMARY CARDS =================
                        _buildKpiHeader(),

                        const SizedBox(height: 20),

                        // ================= 2. SEARCH BAR =================
                        TextField(
                          controller: searchController,
                          onChanged: _filterSearch,
                          decoration: InputDecoration(
                            hintText: "Search by Customer Name, Phone, or City...",
                            hintStyle: const TextStyle(color: slateMuted, fontSize: 13),
                            prefixIcon: const Icon(Icons.search_rounded, color: sapphireBlue),
                            suffixIcon: searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, color: slateMuted),
                                    onPressed: () {
                                      searchController.clear();
                                      _filterSearch('');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorderColor)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: sapphireBlue, width: 2)),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ================= 3. CUSTOMER LIST SECTION TITLE =================
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Customer Accounts (${filteredCustomers.length})",
                              style: const TextStyle(color: slateDark, fontSize: 15.5, fontWeight: FontWeight.w900),
                            ),
                            const Text(
                              "Sorted by Highest Spend",
                              style: TextStyle(color: slateMuted, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
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
                            separatorBuilder: (ctx, idx) => const SizedBox(height: 12),
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

  // ================= KPI SUMMARY HEADER =================
  Widget _buildKpiHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          _kpiItem("Total Buyers", totalUniqueBuyers.toString(), Icons.people_alt_rounded, const Color(0xFF2563EB)),
          _divider(),
          _kpiItem("Repeat Buyers", repeatBuyersCount.toString(), Icons.verified_user_rounded, const Color(0xFF10B981)),
          _divider(),
          _kpiItem("Avg Spend", "Rs. ${avgSpendPerBuyer.toStringAsFixed(0)}", Icons.account_balance_wallet_rounded, const Color(0xFF7C3AED)),
        ],
      ),
    );
  }

  Widget _kpiItem(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: slateDark, fontSize: 16, fontWeight: FontWeight.w900)),
          Text(title, style: const TextStyle(color: slateMuted, fontSize: 10.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(height: 36, width: 1, color: const Color(0xFFE2E8F0));
  }

  // ================= CUSTOMER CARD ITEM =================
  Widget _customerCard(Map<String, dynamic> cust) {
    final name = cust['name']?.toString() ?? 'Customer';
    final phone = cust['phone']?.toString() ?? 'N/A';
    final address = cust['address']?.toString() ?? 'N/A';
    final orderCount = (cust['order_count'] as int?) ?? 1;
    final totalSpent = (cust['total_spent'] as double?) ?? 0.0;
    final lastDateStr = cust['last_order_date']?.toString() ?? '';

    String badgeLabel = "NEW BUYER";
    Color badgeColor = const Color(0xFF2563EB);
    Color badgeBg = const Color(0xFFEFF6FF);

    if (orderCount >= 3) {
      badgeLabel = "VIP BUYER";
      badgeColor = const Color(0xFF7C3AED);
      badgeBg = const Color(0xFFF3E8FF);
    } else if (orderCount == 2) {
      badgeLabel = "REPEAT BUYER";
      badgeColor = const Color(0xFF10B981);
      badgeBg = const Color(0xFFECFDF5);
    }

    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';

    return InkWell(
      onTap: () => _showCustomerOrdersBottomSheet(cust),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorderColor, width: 1.2),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            // Avatar Circle
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sapphireLight,
                border: Border.all(color: sapphireBlue, width: 1.5),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(color: sapphireBlue, fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Info Body
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: slateDark, fontSize: 14.5, fontWeight: FontWeight.w900),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.phone_rounded, color: slateMuted, size: 12),
                      const SizedBox(width: 4),
                      Text(phone, style: const TextStyle(color: slateMuted, fontSize: 11.5, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      const Icon(Icons.shopping_bag_outlined, color: sapphireBlue, size: 12),
                      const SizedBox(width: 4),
                      Text("$orderCount Orders", style: const TextStyle(color: sapphireBlue, fontSize: 11.5, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: slateMuted, size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: slateMuted, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Spend & Arrow
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "Rs. ${totalSpent.toStringAsFixed(0)}",
                  style: const TextStyle(color: slateDark, fontSize: 14, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  lastDateStr.length >= 10 ? "Last: ${lastDateStr.substring(0, 10)}" : "Total Spent",
                  style: const TextStyle(color: slateMuted, fontSize: 9.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================= CUSTOMER ORDERS BOTTOM SHEET =================
  void _showCustomerOrdersBottomSheet(Map<String, dynamic> cust) {
    final name = cust['name']?.toString() ?? 'Customer';
    final ordersList = (cust['orders'] as List?) ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$name's Order History", style: const TextStyle(color: slateDark, fontSize: 17, fontWeight: FontWeight.w900)),
                    Text("${ordersList.length} past orders placed with your store", style: const TextStyle(color: slateMuted, fontSize: 11.5)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded, color: slateMuted), onPressed: () => Navigator.pop(ctx)),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            Expanded(
              child: ListView.separated(
                itemCount: ordersList.length,
                separatorBuilder: (c, i) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final ord = ordersList[idx];
                  final orderId = ord['id']?.toString() ?? '';
                  final amt = (ord['total_amount'] as num?)?.toDouble() ?? 0.0;
                  final status = ord['status']?.toString() ?? 'Processing';
                  final dt = ord['created_at']?.toString() ?? '';

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("#${orderId.length > 8 ? orderId.substring(0, 8) : orderId}", style: const TextStyle(color: slateDark, fontSize: 12.5, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 2),
                            Text(dt.length > 10 ? dt.substring(0, 10) : dt, style: const TextStyle(color: slateMuted, fontSize: 11)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("Rs. ${amt.toStringAsFixed(0)}", style: const TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(color: sapphireLight, borderRadius: BorderRadius.circular(4)),
                              child: Text(status.toUpperCase(), style: const TextStyle(color: sapphireBlue, fontSize: 8.5, fontWeight: FontWeight.w900)),
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

  Widget _buildEmptyCustomersView() {
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
          Icon(Icons.people_outline_rounded, size: 48, color: slateMuted),
          SizedBox(height: 12),
          Text("No Customer Accounts Found", style: TextStyle(color: slateDark, fontSize: 16, fontWeight: FontWeight.w900)),
          SizedBox(height: 4),
          Text("As customers place orders, their profiles and spend statistics will appear here.", style: TextStyle(color: slateMuted, fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }

}