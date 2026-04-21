enum QRResultType {
  url,
  phone,
  email,
  wifi,
  text,
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
    }
  }
}
