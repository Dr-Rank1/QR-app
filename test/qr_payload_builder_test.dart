import 'package:flutter_test/flutter_test.dart';
import 'package:qr_vault/features/generator/domain/qr_payload_builder.dart';

void main() {
  group('QRPayloadBuilder URL payloads', () {
    test('normalizes bare domains to https', () {
      final payload = QRPayloadBuilder.build(
        GeneratorContentType.url,
        {'url': 'example.com'},
      );
      expect(payload, 'https://example.com');
    });

    test('preserves explicit https URLs', () {
      final payload = QRPayloadBuilder.build(
        GeneratorContentType.url,
        {'url': 'https://example.com/path?q=1'},
      );
      expect(payload, 'https://example.com/path?q=1');
    });
  });

  group('QRPayloadBuilder Wi-Fi payloads', () {
    test('builds WPA credentials with escaped characters', () {
      final payload = QRPayloadBuilder.build(
        GeneratorContentType.wifi,
        {
          'ssid': 'Cafe WiFi',
          'password': 'secret;pass',
          'encryption': 'WPA',
          'hidden': 'false',
        },
      );

      expect(payload, startsWith('WIFI:T:WPA;'));
      expect(payload, contains('S:Cafe WiFi'));
      expect(payload, contains(r'P:secret\;pass'));
    });

    test('supports open networks', () {
      final payload = QRPayloadBuilder.build(
        GeneratorContentType.wifi,
        {
          'ssid': 'Guest',
          'password': '',
          'encryption': 'nopass',
          'hidden': 'false',
        },
      );

      expect(payload, contains('T:nopass'));
      expect(payload, contains('S:Guest'));
    });
  });

  group('QRPayloadBuilder phone and email payloads', () {
    test('builds tel payload', () {
      final payload = QRPayloadBuilder.build(
        GeneratorContentType.phone,
        {'number': '+15551234567'},
      );
      expect(payload, 'tel:+15551234567');
    });

    test('builds mailto payload with encoded query params', () {
      final payload = QRPayloadBuilder.build(
        GeneratorContentType.email,
        {
          'to': 'user@example.com',
          'subject': 'Hello there',
          'body': 'QR test',
        },
      );

      expect(payload, startsWith('mailto:user@example.com?'));
      expect(payload, contains('subject=Hello%20there'));
      expect(payload, contains('body=QR%20test'));
    });

    test('builds sms payload', () {
      final payload = QRPayloadBuilder.build(
        GeneratorContentType.sms,
        {
          'number': '+15551234567',
          'message': 'Hi',
        },
      );
      expect(payload, 'sms:+15551234567?body=Hi');
    });
  });

  group('QRPayloadBuilder contact payloads', () {
    test('builds vCard with required fields', () {
      final payload = QRPayloadBuilder.build(
        GeneratorContentType.contact,
        {
          'name': 'Jane Doe',
          'phone': '+1234567890',
          'email': 'jane@example.com',
          'organization': 'Acme',
        },
      );

      expect(payload, contains('BEGIN:VCARD'));
      expect(payload, contains('FN:Jane Doe'));
      expect(payload, contains('TEL:+1234567890'));
      expect(payload, contains('EMAIL:jane@example.com'));
      expect(payload, contains('ORG:Acme'));
      expect(payload, contains('END:VCARD'));
    });
  });

  group('QRPayloadBuilder validation', () {
    test('rejects invalid URLs before generation', () {
      expect(
        QRPayloadBuilder.isValid(
          GeneratorContentType.url,
          {'url': 'not a url'},
        ),
        isFalse,
      );
      expect(
        QRPayloadBuilder.fieldErrors(
          GeneratorContentType.url,
          {'url': 'https://example.com'},
        )['url'],
        isNull,
      );
    });

    test('requires SSID when password is provided for Wi-Fi', () {
      expect(
        QRPayloadBuilder.fieldErrors(
          GeneratorContentType.wifi,
          {'ssid': '', 'password': 'secret', 'encryption': 'WPA'},
        )['ssid'],
        isNotNull,
      );
    });
  });
}
