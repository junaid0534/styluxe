import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellerHomeScreen extends StatefulWidget {
  const SellerHomeScreen({super.key});

  @override
  State<SellerHomeScreen> createState() => _SellerHomeScreenState();
}

class _SellerHomeScreenState extends State<SellerHomeScreen> {
  final String sellerName = "Muhammad Junaid";
  final String sellerEmail = "mrj25346@gmail.com";

  final supabase = Supabase.instance.client;

  String? profileImageUrl;

  double todaysRevenue = 0.0;

  int totalProducts = 0;
  int activeOrdersCount = 0;
  int totalCustomers = 0;
  bool isLoading = true;

  static const Color primaryGreen = Color(0xFFA8E063);
  static const Color darkText = Color(0xFF111827);
  static const Color mutedText = Color(0xFF6B7280);
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color bgColor = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    fetchDashboardData();
  }

  // ================= FETCH DASHBOARD DATA =================
  Future<void> fetchDashboardData() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception("User not logged in");
      }

      final sellerId = currentUser.id;

      // ================= TOTAL PRODUCTS =================
      final productResponse = await supabase
          .from('products')
          .select('id')
          .eq('seller_id', sellerId);

      // ================= ACTIVE ORDERS =================
      final activeResponse = await supabase
          .from('orders')
          .select('id')
          .eq('seller_id', sellerId)
          .inFilter('status', [
        'Pending',
        'Processing',
        'Shipped',
      ]);

      // ================= TOTAL CUSTOMERS =================
      final customersResponse = await supabase
          .from('orders')
          .select('user_id')
          .eq('seller_id', sellerId);

      final uniqueCustomers = <String>{};

      for (final item in customersResponse) {
        final customerId = item['user_id']?.toString();
        if (customerId != null && customerId.trim().isNotEmpty) {
          uniqueCustomers.add(customerId);
        }
      }

      // ================= TODAY'S REVENUE =================
      final now = DateTime.now();

      final startOfToday = DateTime(
        now.year,
        now.month,
        now.day,
      );

      final endOfToday = startOfToday.add(
        const Duration(days: 1),
      );

      final revenueResponse = await supabase
          .from('orders')
          .select('total_amount')
          .eq('seller_id', sellerId)
          .gte('created_at', startOfToday.toUtc().toIso8601String())
          .lt('created_at', endOfToday.toUtc().toIso8601String());

      if (!mounted) return;

      setState(() {
        totalProducts = productResponse.length;
        activeOrdersCount = activeResponse.length;
        totalCustomers = uniqueCustomers.length;

        todaysRevenue = revenueResponse.fold(0.0, (sum, order) {
          final amount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
          return sum + amount;
        });

        isLoading = false;
      });
    } catch (e) {
      debugPrint("Dashboard Error: $e");

      if (!mounted) return;

      setState(() {
        totalProducts = 0;
        activeOrdersCount = 0;
        totalCustomers = 0;
        todaysRevenue = 0.0;
        isLoading = false;
      });
    }
  }

  // ================= BUILD UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      backgroundColor: bgColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            final bool isMobile = width < 650;
            final bool isTablet = width >= 650 && width < 1100;

            int statsGrid = 2;
            int actionsGrid = 2;

            if (width >= 1200) {
              statsGrid = 4;
              actionsGrid = 4;
            } else if (width >= 850) {
              statsGrid = 2;
              actionsGrid = 4;
            } else {
              statsGrid = 2;
              actionsGrid = 2;
            }

            return RefreshIndicator(
              onRefresh: fetchDashboardData,
              color: const Color(0xFF22C55E),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // ================= APP BAR =================
                  SliverAppBar(
                    backgroundColor: primaryGreen,
                    surfaceTintColor: primaryGreen,
                    elevation: 0,
                    floating: true,
                    snap: true,
                    toolbarHeight: kToolbarHeight,
                    iconTheme: const IconThemeData(
                      color: darkText,
                    ),
                    title: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.32),
                            ),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: darkText,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "StyleSphere",
                          style: TextStyle(
                            color: darkText,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      IconButton(
                        tooltip: "Refresh",
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: darkText,
                        ),
                        onPressed: fetchDashboardData,
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                        ),
                        child: IconButton(
                          tooltip: "Notifications",
                          onPressed: () {},
                          icon: const Icon(
                            Icons.notifications_none_rounded,
                            color: darkText,
                            size: 25,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ================= MAIN CONTENT =================
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 28,
                      vertical: 18,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 1400,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ================= HERO HEADER =================
                              _buildHeroHeader(
                                width: width,
                                isMobile: isMobile,
                                isTablet: isTablet,
                              )
                                  .animate()
                                  .fadeIn(duration: 450.ms)
                                  .slideY(begin: 0.08),

                              const SizedBox(height: 24),

                              // ================= STATS =================
                              GridView.count(
                                crossAxisCount: statsGrid,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: width >= 1200
                                    ? 2.15
                                    : width >= 850
                                        ? 2.0
                                        : width >= 650
                                            ? 1.75
                                            : 1.28,
                                children: [
                                  _buildStatCard(
                                    title: "Total Products",
                                    value: isLoading
                                        ? "..."
                                        : totalProducts.toString(),
                                    icon: Icons.inventory_2_outlined,
                                    accentColor: const Color(0xFF2563EB),
                                    bgTint: const Color(0xFFEFF6FF),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/active_orders',
                                      );
                                    },
                                    child: _buildStatCard(
                                      title: "Active Orders",
                                      value: isLoading
                                          ? "..."
                                          : activeOrdersCount.toString(),
                                      icon: Icons.shopping_bag_outlined,
                                      accentColor: const Color(0xFF7C3AED),
                                      bgTint: const Color(0xFFF5F3FF),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/seller_revenue',
                                      );
                                    },
                                    child: _buildStatCard(
                                      title: "Today's Revenue",
                                      value: isLoading
                                          ? "..."
                                          : "PKR ${todaysRevenue.toStringAsFixed(0)}",
                                      icon: Icons.payments_rounded,
                                      accentColor: const Color(0xFF16A34A),
                                      bgTint: const Color(0xFFF0FDF4),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/total_customers',
                                      );
                                    },
                                    child: _buildStatCard(
                                      title: "Total Customers",
                                      value: isLoading
                                          ? "..."
                                          : totalCustomers.toString(),
                                      icon: Icons.people_outline,
                                      accentColor: const Color(0xFF0891B2),
                                      bgTint: const Color(0xFFECFEFF),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 32),

                              // ================= QUICK ACTIONS =================
                              _sectionTitle(
                                title: "Quick Actions",
                                subtitle: "Manage your store faster",
                              ),

                              const SizedBox(height: 16),

                              GridView.count(
                                crossAxisCount: actionsGrid,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: width >= 1200
                                    ? 1.75
                                    : width >= 850
                                        ? 1.55
                                        : width >= 650
                                            ? 1.48
                                            : 1.05,
                                children: [
                                  _buildQuickAction(
                                    title: "Add Product",
                                    subtitle: "Create listing",
                                    icon: Icons.add_circle_outline,
                                    accentColor: const Color(0xFF16A34A),
                                    bgTint: const Color(0xFFF0FDF4),
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/select_category',
                                      );
                                    },
                                  ),
                                  _buildQuickAction(
                                    title: "All Orders",
                                    subtitle: "View all sales",
                                    icon: Icons.list_alt_outlined,
                                    accentColor: const Color(0xFF4F46E5),
                                    bgTint: const Color(0xFFF5F3FF),
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/seller_all_orders',
                                      );
                                    },
                                  ),
                                  _buildQuickAction(
                                    title: "Manage Store",
                                    subtitle: "Store settings",
                                    icon: Icons.store_outlined,
                                    accentColor: const Color(0xFFDB2777),
                                    bgTint: const Color(0xFFFDF2F8),
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/manage_store',
                                      );
                                    },
                                  ),
                                  _buildQuickAction(
                                    title: "My Products",
                                    subtitle: "Edit inventory",
                                    icon: Icons.inventory_outlined,
                                    accentColor: const Color(0xFF0891B2),
                                    bgTint: const Color(0xFFECFEFF),
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/my_products',
                                      );
                                    },
                                  ),
                                ],
                              ),

                              const SizedBox(height: 32),

                              // ================= RECENT ACTIVITY =================
                              _sectionTitle(
                                title: "Recent Activity",
                                subtitle: "Latest order updates",
                              ),

                              const SizedBox(height: 16),

                              _buildRecentActivity(
                                orderId: "Order #3924",
                                item: "Black Hoodie × 2",
                                amount: "PKR 3,298",
                                status: "Pending",
                                accentColor: const Color(0xFF4F46E5),
                                bgTint: const Color(0xFFF5F3FF),
                              )
                                  .animate()
                                  .fadeIn(delay: 250.ms)
                                  .slideX(begin: -0.04),

                              _buildRecentActivity(
                                orderId: "Order #3921",
                                item: "Denim Jacket",
                                amount: "PKR 2,499",
                                status: "Shipped",
                                accentColor: const Color(0xFF0891B2),
                                bgTint: const Color(0xFFECFEFF),
                              )
                                  .animate()
                                  .fadeIn(delay: 330.ms)
                                  .slideX(begin: -0.04),

                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ================= HERO HEADER =================
  Widget _buildHeroHeader({
    required double width,
    required bool isMobile,
    required bool isTablet,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF111827),
            Color(0xFF1F2937),
            Color(0xFF374151),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heroText(isMobile: isMobile),
                const SizedBox(height: 20),
                _heroProfileBox(),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: _heroText(isMobile: isMobile),
                ),
                const SizedBox(width: 20),
                _heroProfileBox(),
              ],
            ),
    );
  }

  Widget _heroText({required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Welcome back, $sellerName 👋",
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 26 : 34,
            fontWeight: FontWeight.w900,
            height: 1.22,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Track your products, orders, revenue, and customers from one clean dashboard.",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: isMobile ? 14.2 : 15.5,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_rounded,
                color: primaryGreen,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                "Verified Seller Dashboard",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroProfileBox() {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 29,
            backgroundColor: Colors.white,
            backgroundImage:
                profileImageUrl != null ? NetworkImage(profileImageUrl!) : null,
            child: profileImageUrl == null
                ? const Icon(
                    Icons.person,
                    size: 34,
                    color: darkText,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sellerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sellerEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= SECTION TITLE =================
  Widget _sectionTitle({
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: darkText,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: mutedText,
                  fontSize: 14.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn().slideY(begin: 0.06);
  }

  // ================= DRAWER =================
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // ================= HEADER =================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Color(0xFF111827),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 42,
                            backgroundColor: Colors.white,
                            backgroundImage: profileImageUrl != null
                                ? NetworkImage(profileImageUrl!)
                                : null,
                            child: profileImageUrl == null
                                ? const Icon(
                                    Icons.person,
                                    size: 48,
                                    color: darkText,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 15),
                          Text(
                            sellerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sellerEmail,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    _drawerTile(
                      Icons.person_outline,
                      "Edit Profile",
                      () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/seller_edit_profile').then((value) {
                          if (value == true) {
                            fetchDashboardData();
                         }
                      });
                      },
                      const Color(0xFF4F46E5),
                      const Color(0xFFF5F3FF),
                    ),
                    _drawerTile(
                      Icons.store_outlined,
                      "My Store",
                      () {},
                      const Color(0xFF0891B2),
                      const Color(0xFFECFEFF),
                    ),
                    _drawerTile(
                      Icons.analytics_outlined,
                      "Analytics",
                      () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/seller_analytics');
                      },
                      const Color(0xFF16A34A),
                      const Color(0xFFF0FDF4),
                    ),
                    _drawerTile(
                      Icons.inventory_2_outlined,
                      "Products",
                      () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/my_products');
                      },
                      const Color(0xFF2563EB),
                      const Color(0xFFEFF6FF),
                    ),
                    _drawerTile(
                      Icons.shopping_bag_outlined,
                      "Orders",
                      () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/seller_all_orders');
                      },
                      const Color(0xFFF59E0B),
                      const Color(0xFFFFFBEB),
                    ),
                    _drawerTile(
                      Icons.people_outline,
                      "Customers",
                      () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/total_customers');
                      },
                      const Color(0xFFDB2777),
                      const Color(0xFFFDF2F8),
                    ),
                    _drawerTile(
                      Icons.campaign_outlined,
                      "Promotions",
                      () {},
                      const Color(0xFF7C3AED),
                      const Color(0xFFF5F3FF),
                    ),
                    _drawerTile(
                      Icons.settings_outlined,
                      "Settings",
                      () {},
                      const Color(0xFF64748B),
                      const Color(0xFFF1F5F9),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                tileColor: const Color(0xFFFEF2F2),
                leading: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFEF4444),
                ),
                title: const Text(
                  "Logout",
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                onTap: () async {
                  try {
                    await supabase.auth.signOut();

                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (route) => false,
                      );
                    }
                  } catch (e) {
                    debugPrint("Logout Error: $e");

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Logout Failed: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile(
    IconData icon,
    String title,
    VoidCallback onTap,
    Color accentColor,
    Color bgTint,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(
            color: borderColor,
          ),
        ),
        tileColor: Colors.white,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bgTint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: accentColor,
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: darkText,
            fontWeight: FontWeight.w800,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: Colors.grey.shade500,
        ),
        onTap: onTap,
      ),
    );
  }

  // ================= STAT CARD =================
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required Color bgTint,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -22,
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: bgTint.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: bgTint,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.12),
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: accentColor,
                    size: 25,
                  ),
                ),
              ),

              const SizedBox(width: 13),

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
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: mutedText,
                        fontSize: 13,
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
    ).animate().fadeIn().slideY(begin: 0.10);
  }

  // ================= QUICK ACTION =================
  Widget _buildQuickAction({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color bgTint,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: borderColor,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -22,
              child: Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: bgTint.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: bgTint,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 27,
                    color: accentColor,
                  ),
                ),

                const Spacer(),

                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: darkText,
                    fontWeight: FontWeight.w900,
                    fontSize: 16.2,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: mutedText,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: accentColor,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn().scale(delay: 100.ms);
  }

  // ================= RECENT ACTIVITY =================
  Widget _buildRecentActivity({
    required String orderId,
    required String item,
    required String amount,
    required String status,
    required Color accentColor,
    required Color bgTint,
  }) {
    final bool isPending = status == "Pending";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgTint,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.12),
              ),
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              color: accentColor,
              size: 26,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orderId,
                  style: const TextStyle(
                    color: darkText,
                    fontWeight: FontWeight.w900,
                    fontSize: 15.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: mutedText,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: const TextStyle(
                  color: darkText,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isPending
                      ? const Color(0xFFFFFBEB)
                      : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isPending
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFFBBF7D0),
                  ),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: isPending
                        ? const Color(0xFFD97706)
                        : const Color(0xFF16A34A),
                    fontSize: 12.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}