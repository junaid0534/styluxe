import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/banner_service.dart';
import 'admin_banner_form_screen.dart';

class AdminBannersScreen extends StatefulWidget {
  final bool isStandalone;
  const AdminBannersScreen({super.key, this.isStandalone = true});

  @override
  State<AdminBannersScreen> createState() => _AdminBannersScreenState();
}

class _AdminBannersScreenState extends State<AdminBannersScreen> {
  List<HomeBannerItem> _banners = [];
  bool _isLoading = true;
  int _activePreviewIndex = 0;
  final PageController _previewController = PageController();

  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  @override
  void dispose() {
    _previewController.dispose();
    super.dispose();
  }

  Future<void> _loadBanners() async {
    setState(() => _isLoading = true);
    final list = await BannerService.fetchAllBanners();
    if (!mounted) return;
    setState(() {
      _banners = list;
      _isLoading = false;
    });
  }

  Future<void> _toggleStatus(HomeBannerItem banner, bool val) async {
    await BannerService.toggleStatus(banner.id, val);
    _loadBanners();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          val ? "'${banner.title}' activated on Home Slider" : "'${banner.title}' deactivated from Home Slider",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12.5),
        ),
        backgroundColor: val ? const Color(0xFF10B981) : slateDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openBannerForm({HomeBannerItem? existing}) async {
    final res = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminBannerFormScreen(existing: existing),
      ),
    );

    if (res == true) {
      _loadBanners();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeBanners = _banners.where((b) => b.isActive).toList();

    Widget content = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Banner
              _buildHeaderBanner(),

              const SizedBox(height: 14),

              // 2. Active Carousel Preview
              _buildLiveCarouselPreview(activeBanners),

              const SizedBox(height: 18),

              // 3. Section Header & Add Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.view_carousel_rounded, color: primaryTeal, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        "All Promo Sliders (${_banners.length})",
                        style: GoogleFonts.poppins(
                          color: slateDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryTeal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                      minimumSize: const Size(100, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _openBannerForm(),
                    child: Text(
                      "+ Add Banner",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12, height: 1.2),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 4. Banners List
              if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: primaryTeal)))
              else if (_banners.isEmpty)
                _buildEmptyState()
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _banners.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = _banners[index];
                    return _buildBannerListItem(item, index);
                  },
                ),
            ],
          ),
        ),
      ),
    );

    if (widget.isStandalone) {
      return Scaffold(
        backgroundColor: bgLight,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            "StyLuxe",
            style: GoogleFonts.poppins(
              color: slateDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slateDark, size: 16),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(child: content),
      );
    }

    return content;
  }

  // ================= 1. HEADER BANNER =================
  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: primaryTeal,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: primaryTeal.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Home Slider Manager",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Text(
                  "Manage promotional hero carousels seen by all customers",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04);
  }

  // ================= 2. LIVE CAROUSEL PREVIEW =================
  Widget _buildLiveCarouselPreview(List<HomeBannerItem> activeBanners) {
    if (activeBanners.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Text(
            "No active banners on Home. Turn on a banner below to preview.",
            style: GoogleFonts.poppins(color: slateMuted, fontSize: 12),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.remove_red_eye_rounded, color: slateMuted, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    "Customer Home Live Preview",
                    style: GoogleFonts.poppins(color: slateMuted, fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              Text(
                "${_activePreviewIndex + 1}/${activeBanners.length}",
                style: GoogleFonts.poppins(color: primaryTeal, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 148,
          child: PageView.builder(
            controller: _previewController,
            onPageChanged: (idx) => setState(() => _activePreviewIndex = idx),
            itemCount: activeBanners.length,
            itemBuilder: (context, index) {
              final b = activeBanners[index];
              return _buildPreviewCard(b);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewCard(HomeBannerItem banner) {
    final colors = banner.gradientColors;
    final icon = banner.iconData;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        banner.discountTag.toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (banner.promoCode != null && banner.promoCode!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "Code: ${banner.promoCode}",
                          style: GoogleFonts.poppins(
                            color: slateDark,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  banner.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  banner.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  // ================= 3. BANNER LIST ITEM =================
  Widget _buildBannerListItem(HomeBannerItem item, int index) {
    final colors = item.gradientColors;
    final icon = item.iconData;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.isActive ? borderColor : const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Gradient Circle Icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 5,
                  runSpacing: 3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.first.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.discountTag,
                        style: GoogleFonts.poppins(
                          color: colors.first,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (item.promoCode != null && item.promoCode!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          item.promoCode!,
                          style: GoogleFonts.poppins(
                            color: slateDark,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: item.isActive ? slateDark : slateMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: slateMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Actions: Clean Text "Edit" Button + Active Switch
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Clean "Edit" Button (Without icon)
              InkWell(
                onTap: () => _openBannerForm(existing: item),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    "Edit",
                    style: GoogleFonts.poppins(
                      color: slateDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // Active Switch
              Transform.scale(
                scale: 0.68,
                child: Switch(
                  value: item.isActive,
                  activeThumbColor: primaryTeal,
                  activeTrackColor: primaryTeal.withValues(alpha: 0.4),
                  onChanged: (val) => _toggleStatus(item, val),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms, delay: (index * 40).ms);
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.view_carousel_outlined, color: slateMuted.withValues(alpha: 0.5), size: 40),
          const SizedBox(height: 10),
          Text(
            "No Home Banners Found",
            style: GoogleFonts.poppins(color: slateDark, fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            "Click '+ Add Banner' above to create your first promotional slider.",
            style: GoogleFonts.poppins(color: slateMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
