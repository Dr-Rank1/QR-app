/// Redacts sensitive fields (e.g. Wi-Fi passwords) for logging and UI.
abstract final class SensitiveMetadata {
  static const _sensitiveKeys = {'password', 'p', 'pass', 'psk', 'key'};

  static Map<String, String> redactForDisplay(Map<String, String>? metadata) {
    if (metadata == null) return {};
    return {
      for (final entry in metadata.entries)
        entry.key: _isSensitiveKey(entry.key) ? '••••••••' : entry.value,
    };
  }

  static Map<String, String> redactForLogging(Map<String, String>? metadata) {
    return redactForDisplay(metadata);
  }

  static String redactWifiRaw(String raw) {
    if (!raw.toUpperCase().startsWith('WIFI:')) return raw;
    return raw.replaceAllMapped(
      RegExp(r'P:([^;\\]*(?:\\.[^;\\]*)*);?', caseSensitive: false),
      (_) => 'P:[REDACTED];',
    );
  }

  static String redactMessage(String message) {
    var redacted = message;
    redacted = redactWifiRaw(redacted);
    redacted = redacted.replaceAllMapped(
      RegExp(
        r'(password|passwd|psk|pass)(["\s:=]+)([^\s,;}\]]+)',
        caseSensitive: false,
        multiLine: true,
      ),
      (match) => '${match.group(1)}${match.group(2)}[REDACTED]',
    );
    return redacted;
  }

  static bool _isSensitiveKey(String key) {
    final normalized = key.toLowerCase();
    return _sensitiveKeys.contains(normalized);
  }
}
