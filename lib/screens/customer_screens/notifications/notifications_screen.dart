import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../orders/order_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;
  String selectedFilter = 'All';

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
          .or('user_id.eq.${currentUser.id},user_id.is.null')
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
          content: Text("Error fetching notifications: $e"),
          backgroundColor: AppColors.roseRed,
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
          .order('created_at', ascending: false)
          .listen(
            (data) {
              if (!mounted) return;
              final userNotifs = data.where((item) {
                final uid = item['user_id'];
                return uid == null || uid == currentUser.id;
              }).toList();

              setState(() {
                notifications = List<Map<String, dynamic>>.from(userNotifs);
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

  List<Map<String, dynamic>> get filteredNotifications {
    if (selectedFilter == 'All') return notifications;
    if (selectedFilter == 'Unread') {
      return notifications.where((notif) => !_isRead(notif)).toList();
    }
    
    return notifications.where((notif) {
      final type = notif['type']?.toString().toLowerCase() ?? '';
      final title = notif['title']?.toString().toLowerCase() ?? '';
      final message = notif['message']?.toString().toLowerCase() ?? '';
      final combined = "$type $title $message";

      if (selectedFilter == 'Orders') {
        return combined.contains('order') ||
            combined.contains('shipped') ||
            combined.contains('delivered') ||
            combined.contains('confirmed') ||
            combined.contains('processing');
      } else if (selectedFilter == 'Offers') {
        return combined.contains('promo') ||
            combined.contains('sale') ||
            combined.contains('discount') ||
            combined.contains('offer');
      }
      return true;
    }).toList();
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return "";
    final date = DateTime.tryParse(raw);
    if (date == null) {
      return raw.length >= 16 ? raw.substring(0, 16) : raw;
    }
    final local = date.toLocal();
    final now = DateTime.now();
    final difference = now.difference(local);

    if (difference.inMinutes < 1) return "Just now";
    if (difference.inMinutes < 60) return "${difference.inMinutes}m ago";
    if (difference.inHours < 24) return "${difference.inHours}h ago";

    return "${local.day.toString().padLeft(2, '0')}-"
        "${local.month.toString().padLeft(2, '0')}-"
        "${local.year} ${local.hour.toString().padLeft(2, '0')}:"
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
            return {...notif, 'is_read': true};
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
      if (currentUser == null) return;

      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', currentUser.id)
          .eq('is_read', false);

      if (!mounted) return;
      setState(() {
        notifications = notifications.map((notif) => {...notif, 'is_read': true}).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("All notifications marked as read!"),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.roseRed),
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

  void _openNotificationDetail(Map<String, dynamic> notification) {
    markAsRead(notification['id']);
    
    // Check if notification has order_id
    final orderId = notification['order_id'];
    if (orderId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderDetailScreen(order: {'id': orderId}),
        ),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      '/notification_detail',
      arguments: notification,
    ).then((_) => fetchNotifications());
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _unreadCount();
    final displayList = filteredNotifications;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      // ================= PURE WHITE STYLUXE APP BAR =================
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.slateDark, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Notifications",
          style: TextStyle(
            color: AppColors.slateDark,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          if (unreadCount > 0)
            IconButton(
              tooltip: "Mark all read",
              icon: const Icon(Icons.done_all_rounded, color: AppColors.primary, size: 20),
              onPressed: markAllAsRead,
            ),
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Icons.refresh_rounded, color: AppColors.slateDark, size: 20),
            onPressed: fetchNotifications,
          ),
          const SizedBox(width: 4),
        ],
      ),

      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              children: [
                // ================= FILTER TABS =================
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: ['All', 'Unread', 'Orders', 'Offers'].map((filter) {
                        final isSelected = selectedFilter == filter;
                        String labelText = filter;
                        if (filter == 'Unread' && unreadCount > 0) {
                          labelText = "Unread ($unreadCount)";
                        }

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(labelText),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => selectedFilter = filter);
                              }
                            },
                            selectedColor: AppColors.primary,
                            backgroundColor: const Color(0xFFF1F5F9),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.slateDark,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 12.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            showCheckmark: false,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // ================= BODY CONTENT =================
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        )
                      : displayList.isEmpty
                          ? _emptyNotificationsView()
                          : RefreshIndicator(
                              onRefresh: fetchNotifications,
                              color: AppColors.primary,
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                                itemCount: displayList.length,
                                itemBuilder: (context, index) {
                                  final notif = displayList[index];
                                  final isRead = _isRead(notif);

                                  return Dismissible(
                                    key: Key(notif['id'].toString()),
                                    direction: DismissDirection.endToStart,
                                    background: _deleteBackground(),
                                    onDismissed: (_) {
                                      final id = notif['id'];
                                      setState(() {
                                        notifications.removeWhere((item) => item['id'] == id);
                                      });
                                      deleteNotification(id);
                                    },
                                    child: NotificationTileCard(
                                      notification: notif,
                                      isRead: isRead,
                                      formattedDate: _formatDate(notif['created_at']),
                                      onTap: () => _openNotificationDetail(notif),
                                    ).animate().fadeIn(duration: 300.ms, delay: (index * 45).ms).slideY(begin: 0.05),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyNotificationsView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_off_outlined,
                  size: 42,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "You're All Caught Up!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.slateDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "No notifications in this section. We'll update you as soon as new activity occurs.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.slateMuted,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 350.ms).scale(begin: const Offset(0.95, 0.95)),
      ),
    );
  }

  Widget _deleteBackground() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: AppColors.roseRed,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.centerRight,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
          SizedBox(width: 6),
          Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
        ],
      ),
    );
  }
}

// ================= NOTIFICATION TILE CARD =================
class NotificationTileCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final bool isRead;
  final String formattedDate;
  final VoidCallback onTap;

  const NotificationTileCard({
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

    if (text.contains('confirmed')) return Icons.check_circle_outline_rounded;
    if (text.contains('processing')) return Icons.sync_rounded;
    if (text.contains('shipped')) return Icons.local_shipping_outlined;
    if (text.contains('delivered')) return Icons.done_all_rounded;
    if (text.contains('order')) return Icons.shopping_bag_outlined;
    if (text.contains('payment')) return Icons.payments_outlined;
    if (text.contains('promo') || text.contains('sale') || text.contains('discount')) return Icons.local_offer_outlined;
    if (text.contains('password') || text.contains('security')) return Icons.lock_outline_rounded;

    return Icons.notifications_active_outlined;
  }

  Color _accentColor() {
    final type = notification['type']?.toString().toLowerCase() ?? '';
    final title = notification['title']?.toString().toLowerCase() ?? '';
    final message = notification['message']?.toString().toLowerCase() ?? '';
    final text = "$type $title $message";

    if (text.contains('confirmed') || text.contains('delivered')) return AppColors.primary;
    if (text.contains('shipped')) return const Color(0xFF3B82F6);
    if (text.contains('processing')) return const Color(0xFF8B5CF6);
    if (text.contains('promo') || text.contains('sale') || text.contains('discount')) return AppColors.roseRed;
    if (text.contains('payment')) return const Color(0xFFF59E0B);
    return const Color(0xFF6366F1);
  }

  @override
  Widget build(BuildContext context) {
    final title = notification['title']?.toString() ?? 'Notification';
    final message = notification['message']?.toString() ?? '';
    final accent = _accentColor();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isRead ? const Color(0xFFE2E8F0) : AppColors.primary.withValues(alpha: 0.28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isRead ? 0.025 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Badge
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _icon(),
                  color: accent,
                  size: 22,
                ),
              ),

              const SizedBox(width: 12),

              // Title & Message Content
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
                              color: AppColors.slateDark,
                              fontSize: 14.5,
                              fontWeight: isRead ? FontWeight.w700 : FontWeight.w900,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            height: 8,
                            width: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.slateMuted,
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 12, color: AppColors.slateLight),
                            const SizedBox(width: 4),
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                color: AppColors.slateLight,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              "View details",
                              style: TextStyle(
                                color: accent,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: accent),
                          ],
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
    );
  }
}