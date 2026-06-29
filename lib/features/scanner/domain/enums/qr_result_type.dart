enum QRResultType {
  url,
  phone,
  email,
  wifi,
  text,
  sms,
  geo,
  vcard,
  calendar,
}

extension QRResultTypeExtension on QRResultType {
  String get displayName {
    switch (this) {
      case QRResultType.url:
        return 'URL';
      case QRResultType.phone:
        return 'Phone';
      case QRResultType.email:
        return 'Email';
      case QRResultType.wifi:
        return 'Wi-Fi';
      case QRResultType.text:
        return 'Text';
      case QRResultType.sms:
        return 'SMS';
      case QRResultType.geo:
        return 'Location';
      case QRResultType.vcard:
        return 'Contact';
      case QRResultType.calendar:
        return 'Event';
    }
  }

  String get iconName {
    switch (this) {
      case QRResultType.url:
        return 'link';
      case QRResultType.phone:
        return 'phone';
      case QRResultType.email:
        return 'email';
      case QRResultType.wifi:
        return 'wifi';
      case QRResultType.text:
        return 'text_fields';
      case QRResultType.sms:
        return 'sms';
      case QRResultType.geo:
        return 'location_on';
      case QRResultType.vcard:
        return 'contact_page';
      case QRResultType.calendar:
        return 'event';
    }
  }
}
