import 'package:flutter/material.dart';

import '../../features/scanner/domain/enums/qr_result_type.dart';

/// Type accent colors from the QR Studio UI reference.
extension QRResultTypeUI on QRResultType {
  Color get color {
    switch (this) {
      case QRResultType.url:
        return const Color(0xFF3B82F6);
      case QRResultType.phone:
        return const Color(0xFF22C55E);
      case QRResultType.email:
        return const Color(0xFFF97316);
      case QRResultType.wifi:
        return const Color(0xFF06B6D4);
      case QRResultType.text:
        return const Color(0xFF737373);
      case QRResultType.sms:
        return const Color(0xFFEAB308);
      case QRResultType.geo:
        return const Color(0xFFEF4444);
      case QRResultType.vcard:
        return const Color(0xFFEC4899);
      case QRResultType.calendar:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData get icon {
    switch (this) {
      case QRResultType.url:
        return Icons.public_outlined;
      case QRResultType.phone:
        return Icons.phone_outlined;
      case QRResultType.email:
        return Icons.email_outlined;
      case QRResultType.wifi:
        return Icons.wifi_outlined;
      case QRResultType.text:
        return Icons.text_fields_outlined;
      case QRResultType.sms:
        return Icons.sms_outlined;
      case QRResultType.geo:
        return Icons.location_on_outlined;
      case QRResultType.vcard:
        return Icons.contact_page_outlined;
      case QRResultType.calendar:
        return Icons.event_outlined;
    }
  }
}
