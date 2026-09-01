import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/admin_notification_service.dart';

class AdminNotificationsScreen extends StatefulWidget {
  final bool isStandalone;
  const AdminNotificationsScreen({super.key, this.isStandalone = true});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _promoController = TextEditingController();

  String _selectedAudience = 'all'; // 'all', 'customers', 'sellers'
  String _selectedType = 'announcement'; // 'announcement', 'offer', 'alert', 'system'

  bool _isSending = false;
  bool _isLoadingHistory = true;
  List<BroadcastItem> _history = [];

  static const Color primaryTeal = Color(0xFF10B981);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  final Map<String, Map<String, dynamic>> _typeConfigs = {
    'announcement': {
      'label': 'Announcement',
      'icon': Icons.campaign_rounded,
      'color': const Color(0xFF10B981),
      'bgColor': const Color(0xFFE6F4EA),
    },
    'offer': {
      'label': 'Offer / Sale',
      'icon': Icons.local_fire_department_rounded,
      'color': const Color(0xFFEF4444),
      'bgColor': const Color(0xFFFEE2E2),
    },
    'alert': {
      'label': 'Important Alert',
      'icon': Icons.warning_amber_rounded,
      'color': const Color(0xFFF59E0B),
      'bgColor': const Color(0xFFFEF3C7),
    },
    'system': {
      'label': 'System Update',
      'icon': Icons.build_circle_rounded,
      'color': const Color(0xFF3B82F6),
      'bgColor': const Color(0xFFEFF6FF),
    },
  };

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    final history = await AdminNotificationService.getBroadcastHistory();
    if (!mounted) return;
    setState(() {
      _history = history;
      _isLoadingHistory = false;
    });
  }

  Future<void> _handleSendBroadcast() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    final promo = _promoController.text.trim();

    String audienceName = "All Users & Sellers";
    if (_selectedAudience == 'customers') audienceName = "All Customers";
    if (_selectedAudience == 'sellers') audienceName = "All Registered Sellers";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.send_rounded, color: primaryTeal, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              "Send Broadcast?",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: slateDark),
            ),
          ],
        ),
        content: Text(
          "This will instantly deliver this notification to $audienceName.",
          style: GoogleFonts.poppins(color: slateMuted, fontSize: 12.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: GoogleFonts.poppins(color: slateMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryTeal,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Confirm & Send", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSending = true);

    final res = await AdminNotificationService.sendBroadcast(
      title: title,
      message: message,
      targetAudience: _selectedAudience,
      type: _selectedType,
      promoCode: promo.isNotEmpty ? promo : null,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (res['success'] == true) {
      _titleController.clear();
      _messageController.clear();
      _promoController.clear();
      _loadHistory();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Broadcast Sent successfully to ${res['recipientCount']} recipient(s)!",
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to send: ${res['error'] ?? 'Unknown error'}",
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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

              // 2. Notification Creator Card
              _buildCreatorCard(),

              const SizedBox(height: 14),

              // 3. Live Notification Preview
              _buildLivePreview(),

              const SizedBox(height: 20),

              // 4. Sent Broadcast History Section
              _buildHistorySection(),
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
          toolbarHeight: 46.0,
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slateDark, size: 18),
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
            child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Push Broadcast Hub",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Text(
                  "Broadcast instant notifications to buyers & sellers",
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

  // ================= 2. CREATOR CARD =================
  Widget _buildCreatorCard() {
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Audience Selector Label
            Row(
              children: [
                const Icon(Icons.group_rounded, color: primaryTeal, size: 16),
                const SizedBox(width: 6),
                Text(
                  "Select Target Audience",
                  style: GoogleFonts.poppins(
                    color: slateDark,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Audience Pills
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildAudienceChip('all', '👥 All Users', 'Customers + Sellers'),
                _buildAudienceChip('customers', '🛍️ Customers Only', 'Registered Buyers'),
                _buildAudienceChip('sellers', '🏪 Sellers Only', 'Store Owners'),
              ],
            ),

            const SizedBox(height: 14),

            // Notification Type Selector
            Row(
              children: [
                const Icon(Icons.category_rounded, color: primaryTeal, size: 16),
                const SizedBox(width: 6),
                Text(
                  "Notification Category",
                  style: GoogleFonts.poppins(
                    color: slateDark,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Type Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _typeConfigs.entries.map((entry) {
                  final key = entry.key;
                  final cfg = entry.value;
                  final isSelected = _selectedType == key;
                  final color = cfg['color'] as Color;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => setState(() => _selectedType = key),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? color.withValues(alpha: 0.12) : bgLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? color : borderColor,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cfg['icon'] as IconData, color: isSelected ? color : slateMuted, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              cfg['label'] as String,
                              style: GoogleFonts.poppins(
                                color: isSelected ? color : slateDark,
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 14),

            // Notification Title Input
            Text(
              "Notification Title *",
              style: GoogleFonts.poppins(color: slateDark, fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _titleController,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.poppins(fontSize: 12.5, color: slateDark),
              decoration: InputDecoration(
                hintText: "e.g. Flash Weekend Sale is Live! 🔥",
                hintStyle: GoogleFonts.poppins(color: slateMuted.withValues(alpha: 0.6), fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: bgLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryTeal, width: 1.5)),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? "Title is required" : null,
            ),

            const SizedBox(height: 12),

            // Message Body Input
            Text(
              "Notification Message *",
              style: GoogleFonts.poppins(color: slateDark, fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _messageController,
              onChanged: (_) => setState(() {}),
              maxLines: 3,
              style: GoogleFonts.poppins(fontSize: 12.5, color: slateDark),
              decoration: InputDecoration(
                hintText: "Enter the complete announcement message for your users...",
                hintStyle: GoogleFonts.poppins(color: slateMuted.withValues(alpha: 0.6), fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: bgLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryTeal, width: 1.5)),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? "Message body is required" : null,
            ),

            const SizedBox(height: 12),

            // Optional Promo Code Input
            Text(
              "Promo Voucher Code (Optional)",
              style: GoogleFonts.poppins(color: slateDark, fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _promoController,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.characters,
              style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: slateDark),
              decoration: InputDecoration(
                hintText: "e.g. STYLUXE20",
                hintStyle: GoogleFonts.poppins(color: slateMuted.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w400),
                prefixIcon: const Icon(Icons.confirmation_number_outlined, color: primaryTeal, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: bgLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryTeal, width: 1.5)),
              ),
            ),

            const SizedBox(height: 16),

            // Send Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryTeal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  alignment: Alignment.center,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSending ? null : _handleSendBroadcast,
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                label: Text(
                  _isSending ? "Broadcasting..." : "Send Broadcast Now",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 300.ms);
  }

  Widget _buildAudienceChip(String key, String label, String sub) {
    final isSelected = _selectedAudience == key;
    return InkWell(
      onTap: () => setState(() => _selectedAudience = key),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryTeal.withValues(alpha: 0.12) : bgLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? primaryTeal : borderColor,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? primaryTeal : slateDark,
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ================= 3. LIVE PREVIEW =================
  Widget _buildLivePreview() {
    final cfg = _typeConfigs[_selectedType] ?? _typeConfigs['announcement']!;
    final color = cfg['color'] as Color;
    final icon = cfg['icon'] as IconData;

    final previewTitle = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : "Notification Title Preview";
    final previewMsg = _messageController.text.trim().isNotEmpty
        ? _messageController.text.trim()
        : "Your notification content will be formatted and presented cleanly here to all targeted users.";
    final promo = _promoController.text.trim();

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
                "Live User Inbox Preview",
                style: GoogleFonts.poppins(color: slateMuted, fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            previewTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(color: slateDark, fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          "Just now",
                          style: GoogleFonts.poppins(color: slateMuted, fontSize: 10, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      previewMsg,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(color: slateMuted, fontSize: 11, height: 1.3),
                    ),
                    if (promo.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: primaryTeal.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          "CODE: $promo",
                          style: GoogleFonts.poppins(color: primaryTeal, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================= 4. BROADCAST HISTORY =================
  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded, color: primaryTeal, size: 16),
                const SizedBox(width: 6),
                Text(
                  "Sent Broadcast Logs",
                  style: GoogleFonts.poppins(
                    color: slateDark,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: slateMuted, size: 18),
              onPressed: _loadHistory,
              tooltip: "Refresh logs",
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_isLoadingHistory)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: primaryTeal, strokeWidth: 2)))
        else if (_history.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, color: slateMuted.withValues(alpha: 0.5), size: 36),
                const SizedBox(height: 8),
                Text(
                  "No broadcast history yet",
                  style: GoogleFonts.poppins(color: slateDark, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                Text(
                  "When you send announcements, they will be logged here.",
                  style: GoogleFonts.poppins(color: slateMuted, fontSize: 11),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _history.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = _history[index];
              final cfg = _typeConfigs[item.type] ?? _typeConfigs['announcement']!;
              final color = cfg['color'] as Color;
              final icon = cfg['icon'] as IconData;

              String audienceLabel = "All Users";
              if (item.targetAudience == 'customers') audienceLabel = "Customers";
              if (item.targetAudience == 'sellers') audienceLabel = "Sellers";

              final timeStr = "${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year} • ${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}";

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, color: color, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(color: slateDark, fontSize: 12.5, fontWeight: FontWeight.w700),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: bgLight,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Text(
                                  audienceLabel,
                                  style: GoogleFonts.poppins(color: slateDark, fontSize: 9.5, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(color: slateMuted, fontSize: 11),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.people_alt_outlined, color: primaryTeal, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${item.recipientCount} delivered",
                                    style: GoogleFonts.poppins(color: primaryTeal, fontSize: 10, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    timeStr,
                                    style: GoogleFonts.poppins(color: slateMuted, fontSize: 9.5),
                                  ),
                                ],
                              ),
                              InkWell(
                                onTap: () async {
                                  await AdminNotificationService.deleteHistoryItem(item.id);
                                  _loadHistory();
                                },
                                child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
