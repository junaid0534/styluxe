import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CourierPartner {
  final String name;
  final String code;
  final String urlTemplate;
  final IconData icon;
  final Color brandColor;
  final String hotline;

  const CourierPartner({
    required this.name,
    required this.code,
    required this.urlTemplate,
    required this.icon,
    required this.brandColor,
    required this.hotline,
  });
}

class CourierService {
  static const List<CourierPartner> supportedCouriers = [
    CourierPartner(
      name: 'TCS Express',
      code: 'TCS',
      urlTemplate: 'https://www.tcsexpress.com/tracking?track={ID}',
      icon: Icons.local_shipping_rounded,
      brandColor: Color(0xFFDC2626), // TCS Red
      hotline: '111-123-456',
    ),
    CourierPartner(
      name: 'Leopards Courier',
      code: 'Leopards',
      urlTemplate: 'https://www.leopardscourier.com/tracking?track={ID}',
      icon: Icons.electric_bolt_rounded,
      brandColor: Color(0xFFEAB308), // Leopards Yellow/Gold
      hotline: '021-111-300-786',
    ),
    CourierPartner(
      name: 'Trax Logistics',
      code: 'Trax',
      urlTemplate: 'https://sonic.pk/tracking?tracking_number={ID}',
      icon: Icons.flight_takeoff_rounded,
      brandColor: Color(0xFF2563EB), // Trax Blue
      hotline: '021-111-118-729',
    ),
    CourierPartner(
      name: 'PostEx',
      code: 'PostEx',
      urlTemplate: 'https://postex.pk/tracking?trackingNo={ID}',
      icon: Icons.mail_rounded,
      brandColor: Color(0xFF0D9488), // PostEx Teal
      hotline: '042-325-000-00',
    ),
    CourierPartner(
      name: 'M&P Express',
      code: 'M&P',
      urlTemplate: 'https://mulphilog.com/tracking/?track={ID}',
      icon: Icons.inventory_2_rounded,
      brandColor: Color(0xFF9333EA), // M&P Purple
      hotline: '021-111-202-020',
    ),
    CourierPartner(
      name: 'Call Courier',
      code: 'CallCourier',
      urlTemplate: 'https://callcourier.com.pk/tracking/?tc={ID}',
      icon: Icons.phone_in_talk_rounded,
      brandColor: Color(0xFFEA580C), // CallCourier Orange
      hotline: '042-111-786-227',
    ),
    CourierPartner(
      name: 'Self / Other Delivery',
      code: 'Other',
      urlTemplate: 'https://www.google.com/search?q={ID}+tracking',
      icon: Icons.delivery_dining_rounded,
      brandColor: Color(0xFF475569), // Slate
      hotline: 'N/A',
    ),
  ];

  /// Find partner by code or name
  static CourierPartner getPartner(String? codeOrName) {
    if (codeOrName == null || codeOrName.trim().isEmpty) {
      return supportedCouriers[0]; // Default TCS
    }

    final query = codeOrName.trim().toLowerCase();
    for (final partner in supportedCouriers) {
      if (partner.code.toLowerCase() == query ||
          partner.name.toLowerCase().contains(query) ||
          query.contains(partner.code.toLowerCase())) {
        return partner;
      }
    }

    return supportedCouriers.last; // Other
  }

  /// Generate live tracking URL
  static String getTrackingUrl(String courierName, String trackingNumber) {
    final partner = getPartner(courierName);
    final cleanTracking = trackingNumber.trim();
    return partner.urlTemplate.replaceAll('{ID}', Uri.encodeComponent(cleanTracking));
  }

  /// Open Courier Tracking Portal in external browser
  static Future<bool> openTrackingPortal(String courierName, String trackingNumber) async {
    final urlStr = getTrackingUrl(courierName, trackingNumber);
    final uri = Uri.tryParse(urlStr);

    if (uri != null) {
      try {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint("Error launching tracking URL: $e");
      }
    }
    return false;
  }
}
