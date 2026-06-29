import 'package:flutter_test/flutter_test.dart';
import 'package:qr_vault/features/scanner/domain/enums/qr_result_type.dart';
import 'package:qr_vault/shared/utils/qr_parser.dart';
import 'package:qr_vault/shared/utils/url_safety.dart';

void main() {
  group('QRContentParser', () {
    test('detects URLs', () {
      final result = QRContentParser.parse('https://example.com');
      expect(result.type, QRResultType.url);
    });

    test('detects phone numbers', () {
      final result = QRContentParser.parse('tel:+1234567890');
      expect(result.type, QRResultType.phone);
    });

    test('detects email', () {
      final result = QRContentParser.parse('mailto:test@example.com');
      expect(result.type, QRResultType.email);
    });

    test('detects wifi', () {
      final result = QRContentParser.parse('WIFI:T:WPA;S:Home;P:secret;;');
      expect(result.type, QRResultType.wifi);
      expect(result.metadata?['ssid'], 'Home');
    });

    test('detects SMS', () {
      final result = QRContentParser.parse('sms:+1234567890?body=Hi');
      expect(result.type, QRResultType.sms);
      expect(result.metadata?['number'], '+1234567890');
    });

    test('detects geo', () {
      final result = QRContentParser.parse('geo:37.7749,-122.4194');
      expect(result.type, QRResultType.geo);
      expect(result.metadata?['lat'], '37.7749');
    });

    test('falls back to text', () {
      final result = QRContentParser.parse('Hello world');
      expect(result.type, QRResultType.text);
    });
  });

  group('UrlSafety', () {
    test('extracts domain', () {
      expect(UrlSafety.extractDomain('https://www.example.com/path'), 'www.example.com');
    });

    test('flags suspicious shorteners', () {
      expect(UrlSafety.looksSuspicious('https://bit.ly/abc'), isTrue);
      expect(UrlSafety.looksSuspicious('https://example.com'), isFalse);
    });
  });
}
