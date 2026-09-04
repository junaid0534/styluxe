import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'seller_shimmer_loading.dart';

// ==========================================
// 1. CUSTOMER PRODUCTS GRID SHIMMER (Shop Now / Feeds)
// ==========================================
class CustomerProductsGridShimmer extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;

  const CustomerProductsGridShimmer({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsets.fromLTRB(12, 4, 12, 20),
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 700;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: padding,
      itemCount: itemCount,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: isTablet ? 180 : 135,
        mainAxisExtent: isTablet ? 230 : 178,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image Placeholder with Heart Badge
              Expanded(
                flex: 9,
                child: Stack(
                  children: const [
                    ShimmerBox(
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: 12,
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: ShimmerCircle(radius: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Title & Price Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerBox(width: double.infinity, height: 11, borderRadius: 3),
                    SizedBox(height: 4),
                    ShimmerBox(width: 65, height: 12, borderRadius: 3),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// 2. CUSTOMER PRODUCT DETAIL SHIMMER
// ==========================================
class CustomerProductDetailShimmer extends StatelessWidget {
  const CustomerProductDetailShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Gallery Carousel Placeholder
          const ShimmerBox(
            width: double.infinity,
            height: 320,
            borderRadius: 20,
          ),
          const SizedBox(height: 16),

          // Price & Stock Tag Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              ShimmerBox(width: 120, height: 26, borderRadius: 6),
              ShimmerBox(width: 80, height: 24, borderRadius: 12),
            ],
          ),
          const SizedBox(height: 12),

          // Product Title
          const ShimmerBox(width: double.infinity, height: 20, borderRadius: 4),
          const SizedBox(height: 6),
          const ShimmerBox(width: 180, height: 16, borderRadius: 4),
          const SizedBox(height: 16),

          // Size/Color Options Row
          const ShimmerBox(width: 100, height: 14, borderRadius: 4),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              4,
              (i) => const Padding(
                padding: EdgeInsets.only(right: 8),
                child: ShimmerBox(width: 44, height: 36, borderRadius: 10),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Store Card Info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const ShimmerCircle(radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(width: 130, height: 14, borderRadius: 4),
                      SizedBox(height: 4),
                      ShimmerBox(width: 80, height: 11, borderRadius: 4),
                    ],
                  ),
                ),
                const ShimmerBox(width: 70, height: 30, borderRadius: 12),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Description Section
          const ShimmerBox(width: 120, height: 16, borderRadius: 4),
          const SizedBox(height: 8),
          const ShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
          const SizedBox(height: 6),
          const ShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
          const SizedBox(height: 6),
          const ShimmerBox(width: 220, height: 12, borderRadius: 4),
        ],
      ),
    );
  }
}

// ==========================================
// 3. CUSTOMER CART & WISHLIST LIST SHIMMER
// ==========================================
class CustomerListItemsShimmer extends StatelessWidget {
  final int count;

  const CustomerListItemsShimmer({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: count,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Thumbnail
              const ShimmerBox(width: 80, height: 85, borderRadius: 12),
              const SizedBox(width: 12),

              // Info & Action Buttons
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerBox(width: double.infinity, height: 14, borderRadius: 4),
                    SizedBox(height: 6),
                    ShimmerBox(width: 90, height: 11, borderRadius: 4),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ShimmerBox(width: 75, height: 16, borderRadius: 4),
                        ShimmerBox(width: 70, height: 26, borderRadius: 8),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// 4. CUSTOMER ORDERS SHIMMER
// ==========================================
class CustomerOrdersShimmer extends StatelessWidget {
  final int count;

  const CustomerOrdersShimmer({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: count,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(16),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  ShimmerBox(width: 110, height: 16, borderRadius: 4),
                  ShimmerBox(width: 80, height: 24, borderRadius: 12),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const ShimmerBox(width: 60, height: 60, borderRadius: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        ShimmerBox(width: double.infinity, height: 13, borderRadius: 4),
                        SizedBox(height: 5),
                        ShimmerBox(width: 80, height: 11, borderRadius: 4),
                      ],
                    ),
                  ),
                  const ShimmerBox(width: 70, height: 16, borderRadius: 4),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: const [
                  Expanded(child: ShimmerBox(height: 36, borderRadius: 10)),
                  SizedBox(width: 8),
                  Expanded(child: ShimmerBox(height: 36, borderRadius: 10)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// 5. CUSTOMER NOTIFICATIONS SHIMMER
// ==========================================
class CustomerNotificationsShimmer extends StatelessWidget {
  final int count;

  const CustomerNotificationsShimmer({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: count,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShimmerCircle(radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerBox(width: 140, height: 14, borderRadius: 4),
                    SizedBox(height: 6),
                    ShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
                    SizedBox(height: 6),
                    ShimmerBox(width: 70, height: 10, borderRadius: 4),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// 6. CUSTOMER PROFILE SHIMMER
// ==========================================
class CustomerProfileShimmer extends StatelessWidget {
  const CustomerProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile Header Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const ShimmerCircle(radius: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(width: 130, height: 16, borderRadius: 4),
                      SizedBox(height: 6),
                      ShimmerBox(width: 160, height: 12, borderRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Menu Options Skeleton
          ...List.generate(
            5,
            (i) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: const [
                  ShimmerCircle(radius: 14),
                  SizedBox(width: 12),
                  Expanded(child: ShimmerBox(width: 120, height: 14, borderRadius: 4)),
                  ShimmerBox(width: 14, height: 14, borderRadius: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
