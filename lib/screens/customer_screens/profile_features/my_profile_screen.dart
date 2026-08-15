import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../theme/app_theme.dart';

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
      await supabase.auth.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
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
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          "My Profile",
          style: TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: fetchProfileData,
              color: AppColors.primary,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 850),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ================= 1. HERO GRADIENT PROFILE CARD =================
                        _gradientProfileCard().animate().fadeIn(duration: 350.ms).slideY(begin: 0.06, end: 0),

                    const SizedBox(height: 16),

                    // ================= 2. QUICK STATS ROW =================
                    _quickStatsBar().animate().fadeIn(delay: 100.ms, duration: 350.ms),

                    const SizedBox(height: 24),

                    // ================= 3. ACCOUNT SETTINGS =================
                    _sectionHeader("ACCOUNT SETTINGS"),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _profileRowItem(
                            icon: Icons.receipt_long_outlined,
                            iconBg: const Color(0xFFEFF6FF),
                            iconColor: const Color(0xFF3B82F6),
                            title: "My Orders",
                            subtitle: "$ordersCount orders placed",
                            badgeText: ordersCount > 0 ? "$ordersCount" : null,
                            onTap: () => Navigator.pushNamed(context, '/my_orders'),
                          ),
                          const _DividerLine(),
                          _profileRowItem(
                            icon: Icons.person_outline_rounded,
                            iconBg: const Color(0xFFF0FDF4),
                            iconColor: const Color(0xFF10B981),
                            title: "Edit Profile",
                            subtitle: "Name, email & phone",
                            onTap: () => Navigator.pushNamed(context, '/edit_profile'),
                          ),
                          const _DividerLine(),
                          _profileRowItem(
                            icon: Icons.local_shipping_outlined,
                            iconBg: const Color(0xFFF5F3FF),
                            iconColor: const Color(0xFF8B5CF6),
                            title: "Shipping Addresses",
                            subtitle: "Manage delivery locations",
                            onTap: () => Navigator.pushNamed(context, '/shipping_addresses'),
                          ),
                          const _DividerLine(),
                          _profileRowItem(
                            icon: Icons.favorite_border_rounded,
                            iconBg: const Color(0xFFFFF1F2),
                            iconColor: const Color(0xFFF43F5E),
                            title: "Wishlist",
                            subtitle: "$wishlistCount items saved",
                            onTap: () => Navigator.pushNamed(context, '/wishlist'),
                          ),
                          const _DividerLine(),
                          _profileRowItem(
                            icon: Icons.notifications_none_rounded,
                            iconBg: const Color(0xFFFFFBEB),
                            iconColor: const Color(0xFFF59E0B),
                            title: "Notifications",
                            subtitle: "Offers & order updates",
                            onTap: () => Navigator.pushNamed(context, '/notifications'),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 180.ms, duration: 350.ms),

                    const SizedBox(height: 24),

                    // ================= 4. SECURITY & SUPPORT =================
                    _sectionHeader("SECURITY & SUPPORT"),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _profileRowItem(
                            icon: Icons.lock_outline_rounded,
                            iconBg: const Color(0xFFECFDF5),
                            iconColor: const Color(0xFF059669),
                            arrowColor: const Color(0xFF10B981),
                            title: "Change Password",
                            subtitle: "Security & auth settings",
                            onTap: () => Navigator.pushNamed(context, '/change_password'),
                          ),
                          const _DividerLine(),
                          _profileRowItem(
                            icon: Icons.help_outline_rounded,
                            iconBg: const Color(0xFFECFDF5),
                            iconColor: const Color(0xFF059669),
                            arrowColor: const Color(0xFF10B981),
                            title: "Help & Support",
                            subtitle: "FAQs, contact & live help",
                            onTap: () => Navigator.pushNamed(context, '/help_support'),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 260.ms, duration: 350.ms),

                    const SizedBox(height: 28),

                    // ================= 5. LOGOUT BUTTON =================
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFECDD3)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFBE123C).withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: logout,
                        borderRadius: BorderRadius.circular(16),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.output_rounded, color: Color(0xFFBE123C), size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Logout",
                              style: TextStyle(
                                color: Color(0xFFBE123C),
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 320.ms, duration: 350.ms),

                    const SizedBox(height: 24),

                    // ================= FOOTER VERSION =================
                    Center(
                      child: Column(
                        children: [
                          Text(
                            "StyLuxe Fashion Store v2.4.0",
                            style: TextStyle(
                              color: AppColors.slateMuted.withValues(alpha: 0.70),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Designed with Elegance & Excellence",
                            style: TextStyle(
                              color: AppColors.slateMuted.withValues(alpha: 0.50),
                              fontSize: 11,
                            ),
                          ),
                        ],
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

  // ================= 1. GRADIENT PROFILE CARD =================
  Widget _gradientProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF10B981), // Emerald Teal
            Color(0xFF34D399), // Mint Accent
            Color(0xFFE0F2FE), // Soft Icy Sky Blue
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with Verified Badge
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: const Color(0xFFF1F5F9),
                  backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                      ? NetworkImage(avatarUrl!)
                      : null,
                  child: avatarUrl == null || avatarUrl!.isEmpty
                      ? Text(
                          _getInitials(),
                          style: const TextStyle(
                            color: Color(0xFF006837),
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Customer Name
          Text(
            userName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 3),

          // Email Address
          Text(
            userEmail,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Verified Customer Chip Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, color: Color(0xFF10B981), size: 16),
                SizedBox(width: 6),
                Text(
                  "Verified Customer",
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= 2. QUICK STATS BAR =================
  Widget _quickStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _quickStatItem(
            icon: Icons.local_mall_outlined,
            label: "Orders",
            value: "$ordersCount",
            onTap: () => Navigator.pushNamed(context, '/my_orders'),
          ),
          Container(height: 28, width: 1, color: const Color(0xFFE2E8F0)),
          _quickStatItem(
            icon: Icons.favorite_border_rounded,
            label: "Wishlist",
            value: "$wishlistCount",
            onTap: () => Navigator.pushNamed(context, '/wishlist'),
          ),
          Container(height: 28, width: 1, color: const Color(0xFFE2E8F0)),
          _quickStatItem(
            icon: Icons.workspace_premium_outlined,
            label: "Member",
            value: "VIP Gold",
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _quickStatItem({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.slateDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.slateMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= SECTION HEADER =================
  Widget _sectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ================= ROW ITEM =================
  Widget _profileRowItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    Color arrowColor = const Color(0xFFCBD5E1),
    required String title,
    String? subtitle,
    String? badgeText,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeText != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.chevron_right_rounded,
              color: arrowColor,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ================= FULL WIDTH BOTTOM NAV BAR =================
  Widget _buildFullWidthBottomNav(int activeIndex) {
    return Container(
      height: 64,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppColors.primary : AppColors.slateMuted,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12.5,
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

// ================= DIVIDER LINE =================
class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      endIndent: 16,
      color: Color(0xFFF1F5F9),
    );
  }
}