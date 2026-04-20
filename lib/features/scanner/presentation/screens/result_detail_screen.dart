import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../history/data/repositories/scan_history_repository.dart';
import '../../domain/enums/qr_result_type.dart';
import '../../domain/models/qr_result.dart';
import '../../../../shared/utils/qr_parser.dart';

class ResultDetailScreen extends ConsumerWidget {
  final String scanId;

  const ResultDetailScreen({
    super.key,
    required this.scanId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<QRResult?>(
      future: ScanHistoryRepository().getScan(scanId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final result = snapshot.data;
        if (result == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: Text('Scan not found'),
            ),
          );
        }

        return _ResultDetailContent(result: result);
      },
    );
  }
}

class _ResultDetailContent extends StatelessWidget {
  final QRResult result;

  const _ResultDetailContent({required this.result});

  Color _getTypeColor(QRResultType type) {
    switch (type) {
      case QRResultType.url:
        return const Color(0xFF2196F3);
      case QRResultType.phone:
        return const Color(0xFF4CAF50);
      case QRResultType.email:
        return const Color(0xFFFF9800);
      case QRResultType.wifi:
        return const Color(0xFF9C27B0);
      case QRResultType.text:
        return const Color(0xFF607D8B);
    }
  }

  IconData _getIcon() {
    switch (result.type) {
      case QRResultType.url:
        return Icons.link;
      case QRResultType.phone:
        return Icons.phone;
      case QRResultType.email:
        return Icons.email;
      case QRResultType.wifi:
        return Icons.wifi;
      case QRResultType.text:
        return Icons.text_fields;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Result'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _share(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getIcon(),
                    size: 18,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    result.type.displayName,
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Value card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Content',
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      result.formattedValue,
                      style: textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Metadata (for Wi-Fi)
            if (result.metadata != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Details',
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...result.metadata!.entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 80,
                                child: Text(
                                  entry.key.toUpperCase(),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Scanned at
            Text(
              'Scanned on ${_formatDate(result.scannedAt)}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // Action buttons
            _ActionButtons(result: result),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _share(BuildContext context) async {
    await Share.share(
      result.formattedValue,
      subject: 'QR Scan Result',
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Scan'),
        content: const Text('Are you sure you want to delete this scan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ScanHistoryRepository().deleteScan(result.id);
      if (context.mounted) {
        context.pop();
      }
    }
  }
}

class _ActionButtons extends StatelessWidget {
  final QRResult result;

  const _ActionButtons({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Copy button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _copy(context),
            icon: const Icon(Icons.copy),
            label: const Text('Copy to Clipboard'),
          ),
        ),
        const SizedBox(height: 12),

        // Open button (for URLs, phone, email)
        if (result.type != QRResultType.text && result.type != QRResultType.wifi)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _open(context),
              icon: const Icon(Icons.open_in_new),
              label: Text(_getOpenLabel()),
            ),
          ),
      ],
    );
  }

  String _getOpenLabel() {
    switch (result.type) {
      case QRResultType.url:
        return 'Open in Browser';
      case QRResultType.phone:
        return 'Call Number';
      case QRResultType.email:
        return 'Open Email App';
      case QRResultType.wifi:
        return 'Connect to Wi-Fi';
      case QRResultType.text:
        return 'Open';
    }
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: result.rawValue));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to clipboard')),
      );
    }
  }

  Future<void> _open(BuildContext context) async {
    final success = await QRContentParser.tryOpen(
      result.type,
      result.rawValue,
      result.metadata,
    );

    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.type == QRResultType.wifi
                ? 'Wi-Fi connection must be done manually'
                : 'Could not open',
          ),
        ),
      );
    }
  }
}