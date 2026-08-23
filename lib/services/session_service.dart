import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to handle 30-minute auto-login persistence and graceful session management
class SessionService {
  static const String _keyLastActive = 'styluxe_last_active_time';
  static const String _keyUserRole = 'styluxe_user_role';
  static const String _keyIsLoggedIn = 'styluxe_is_logged_in';
  static const String _keyUserId = 'styluxe_user_id';
  static const int sessionTimeoutMinutes = 30;

  /// Records user activity (on login, app interaction, app backgrounding)
  static Future<void> recordActivity({String? role, String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_keyLastActive, nowMs);
      await prefs.setBool(_keyIsLoggedIn, true);

      final supabase = Supabase.instance.client;
      final currentUserId = userId ?? supabase.auth.currentUser?.id;
      if (currentUserId != null && currentUserId.isNotEmpty) {
        await prefs.setString(_keyUserId, currentUserId);
      }

      if (role != null && role.isNotEmpty) {
        await prefs.setString(_keyUserRole, role.toLowerCase());
      }
    } catch (e) {
      debugPrint("SessionService.recordActivity error: $e");
    }
  }

  /// Checks if the current session is still valid (within 30 minutes of last activity)
  static Future<bool> isSessionValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      final lastActiveMs = prefs.getInt(_keyLastActive);

      // If user explicitly logged out or was never logged in, return false immediately
      if (!isLoggedIn) {
        return false;
      }

      // If logged in previously or user exists, but no lastActive timestamp recorded, record now
      if (lastActiveMs == null) {
        await recordActivity();
        return true;
      }

      final lastActive = DateTime.fromMillisecondsSinceEpoch(lastActiveMs);
      final elapsedMinutes = DateTime.now().difference(lastActive).inMinutes;

      if (elapsedMinutes <= sessionTimeoutMinutes) {
        await recordActivity();
        return true;
      } else {
        debugPrint("Session expired ($elapsedMinutes mins elapsed > $sessionTimeoutMinutes mins max). Logging out.");
        await clearSession();
        return false;
      }
    } catch (e) {
      debugPrint("SessionService.isSessionValid error: $e");
      return false;
    }
  }

  /// Gets the cached user role
  static Future<String?> getCachedRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserRole);
    } catch (e) {
      return null;
    }
  }

  /// Clears stored session data and signs out from Supabase (Explicit Logout)
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, false);
      await prefs.remove(_keyLastActive);
      await prefs.remove(_keyUserRole);
      await prefs.remove(_keyUserId);
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint("SessionService.clearSession error: $e");
    }
  }
}
