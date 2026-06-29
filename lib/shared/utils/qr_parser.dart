import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/scanner/domain/enums/qr_result_type.dart';
import 'url_safety.dart';

class QRContentParser {
  static ({QRResultType type, String value, Map<String, String>? metadata}) parse(
    String rawValue,
  ) {
    final trimmed = rawValue.trim();

    if (_isVcard(trimmed)) {
      return (type: QRResultType.vcard, value: trimmed, metadata: _parseVcard(trimmed));
    }

    if (_isCalendar(trimmed)) {
      return (type: QRResultType.calendar, value: trimmed, metadata: _parseCalendar(trimmed));
    }

    if (_isGeo(trimmed)) {
      return (type: QRResultType.geo, value: trimmed, metadata: _parseGeo(trimmed));
    }

    if (_isSms(trimmed)) {
      return (type: QRResultType.sms, value: trimmed, metadata: _parseSms(trimmed));
    }

    if (_isUrl(trimmed)) {
      return (type: QRResultType.url, value: trimmed, metadata: null);
    }

    if (_isPhone(trimmed)) {
      final phone = trimmed.replaceAll('tel:', '');
      return (type: QRResultType.phone, value: phone, metadata: null);
    }

    if (_isEmail(trimmed)) {
      return (type: QRResultType.email, value: trimmed, metadata: null);
    }

    if (_isWifi(trimmed)) {
      return (type: QRResultType.wifi, value: trimmed, metadata: _parseWifi(trimmed));
    }

    return (type: QRResultType.text, value: trimmed, metadata: null);
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

  static bool _isSms(String value) {
    return value.toLowerCase().startsWith('sms:') ||
        value.toLowerCase().startsWith('smsto:');
  }

  static bool _isGeo(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('geo:') || lower.startsWith('http://maps.google') ||
        lower.startsWith('https://maps.google') ||
        lower.startsWith('https://maps.apple.com');
  }

  static bool _isVcard(String value) {
    final upper = value.toUpperCase();
    return upper.startsWith('BEGIN:VCARD') || upper.contains('BEGIN:VCARD');
  }

  static bool _isCalendar(String value) {
    final upper = value.toUpperCase();
    return upper.startsWith('BEGIN:VEVENT') || upper.contains('BEGIN:VEVENT');
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

        final rawKey = part.substring(0, colonIndex).toLowerCase();
        final val = part.substring(colonIndex + 1);
        const keyMap = {'s': 'ssid', 't': 'type', 'p': 'password', 'h': 'hidden'};
        final key = keyMap[rawKey] ?? rawKey;
        metadata[key] = val;
      }

      return metadata;
    } catch (_) {
      return null;
    }
  }

  static Map<String, String>? _parseSms(String value) {
    try {
      final body = value.replaceFirst(RegExp(r'^sms(to)?:', caseSensitive: false), '');
      final parts = body.split('?');
      final number = parts.first;
      final metadata = <String, String>{'number': number};
      if (parts.length > 1) {
        final message = Uri.splitQueryString(parts[1])['body'];
        if (message != null) metadata['body'] = message;
      }
      return metadata;
    } catch (_) {
      return null;
    }
  }

  static Map<String, String>? _parseGeo(String value) {
    try {
      if (value.toLowerCase().startsWith('geo:')) {
        final coords = value.substring(4).split('?').first;
        final parts = coords.split(',');
        if (parts.length >= 2) {
          return {'lat': parts[0], 'lng': parts[1]};
        }
      }
      return {'url': value};
    } catch (_) {
      return null;
    }
  }

  static Map<String, String>? _parseVcard(String value) {
    final metadata = <String, String>{};
    for (final line in value.split('\n')) {
      if (line.startsWith('FN:')) metadata['name'] = line.substring(3).trim();
      if (line.startsWith('TEL')) {
        final tel = line.split(':').last.trim();
        metadata['phone'] = tel;
      }
      if (line.startsWith('EMAIL')) {
        metadata['email'] = line.split(':').last.trim();
      }
    }
    return metadata.isEmpty ? null : metadata;
  }

  static Map<String, String>? _parseCalendar(String value) {
    final metadata = <String, String>{};
    for (final line in value.split('\n')) {
      if (line.startsWith('SUMMARY:')) metadata['title'] = line.substring(8).trim();
      if (line.startsWith('DTSTART')) metadata['start'] = line.split(':').last.trim();
      if (line.startsWith('LOCATION:')) metadata['location'] = line.substring(9).trim();
    }
    return metadata.isEmpty ? null : metadata;
  }

  static Future<bool> tryOpen(
    QRResultType type,
    String value,
    Map<String, String>? metadata, {
    BuildContext? context,
  }) async {
    switch (type) {
      case QRResultType.url:
        if (context != null) {
          final confirmed = await UrlSafety.confirmOpen(context, value);
          if (!confirmed) return false;
        }
        var url = value;
        if (!url.startsWith('http')) url = 'https://$url';
        return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

      case QRResultType.phone:
        final phone = value.replaceAll(RegExp(r'[^\d+]'), '');
        return launchUrl(Uri(scheme: 'tel', path: phone));

      case QRResultType.email:
        return launchUrl(Uri(
          scheme: 'mailto',
          path: value.replaceAll('mailto:', ''),
        ));

      case QRResultType.sms:
        final number = metadata?['number'] ?? value.replaceAll(RegExp(r'^sms(to)?:', caseSensitive: false), '');
        final body = metadata?['body'];
        final uri = body != null
            ? Uri(scheme: 'sms', path: number, queryParameters: {'body': body})
            : Uri(scheme: 'sms', path: number);
        return launchUrl(uri);

      case QRResultType.geo:
        if (metadata?['lat'] != null && metadata?['lng'] != null) {
          return launchUrl(Uri.parse('geo:${metadata!['lat']},${metadata['lng']}'));
        }
        return launchUrl(Uri.parse(value));

      case QRResultType.wifi:
      case QRResultType.vcard:
      case QRResultType.calendar:
      case QRResultType.text:
        return false;
    }
  }
}
