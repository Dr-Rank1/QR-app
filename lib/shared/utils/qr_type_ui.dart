import 'package:flutter/material.dart';

import '../../features/scanner/domain/enums/qr_result_type.dart';

extension QRResultTypeUI on QRResultType {
  Color get color {
    switch (this) {
      case QRResultType.url:
        return const Color(0xFF2196F3);
      case QRResultType.phone:
        return const Color(0xFF4CAF50);
      case QRResultType.email:
        return const Color(0xFFFF9800);
      case QRResultType.wifi:
        return const Color(0xFF9C27B0);
      case QRResultType.text:
        return const Color(0xFF607D8B);
      case QRResultType.sms:
        return const Color(0xFF00BCD4);
      case QRResultType.geo:
        return const Color(0xFFE91E63);
      case QRResultType.vcard:
        return const Color(0xFF795548);
      case QRResultType.calendar:
        return const Color(0xFF3F51B5);
    }
  }

  IconData get icon {
    switch (this) {
      case QRResultType.url:
        return Icons.link;
      case QRResultType.phone:
        return Icons.phone;
      case QRResultType.email:
        return Icons.email;
      case QRResultType.wifi:
        return Icons.wifi;
      case QRResultType.text:
        return Icons.text_fields;
      case QRResultType.sms:
        return Icons.sms;
      case QRResultType.geo:
        return Icons.location_on;
      case QRResultType.vcard:
        return Icons.contact_page;
      case QRResultType.calendar:
        return Icons.event;
    }
  }
}
