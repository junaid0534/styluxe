import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/customer_shimmer_loading.dart';
import '../../../services/session_service.dart';
import '../../chat/inbox_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final supabase = Supabase.instance.client;

  String userName = "Muhammad Junaid";
  String userEmail = "mj300843@gmail.com";
  String? avatarUrl;
  bool isLoading = true;

  int ordersCount = 0;
  int wishlistCount = 0;

  @override
  void initState() {
    super.initState();
    fetchProfileData();
  }

  Future<void> fetchProfileData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final user = supabase.auth.currentUser;

      if (user != null) {
        final metaName = user.userMetadata?['name']?.toString();
        final metaAvatar = user.userMetadata?['avatar_url']?.toString();

        userName = (metaName != null && metaName.trim().isNotEmpty)
            ? metaName.trim()
            : user.email?.split('@')[0] ?? "Muhammad Junaid";

        userEmail = user.email ?? "mj300843@gmail.com";
        avatarUrl = metaAvatar;

        // Fetch counts for quick stats bar
        final ordersRes = await supabase
            .from('orders')
            .select('id')
            .eq('user_id', user.id);
        final wishlistRes = await supabase
            .from('wishlist')
            .select('id')
            .eq('user_id', user.id);

        if (mounted) {
          ordersCount = (ordersRes as List).length;
          wishlistCount = (wishlistRes as List).length;
        }
      }
    } catch (e) {
      debugPrint("Profile fetch error: $e");
    }

    if (!mounted) return;
    setState(() => isLoading = false);
  }

  Future<void> logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.output_rounded, color: AppColors.roseRed, size: 22),
            SizedBox(width: 8),
            Text(
              "Logout",
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          "Are you sure you want to sign out of your StyLuxe account?",
          style: TextStyle(color: AppColors.slateMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: AppColors.slateMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.roseRed,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Logout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SessionService.clearSession();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Logout error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getInitials() {
    final cleanName = userName.trim();
    if (cleanName.isEmpty) return "J";
    final parts = cleanName.split(" ");
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return "${parts.first[0]}${parts.last[0]}".toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      // ================= APP BAR =================
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        toolbarHeight: 46.0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          "My Profile",
          style: TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 16.5,
          ),
        ),
      ),

      body: isLoading
          ? const CustomerProfileShimmer()
          : RefreshIndicator(
              onRefresh: fetchProfileData,
              color: AppColors.primary,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                    child: Column(
                      children: [
                        // ================= 1. CLEAN PROFILE HEADER =================
                        _buildProfileHeader().animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0),

                        const SizedBox(height: 16),

                        // ================= 2. 3 QUICK STAT METRIC CARDS =================
                        _buildQuickStatCards().animate().fadeIn(delay: 80.ms, duration: 350.ms),

                        const SizedBox(height: 20),

                        // ================= 3. NAVIGATION MENU LIST =================
                        _buildMenuSection().animate().fadeIn(delay: 150.ms, duration: 350.ms),

                        const SizedBox(height: 22),

                        // ================= 4. COMPACT LOGOUT PILL BUTTON =================
                        _buildLogoutButton().animate().fadeIn(delay: 220.ms, duration: 350.ms),

                        const SizedBox(height: 18),

                        // ================= 5. FOOTER =================
                        Center(
                          child: Text(
                            "StyLuxe v2.4.0 • Luxury & Lifestyle",
                            style: TextStyle(
                              color: AppColors.slateMuted.withValues(alpha: 0.6),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: _buildFullWidthBottomNav(4),
    );
  }

  // ================= 1. CLEAN PROFILE HEADER (APP GREEN) =================
  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Circular Avatar with Camera/Edit Badge
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: const Color(0xFFF1F5F9),
                  backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                      ? NetworkImage(avatarUrl!)
                      : null,
                  child: avatarUrl == null || avatarUrl!.isEmpty
                      ? Text(
                          _getInitials(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: () => Navigator.pushNamed(context, '/edit_profile'),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppColors.slateDark,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // User Name
          Text(
            userName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 2),

          // User Email
          Text(
            userEmail,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 10),

          // VIP Gold Member Badge Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium_rounded, color: Color(0xFFFDE68A), size: 13),
                SizedBox(width: 4),
                Text(
                  "VIP GOLD MEMBER",
                  style: TextStyle(
                    color: Colors.white,
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
    );
  }

  // ================= 2. 3 QUICK STAT METRIC CARDS =================
  Widget _buildQuickStatCards() {
    return Row(
      children: [
        Expanded(
          child: _statPillCard(
            icon: Icons.shopping_bag_outlined,
            iconColor: const Color(0xFF10B981),
            iconBg: const Color(0xFFECFDF5),
            value: "$ordersCount",
            label: "Orders",
            onTap: () => Navigator.pushNamed(context, '/my_orders'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statPillCard(
            icon: Icons.favorite_border_rounded,
            iconColor: const Color(0xFFF43F5E),
            iconBg: const Color(0xFFFFF1F2),
            value: "$wishlistCount",
            label: "Wishlist",
            onTap: () => Navigator.pushNamed(context, '/wishlist'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statPillCard(
            icon: Icons.confirmation_number_outlined,
            iconColor: const Color(0xFF3B82F6),
            iconBg: const Color(0xFFEFF6FF),
            value: "5",
            label: "Coupons",
            onTap: () => Navigator.pushNamed(context, '/my_orders'),
          ),
        ),
      ],
    );
  }

  Widget _statPillCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String value,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 14),
                ),
                const SizedBox(width: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slateDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.slateMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= 3. NAVIGATION MENU LIST =================
  // ================= 3. NAVIGATION MENU LIST (SEPARATE PILL CARDS) =================
  Widget _buildMenuSection() {
    return Column(
      children: [
        _menuTile(
          icon: Icons.shopping_bag_outlined,
          title: "My Orders & Order History",
          badge: ordersCount > 0 ? "$ordersCount" : null,
          onTap: () => Navigator.pushNamed(context, '/my_orders'),
        ),
        const SizedBox(height: 8),
        _menuTile(
          icon: Icons.location_on_outlined,
          title: "Shipping Addresses",
          onTap: () => Navigator.pushNamed(context, '/shipping_addresses'),
        ),
        const SizedBox(height: 8),
        _menuTile(
          icon: Icons.credit_card_outlined,
          title: "Payment Methods & Cards",
          onTap: () => Navigator.pushNamed(context, '/shipping_addresses'),
        ),
        const SizedBox(height: 8),
        _menuTile(
          icon: Icons.favorite_border_rounded,
          title: "My Wishlist & Favorites",
          badge: wishlistCount > 0 ? "$wishlistCount" : null,
          onTap: () => Navigator.pushNamed(context, '/wishlist'),
        ),
        const SizedBox(height: 8),
        _menuTile(
          icon: Icons.forum_outlined,
          title: "Chat with Sellers",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InboxScreen(isCustomer: true)),
            );
          },
        ),
        const SizedBox(height: 8),
        _menuTile(
          icon: Icons.notifications_none_rounded,
          title: "Notifications & Alerts",
          onTap: () => Navigator.pushNamed(context, '/notifications'),
        ),
        const SizedBox(height: 8),
        _menuTile(
          icon: Icons.lock_outline_rounded,
          title: "Privacy & Security",
          onTap: () => Navigator.pushNamed(context, '/change_password'),
        ),
        const SizedBox(height: 8),
        _menuTile(
          icon: Icons.headset_mic_outlined,
          title: "Help & Customer Support",
          onTap: () => Navigator.pushNamed(context, '/help_support'),
        ),
      ],
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    String? badge,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Icon(icon, size: 16, color: AppColors.slateDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slateDark,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= 4. COMPACT LOGOUT PILL BUTTON =================
  Widget _buildLogoutButton() {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: logout,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.slateDark,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.logout_rounded, size: 16, color: Colors.white),
            SizedBox(width: 6),
            Text(
              "Logout",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= FULL WIDTH BOTTOM NAV BAR =================
  Widget _buildFullWidthBottomNav(int activeIndex) {
    return Container(
      height: 48,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, -2),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.primary : AppColors.slateMuted,
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11.5,
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