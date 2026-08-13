import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  static const Color appGreen = Color(0xFFA8E063);
  static const Color darkText = Color(0xFF111827);
  static const Color mutedText = Color(0xFF6B7280);
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color bgColor = Color(0xFFF8FAFC);

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

      setState(() {
        isRead = true;
      });
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

    return "$day-$month-$year • $hour:$minute $amPm";
  }

  IconData _notificationIcon(String title) {
    final value = title.toLowerCase();

    if (value.contains("confirmed")) {
      return Icons.check_circle_outline_rounded;
    }

    if (value.contains("shipped")) {
      return Icons.local_shipping_outlined;
    }

    if (value.contains("delivered")) {
      return Icons.done_all_rounded;
    }

    if (value.contains("processing")) {
      return Icons.sync_rounded;
    }

    if (value.contains("password")) {
      return Icons.lock_outline_rounded;
    }

    return Icons.notifications_active_outlined;
  }

  Color _notificationColor(String title) {
    final value = title.toLowerCase();

    if (value.contains("confirmed")) {
      return const Color(0xFF16A34A);
    }

    if (value.contains("shipped")) {
      return const Color(0xFF2563EB);
    }

    if (value.contains("delivered")) {
      return const Color(0xFF059669);
    }

    if (value.contains("processing")) {
      return const Color(0xFF7C3AED);
    }

    if (value.contains("password")) {
      return const Color(0xFFF59E0B);
    }

    return const Color(0xFF4F46E5);
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.notification['title']?.toString() ?? 'Notification Detail';

    final message = widget.notification['message']?.toString() ??
        'No notification message available.';

    final createdAt = _formatDate(widget.notification['created_at']);

    final iconColor = _notificationColor(title);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appGreen,
        surfaceTintColor: appGreen,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: kToolbarHeight,
        iconTheme: const IconThemeData(
          color: darkText,
        ),
        title: const Text(
          "Notification",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: darkText,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 26),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _topHeader(
                    title: title,
                    iconColor: iconColor,
                  ),
                  const SizedBox(height: 18),
                  _messageCard(
                    title: title,
                    message: message,
                    createdAt: createdAt,
                    iconColor: iconColor,
                  ),
                  const SizedBox(height: 18),
                  _statusCard(),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "BACK TO NOTIFICATIONS",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topHeader({
    required String title,
    required Color iconColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: darkText,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: iconColor.withValues(alpha: 0.25),
              ),
            ),
            child: Icon(
              _notificationIcon(title),
              color: iconColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Notification Message",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "Read complete notification details here.",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageCard({
    required String title,
    required String message,
    required String createdAt,
    required Color iconColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _notificationIcon(title),
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: borderColor,
              ),
            ),
            child: SelectableText(
              message,
              style: const TextStyle(
                color: darkText,
                fontSize: 16,
                height: 1.55,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 18,
                color: mutedText,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  createdAt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: mutedText,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isRead ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isRead ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isRead
                ? Icons.mark_email_read_outlined
                : Icons.mark_email_unread_outlined,
            color: isRead ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isRead
                  ? "This notification is marked as read."
                  : "This notification is unread.",
              style: TextStyle(
                color:
                    isRead ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}