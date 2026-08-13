import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;

  StreamSubscription<List<Map<String, dynamic>>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
    _setupRealtime();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  // ================= FETCH NOTIFICATIONS =================
  Future<void> fetchNotifications() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception("Please login first");
      }

      final data = await supabase
          .from('notifications')
          .select('*')
          .eq('user_id', currentUser.id)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        notifications = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ================= REALTIME NOTIFICATIONS =================
  void _setupRealtime() {
    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) return;

      _notificationSubscription = supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', currentUser.id)
          .order('created_at', ascending: false)
          .listen(
        (data) {
          if (!mounted) return;

          setState(() {
            notifications = List<Map<String, dynamic>>.from(data);
            isLoading = false;
          });
        },
        onError: (error) {
          debugPrint("Notifications realtime error: $error");
        },
      );
    } catch (e) {
      debugPrint("Realtime setup error: $e");
    }
  }

  // ================= OPEN DETAIL SCREEN =================
  void _openNotificationDetail(Map<String, dynamic> notification) {
    Navigator.pushNamed(
      context,
      '/notification_detail',
      arguments: notification,
    ).then((_) {
      fetchNotifications();
    });
  }

  // ================= HELPERS =================
  bool _isRead(Map<String, dynamic> notif) {
    final value = notif['is_read'];

    if (value == true) return true;
    if (value == 1) return true;
    if (value.toString().toLowerCase() == 'true') return true;

    return false;
  }

  int _unreadCount() {
    return notifications.where((notif) => !_isRead(notif)).length;
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString();

    if (raw == null || raw.isEmpty) return "";

    final date = DateTime.tryParse(raw);

    if (date == null) {
      return raw.length >= 16 ? raw.substring(0, 16) : raw;
    }

    final local = date.toLocal();

    return "${local.day.toString().padLeft(2, '0')}-"
        "${local.month.toString().padLeft(2, '0')}-"
        "${local.year}  "
        "${local.hour.toString().padLeft(2, '0')}:"
        "${local.minute.toString().padLeft(2, '0')}";
  }

  Future<void> markAsRead(dynamic id) async {
    try {
      await supabase.from('notifications').update({
        'is_read': true,
      }).eq('id', id);

      if (!mounted) return;

      setState(() {
        notifications = notifications.map((notif) {
          if (notif['id'] == id) {
            return {
              ...notif,
              'is_read': true,
            };
          }
          return notif;
        }).toList();
      });
    } catch (e) {
      debugPrint("Mark read error: $e");
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception("Please login first");
      }

      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', currentUser.id)
          .eq('is_read', false);

      if (!mounted) return;

      setState(() {
        notifications = notifications.map((notif) {
          return {
            ...notif,
            'is_read': true,
          };
        }).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("All notifications marked as read"),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> deleteNotification(dynamic id) async {
    try {
      await supabase.from('notifications').delete().eq('id', id);
    } catch (e) {
      debugPrint("Delete notification error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _unreadCount();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: const Color(0xFFA8E063),
        surfaceTintColor: const Color(0xFFA8E063),
        elevation: 0,
        centerTitle: false,
        toolbarHeight: kToolbarHeight,
        iconTheme: const IconThemeData(
          color: Color(0xFF111827),
        ),
        title: const Text(
          "Notifications",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: markAllAsRead,
              icon: const Icon(
                Icons.done_all_rounded,
                size: 18,
                color: Color(0xFF111827),
              ),
              label: const Text(
                "Read all",
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF111827),
            ),
            onPressed: fetchNotifications,
          ),
          const SizedBox(width: 6),
        ],
      ),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF22C55E),
              ),
            )
          : notifications.isEmpty
              ? _emptyNotificationsView()
              : RefreshIndicator(
                  onRefresh: fetchNotifications,
                  color: const Color(0xFF22C55E),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notif = notifications[index];
                      final isRead = _isRead(notif);

                      return Dismissible(
                        key: Key(notif['id'].toString()),
                        direction: DismissDirection.endToStart,
                        background: _deleteBackground(),
                        onDismissed: (_) {
                          final id = notif['id'];

                          setState(() {
                            notifications.removeWhere(
                              (item) => item['id'] == id,
                            );
                          });

                          deleteNotification(id);
                        },
                        child: NotificationCard(
                          notification: notif,
                          isRead: isRead,
                          formattedDate: _formatDate(notif['created_at']),
                          onTap: () {
                            _openNotificationDetail(notif);
                          },
                        )
                            .animate()
                            .fadeIn(
                              duration: 350.ms,
                              delay: (index * 60).ms,
                            )
                            .slideX(
                              begin: 0.05,
                              end: 0,
                              duration: 350.ms,
                              curve: Curves.easeOutCubic,
                            ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _emptyNotificationsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 46,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.045),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 92,
                width: 92,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  size: 50,
                  color: Color(0xFF6366F1),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "No notifications yet",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "We'll notify you when something important happens.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 350.ms).scale(),
      ),
    );
  }

  Widget _deleteBackground() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.only(right: 22),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: Alignment.centerRight,
      child: const Icon(
        Icons.delete_outline_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}

// ================= NOTIFICATION CARD =================
class NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final bool isRead;
  final String formattedDate;
  final VoidCallback onTap;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.isRead,
    required this.formattedDate,
    required this.onTap,
  });

  IconData _icon() {
    final type = notification['type']?.toString().toLowerCase() ?? '';
    final title = notification['title']?.toString().toLowerCase() ?? '';
    final message = notification['message']?.toString().toLowerCase() ?? '';

    final text = "$type $title $message";

    if (text.contains('confirmed')) {
      return Icons.check_circle_outline_rounded;
    }

    if (text.contains('processing')) {
      return Icons.sync_rounded;
    }

    if (text.contains('shipped')) {
      return Icons.local_shipping_outlined;
    }

    if (text.contains('delivered')) {
      return Icons.done_all_rounded;
    }

    if (text.contains('order')) {
      return Icons.shopping_bag_outlined;
    }

    if (text.contains('payment')) {
      return Icons.payments_outlined;
    }

    if (text.contains('cart')) {
      return Icons.shopping_cart_outlined;
    }

    if (text.contains('password')) {
      return Icons.lock_outline_rounded;
    }

    return Icons.notifications_active_outlined;
  }

  Color _accentColor() {
    final type = notification['type']?.toString().toLowerCase() ?? '';
    final title = notification['title']?.toString().toLowerCase() ?? '';
    final message = notification['message']?.toString().toLowerCase() ?? '';

    final text = "$type $title $message";

    if (text.contains('confirmed')) {
      return const Color(0xFF22C55E);
    }

    if (text.contains('processing')) {
      return const Color(0xFF7C3AED);
    }

    if (text.contains('shipped')) {
      return const Color(0xFF2563EB);
    }

    if (text.contains('delivered')) {
      return const Color(0xFF059669);
    }

    if (text.contains('payment')) {
      return const Color(0xFFF59E0B);
    }

    if (text.contains('cart')) {
      return const Color(0xFFEC4899);
    }

    if (text.contains('password')) {
      return const Color(0xFFF59E0B);
    }

    return const Color(0xFF6366F1);
  }

  @override
  Widget build(BuildContext context) {
    final title = notification['title']?.toString() ?? 'Notification';
    final message = notification['message']?.toString() ?? '';
    final accent = _accentColor();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isRead ? const Color(0xFFE5E7EB) : accent.withValues(alpha: 0.24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isRead ? 0.04 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (!isRead)
              Positioned(
                left: 0,
                top: 18,
                bottom: 18,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(100),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent,
                          accent.withValues(alpha: 0.72),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(17),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.22),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      _icon(),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isRead
                                      ? const Color(0xFF111827)
                                      : const Color(0xFF1E40AF),
                                  fontSize: 15.5,
                                  fontWeight:
                                      isRead ? FontWeight.w700 : FontWeight.w900,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            if (!isRead)
                              Container(
                                height: 9,
                                width: 9,
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                formattedDate,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Tap to read",
                              style: TextStyle(
                                color: accent,
                                fontSize: 11.8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: accent,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}