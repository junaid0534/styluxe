import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomerCategoryScreen extends StatefulWidget {
  const CustomerCategoryScreen({super.key});

  @override
  State<CustomerCategoryScreen> createState() => _CustomerCategoryScreenState();
}

class _CustomerCategoryScreenState extends State<CustomerCategoryScreen> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  // Comprehensive Category Catalog (15 Essential Fashion Categories)
  final List<CategoryItem> categories = const [
    CategoryItem(
      name: "Dresses",
      tagline: "Maxi & Party Wear",
      icon: Icons.woman_rounded,
      accentColor: Color(0xFFEC4899),
      bgGradient: [Color(0xFFFDF2F8), Color(0xFFFCE7F3)],
    ),
    CategoryItem(
      name: "Shirts",
      tagline: "Formal & Casual",
      icon: Icons.dry_cleaning_rounded,
      accentColor: Color(0xFF2563EB),
      bgGradient: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
    ),
    CategoryItem(
      name: "T-Shirts",
      tagline: "Polo & Graphic Tees",
      icon: Icons.checkroom_rounded,
      accentColor: Color(0xFFF59E0B),
      bgGradient: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
    ),
    CategoryItem(
      name: "Hoodies",
      tagline: "Winter & Sweatshirts",
      icon: Icons.local_mall_rounded,
      accentColor: Color(0xFF8B5CF6),
      bgGradient: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
    ),
    CategoryItem(
      name: "Jeans",
      tagline: "Denim & Trousers",
      icon: Icons.straighten_rounded,
      accentColor: Color(0xFF3B82F6),
      bgGradient: [Color(0xFFEFF6FF), Color(0xFFE0E7FF)],
    ),
    CategoryItem(
      name: "Jackets",
      tagline: "Leather & Coats",
      icon: Icons.style_rounded,
      accentColor: Color(0xFF0D9488),
      bgGradient: [Color(0xFFF0FDFA), Color(0xFFCCFBF1)],
    ),
    CategoryItem(
      name: "Suits",
      tagline: "Blazers & 2-Piece",
      icon: Icons.business_center_rounded,
      accentColor: Color(0xFF334155),
      bgGradient: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
    ),
    CategoryItem(
      name: "Kids Wear",
      tagline: "Boys & Girls",
      icon: Icons.child_care_rounded,
      accentColor: Color(0xFFF43F5E),
      bgGradient: [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
    ),
    CategoryItem(
      name: "Shoes",
      tagline: "Sneakers & Heels",
      icon: Icons.roller_skating_rounded,
      accentColor: Color(0xFF14B8A6),
      bgGradient: [Color(0xFFF0FDFA), Color(0xFFD1FAE5)],
    ),
    CategoryItem(
      name: "Bags",
      tagline: "Handbags & Wallets",
      icon: Icons.shopping_bag_rounded,
      accentColor: Color(0xFFEA580C),
      bgGradient: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
    ),
    CategoryItem(
      name: "Watches",
      tagline: "Luxury & Smart",
      icon: Icons.watch_rounded,
      accentColor: Color(0xFFD97706),
      bgGradient: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
    ),
    CategoryItem(
      name: "Accessories",
      tagline: "Jewelry & Belts",
      icon: Icons.diamond_rounded,
      accentColor: Color(0xFF06B6D4),
      bgGradient: [Color(0xFFECFEFF), Color(0xFFCFFAFE)],
    ),
    CategoryItem(
      name: "Traditional",
      tagline: "Kurta & Shalwar",
      icon: Icons.auto_awesome_rounded,
      accentColor: Color(0xFF9333EA),
      bgGradient: [Color(0xFFFAF5FF), Color(0xFFF3E8FF)],
    ),
    CategoryItem(
      name: "Activewear",
      tagline: "Gym & Sports",
      icon: Icons.fitness_center_rounded,
      accentColor: Color(0xFFEF4444),
      bgGradient: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
    ),
    CategoryItem(
      name: "Nightwear",
      tagline: "Sleep & Loungewear",
      icon: Icons.bedtime_rounded,
      accentColor: Color(0xFF4F46E5),
      bgGradient: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _getCrossAxisCount(double width) {
    if (width >= 1100) return 6;
    if (width >= 700) return 4;
    return 3; // Exactly 3 items per row on mobile!
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = _getCrossAxisCount(width);

    final filtered = categories.where((c) {
      final query = _searchQuery.toLowerCase();
      return query.isEmpty ||
          c.name.toLowerCase().contains(query) ||
          c.tagline.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        toolbarHeight: 52.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: slateDark, size: 21),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          "All Categories",
          style: GoogleFonts.poppins(
            color: slateDark,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Search Bar Capsule
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: GoogleFonts.poppins(fontSize: 13, color: slateDark, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: "Search categories (e.g. Dresses, Jeans...)",
                    hintStyle: GoogleFonts.poppins(color: slateMuted, fontSize: 12.5),
                    prefixIcon: const Icon(Icons.search_rounded, color: slateMuted, size: 19),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.cancel_rounded, color: slateMuted, size: 17),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = "");
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            // 2. 3-Items per row Categories Grid
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        "No category matching '$_searchQuery'",
                        style: GoogleFonts.poppins(color: slateMuted, fontSize: 13),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                      physics: const BouncingScrollPhysics(),
                      itemCount: filtered.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.80, // Optimized for 3 per row
                      ),
                      itemBuilder: (context, index) {
                        final cat = filtered[index];
                        return _buildCategoryCard(cat, index);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(CategoryItem cat, int index) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/shop_now',
          arguments: cat.name,
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: cat.accentColor.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon in Pastel Gradient Squircle
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: cat.bgGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cat.accentColor.withValues(alpha: 0.20)),
              ),
              alignment: Alignment.center,
              child: Icon(cat.icon, color: cat.accentColor, size: 24),
            ),
            const SizedBox(height: 8),

            // Category Name
            Text(
              cat.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: slateDark,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 2),

            // Tagline / Hint
            Text(
              cat.tagline,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: slateMuted,
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 250.ms, delay: (index * 30).ms)
        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), duration: 250.ms);
  }
}

class CategoryItem {
  final String name;
  final String tagline;
  final IconData icon;
  final Color accentColor;
  final List<Color> bgGradient;

  const CategoryItem({
    required this.name,
    required this.tagline,
    required this.icon,
    required this.accentColor,
    required this.bgGradient,
  });
}