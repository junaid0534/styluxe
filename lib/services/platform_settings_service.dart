import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlatformSettingsService {
  static const String _prefKeyMaintenance = 'platform_maintenance_mode';
  static const String _prefKeyMaintenanceMsg = 'platform_maintenance_msg';
  
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Check whether Platform Maintenance Mode is active
  static Future<bool> isMaintenanceModeActive() async {
    try {
      // 1. Check from Supabase table `platform_settings` if exists
      final res = await _supabase
          .from('platform_settings')
          .select('value')
          .eq('key', 'maintenance_mode')
          .maybeSingle();

      if (res != null && res['value'] != null) {
        final val = res['value'];
        bool isEnabled = false;
        if (val is bool) {
          isEnabled = val;
        } else if (val is Map) {
          isEnabled = val['is_enabled'] == true;
        } else if (val is String) {
          isEnabled = val.toLowerCase() == 'true';
        }
        
        // Cache to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefKeyMaintenance, isEnabled);
        return isEnabled;
      }
    } catch (e) {
      debugPrint("PlatformSettingsService remote fetch fallback: $e");
    }

    // 2. Fallback to cached local preferences
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefKeyMaintenance) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Toggle Platform Maintenance Mode
  static Future<bool> setMaintenanceMode(bool isEnabled, {String? customMessage}) async {
    // 1. Cache to local storage immediately
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyMaintenance, isEnabled);
      if (customMessage != null) {
        await prefs.setString(_prefKeyMaintenanceMsg, customMessage);
      }
    } catch (_) {}

    // 2. Persist to Supabase if table exists
    try {
      await _supabase.from('platform_settings').upsert({
        'key': 'maintenance_mode',
        'value': {
          'is_enabled': isEnabled,
          'message': customMessage ?? 'Platform is undergoing scheduled maintenance.',
          'updated_at': DateTime.now().toIso8601String(),
        },
      });
      return true;
    } catch (e) {
      debugPrint("PlatformSettingsService remote upsert note: $e");
      return true; // Local storage updated
    }
  }
}
