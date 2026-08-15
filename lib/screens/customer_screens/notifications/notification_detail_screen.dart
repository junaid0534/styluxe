import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';

class NotificationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> notification;

  const NotificationDetailScreen({
    super.key,
    required this.notification,
  });

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  final supabase = Supabase.instance.client;
  late bool isRead;

  @override
  void initState() {
    super.initState();
    isRead = widget.notification['is_read'] == true ||
        widget.notification['is_read'].toString().toLowerCase() == 'true';

    markAsRead();
  }

  Future<void> markAsRead() async {
    try {
      final notificationId = widget.notification['id'];
      if (notificationId == null || isRead) return;

      await supabase.from('notifications').update({
        'is_read': true,
      }).eq('id', notificationId);

      if (!mounted) return;
      setState(() => isRead = true);
    } catch (e) {
      debugPrint("Mark notification read error: $e");
    }
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return "N/A";
    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();

    int hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final amPm = hour >= 12 ? "PM" : "AM";

    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }

    return "$day-$month-$year  •  $hour:$minute $amPm";
  }

  IconData _notificationIcon(String title) {
    final value = title.toLowerCase();
    if (value.contains("confirmed")) return Icons.check_circle_outline_rounded;
    if (value.contains("shipped")) return Icons.local_shipping_outlined;
    if (value.contains("delivered")) return Icons.done_all_rounded;
    if (value.contains("processing")) return Icons.sync_rounded;
    if (value.contains("password")) return Icons.lock_outline_rounded;
    if (value.contains("promo") || value.contains("sale")) return Icons.local_offer_outlined;

    return Icons.notifications_active_outlined;
  }



  @override
  Widget build(BuildContext context) {
    final title = widget.notification['title']?.toString() ?? 'Notification';
    final message = widget.notification['message']?.toString() ?? 'No detail message available.';
    final createdAt = _formatDate(widget.notification['created_at']);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      // ================= PURE WHITE STYLUXE APP BAR =================
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.slateDark, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Notification Detail",
          style: TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),

      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                children: [
                  // ================= STYLUXE HERO CARD =================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.26),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _notificationIcon(title),
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                createdAt,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05),

                  const SizedBox(height: 20),

                  // ================= MESSAGE BODY CARD =================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "NOTIFICATION DETAILS",
                          style: TextStyle(
                            color: AppColors.slateMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          message,
                          style: const TextStyle(
                            color: AppColors.slateDark,
                            fontSize: 14.5,
                            height: 1.55,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),

                  const SizedBox(height: 24),

                  // ================= BACK BUTTON =================
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                    label: const Text("Back to Notifications", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      elevation: 0,
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}