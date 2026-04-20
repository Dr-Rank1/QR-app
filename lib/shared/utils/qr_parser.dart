import 'package:url_launcher/url_launcher.dart';

import '../../features/scanner/domain/enums/qr_result_type.dart';

class QRContentParser {
  static ({QRResultType type, String value, Map<String, String>? metadata}) parse(String rawValue) {
    // Check for URL
    if (_isUrl(rawValue)) {
      return (
        type: QRResultType.url,
        value: rawValue,
        metadata: null,
      );
    }

    // Check for phone number
    if (_isPhone(rawValue)) {
      final phone = rawValue.replaceAll('tel:', '');
      return (
        type: QRResultType.phone,
        value: phone,
        metadata: null,
      );
    }

    // Check for email
    if (_isEmail(rawValue)) {
      return (
        type: QRResultType.email,
        value: rawValue,
        metadata: null,
      );
    }

    // Check for Wi-Fi
    if (_isWifi(rawValue)) {
      final metadata = _parseWifi(rawValue);
      return (
        type: QRResultType.wifi,
        value: rawValue,
        metadata: metadata,
      );
    }

    // Default to plain text
    return (
      type: QRResultType.text,
      value: rawValue,
      metadata: null,
    );
  }

  static bool _isUrl(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('www.');
  }

  static bool _isPhone(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('tel:') ||
        RegExp(r'^[\+]?[(]?[0-9]{3}[)]?[-\s\.]?[0-9]{3}[-\s\.]?[0-9]{4,6}$')
            .hasMatch(value);
  }

  static bool _isEmail(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('mailto:') ||
        RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(value);
  }

  static bool _isWifi(String value) {
    return value.toUpperCase().startsWith('WIFI:');
  }

  static Map<String, String>? _parseWifi(String value) {
    if (!_isWifi(value)) return null;

    try {
      final cleaned = value.substring(5);
      final parts = cleaned.split(';');
      final metadata = <String, String>{};

      for (final part in parts) {
        if (part.isEmpty) continue;
        final colonIndex = part.indexOf(':');
        if (colonIndex == -1) continue;

        final key = part.substring(0, colonIndex).toLowerCase();
        final val = part.substring(colonIndex + 1);
        metadata[key] = val;
      }

      return metadata;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> tryOpen(QRResultType type, String value, Map<String, String>? metadata) async {
    switch (type) {
      case QRResultType.url:
        final uri = Uri.parse(value);
        return await launchUrl(uri, mode: LaunchMode.externalApplication);

      case QRResultType.phone:
        final phone = value.replaceAll(RegExp(r'[^\d+]'), '');
        final uri = Uri(scheme: 'tel', path: phone);
        return await launchUrl(uri);

      case QRResultType.email:
        final uri = Uri(
          scheme: 'mailto',
          path: value.replaceAll('mailto:', ''),
        );
        return await launchUrl(uri);

      case QRResultType.wifi:
        // Wi-Fi QR codes can't be automatically connected
        return false;

      case QRResultType.text:
        return false;
    }
  }
}