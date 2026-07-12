import 'package:http/http.dart' as http;

/// Shortens long URLs before QR encoding to reduce density.
///
/// Uses the public is.gd API (no API key). Fails gracefully when offline.
class UrlShortenerService {
  UrlShortenerService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _endpoint = 'https://is.gd/create.php';

  Future<String> shorten(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('URL is empty');
    }

    final uri = Uri.parse(_endpoint).replace(
      queryParameters: {
        'format': 'simple',
        'url': trimmed,
      },
    );

    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw UrlShortenerException(
        'Shortener returned ${response.statusCode}',
      );
    }

    final body = response.body.trim();
    if (body.isEmpty ||
        body.toLowerCase().contains('error') ||
        !body.toLowerCase().startsWith('http')) {
      throw UrlShortenerException(
        body.isEmpty ? 'Empty shortener response' : body,
      );
    }

    return body;
  }

  void dispose() {
    _client.close();
  }
}

class UrlShortenerException implements Exception {
  final String message;
  UrlShortenerException(this.message);

  @override
  String toString() => message;
}
