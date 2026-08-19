import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class BroadcastItem {
  final String id;
  final String title;
  final String message;
  final String targetAudience; // 'all', 'customers', 'sellers'
  final String type; // 'announcement', 'offer', 'alert', 'system'
  final String? promoCode;
  final DateTime createdAt;
  final int recipientCount;

  BroadcastItem({
    required this.id,
    required this.title,
    required this.message,
    required this.targetAudience,
    required this.type,
    this.promoCode,
    required this.createdAt,
    required this.recipientCount,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'targetAudience': targetAudience,
        'type': type,
        'promoCode': promoCode,
        'createdAt': createdAt.toIso8601String(),
        'recipientCount': recipientCount,
      };

  factory BroadcastItem.fromJson(Map<String, dynamic> json) => BroadcastItem(
        id: json['id'] ?? const Uuid().v4(),
        title: json['title'] ?? '',
        message: json['message'] ?? '',
        targetAudience: json['targetAudience'] ?? 'all',
        type: json['type'] ?? 'announcement',
        promoCode: json['promoCode'],
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
            : DateTime.now(),
        recipientCount: json['recipientCount'] ?? 0,
      );
}

class AdminNotificationService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _prefKeyBroadcastHistory = 'admin_broadcast_history';

  /// Send a broadcast push notification to the targeted audience
  static Future<Map<String, dynamic>> sendBroadcast({
    required String title,
    required String message,
    required String targetAudience, // 'all', 'customers', 'sellers'
    String type = 'announcement',
    String? promoCode,
  }) async {
    try {
      // 1. Query targeted user IDs from `users` table
      final List<dynamic> allUsers = await _supabase.from('users').select('id, role');

      final List<String> targetUserIds = [];
      for (final u in allUsers) {
        final id = u['id']?.toString();
        if (id == null || id.isEmpty) continue;

        final role = (u['role']?.toString() ?? 'customer').toLowerCase();
        if (targetAudience == 'all') {
          targetUserIds.add(id);
        } else if (targetAudience == 'customers') {
          if (role != 'seller' && role != 'admin' && role != 'super_admin') {
            targetUserIds.add(id);
          }
        } else if (targetAudience == 'sellers') {
          if (role == 'seller') {
            targetUserIds.add(id);
          }
        }
      }

      int deliveredCount = 0;
      final msgContent = promoCode != null && promoCode.trim().isNotEmpty
          ? "${message.trim()}\nUse Promo Code: ${promoCode.trim()}"
          : message.trim();

      final List<Map<String, dynamic>> notificationsPayload = [];

      for (final userId in targetUserIds) {
        notificationsPayload.add({
          'user_id': userId,
          'title': title.trim(),
          'message': msgContent,
          'type': type,
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Also add a general broadcast row if audience is 'all' or no users found
      if (targetAudience == 'all' || notificationsPayload.isEmpty) {
        notificationsPayload.add({
          'user_id': null,
          'title': title.trim(),
          'message': msgContent,
          'type': type,
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // 2. Insert notification records for all recipients
      if (notificationsPayload.isNotEmpty) {
        try {
          await _supabase.from('notifications').insert(notificationsPayload);
          deliveredCount = targetUserIds.isNotEmpty ? targetUserIds.length : 1;
        } catch (e) {
          debugPrint("Note: batch notifications insert fallback: $e");
          for (final payload in notificationsPayload) {
            try {
              await _supabase.from('notifications').insert(payload);
              deliveredCount++;
            } catch (_) {}
          }
        }
      }

      // 3. Save to broadcast history
      final newItem = BroadcastItem(
        id: const Uuid().v4(),
        title: title.trim(),
        message: message.trim(),
        targetAudience: targetAudience,
        type: type,
        promoCode: promoCode?.trim(),
        createdAt: DateTime.now(),
        recipientCount: deliveredCount > 0 ? deliveredCount : targetUserIds.length,
      );

      await _saveToHistory(newItem);

      return {
        'success': true,
        'recipientCount': newItem.recipientCount,
        'item': newItem,
      };
    } catch (e) {
      debugPrint("AdminNotificationService Error: $e");
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Fetch broadcast history from local cache and remote
  static Future<List<BroadcastItem>> getBroadcastHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKeyBroadcastHistory);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw);
        return list.map((item) => BroadcastItem.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint("Error reading broadcast history: $e");
    }
    return [];
  }

  /// Save single item to history
  static Future<void> _saveToHistory(BroadcastItem item) async {
    try {
      final currentList = await getBroadcastHistory();
      currentList.insert(0, item);
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(currentList.map((e) => e.toJson()).toList());
      await prefs.setString(_prefKeyBroadcastHistory, jsonStr);
    } catch (e) {
      debugPrint("Error saving broadcast history: $e");
    }
  }

  /// Delete broadcast history item
  static Future<void> deleteHistoryItem(String id) async {
    try {
      final currentList = await getBroadcastHistory();
      currentList.removeWhere((item) => item.id == id);
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(currentList.map((e) => e.toJson()).toList());
      await prefs.setString(_prefKeyBroadcastHistory, jsonStr);
    } catch (e) {
      debugPrint("Error deleting history item: $e");
    }
  }
}
