import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SelectCategoryScreen extends StatefulWidget {
  const SelectCategoryScreen({super.key});

  @override
  State<SelectCategoryScreen> createState() => _SelectCategoryScreenState();
}

class _SelectCategoryScreenState extends State<SelectCategoryScreen> {
  String? selectedGender;

  final Map<String, List<Map<String, dynamic>>> genderWiseCategories = {
    "Men": [
      {"name": "T-Shirt", "icon": Icons.checkroom},
      {"name": "Shirt"},
      {"name": "Hoodie", "icon": Icons.local_mall},
      {"name": "Jeans", "icon": Icons.straighten},
      {"name": "Jacket", "icon": Icons.style},
      {"name": "Trouser", "icon": Icons.accessibility_new},
    ],
    "Women": [
      {"name": "Dress", "icon": Icons.woman},
      {"name": "Kurti", "icon": Icons.person},
      {"name": "Top", "icon": Icons.checkroom},
      {"name": "Jeans", "icon": Icons.straighten},
      {"name": "Jacket", "icon": Icons.style},
      {"name": "Saree", "icon": Icons.woman_2},
    ],
    "Unisex": [
      {"name": "Hoodie", "icon": Icons.local_mall},
      {"name": "T-Shirt", "icon": Icons.checkroom},
      {"name": "Jeans", "icon": Icons.straighten},
      {"name": "Jacket", "icon": Icons.style},
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Color(0xFF111827),
        ),
        title: const Text(
          "Add New Product",
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final bool isMobile = width < 650;
            final bool isSmallMobile = width < 380;

            int categoryGridCount = 2;

            if (width >= 1200) {
              categoryGridCount = 4;
            } else if (width >= 850) {
              categoryGridCount = 3;
            } else {
              categoryGridCount = 2;
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 28,
                vertical: 20,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 1200,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(isMobile: isMobile)
                          .animate()
                          .fadeIn(duration: 450.ms)
                          .slideY(begin: 0.10),

                      const SizedBox(height: 24),

                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: isSmallMobile ? 8 : 12,
                        mainAxisSpacing: isSmallMobile ? 8 : 12,
                        childAspectRatio: isSmallMobile
                            ? 0.72
                            : isMobile
                                ? 0.78
                                : 1.45,
                        children: [
                          _genderCard(
                            "Men",
                            Icons.male_rounded,
                            const Color(0xFF2563EB),
                            const [
                              Color(0xFF2563EB),
                              Color(0xFF60A5FA),
                            ],
                          ),
                          _genderCard(
                            "Women",
                            Icons.female_rounded,
                            const Color(0xFFDB2777),
                            const [
                              Color(0xFFDB2777),
                              Color(0xFFF472B6),
                            ],
                          ),
                          _genderCard(
                            "Unisex",
                            Icons.people_alt_rounded,
                            const Color(0xFF0F766E),
                            const [
                              Color(0xFF0F766E),
                              Color(0xFF2DD4BF),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      if (selectedGender != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(
                              title: "$selectedGender Categories",
                              subtitle: "Choose the exact product category",
                            ),

                            const SizedBox(height: 18),

                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount:
                                  genderWiseCategories[selectedGender]!.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: categoryGridCount,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: width >= 850
                                    ? 1.25
                                    : isSmallMobile
                                        ? 0.88
                                        : 0.95,
                              ),
                              itemBuilder: (context, index) {
                                final cat =
                                    genderWiseCategories[selectedGender]![index];

                                return _categoryCard(cat, index);
                              },
                            ),
                          ],
                        )
                      else
                        _emptySelectionView(),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader({required bool isMobile}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 49, 212, 73),
            Color.fromARGB(255, 167, 197, 118),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isMobile ? 58 : 72,
            height: isMobile ? 58 : 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
            child: Icon(
              Icons.add_business_rounded,
              color: Colors.white,
              size: isMobile ? 30 : 38,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Create Product Listing",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 23 : 34,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Select gender first, then choose a category for your product.",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: isMobile ? 13.5 : 16,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle({
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF3FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.category_outlined,
            color: Color(0xFF4F46E5),
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
                  color: Color(0xFF111827),
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn().slideY(begin: 0.08);
  }

  Widget _genderCard(
    String gender,
    IconData icon,
    Color accentColor,
    List<Color> gradientColors,
  ) {
    final bool isSelected = selectedGender == gender;

    return GestureDetector(
      onTap: () => setState(() => selectedGender = gender),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                )
              : null,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? accentColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.22)
                  : Colors.black.withValues(alpha: 0.045),
              blurRadius: isSelected ? 22 : 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double iconBoxSize =
                (constraints.maxHeight * 0.42).clamp(38.0, 56.0);
            final double iconSize = (iconBoxSize * 0.55).clamp(22.0, 32.0);
            final bool compact = constraints.maxHeight < 115;

            return FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: iconBoxSize,
                    height: iconBoxSize,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.20)
                          : accentColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      icon,
                      size: iconSize,
                      color: isSelected ? Colors.white : accentColor,
                    ),
                  ),

                  SizedBox(height: compact ? 7 : 10),

                  Text(
                    gender,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF111827),
                      fontSize: compact ? 14 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  if (!compact) ...[
                    const SizedBox(height: 4),
                    Text(
                      isSelected ? "Selected" : "Tap to select",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.86)
                            : Colors.grey.shade500,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ).animate().fadeIn().scale(delay: 80.ms),
    );
  }

  Widget _categoryCard(Map<String, dynamic> cat, int index) {
    final String categoryName = cat['name']?.toString() ?? 'Category';
    final IconData categoryIcon = cat['icon'] ?? Icons.checkroom_outlined;

    final List<List<Color>> gradients = [
      [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
      [const Color(0xFFDB2777), const Color(0xFFEC4899)],
      [const Color(0xFF0F766E), const Color(0xFF14B8A6)],
      [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
      [const Color(0xFF2563EB), const Color(0xFF06B6D4)],
      [const Color(0xFF9333EA), const Color(0xFFF43F5E)],
    ];

    final List<Color> cardGradient = gradients[index % gradients.length];

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/add_product',
          arguments: categoryName,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: cardGradient,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: cardGradient.first.withValues(alpha: 0.24),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double iconBoxSize =
                (constraints.maxHeight * 0.38).clamp(44.0, 68.0);
            final double iconSize = (iconBoxSize * 0.52).clamp(24.0, 36.0);
            final bool compact = constraints.maxHeight < 125;

            return FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: iconBoxSize,
                    height: iconBoxSize,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Icon(
                      categoryIcon,
                      size: iconSize,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(height: compact ? 9 : 13),

                  SizedBox(
                    width: 120,
                    child: Text(
                      categoryName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 15.5 : 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  if (!compact) ...[
                    const SizedBox(height: 7),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Continue",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.86),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white.withValues(alpha: 0.86),
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ).animate().fadeIn(delay: (index * 70).ms).slideY(begin: 0.10),
    );
  }

  Widget _emptySelectionView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 55,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF3FF),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(
              Icons.touch_app_rounded,
              color: Color(0xFF4F46E5),
              size: 38,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Please select gender first",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "After selecting gender, related product categories will appear here.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale();
  }
}