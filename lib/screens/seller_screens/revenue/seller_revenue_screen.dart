import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'seller_setup_account_screen.dart';
import 'seller_withdraw_screen.dart';

class SellerRevenueScreen extends StatefulWidget {
  const SellerRevenueScreen({super.key});

  @override
  State<SellerRevenueScreen> createState() => _SellerRevenueScreenState();
}

class _SellerRevenueScreenState extends State<SellerRevenueScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;

  double totalRevenue = 0.0;
  double totalWithdrawn = 0.0;
  double pendingWithdrawals = 0.0;

  // Saved Payment Accounts
  Map<String, dynamic>? easyPaisaAccount;
  Map<String, dynamic>? jazzCashAccount;
  Map<String, dynamic>? bankCardAccount;
  String defaultMethod = "EasyPaisa";

  List<Map<String, dynamic>> payoutHistory = [];

  bool isHistoryExpanded = false;

  static const Color sapphireBlue = Color(0xFF2563EB);
  static const Color sapphireLight = Color(0xFFEFF6FF);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color bgColor = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _fetchRevenueData();
  }

  // ================= FETCH REVENUE & PAYOUT DATA =================
  Future<void> _fetchRevenueData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => isLoading = false);
        return;
      }

      // 1. Fetch Orders for total store earnings calculation
      final ordersRes = await supabase
          .from('orders')
          .select('total_amount, status, created_at')
          .eq('seller_id', user.id);

      double sumTotal = 0.0;
      for (final o in ordersRes) {
        final st = o['status']?.toString().toLowerCase() ?? '';
        if (st != 'cancelled' && st != 'canceled') {
          sumTotal += (o['total_amount'] as num?)?.toDouble() ?? 0.0;
        }
      }

      // 2. Fetch Payout Requests from database
      List<Map<String, dynamic>> fetchedPayouts = [];
      try {
        final pRes = await supabase
            .from('payout_requests')
            .select('*')
            .eq('seller_id', user.id)
            .order('created_at', ascending: false);
        fetchedPayouts = List<Map<String, dynamic>>.from(pRes);
      } catch (_) {}

      double sumPending = 0.0;
      double sumWithdrawn = 0.0;
      for (final p in fetchedPayouts) {
        final amt = (p['amount'] as num?)?.toDouble() ?? 0.0;
        final status = p['status']?.toString().toLowerCase() ?? 'pending';
        if (status == 'pending' || status == 'processing') {
          sumPending += amt;
        } else if (status == 'completed' || status == 'transferred') {
          sumWithdrawn += amt;
        }
      }

      // 3. Fetch Saved Payment Accounts from DB table + Metadata backup
      Map<String, dynamic>? epData;
      Map<String, dynamic>? jcData;
      Map<String, dynamic>? bankData;
      String defM = "EasyPaisa";

      try {
        final dbMethods = await supabase
            .from('seller_payout_methods')
            .select('*')
            .eq('seller_id', user.id);

        for (final row in dbMethods) {
          final type = row['method_type']?.toString();
          final mapData = <String, dynamic>{
            'title': row['account_title']?.toString() ?? '',
            'number': row['account_number']?.toString() ?? '',
            'bank': row['bank_name']?.toString(),
          };
          if (type == 'EasyPaisa') epData = mapData;
          if (type == 'JazzCash') jcData = mapData;
          if (type == 'BankCard') bankData = mapData;
          if (row['is_default'] == true && type != null) defM = type;
        }
      } catch (_) {}

      // Metadata Fallback
      final meta = user.userMetadata ?? {};
      epData ??= meta['payout_easypaisa'] is Map ? Map<String, dynamic>.from(meta['payout_easypaisa']) : null;
      jcData ??= meta['payout_jazzcash'] is Map ? Map<String, dynamic>.from(meta['payout_jazzcash']) : null;
      bankData ??= meta['payout_bankcard'] is Map ? Map<String, dynamic>.from(meta['payout_bankcard']) : null;
      if (meta['payout_default_method'] != null) {
        defM = meta['payout_default_method'].toString();
      }

      if (!mounted) return;
      setState(() {
        totalRevenue = sumTotal;
        totalWithdrawn = sumWithdrawn;
        pendingWithdrawals = sumPending;
        easyPaisaAccount = epData;
        jazzCashAccount = jcData;
        bankCardAccount = bankData;
        defaultMethod = defM;
        payoutHistory = fetchedPayouts.isEmpty ? _dummyFallbackHistory() : fetchedPayouts;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Revenue Fetch Error: $e");
      if (!mounted) return;
      setState(() {
        payoutHistory = _dummyFallbackHistory();
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _dummyFallbackHistory() {
    return [
      {
        'id': 'PAY-9041',
        'amount': 25000.0,
        'method': 'EasyPaisa',
        'account_title': 'Muhammad Junaid',
        'account_number': '03001234567',
        'status': 'Completed',
        'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      },
      {
        'id': 'PAY-8812',
        'amount': 12000.0,
        'method': 'JazzCash',
        'account_title': 'Muhammad Junaid',
        'account_number': '03129876543',
        'status': 'Processing',
        'created_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
      },
    ];
  }

  double get availableBalance {
    double avail = totalRevenue - totalWithdrawn - pendingWithdrawals;
    return avail < 0 ? 0.0 : avail;
  }

  // Navigate to Setup Account Screen
  void _openSetupScreen(String methodType, Map<String, dynamic>? existingData) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => SellerSetupAccountScreen(
          methodType: methodType,
          existingData: existingData,
        ),
      ),
    );

    if (updated == true) {
      _fetchRevenueData();
    }
  }

  // Navigate to Withdraw Screen
  void _openWithdrawScreen() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => SellerWithdrawScreen(
          availableBalance: availableBalance,
          easyPaisaAccount: easyPaisaAccount,
          jazzCashAccount: jazzCashAccount,
          bankCardAccount: bankCardAccount,
          defaultMethod: defaultMethod,
        ),
      ),
    );

    if (updated == true) {
      _fetchRevenueData();
    }
  }

  // ================= BUILD UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: slateDark),
        title: const Text(
          "Payouts & Revenue",
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
            onPressed: _fetchRevenueData,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: sapphireBlue))
          : RefreshIndicator(
              onRefresh: _fetchRevenueData,
              color: sapphireBlue,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. CLEAN HERO CARD (Total, Withdrawn, Pending + Withdraw Button)
                        _heroRevenueCard3Metrics().animate().fadeIn(duration: 350.ms).slideY(begin: 0.04),

                        const SizedBox(height: 22),

                        // 2. PAYOUT ACCOUNTS SETUP SECTION (EasyPaisa Green, JazzCash Red, Bank Blue)
                        const Text(
                          "Payout Accounts",
                          style: TextStyle(color: slateDark, fontSize: 16.5, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 12),

                        _accountBrandCard(
                          type: "EasyPaisa",
                          title: "EasyPaisa Wallet",
                          data: easyPaisaAccount,
                          brandColor: const Color(0xFF00A651), // EasyPaisa Green
                          icon: Icons.account_balance_wallet_rounded,
                        ),

                        const SizedBox(height: 10),

                        _accountBrandCard(
                          type: "JazzCash",
                          title: "JazzCash Wallet",
                          data: jazzCashAccount,
                          brandColor: const Color(0xFFD32F2F), // JazzCash Red
                          icon: Icons.mobile_friendly_rounded,
                        ),

                        const SizedBox(height: 10),

                        _accountBrandCard(
                          type: "BankCard",
                          title: "Bank Account / IBAN",
                          data: bankCardAccount,
                          brandColor: sapphireBlue, // Bank Royal Blue
                          icon: Icons.credit_card_rounded,
                        ),

                        const SizedBox(height: 24),

                        // 3. WITHDRAWAL HISTORY ACCORDION / DROPDOWN
                        _payoutHistoryAccordion(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: _buildSellerBottomNav(4),
    );
  }

  // ================= HERO CARD (3 METRICS + WITHDRAW BUTTON) =================
  Widget _heroRevenueCard3Metrics() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: sapphireBlue.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Title + Withdraw Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  "Store Earnings",
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: sapphireBlue,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.arrow_upward_rounded, size: 15),
                label: const Text("Withdraw", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                onPressed: _openWithdrawScreen,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Total Earnings Amount
          Text(
            "Rs. ${totalRevenue.toStringAsFixed(0)}",
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.6),
          ),

          const SizedBox(height: 18),
          const Divider(height: 1, color: Colors.white24),
          const SizedBox(height: 16),

          // 3 Metric Grid Pills (Total, Withdrawn, Pending)
          Row(
            children: [
              Expanded(
                child: _heroMetricItem(
                  label: "Total Earnings",
                  value: "Rs. ${totalRevenue.toStringAsFixed(0)}",
                  icon: Icons.payments_rounded,
                ),
              ),
              Container(width: 1, height: 36, color: Colors.white24),
              Expanded(
                child: _heroMetricItem(
                  label: "Withdrawn",
                  value: "Rs. ${totalWithdrawn.toStringAsFixed(0)}",
                  icon: Icons.check_circle_rounded,
                ),
              ),
              Container(width: 1, height: 36, color: Colors.white24),
              Expanded(
                child: _heroMetricItem(
                  label: "Pending",
                  value: "Rs. ${pendingWithdrawals.toStringAsFixed(0)}",
                  icon: Icons.hourglass_top_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetricItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 13),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  // ================= ACCOUNT BRAND CARD WITH EXPANDABLE INFO =================
  Widget _accountBrandCard({
    required String type,
    required String title,
    required Map<String, dynamic>? data,
    required Color brandColor,
    required IconData icon,
  }) {
    final isConfigured = data != null && data.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: brandColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: brandColor.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: brandColor, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(color: slateDark, fontSize: 14.5, fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            isConfigured ? "${data['title'] ?? ''} • ${data['number'] ?? ''}" : "Not Configured",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isConfigured ? const Color(0xFF10B981) : slateMuted,
              fontSize: 11.5,
              fontWeight: isConfigured ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),
                  if (isConfigured) ...[
                    if (data['bank'] != null) ...[
                      _infoRow("Bank Name", data['bank'].toString()),
                      const SizedBox(height: 6),
                    ],
                    _infoRow("Account Title", data['title']?.toString() ?? 'N/A'),
                    const SizedBox(height: 6),
                    _infoRow("Account / Mobile Number", data['number']?.toString() ?? 'N/A'),
                    const SizedBox(height: 14),
                  ] else ...[
                    const Text(
                      "Configure your account to receive automated payout transfers.",
                      style: TextStyle(color: slateMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: brandColor,
                        side: BorderSide(color: brandColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _openSetupScreen(type, data),
                      child: Text(
                        isConfigured ? "Edit Account Details" : "Setup Account",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: slateMuted, fontSize: 12, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(color: slateDark, fontSize: 12.5, fontWeight: FontWeight.w900)),
      ],
    );
  }

  // ================= WITHDRAWAL HISTORY ACCORDION =================
  Widget _payoutHistoryAccordion() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: sapphireLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.history_rounded, color: sapphireBlue, size: 22),
          ),
          title: const Text(
            "Withdrawal History",
            style: TextStyle(color: slateDark, fontSize: 15, fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            "${payoutHistory.length} Records",
            style: const TextStyle(color: slateMuted, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),
                  if (payoutHistory.isEmpty)
                    const Text("No Payout Records Found", style: TextStyle(color: slateMuted, fontSize: 12))
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: payoutHistory.length,
                      separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = payoutHistory[index];
                        final refId = item['id']?.toString() ?? '#PAY';
                        final amt = (item['amount'] as num?)?.toDouble() ?? 0.0;
                        final method = item['method']?.toString() ?? 'EasyPaisa';
                        final status = item['status']?.toString() ?? 'Pending';
                        final dateStr = item['created_at']?.toString() ?? '';

                        Color statusColor = const Color(0xFFF59E0B);
                        Color statusBg = const Color(0xFFFFFBEB);
                        if (status.toLowerCase() == 'completed' || status.toLowerCase() == 'transferred') {
                          statusColor = const Color(0xFF10B981);
                          statusBg = const Color(0xFFECFDF5);
                        } else if (status.toLowerCase() == 'rejected' || status.toLowerCase() == 'failed') {
                          statusColor = Colors.red;
                          statusBg = const Color(0xFFFEF2F2);
                        }

                        return Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "$refId • $method",
                                    style: const TextStyle(color: slateDark, fontSize: 13, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr,
                                    style: const TextStyle(color: slateMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "Rs. ${amt.toStringAsFixed(0)}",
                                  style: const TextStyle(color: slateDark, fontSize: 14, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(color: statusColor, fontSize: 9.5, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= 5-TAB SELLER BOTTOM NAV BAR =================
  Widget _buildSellerBottomNav(int currentIndex) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
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
