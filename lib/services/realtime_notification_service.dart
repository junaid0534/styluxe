import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Global service providing Realtime Push Notifications with Sound & Mobile System Banners
/// for both Buyer and Seller apps.
class RealtimeNotificationService {
  static final RealtimeNotificationService _instance = RealtimeNotificationService._internal();
  factory RealtimeNotificationService() => _instance;
  RealtimeNotificationService._internal();

  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final SupabaseClient _supabase = Supabase.instance.client;

  static RealtimeChannel? _notificationChannel;
  static RealtimeChannel? _ordersChannel;
  static StreamSubscription<List<Map<String, dynamic>>>? _notificationStreamSub;
  static final Set<String> _knownNotificationIds = {};
  static bool _isFirstStreamLoad = true;
  static String? _currentListeningUserId;
  static GlobalKey<NavigatorState>? navigatorKey;

  // Android Notification Channels
  static const AndroidNotificationChannel _orderChannel = AndroidNotificationChannel(
    'styluxe_orders_channel',
    'Order & Sales Alerts',
    description: 'High-priority real-time notifications for incoming orders and status updates with sound',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _generalChannel = AndroidNotificationChannel(
    'styluxe_general_channel',
    'General Alerts & Updates',
    description: 'Promotions, messages, and general app announcements',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// Initialize Local Notification Plugin & Notification Channels
  static Future<void> initialize({GlobalKey<NavigatorState>? navKey}) async {
    navigatorKey = navKey;

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Notification Channels on Android
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_orderChannel);
      await androidPlugin.createNotificationChannel(_generalChannel);

      // Request runtime notification permission for Android 13+
      try {
        await androidPlugin.requestNotificationsPermission();
      } catch (e) {
        debugPrint("Notification permission request error: $e");
      }
    }

    // Bind current user if already logged in
    final currentUser = _supabase.auth.currentUser;
    if (currentUser != null) {
      startListening(currentUser.id);
    }

    // Listen to Supabase Auth state changes (Auto Bind / Unbind on Login / Logout)
    _supabase.auth.onAuthStateChange.listen((data) {
      final user = data.session?.user;
      if (user != null) {
        startListening(user.id);
      } else {
        stopListening();
      }
    });
  }

  /// Start Realtime WebSocket & Stream Listening for the given User
  static void startListening(String userId) {
    if (_currentListeningUserId == userId && _notificationStreamSub != null) {
      return; // Already listening
    }

    stopListening();
    _currentListeningUserId = userId;
    _isFirstStreamLoad = true;
    _knownNotificationIds.clear();

    debugPrint("🔔 [RealtimeNotificationService] Starting real-time listener for user: $userId");

    try {
      // 1. Primary Reliable Stream Subscription
      _notificationStreamSub = _supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .listen(
            (List<Map<String, dynamic>> items) {
              if (_isFirstStreamLoad) {
                for (final item in items) {
                  final id = item['id']?.toString();
                  if (id != null) _knownNotificationIds.add(id);
                }
                _isFirstStreamLoad = false;
                return;
              }

              for (final item in items) {
                final id = item['id']?.toString();
                final itemUserId = item['user_id']?.toString();

                if (id != null && !_knownNotificationIds.contains(id)) {
                  _knownNotificationIds.add(id);

                  if (itemUserId == null || itemUserId == userId) {
                    final title = item['title']?.toString() ?? 'Styluxe Alert';
                    final message = item['message']?.toString() ?? '';
                    final type = item['type']?.toString() ?? 'alert';

                    debugPrint("🔔 Stream new notification received: $title - $message");
                    showNotification(
                      title: title,
                      body: message,
                      payload: jsonEncode(item),
                      type: type,
                    );
                  }
                }
              }
            },
            onError: (err) {
              debugPrint("Notification stream error: $err");
            },
          );

      // 2. Secondary Realtime Channel for Instant Order Alerts to Seller
      _ordersChannel = _supabase
          .channel('realtime_seller_orders_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'seller_id',
              value: userId,
            ),
            callback: (payload) {
              final ord = payload.newRecord;
              final customerName = ord['customer_name']?.toString() ?? 'A customer';
              final total = (ord['total_amount'] as num?)?.toDouble() ?? 0.0;
              final orderId = ord['id']?.toString() ?? '';

              debugPrint("🛍️ Realtime new order received for seller: $orderId from $customerName");
              showNotification(
                title: '🛍️ New Order Received!',
                body: '$customerName placed an order for Rs. ${total.toStringAsFixed(0)}',
                payload: jsonEncode({
                  'order_id': orderId,
                  'type': 'new_order',
                  'customer_name': customerName,
                }),
                type: 'new_order',
              );
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint("Error starting realtime notification listener: $e");
    }
  }

  /// Stop all active Realtime Channels
  static void stopListening() {
    _notificationStreamSub?.cancel();
    _notificationStreamSub = null;

    if (_notificationChannel != null) {
      _supabase.removeChannel(_notificationChannel!);
      _notificationChannel = null;
    }
    if (_ordersChannel != null) {
      _supabase.removeChannel(_ordersChannel!);
      _ordersChannel = null;
    }
    _currentListeningUserId = null;
    _knownNotificationIds.clear();
    _isFirstStreamLoad = true;
  }

  /// Display a Native Heads-Up Mobile Notification with Sound & Vibration
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    String type = 'alert',
  }) async {
    final int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    final bool isOrder = type == 'new_order' || type == 'order' || type == 'status_change';

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      isOrder ? _orderChannel.id : _generalChannel.id,
      isOrder ? _orderChannel.name : _generalChannel.name,
      channelDescription: isOrder ? _orderChannel.description : _generalChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: isOrder ? 'Order Alert' : 'Styluxe',
      ),
      color: const Color(0xFF2563EB),
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _localNotifications.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint("Error showing system notification: $e");
    }
  }

  /// Send a Notification to any User (Inserts into Supabase `notifications` table)
  /// And if sender is recipient, instantly shows on screen without lag!
  static Future<bool> sendNotification({
    required String userId,
    required String title,
    required String message,
    String type = 'alert',
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      if (userId.isEmpty) return false;

      // If sending to currently active user on this phone, trigger local banner immediately!
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null && currentUser.id == userId) {
        showNotification(
          title: title,
          body: message,
          payload: additionalData != null ? jsonEncode(additionalData) : null,
          type: type,
        );
      }

      // Insert into Supabase notifications table
      try {
        await _supabase.from('notifications').insert({
          'user_id': userId,
          'title': title.trim(),
          'message': message.trim(),
          'type': type,
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        // Safe fallback for flexible schemas
        try {
          await _supabase.from('notifications').insert({
            'user_id': userId,
            'title': title.trim(),
            'message': message.trim(),
            'is_read': false,
          });
        } catch (innerErr) {
          debugPrint("Failed to insert notification into DB: $innerErr");
        }
      }

      return true;
    } catch (e) {
      debugPrint("Error in sendNotification: $e");
      return false;
    }
  }

  /// Handle Notification Tap
  static void _onNotificationTapped(NotificationResponse response) {
    final payloadStr = response.payload;
    if (payloadStr == null || payloadStr.isEmpty) return;

    try {
      final Map<String, dynamic> data = jsonDecode(payloadStr);
      final type = data['type']?.toString();

      if (navigatorKey?.currentState != null) {
        if (type == 'new_order') {
          navigatorKey!.currentState!.pushNamed('/active_orders');
        } else if (type == 'order' || type == 'status_change') {
          navigatorKey!.currentState!.pushNamed('/my_orders');
        } else {
          navigatorKey!.currentState!.pushNamed('/notifications');
        }
      }
    } catch (e) {
      debugPrint("Error handling notification tap: $e");
    }
  }
}
