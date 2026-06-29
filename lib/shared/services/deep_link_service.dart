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

/// Parses custom scheme and app-specific HTTPS links.
class DeepLinkService {
  static const customScheme = 'qrvault';
  static const httpsHost = 'scan.qrvault.app';

  static DeepLinkAction? parse(Uri uri) {
    final normalized = uri.normalizePath();

    if (uri.scheme == customScheme) {
      return _parseCustomScheme(normalized);
    }

    if (uri.scheme == 'https' && uri.host == httpsHost) {
      return _parseHttpsLink(normalized);
    }

    return null;
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

  static DeepLinkAction? _parseHttpsLink(Uri uri) {
    final data = uri.queryParameters['data'] ?? uri.queryParameters['payload'];
    if (data == null || data.isEmpty) return const OpenScannerDeepLink();

    if (uri.path.startsWith('/generate')) {
      return GenerateDeepLink(Uri.decodeComponent(data));
    }

    return ScanDeepLink(Uri.decodeComponent(data));
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
