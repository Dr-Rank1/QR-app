import 'package:flutter/material.dart';

class UrlSafety {
  static const _suspiciousPatterns = [
    'bit.ly',
    'tinyurl.com',
    't.co',
    'goo.gl',
    'rb.gy',
    'is.gd',
  ];

  static String? extractDomain(String url) {
    try {
      var normalized = url.trim();
      if (!normalized.contains('://')) {
        normalized = 'https://$normalized';
      }
      return Uri.parse(normalized).host.toLowerCase();
    } catch (_) {
      return null;
    }
  }

  static bool looksSuspicious(String url) {
    final domain = extractDomain(url);
    if (domain == null) return true;
    return _suspiciousPatterns.any((pattern) => domain.contains(pattern));
  }

  static Future<bool> confirmOpen(BuildContext context, String url) async {
    final domain = extractDomain(url) ?? url;
    final suspicious = looksSuspicious(url);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open Link?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to open:', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            SelectableText(
              domain,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (suspicious) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This link uses a URL shortener. Proceed with caution.',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Open'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }
}
