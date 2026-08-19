import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../services/banner_service.dart';

class AdminBannerFormScreen extends StatefulWidget {
  final HomeBannerItem? existing;
  const AdminBannerFormScreen({super.key, this.existing});

  @override
  State<AdminBannerFormScreen> createState() => _AdminBannerFormScreenState();
}

class _AdminBannerFormScreenState extends State<AdminBannerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late TextEditingController _tagController;
  late TextEditingController _codeController;

  late String _selectedStart;
  late String _selectedEnd;
  late String _selectedIcon;
  bool _isActive = true;
  bool _isSaving = false;
  bool _isDeleting = false;

  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  final List<Map<String, dynamic>> _themePresets = [
    {
      'name': 'Emerald Luxe',
      'start': '0xFF047857',
      'end': '0xFF10B981',
      'colors': [Color(0xFF047857), Color(0xFF10B981)],
    },
    {
      'name': 'Royal Indigo',
      'start': '0xFF4338CA',
      'end': '0xFF6366F1',
      'colors': [Color(0xFF4338CA), Color(0xFF6366F1)],
    },
    {
      'name': 'Ruby Rose',
      'start': '0xFFBE123C',
      'end': '0xFFF43F5E',
      'colors': [Color(0xFFBE123C), Color(0xFFF43F5E)],
    },
    {
      'name': 'Midnight Slate',
      'start': '0xFF0F172A',
      'end': '0xFF334155',
      'colors': [Color(0xFF0F172A), Color(0xFF334155)],
    },
    {
      'name': 'Sunset Amber',
      'start': '0xFFD97706',
      'end': '0xFFF59E0B',
      'colors': [Color(0xFFD97706), Color(0xFFF59E0B)],
    },
    {
      'name': 'Cyan Ice',
      'start': '0xFF0284C7',
      'end': '0xFF0EA5E9',
      'colors': [Color(0xFF0284C7), Color(0xFF0EA5E9)],
    },
  ];

  final List<Map<String, dynamic>> _iconPresets = [
    {'name': 'local_offer', 'label': 'Offer Badge', 'icon': Icons.local_offer_rounded},
    {'name': 'celebration', 'label': 'Celebration / Festival', 'icon': Icons.celebration_rounded},
    {'name': 'bolt', 'label': 'Flash / Fast Deal', 'icon': Icons.bolt_rounded},
    {'name': 'local_shipping', 'label': 'Free Shipping / Delivery', 'icon': Icons.local_shipping_rounded},
    {'name': 'diamond', 'label': 'Luxury / Premium', 'icon': Icons.diamond_rounded},
    {'name': 'star', 'label': 'Featured / Popular', 'icon': Icons.star_rounded},
    {'name': 'fire', 'label': 'Hot Sale / Trend', 'icon': Icons.local_fire_department_rounded},
    {'name': 'shopping_bag', 'label': 'Shopping Special', 'icon': Icons.shopping_bag_rounded},
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleController = TextEditingController(text: e?.title ?? '');
    _subtitleController = TextEditingController(text: e?.subtitle ?? '');
    _tagController = TextEditingController(text: e?.discountTag ?? 'SPECIAL OFFER');
    _codeController = TextEditingController(text: e?.promoCode ?? '');

    _selectedStart = e?.gradientStart ?? _themePresets.first['start'];
    _selectedEnd = e?.gradientEnd ?? _themePresets.first['end'];
    _selectedIcon = e?.iconName ?? 'local_offer';
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _tagController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  IconData _getIconData(String name) {
    for (final ip in _iconPresets) {
      if (ip['name'] == name) return ip['icon'] as IconData;
    }
    return Icons.local_offer_rounded;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final banner = HomeBannerItem(
      id: widget.existing?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      subtitle: _subtitleController.text.trim(),
      discountTag: _tagController.text.trim(),
      promoCode: _codeController.text.trim().isNotEmpty ? _codeController.text.trim() : null,
      gradientStart: _selectedStart,
      gradientEnd: _selectedEnd,
      iconName: _selectedIcon,
      isActive: _isActive,
      orderIndex: widget.existing?.orderIndex ?? 0,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    await BannerService.saveBanner(banner);

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.pop(context, true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.existing != null ? "Banner updated successfully!" : "New Banner published to Home Slider!",
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5),
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleDelete() async {
    if (widget.existing == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              "Delete Banner?",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15, color: slateDark),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to permanently delete '${widget.existing!.title}' from the Home carousel?",
          style: GoogleFonts.poppins(color: slateMuted, fontSize: 12.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: GoogleFonts.poppins(color: slateMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              minimumSize: const Size(80, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Delete", style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    await BannerService.deleteBanner(widget.existing!.id);

    if (!mounted) return;
    setState(() => _isDeleting = false);
    Navigator.pop(context, true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Banner deleted successfully", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

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
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Header Banner
                    _buildHeaderBanner(isEditing),

                    const SizedBox(height: 12),

                    // 2. Live Card Preview
                    _buildLiveCardPreview(),

                    const SizedBox(height: 14),

                    // 3. Form Card Container
                    _buildFormCard(),

                    const SizedBox(height: 18),

                    // 4. Bottom Action Buttons
                    _buildActionButtons(isEditing),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================= 1. HEADER BANNER =================
  Widget _buildHeaderBanner(bool isEditing) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: primaryTeal,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryTeal.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isEditing ? Icons.edit_note_rounded : Icons.add_photo_alternate_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? "Edit Promo Slider" : "Create New Promo Slider",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                Text(
                  isEditing
                      ? "Modify slider text, colors, tag & promo code"
                      : "Configure visual promotion for Customer Home carousel",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.04);
  }

  // ================= 2. LIVE CARD PREVIEW =================
  Widget _buildLiveCardPreview() {
    List<Color> colors;
    try {
      colors = [Color(int.parse(_selectedStart)), Color(int.parse(_selectedEnd))];
    } catch (_) {
      colors = [primaryTeal, const Color(0xFF10B981)];
    }

    final title = _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : "Banner Title Preview";
    final sub = _subtitleController.text.trim().isNotEmpty ? _subtitleController.text.trim() : "Your promotional offer and details will appear here";
    final tag = _tagController.text.trim().isNotEmpty ? _tagController.text.trim() : "SPECIAL OFFER";
    final code = _codeController.text.trim();
    final icon = _getIconData(_selectedIcon);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const Icon(Icons.remove_red_eye_rounded, color: slateMuted, size: 14),
              const SizedBox(width: 6),
              Text(
                "Live Customer Slider Preview",
                style: GoogleFonts.poppins(color: slateMuted, fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 5),
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
                      runSpacing: 3,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tag.toUpperCase(),
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (code.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              "Code: $code",
                              style: GoogleFonts.poppins(color: slateDark, fontSize: 9, fontWeight: FontWeight.w800),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.9), fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================= 3. FORM CARD CONTAINER =================
  Widget _buildFormCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Title Field
          _buildInputLabel("Banner Title *"),
          TextFormField(
            controller: _titleController,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.poppins(fontSize: 12.5, color: slateDark),
            decoration: _inputDecoration("e.g. Summer Clearance Luxe"),
            validator: (v) => v == null || v.trim().isEmpty ? "Title is required" : null,
          ),

          const SizedBox(height: 10),

          // 2. Subtitle Field
          _buildInputLabel("Subtitle / Short Message *"),
          TextFormField(
            controller: _subtitleController,
            onChanged: (_) => setState(() {}),
            maxLines: 2,
            style: GoogleFonts.poppins(fontSize: 12.5, color: slateDark),
            decoration: _inputDecoration("e.g. UPTO 50% OFF on Luxury Dresses & Shoes"),
            validator: (v) => v == null || v.trim().isEmpty ? "Subtitle is required" : null,
          ),

          const SizedBox(height: 10),

          // 3. Tag & Code Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel("Discount Tag *"),
                    TextFormField(
                      controller: _tagController,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.poppins(fontSize: 12.5, color: slateDark),
                      decoration: _inputDecoration("e.g. 50% OFF"),
                      validator: (v) => v == null || v.trim().isEmpty ? "Tag required" : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel("Coupon Code"),
                    TextFormField(
                      controller: _codeController,
                      onChanged: (_) => setState(() {}),
                      textCapitalization: TextCapitalization.characters,
                      style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: slateDark),
                      decoration: _inputDecoration("e.g. SUMMER50 (Optional)"),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 4. Banner Icon Selector (DROPDOWN)
          _buildInputLabel("Banner Icon (Dropdown)"),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: bgLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedIcon,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: slateMuted, size: 20),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(12),
                items: _iconPresets.map((ip) {
                  final name = ip['name'] as String;
                  final label = ip['label'] as String;
                  final icon = ip['icon'] as IconData;

                  return DropdownMenuItem<String>(
                    value: name,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: primaryTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(icon, size: 16, color: primaryTeal),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          label,
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: slateDark),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedIcon = val);
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 5. Theme Color Gradient Presets
          _buildInputLabel("Color Gradient Theme"),
          const SizedBox(height: 2),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _themePresets.map((tp) {
                final isSelected = _selectedStart == tp['start'];
                final colors = tp['colors'] as List<Color>;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedStart = tp['start'];
                        _selectedEnd = tp['end'];
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: colors),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: colors.first.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        tp['name'] as String,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // 6. Active Switch Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Active on Home Slider",
                    style: GoogleFonts.poppins(color: slateDark, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    "Display immediately in customer carousel",
                    style: GoogleFonts.poppins(color: slateMuted, fontSize: 10),
                  ),
                ],
              ),
              Transform.scale(
                scale: 0.72,
                child: Switch(
                  value: _isActive,
                  activeThumbColor: primaryTeal,
                  activeTrackColor: primaryTeal.withValues(alpha: 0.4),
                  onChanged: (val) => setState(() => _isActive = val),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= 4. BOTTOM ACTION BUTTONS =================
  Widget _buildActionButtons(bool isEditing) {
    if (!isEditing) {
      // Single Create Button
      return SizedBox(
        width: double.infinity,
        height: 44,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryTeal,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.zero,
            alignment: Alignment.center,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(
                  "Save & Publish Banner",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, height: 1.2),
                ),
        ),
      );
    }

    // Two Buttons: Update & Delete
    return Row(
      children: [
        // Update Button
        Expanded(
          flex: 6,
          child: SizedBox(
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryTeal,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.zero,
                alignment: Alignment.center,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: (_isSaving || _isDeleting) ? null : _handleSave,
              child: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      "Update",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.2),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Delete Button (Refined Luxury Red)
        Expanded(
          flex: 4,
          child: SizedBox(
            height: 44,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFF87171), width: 1.2),
                backgroundColor: const Color(0xFFFEF2F2),
                elevation: 0,
                padding: EdgeInsets.zero,
                alignment: Alignment.center,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: (_isSaving || _isDeleting) ? null : _handleDelete,
              child: _isDeleting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Color(0xFFDC2626), strokeWidth: 2))
                  : Text(
                      "Delete",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: const Color(0xFFDC2626),
                        height: 1.2,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        text,
        style: GoogleFonts.poppins(color: slateDark, fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(color: slateMuted.withValues(alpha: 0.6), fontSize: 11.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      filled: true,
      fillColor: bgLight,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: primaryTeal, width: 1.5)),
    );
  }
}
