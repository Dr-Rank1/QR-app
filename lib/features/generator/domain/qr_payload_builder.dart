enum GeneratorContentType {
  text,
  url,
  wifi,
  phone,
  email,
  sms,
  contact,
}

extension GeneratorContentTypeX on GeneratorContentType {
  String get label {
    switch (this) {
      case GeneratorContentType.text:
        return 'Text';
      case GeneratorContentType.url:
        return 'Link';
      case GeneratorContentType.wifi:
        return 'Wi-Fi';
      case GeneratorContentType.phone:
        return 'Phone';
      case GeneratorContentType.email:
        return 'Email';
      case GeneratorContentType.sms:
        return 'SMS';
      case GeneratorContentType.contact:
        return 'Contact';
    }
  }
}

class QRPayloadBuilder {
  static Map<String, String> defaultFields(GeneratorContentType type) {
    switch (type) {
      case GeneratorContentType.text:
        return {'message': ''};
      case GeneratorContentType.url:
        return {'url': 'https://'};
      case GeneratorContentType.wifi:
        return {
          'ssid': '',
          'password': '',
          'encryption': 'WPA',
          'hidden': 'false',
        };
      case GeneratorContentType.phone:
        return {'number': ''};
      case GeneratorContentType.email:
        return {'to': '', 'subject': '', 'body': ''};
      case GeneratorContentType.sms:
        return {'number': '', 'message': ''};
      case GeneratorContentType.contact:
        return {'name': '', 'phone': '', 'email': '', 'organization': ''};
    }
  }

  static String build(GeneratorContentType type, Map<String, String> fields) {
    switch (type) {
      case GeneratorContentType.text:
        return fields['message']?.trim() ?? '';
      case GeneratorContentType.url:
        var url = fields['url']?.trim() ?? '';
        if (url.isNotEmpty && !url.contains('://')) {
          url = 'https://$url';
        }
        return url;
      case GeneratorContentType.wifi:
        final ssid = _escapeWifi(fields['ssid'] ?? '');
        final password = _escapeWifi(fields['password'] ?? '');
        final encryption = fields['encryption'] ?? 'WPA';
        final hidden = fields['hidden'] == 'true' ? 'H:true;' : '';
        return 'WIFI:T:$encryption;S:$ssid;P:$password;$hidden';
      case GeneratorContentType.phone:
        final number = fields['number']?.trim() ?? '';
        return number.isEmpty ? '' : 'tel:$number';
      case GeneratorContentType.email:
        final to = fields['to']?.trim() ?? '';
        if (to.isEmpty) return '';
        final subject = Uri.encodeComponent(fields['subject']?.trim() ?? '');
        final body = Uri.encodeComponent(fields['body']?.trim() ?? '');
        return 'mailto:$to?subject=$subject&body=$body';
      case GeneratorContentType.sms:
        final number = fields['number']?.trim() ?? '';
        if (number.isEmpty) return '';
        final message = Uri.encodeComponent(fields['message']?.trim() ?? '');
        return 'sms:$number?body=$message';
      case GeneratorContentType.contact:
        return _buildVcard(fields);
    }
  }

  static String _escapeWifi(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll(';', '\\;')
        .replaceAll(',', '\\,')
        .replaceAll(':', '\\:')
        .replaceAll('"', '\\"');
  }

  static String _buildVcard(Map<String, String> fields) {
    final name = fields['name']?.trim() ?? '';
    final phone = fields['phone']?.trim() ?? '';
    final email = fields['email']?.trim() ?? '';
    final org = fields['organization']?.trim() ?? '';
    if (name.isEmpty && phone.isEmpty && email.isEmpty) return '';

    final buffer = StringBuffer()
      ..writeln('BEGIN:VCARD')
      ..writeln('VERSION:3.0');
    if (name.isNotEmpty) buffer.writeln('FN:$name');
    if (phone.isNotEmpty) buffer.writeln('TEL:$phone');
    if (email.isNotEmpty) buffer.writeln('EMAIL:$email');
    if (org.isNotEmpty) buffer.writeln('ORG:$org');
    buffer.write('END:VCARD');
    return buffer.toString();
  }

  static bool isValid(GeneratorContentType type, Map<String, String> fields) {
    if (hasValidationErrors(type, fields)) return false;
    return build(type, fields).trim().isNotEmpty;
  }

  static bool hasValidationErrors(
    GeneratorContentType type,
    Map<String, String> fields,
  ) {
    return fieldErrors(type, fields).values.any((error) => error != null);
  }

  static Map<String, String?> fieldErrors(
    GeneratorContentType type,
    Map<String, String> fields,
  ) {
    final errors = <String, String?>{};

    switch (type) {
      case GeneratorContentType.url:
        errors['url'] = _urlFieldError(fields['url']);
      case GeneratorContentType.email:
        errors['to'] = _emailFieldError(fields['to']);
      case GeneratorContentType.phone:
        errors['number'] = _phoneFieldError(fields['number']);
      case GeneratorContentType.sms:
        errors['number'] = _phoneFieldError(fields['number']);
      case GeneratorContentType.wifi:
        final ssid = fields['ssid']?.trim() ?? '';
        if (ssid.isEmpty && (fields['password']?.trim().isNotEmpty ?? false)) {
          errors['ssid'] = 'Network name is required';
        }
      case GeneratorContentType.text:
      case GeneratorContentType.contact:
        break;
    }

    return errors;
  }

  static String? _urlFieldError(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty || value == 'https://' || value == 'http://') {
      return null;
    }
    return _isValidUrl(value) ? null : 'Enter a valid URL (e.g. https://example.com)';
  }

  static String? _emailFieldError(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailPattern.hasMatch(value)
        ? null
        : 'Enter a valid email address';
  }

  static String? _phoneFieldError(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    final digits = value.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    if (digits.length < 7 || !RegExp(r'^\d+$').hasMatch(digits)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static bool _isValidUrl(String raw) {
    var url = raw;
    if (!url.contains('://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    final host = uri.host;
    if (host.isEmpty) return false;
    return host.contains('.') || host == 'localhost';
  }
}
