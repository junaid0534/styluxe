import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CustomerCategoryScreen extends StatelessWidget {
  const CustomerCategoryScreen({super.key});

  final List<CategoryData> categories = const [
    CategoryData(
      name: "Dresses",
      icon: Icons.woman_rounded,
      gradientColors: [
        Color(0xFF00E676),
        Color(0xFF00C853),
      ],
      shadowColor: Color.fromARGB(255, 49, 198, 104),
    ),
    CategoryData(
      name: "Shirts",
      icon: Icons.shopping_bag_rounded,
      gradientColors: [
        Color(0xFF00E676),
        Color(0xFF00C853),
      ],
      shadowColor: Color.fromARGB(255, 49, 198, 104),
    ),
    CategoryData(
      name: "Hoodies",
      icon: Icons.local_mall_rounded,
      gradientColors: [
        Color(0xFF00E676),
        Color(0xFF00C853),
      ],
      shadowColor: Color.fromARGB(255, 49, 198, 104),
    ),
    CategoryData(
      name: "Jeans",
      icon: Icons.straighten_rounded,
      gradientColors: [
        Color(0xFF00E676),
        Color(0xFF00C853),
      ],
      shadowColor: Color.fromARGB(255, 49, 198, 104),
    ),
    CategoryData(
      name: "Jackets",
      icon: Icons.style_rounded,
      gradientColors: [
        Color(0xFF00E676),
        Color(0xFF00C853),
      ],
      shadowColor: Color.fromARGB(255, 49, 198, 104),
    ),
    CategoryData(
      name: "Kids Wear",
      icon: Icons.child_care_rounded,
      gradientColors: [
        Color(0xFF00E676),
        Color(0xFF00C853),
      ],
     shadowColor: Color.fromARGB(255, 49, 198, 104),
    ),
  ];

  int _getCrossAxisCount(double width) {
    if (width >= 1100) return 4;
    if (width >= 760) return 3;
    return 2;
  }

  double _getHorizontalPadding(double width) {
    if (width >= 1100) return 48;
    if (width >= 760) return 32;
    return 16;
  }

  double _getCardHeight(double width) {
    if (width < 360) return 150;
    if (width < 600) return 165;
    return 180;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final crossAxisCount = _getCrossAxisCount(width);
    final horizontalPadding = _getHorizontalPadding(width);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ================= APP BAR =================
            SliverAppBar(
              backgroundColor: const Color(0xFFA8E063),
              surfaceTintColor: const Color(0xFFA8E063),
              elevation: 0,
              floating: true,
              toolbarHeight: kToolbarHeight,
              iconTheme: const IconThemeData(
                color: Color(0xFF111827),
              ),
              title: const Text(
                "Categories",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: -0.3,
                ),
              ),
            ),

            // ================= HEADER =================
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                18,
                horizontalPadding,
                8,
              ),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Find Your Style",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                            letterSpacing: -0.9,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Premium fashion collections",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ================= CATEGORY CARDS =================
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                14,
                horizontalPadding,
                24,
              ),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final cat = categories[index];

                    return CategoryCard(
                      category: cat,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/shop_now',
                          arguments: cat.name,
                        );
                      },
                    )
                        .animate()
                        .fadeIn(
                          duration: 350.ms,
                          delay: (index * 80).ms,
                        )
                        .scale(
                          begin: const Offset(0.96, 0.96),
                          end: const Offset(1, 1),
                          duration: 350.ms,
                          curve: Curves.easeOutCubic,
                        );
                  },
                  childCount: categories.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: _getCardHeight(width),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= CATEGORY DATA MODEL =================
class CategoryData {
  final String name;
  final IconData icon;
  final List<Color> gradientColors;
  final Color shadowColor;

  const CategoryData({
    required this.name,
    required this.icon,
    required this.gradientColors,
    required this.shadowColor,
  });
}

// ================= CATEGORY CARD =================
class CategoryCard extends StatelessWidget {
  final CategoryData category;
  final VoidCallback onTap;

  const CategoryCard({super.key, 
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 170;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            splashColor: Colors.white.withValues(alpha: 0.12),
            highlightColor: Colors.white.withValues(alpha: 0.06),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  colors: category.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: category.shadowColor.withValues(alpha: 0.25),
                    blurRadius: 22,
                    spreadRadius: 1,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    Positioned(
                      right: -34,
                      top: -36,
                      child: _CardCircle(
                        size: 118,
                        opacity: 0.12,
                      ),
                    ),
                    Positioned(
                      right: -42,
                      bottom: -48,
                      child: _CardCircle(
                        size: 132,
                        opacity: 0.08,
                      ),
                    ),
                    Positioned(
                      left: -34,
                      bottom: -42,
                      child: _CardCircle(
                        size: 100,
                        opacity: 0.06,
                      ),
                    ),

                    Padding(
                      padding: EdgeInsets.all(isCompact ? 14 : 17),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: isCompact ? 52 : 60,
                            width: isCompact ? 52 : 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.17),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              category.icon,
                              size: isCompact ? 28 : 32,
                              color: Colors.white,
                            ),
                          ),

                          const Spacer(),

                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              category.name,
                              maxLines: 1,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isCompact ? 19 : 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                height: 1,
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  "Shop Now",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.86),
                                    fontSize: isCompact ? 12 : 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white.withValues(alpha: 0.9),
                                size: isCompact ? 15 : 16,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ================= DECORATIVE CIRCLE =================
class _CardCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _CardCircle({
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}