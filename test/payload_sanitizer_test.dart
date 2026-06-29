import 'package:flutter_test/flutter_test.dart';
import 'package:qr_vault/shared/security/payload_sanitizer.dart';
import 'package:qr_vault/shared/security/sensitive_metadata.dart';

void main() {
  group('PayloadSanitizer', () {
    test('blocks javascript URLs', () {
      final result = PayloadSanitizer.sanitizeUrl('javascript:alert(1)');
      expect(result.isBlocked, isTrue);
    });

    test('blocks data URLs', () {
      final result = PayloadSanitizer.sanitizeUrl('data:text/html,<script>alert(1)</script>');
      expect(result.isBlocked, isTrue);
    });

    test('allows https URLs', () {
      final result = PayloadSanitizer.sanitizeUrl('https://example.com/path');
      expect(result.isAllowed, isTrue);
      expect(result.value, 'https://example.com/path');
    });

    test('strips control characters from raw payloads', () {
      final result = PayloadSanitizer.sanitizeRaw('hello\x00world');
      expect(result.value, 'helloworld');
      expect(result.isAllowed, isTrue);
    });

    test('blocks script injection in raw text', () {
      final result = PayloadSanitizer.sanitizeRaw('<script>alert(1)</script>');
      expect(result.isBlocked, isTrue);
    });
  });

  group('SensitiveMetadata', () {
    test('redacts wifi passwords for display', () {
      final redacted = SensitiveMetadata.redactForDisplay({
        'ssid': 'Home',
        'password': 'secret123',
      });
      expect(redacted['ssid'], 'Home');
      expect(redacted['password'], '••••••••');
    });

    test('redacts wifi raw strings for logging', () {
      const raw = r'WIFI:T:WPA;S:Home;P:secret;;';
      expect(
        SensitiveMetadata.redactWifiRaw(raw),
        contains('[REDACTED]'),
      );
      expect(
        SensitiveMetadata.redactWifiRaw(raw),
        isNot(contains('secret')),
      );
    });
  });
}
