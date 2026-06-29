/// Result of sanitizing a scanned or inbound payload.
class SanitizedPayload {
  final String value;
  final bool isBlocked;
  final String? blockReason;

  const SanitizedPayload({
    required this.value,
    this.isBlocked = false,
    this.blockReason,
  });

  bool get isAllowed => !isBlocked && value.isNotEmpty;
}

/// Strict sanitization for scanned QR payloads to reduce injection and
/// malicious URL execution risks. Local-only; no network calls.
class PayloadSanitizer {
  static const _blockedUrlSchemes = {
    'javascript',
    'data',
    'file',
    'vbscript',
    'intent',
    'content',
    'blob',
  };

  static const _allowedUrlSchemes = {'http', 'https', 'tel', 'mailto', 'sms', 'smsto', 'geo'};

  static final _controlChars = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');

  /// Sanitizes raw scan text before parsing or persistence.
  static SanitizedPayload sanitizeRaw(String raw) {
    var value = raw.trim();
    if (value.isEmpty) {
      return const SanitizedPayload(value: '', isBlocked: true, blockReason: 'Empty payload');
    }

    value = value.replaceAll(_controlChars, '');
    if (value.length > 4096) {
      value = value.substring(0, 4096);
    }

    final lower = value.toLowerCase();
    if (_containsInlineScript(lower)) {
      return SanitizedPayload(
        value: value,
        isBlocked: true,
        blockReason: 'Blocked potentially malicious script content',
      );
    }

    if (_looksLikeUrl(lower) || lower.contains('://')) {
      final urlCheck = sanitizeUrl(value);
      if (urlCheck.isBlocked) return urlCheck;
      return SanitizedPayload(value: urlCheck.value);
    }

    return SanitizedPayload(value: value);
  }

  /// Validates and normalizes URLs before they are opened in a browser.
  static SanitizedPayload sanitizeUrl(String raw) {
    var value = raw.trim().replaceAll(_controlChars, '');
    if (value.isEmpty) {
      return const SanitizedPayload(value: '', isBlocked: true, blockReason: 'Empty URL');
    }

    if (!value.contains('://')) {
      value = 'https://$value';
    }

    Uri uri;
    try {
      uri = Uri.parse(value);
    } catch (_) {
      return SanitizedPayload(
        value: value,
        isBlocked: true,
        blockReason: 'Malformed URL',
      );
    }

    final scheme = uri.scheme.toLowerCase();
    if (_blockedUrlSchemes.contains(scheme)) {
      return SanitizedPayload(
        value: value,
        isBlocked: true,
        blockReason: 'Blocked URL scheme: $scheme',
      );
    }

    if (!_allowedUrlSchemes.contains(scheme)) {
      return SanitizedPayload(
        value: value,
        isBlocked: true,
        blockReason: 'Unsupported URL scheme: $scheme',
      );
    }

    if ((scheme == 'http' || scheme == 'https') && (uri.host.isEmpty)) {
      return SanitizedPayload(
        value: value,
        isBlocked: true,
        blockReason: 'URL host is missing',
      );
    }

    if (_containsInlineScript(uri.toString().toLowerCase())) {
      return SanitizedPayload(
        value: value,
        isBlocked: true,
        blockReason: 'Blocked suspicious URL content',
      );
    }

    return SanitizedPayload(value: uri.toString());
  }

  /// Sanitizes metadata maps (e.g. Wi-Fi fields) before storage/display.
  static Map<String, String> sanitizeMetadata(Map<String, String>? metadata) {
    if (metadata == null) return {};
    final sanitized = <String, String>{};
    for (final entry in metadata.entries) {
      final key = entry.key.replaceAll(_controlChars, '');
      var val = entry.value.replaceAll(_controlChars, '');
      if (val.length > 512) {
        val = val.substring(0, 512);
      }
      sanitized[key] = val;
    }
    return sanitized;
  }

  static bool _looksLikeUrl(String lower) {
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('www.') ||
        _blockedUrlSchemes.any((scheme) => lower.startsWith('$scheme:'));
  }

  static bool _containsInlineScript(String lower) {
    return lower.contains('<script') ||
        lower.contains('javascript:') ||
        lower.contains('onerror=') ||
        lower.contains('onload=');
  }
}
