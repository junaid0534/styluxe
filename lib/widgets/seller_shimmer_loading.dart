import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Base Shimmer Box Widget
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;
  final Color baseColor;
  final Color highlightColor;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.margin,
    this.baseColor = const Color(0xFFE2E8F0),
    this.highlightColor = const Color(0xFFF8FAFC),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 1200.ms, color: highlightColor);
  }
}

/// Base Shimmer Circle Avatar Widget
class ShimmerCircle extends StatelessWidget {
  final double radius;
  final EdgeInsetsGeometry? margin;
  final Color baseColor;
  final Color highlightColor;

  const ShimmerCircle({
    super.key,
    required this.radius,
    this.margin,
    this.baseColor = const Color(0xFFE2E8F0),
    this.highlightColor = const Color(0xFFF8FAFC),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      margin: margin,
      decoration: BoxDecoration(
        color: baseColor,
        shape: BoxShape.circle,
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 1200.ms, color: highlightColor);
  }
}

// ==========================================
// 1. SELLER DASHBOARD / HOME SHIMMER
// ==========================================
class SellerDashboardShimmer extends StatelessWidget {
  const SellerDashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store Greeting & Avatar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const ShimmerCircle(radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(width: 140, height: 16, borderRadius: 4),
                      SizedBox(height: 6),
                      ShimmerBox(width: 90, height: 12, borderRadius: 4),
                    ],
                  ),
                ),
                const ShimmerBox(width: 70, height: 28, borderRadius: 14),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4 Metric KPI Cards (2x2 Grid)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: List.generate(4, (index) => _metricCardShimmer()),
          ),
          const SizedBox(height: 14),

          // Sales Chart Card Shimmer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    ShimmerBox(width: 120, height: 16, borderRadius: 4),
                    ShimmerBox(width: 80, height: 26, borderRadius: 12),
                  ],
                ),
                const SizedBox(height: 16),
                const ShimmerBox(width: double.infinity, height: 140, borderRadius: 12),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Recent Orders Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              ShimmerBox(width: 110, height: 16, borderRadius: 4),
              ShimmerBox(width: 60, height: 14, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 10),

          // 2 Recent Order Cards
          _orderCardShimmer(),
          const SizedBox(height: 10),
          _orderCardShimmer(),
        ],
      ),
    );
  }

  Widget _metricCardShimmer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              ShimmerBox(width: 60, height: 12, borderRadius: 4),
              ShimmerCircle(radius: 14),
            ],
          ),
          const ShimmerBox(width: 90, height: 20, borderRadius: 4),
          const ShimmerBox(width: 70, height: 10, borderRadius: 4),
        ],
      ),
    );
  }

  Widget _orderCardShimmer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
                ShimmerBox(width: 120, height: 14, borderRadius: 4),
                SizedBox(height: 5),
                ShimmerBox(width: 80, height: 11, borderRadius: 4),
              ],
            ),
          ),
          const ShimmerBox(width: 65, height: 24, borderRadius: 12),
        ],
      ),
    );
  }
}

// ==========================================
// 2. SELLER MY PRODUCTS SHIMMER
// ==========================================
class SellerProductsShimmer extends StatelessWidget {
  const SellerProductsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          // 3-Metric KPI Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                3,
                (i) => Column(
                  children: const [
                    ShimmerBox(width: 50, height: 16, borderRadius: 4),
                    SizedBox(height: 4),
                    ShimmerBox(width: 60, height: 11, borderRadius: 4),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Search Bar
          const ShimmerBox(width: double.infinity, height: 42, borderRadius: 12),
          const SizedBox(height: 10),

          // Category Pills
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 5,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) => const ShimmerBox(width: 68, height: 32, borderRadius: 16),
            ),
          ),
          const SizedBox(height: 14),

          // 2-Column Product Grid (6 Items)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
              childAspectRatio: 0.56,
            ),
            itemBuilder: (context, index) => _productCardShimmer(),
          ),
        ],
      ),
    );
  }

  Widget _productCardShimmer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          const Expanded(
            flex: 9,
            child: ShimmerBox(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 12,
            ),
          ),
          const SizedBox(height: 8),

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: 60, height: 10, borderRadius: 3),
                SizedBox(height: 5),
                ShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
                SizedBox(height: 4),
                ShimmerBox(width: 80, height: 12, borderRadius: 4),
                SizedBox(height: 6),
                ShimmerBox(width: 60, height: 14, borderRadius: 4),
                SizedBox(height: 8),
                // Toggle Button Capsule
                ShimmerBox(width: double.infinity, height: 30, borderRadius: 10),
                SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. SELLER ORDERS SHIMMER
// ==========================================
class SellerOrdersShimmer extends StatelessWidget {
  const SellerOrdersShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          // Status Tabs
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 5,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) => const ShimmerBox(width: 76, height: 36, borderRadius: 18),
            ),
          ),
          const SizedBox(height: 14),

          // List of 4 Order Cards
          ...List.generate(4, (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _orderCardShimmer(),
          )),
        ],
      ),
    );
  }

  Widget _orderCardShimmer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Order ID + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              ShimmerBox(width: 90, height: 15, borderRadius: 4),
              ShimmerBox(width: 70, height: 24, borderRadius: 12),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Customer info & Total
          Row(
            children: [
              const ShimmerCircle(radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerBox(width: 110, height: 13, borderRadius: 4),
                    SizedBox(height: 4),
                    ShimmerBox(width: 70, height: 10, borderRadius: 4),
                  ],
                ),
              ),
              const ShimmerBox(width: 80, height: 18, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 12),

          // Action Buttons
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
  }
}

// ==========================================
// 4. SELLER ANALYTICS SHIMMER
// ==========================================
class SellerAnalyticsShimmer extends StatelessWidget {
  const SellerAnalyticsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          // Filter Tabs
          Row(
            children: const [
              Expanded(child: ShimmerBox(height: 38, borderRadius: 10)),
              SizedBox(width: 8),
              Expanded(child: ShimmerBox(height: 38, borderRadius: 10)),
              SizedBox(width: 8),
              Expanded(child: ShimmerBox(height: 38, borderRadius: 10)),
            ],
          ),
          const SizedBox(height: 12),

          // 4 KPI Cards Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: List.generate(4, (i) => _kpiShimmer()),
          ),
          const SizedBox(height: 12),

          // Revenue Chart Card
          _chartCardShimmer(height: 200),
          const SizedBox(height: 12),

          // Orders Chart Card
          _chartCardShimmer(height: 180),
        ],
      ),
    );
  }

  Widget _kpiShimmer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          ShimmerBox(width: 70, height: 11, borderRadius: 4),
          ShimmerBox(width: 100, height: 20, borderRadius: 4),
          ShimmerBox(width: 50, height: 10, borderRadius: 4),
        ],
      ),
    );
  }

  Widget _chartCardShimmer({required double height}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(width: 130, height: 16, borderRadius: 4),
          const SizedBox(height: 6),
          const ShimmerBox(width: 180, height: 11, borderRadius: 4),
          const SizedBox(height: 16),
          ShimmerBox(width: double.infinity, height: height - 60, borderRadius: 12),
        ],
      ),
    );
  }
}

// ==========================================
// 5. SELLER REVENUE / WALLET SHIMMER
// ==========================================
class SellerRevenueShimmer extends StatelessWidget {
  const SellerRevenueShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        children: [
          // Main Balance Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: 100, height: 13, borderRadius: 4),
                SizedBox(height: 10),
                ShimmerBox(width: 160, height: 28, borderRadius: 6),
                SizedBox(height: 16),
                ShimmerBox(width: double.infinity, height: 44, borderRadius: 12),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2x2 Stats Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: List.generate(4, (i) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  ShimmerBox(width: 70, height: 11, borderRadius: 4),
                  ShimmerBox(width: 90, height: 18, borderRadius: 4),
                ],
              ),
            )),
          ),
          const SizedBox(height: 16),

          // Payout History Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              ShimmerBox(width: 120, height: 16, borderRadius: 4),
              ShimmerBox(width: 60, height: 12, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(3, (i) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                ShimmerBox(width: 120, height: 14, borderRadius: 4),
                ShimmerBox(width: 70, height: 14, borderRadius: 4),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
