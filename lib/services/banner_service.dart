import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class HomeBannerItem {
  final String id;
  final String title;
  final String subtitle;
  final String discountTag;
  final String? promoCode;
  final String? imageUrl;
  final String gradientStart;
  final String gradientEnd;
  final String iconName;
  final bool isActive;
  final int orderIndex;
  final DateTime createdAt;

  HomeBannerItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.discountTag,
    this.promoCode,
    this.imageUrl,
    this.gradientStart = '0xFF0D9488',
    this.gradientEnd = '0xFF10B981',
    this.iconName = 'local_offer',
    this.isActive = true,
    this.orderIndex = 0,
    required this.createdAt,
  });

  List<Color> get gradientColors {
    try {
      final c1 = Color(int.parse(gradientStart));
      final c2 = Color(int.parse(gradientEnd));
      return [c1, c2];
    } catch (_) {
      return [const Color(0xFF0D9488), const Color(0xFF10B981)];
    }
  }

  IconData get iconData {
    switch (iconName.toLowerCase()) {
      case 'celebration':
        return Icons.celebration_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      case 'shipping':
      case 'local_shipping':
        return Icons.local_shipping_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'diamond':
        return Icons.diamond_rounded;
      case 'fire':
      case 'local_fire_department':
        return Icons.local_fire_department_rounded;
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'local_offer':
      default:
        return Icons.local_offer_rounded;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'discount_tag': discountTag,
        'promo_code': promoCode,
        'image_url': imageUrl,
        'gradient_start': gradientStart,
        'gradient_end': gradientEnd,
        'icon_name': iconName,
        'is_active': isActive,
        'order_index': orderIndex,
        'created_at': createdAt.toIso8601String(),
      };

  factory HomeBannerItem.fromJson(Map<String, dynamic> json) => HomeBannerItem(
        id: json['id']?.toString() ?? const Uuid().v4(),
        title: json['title']?.toString() ?? 'Special Offer',
        subtitle: json['subtitle']?.toString() ?? 'Discover luxury collections today',
        discountTag: json['discount_tag']?.toString() ?? 'PROMO OFFER',
        promoCode: json['promo_code']?.toString(),
        imageUrl: json['image_url']?.toString(),
        gradientStart: json['gradient_start']?.toString() ?? '0xFF0D9488',
        gradientEnd: json['gradient_end']?.toString() ?? '0xFF10B981',
        iconName: json['icon_name']?.toString() ?? 'local_offer',
        isActive: json['is_active'] == true || json['is_active'] == null,
        orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
            : DateTime.now(),
      );
}

class BannerService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _prefKeyBanners = 'styluxe_home_banners_cache';

  static List<HomeBannerItem> get defaultBanners => [
        HomeBannerItem(
          id: 'banner_1',
          title: 'Independence Grand Special',
          subtitle: 'FLAT 14% OFF on All Luxury Seller Stores',
          discountTag: 'FLAT 14% OFF',
          promoCode: 'INDEPENDENCE14',
          gradientStart: '0xFF047857',
          gradientEnd: '0xFF10B981',
          iconName: 'celebration',
          isActive: true,
          orderIndex: 0,
          createdAt: DateTime.now(),
        ),
        HomeBannerItem(
          id: 'banner_2',
          title: 'Summer Clearance Luxe',
          subtitle: 'UPTO 50% OFF | Selected Dresses & Designer Shoes',
          discountTag: 'UPTO 50% OFF',
          promoCode: 'SUMMER50',
          gradientStart: '0xFF4338CA',
          gradientEnd: '0xFF6366F1',
          iconName: 'local_offer',
          isActive: true,
          orderIndex: 1,
          createdAt: DateTime.now(),
        ),
        HomeBannerItem(
          id: 'banner_3',
          title: 'Flash Voucher Deal',
          subtitle: 'FLAT Rs. 500 OFF on Orders Above Rs. 2,000',
          discountTag: 'FLAT Rs. 500 OFF',
          promoCode: 'FLASHSALE500',
          gradientStart: '0xFFBE123C',
          gradientEnd: '0xFFF43F5E',
          iconName: 'bolt',
          isActive: true,
          orderIndex: 2,
          createdAt: DateTime.now(),
        ),
        HomeBannerItem(
          id: 'banner_4',
          title: 'Free Delivery Special',
          subtitle: 'Zero Shipping Charges Nationwide on All Orders',
          discountTag: 'FREE SHIPPING',
          promoCode: 'FREESHIP',
          gradientStart: '0xFF0F172A',
          gradientEnd: '0xFF334155',
          iconName: 'local_shipping',
          isActive: true,
          orderIndex: 3,
          createdAt: DateTime.now(),
        ),
      ];

  /// Fetch active banners for Customer Home Screen
  static Future<List<HomeBannerItem>> fetchActiveBanners() async {
    try {
      final res = await _supabase
          .from('home_banners')
          .select('*')
          .eq('is_active', true)
          .order('order_index', ascending: true);

      if (res.isNotEmpty) {
        final list = (res as List).map((e) => HomeBannerItem.fromJson(e)).toList();
        await _cacheBanners(list);
        return list;
      }
    } catch (e) {
      debugPrint("Remote banner fetch note: $e");
    }

    // Fallback to cached banners
    final cached = await _getCachedBanners();
    if (cached.isNotEmpty) {
      return cached.where((b) => b.isActive).toList();
    }

    return defaultBanners;
  }

  /// Fetch all banners for Admin Manager
  static Future<List<HomeBannerItem>> fetchAllBanners() async {
    try {
      final res = await _supabase
          .from('home_banners')
          .select('*')
          .order('order_index', ascending: true);

      if (res.isNotEmpty) {
        final list = (res as List).map((e) => HomeBannerItem.fromJson(e)).toList();
        await _cacheBanners(list);
        return list;
      }
    } catch (e) {
      debugPrint("Admin banner remote fetch note: $e");
    }

    final cached = await _getCachedBanners();
    if (cached.isNotEmpty) return cached;

    // Seed default banners if nothing in cache
    await _cacheBanners(defaultBanners);
    return defaultBanners;
  }

  /// Create or update a banner
  static Future<bool> saveBanner(HomeBannerItem banner) async {
    // 1. Update cache
    final current = await fetchAllBanners();
    final index = current.indexWhere((b) => b.id == banner.id);
    if (index >= 0) {
      current[index] = banner;
    } else {
      current.insert(0, banner);
    }
    await _cacheBanners(current);

    // 2. Persist to Supabase
    try {
      await _supabase.from('home_banners').upsert(banner.toJson());
      return true;
    } catch (e) {
      debugPrint("Remote banner upsert note: $e");
      return true;
    }
  }

  /// Delete a banner
  static Future<bool> deleteBanner(String id) async {
    final current = await fetchAllBanners();
    current.removeWhere((b) => b.id == id);
    await _cacheBanners(current);

    try {
      await _supabase.from('home_banners').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint("Remote banner delete note: $e");
      return true;
    }
  }

  /// Toggle active state
  static Future<bool> toggleStatus(String id, bool isActive) async {
    final current = await fetchAllBanners();
    final index = current.indexWhere((b) => b.id == id);
    if (index >= 0) {
      final updated = HomeBannerItem(
        id: current[index].id,
        title: current[index].title,
        subtitle: current[index].subtitle,
        discountTag: current[index].discountTag,
        promoCode: current[index].promoCode,
        imageUrl: current[index].imageUrl,
        gradientStart: current[index].gradientStart,
        gradientEnd: current[index].gradientEnd,
        iconName: current[index].iconName,
        isActive: isActive,
        orderIndex: current[index].orderIndex,
        createdAt: current[index].createdAt,
      );
      current[index] = updated;
      await _cacheBanners(current);

      try {
        await _supabase.from('home_banners').update({'is_active': isActive}).eq('id', id);
      } catch (_) {}
      return true;
    }
    return false;
  }

  static Future<void> _cacheBanners(List<HomeBannerItem> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = jsonEncode(list.map((e) => e.toJson()).toList());
      await prefs.setString(_prefKeyBanners, str);
    } catch (_) {}
  }

  static Future<List<HomeBannerItem>> _getCachedBanners() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_prefKeyBanners);
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str);
        return list.map((e) => HomeBannerItem.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }
}
