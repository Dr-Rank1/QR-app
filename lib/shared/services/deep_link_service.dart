import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Parsed deep-link action for in-app routing.
sealed class DeepLinkAction {
  const DeepLinkAction();
}

class ScanDeepLink extends DeepLinkAction {
  final String payload;

  const ScanDeepLink(this.payload);
}

class GenerateDeepLink extends DeepLinkAction {
  final String payload;

  const GenerateDeepLink(this.payload);
}

class OpenScannerDeepLink extends DeepLinkAction {
  const OpenScannerDeepLink();
}

/// Parses custom-scheme deep links (`qrvault://`).
class DeepLinkService {
  static const customScheme = 'qrvault';

  static DeepLinkAction? parse(Uri uri) {
    if (uri.scheme != customScheme) return null;
    return _parseCustomScheme(uri.normalizePath());
  }

  static DeepLinkAction? _parseCustomScheme(Uri uri) {
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    final data = uri.queryParameters['data'] ?? uri.queryParameters['payload'];

    if (host == 'scan' || path == '/scan') {
      if (data != null && data.isNotEmpty) {
        return ScanDeepLink(Uri.decodeComponent(data));
      }
      return const OpenScannerDeepLink();
    }

    if (host == 'generate' || path == '/generate') {
      if (data != null && data.isNotEmpty) {
        return GenerateDeepLink(Uri.decodeComponent(data));
      }
      return const OpenScannerDeepLink();
    }

    if (host == 'open' || path == '/open') {
      final url = uri.queryParameters['url'];
      if (url != null && url.isNotEmpty) {
        return ScanDeepLink(Uri.decodeComponent(url));
      }
    }

    return null;
  }

  static Uri buildScanLink(String payload) {
    return Uri(
      scheme: customScheme,
      host: 'scan',
      queryParameters: {'data': payload},
    );
  }
}

final inboundDeepLinkProvider = StateProvider<DeepLinkAction?>((ref) => null);

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  return DeepLinkService();
});
