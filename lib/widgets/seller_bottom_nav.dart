import 'package:flutter/material.dart';

/// Shared clean bottom navigation bar for all Seller screens.
///
/// Inspired by a flat, modern seller dashboard design:
/// - Pure white background with subtle top shadow (no heavy borders)
/// - Active tab: sapphire blue filled icon + blue label
/// - Inactive tabs: outlined slate icons + muted labels
/// - 5 tabs: Home, Orders, Products, Analytics, More
class SellerBottomNav extends StatelessWidget {
  final int currentIndex;

  const SellerBottomNav({super.key, required this.currentIndex});

  // Sapphire Blue brand color (matches seller dashboard theme)
  static const Color _activeColor = Color(0xFF2563EB);
  static const Color _inactiveColor = Color(0xFF94A3B8);
  static const Color _labelInactive = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(
                context,
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
              ),
              _navItem(
                context,
                index: 1,
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
                label: 'Orders',
              ),
              _navItem(
                context,
                index: 2,
                icon: Icons.inventory_2_outlined,
                activeIcon: Icons.inventory_2_rounded,
                label: 'Products',
              ),
              _navItem(
                context,
                index: 3,
                icon: Icons.bar_chart_outlined,
                activeIcon: Icons.bar_chart_rounded,
                label: 'Analytics',
              ),
              _navItem(
                context,
                index: 4,
                icon: Icons.more_horiz_rounded,
                activeIcon: Icons.more_horiz_rounded,
                label: 'More',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final bool isActive = currentIndex == index;

    return GestureDetector(
      onTap: () => _onTabTap(context, index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: EdgeInsets.symmetric(
                horizontal: isActive ? 16 : 0,
                vertical: isActive ? 6 : 4,
              ),
              decoration: BoxDecoration(
                color: isActive ? _activeColor.withValues(alpha: 0.10) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isActive ? activeIcon : icon,
                color: isActive ? _activeColor : _inactiveColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isActive ? _activeColor : _labelInactive,
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTabTap(BuildContext context, int index) {
    if (index == currentIndex) return;

    // Routes matching the existing seller navigation
    switch (index) {
      case 0:
        Navigator.pushNamedAndRemoveUntil(context, '/seller', (route) => false);
        break;
      case 1:
        Navigator.pushNamed(context, '/active_orders');
        break;
      case 2:
        Navigator.pushNamed(context, '/my_products');
        break;
      case 3:
        Navigator.pushNamed(context, '/seller_analytics');
        break;
      case 4:
        Navigator.pushNamed(context, '/manage_store');
        break;
    }
  }
}
