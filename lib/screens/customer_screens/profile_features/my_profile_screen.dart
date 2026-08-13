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
      }
    } catch (e) {
      debugPrint("Profile fetch error: $e");
    }

    if (!mounted) return;
    setState(() => isLoading = false);
  }

  Future<void> logout() async {
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
        titleSpacing: 20,
        automaticallyImplyLeading: false,
        title: const Text(
          "StyLuxe",
          style: TextStyle(
            color: Color(0xFF006837),
            fontWeight: FontWeight.w900,
            fontSize: 24,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Color(0xFF0F172A), size: 22),
            onPressed: () => Navigator.pushNamed(context, '/shop_now'),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: fetchProfileData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================= 1. GRADIENT PROFILE CARD =================
                    _gradientProfileCard().animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0),

                    const SizedBox(height: 24),

                    // ================= 2. ACCOUNT SETTINGS =================
                    _sectionHeader("ACCOUNT SETTINGS"),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.025),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _profileRowItem(
                            icon: Icons.person_outline_rounded,
                            iconBg: const Color(0xFFF0F5FF),
                            iconColor: const Color(0xFF4F46E5),
                            title: "Edit Profile",
                            onTap: () => Navigator.pushNamed(context, '/edit_profile'),
                          ),
                          const _DividerLine(),
                          _profileRowItem(
                            icon: Icons.local_shipping_outlined,
                            iconBg: const Color(0xFFF0F5FF),
                            iconColor: const Color(0xFF4F46E5),
                            title: "Shipping Addresses",
                            onTap: () => Navigator.pushNamed(context, '/shipping_addresses'),
                          ),
                          const _DividerLine(),
                          _profileRowItem(
                            icon: Icons.favorite_border_rounded,
                            iconBg: const Color(0xFFF0F5FF),
                            iconColor: const Color(0xFF4F46E5),
                            title: "Wishlist",
                            onTap: () => Navigator.pushNamed(context, '/wishlist'),
                          ),
                          const _DividerLine(),
                          _profileRowItem(
                            icon: Icons.notifications_none_rounded,
                            iconBg: const Color(0xFFF0F5FF),
                            iconColor: const Color(0xFF4F46E5),
                            title: "Notifications",
                            onTap: () => Navigator.pushNamed(context, '/notifications'),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 150.ms, duration: 350.ms),

                    const SizedBox(height: 24),

                    // ================= 3. SECURITY & SUPPORT =================
                    _sectionHeader("SECURITY & SUPPORT"),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.025),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _profileRowItem(
                            icon: Icons.lock_outline_rounded,
                            iconBg: const Color(0xFFE6F4EA),
                            iconColor: const Color(0xFF10B981),
                            arrowColor: const Color(0xFF10B981),
                            title: "Change Password",
                            onTap: () => Navigator.pushNamed(context, '/change_password'),
                          ),
                          const _DividerLine(),
                          _profileRowItem(
                            icon: Icons.help_outline_rounded,
                            iconBg: const Color(0xFFE6F4EA),
                            iconColor: const Color(0xFF10B981),
                            arrowColor: const Color(0xFF10B981),
                            title: "Help & Support",
                            onTap: () => Navigator.pushNamed(context, '/help_support'),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 250.ms, duration: 350.ms),

                    const SizedBox(height: 28),

                    // ================= 4. LOGOUT BUTTON =================
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(16),
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
                  ],
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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF10B981), // Emerald Teal
            Color(0xFF6EE7B7), // Light Mint
            Color(0xFFE0F2FE), // Soft Icy Blue
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with Verified Badge
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(3.5),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
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
                    size: 20,
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
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),

          // Email Address
          Text(
            userEmail,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),

          // Verified Customer Chip Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_border_rounded, color: Color(0xFF10B981), size: 16),
                SizedBox(width: 6),
                Text(
                  "Verified Customer",
                  style: TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
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
          color: Color(0xFF475569),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
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
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(12),
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
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        color: arrowColor,
        size: 14,
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
            color: Colors.black.withOpacity(0.05),
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
          color: isSelected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
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
      indent: 66,
      endIndent: 16,
      color: Color(0xFFF1F5F9),
    );
  }
}