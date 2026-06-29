import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../history/presentation/providers/history_provider.dart';
import '../../domain/enums/qr_result_type.dart';
import '../../domain/models/qr_result.dart';
import '../../../../shared/utils/qr_parser.dart';
import '../../../../shared/utils/qr_type_ui.dart';

class ResultDetailScreen extends ConsumerWidget {
  final String scanId;

  const ResultDetailScreen({
    super.key,
    required this.scanId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(scanHistoryProvider);

    return historyAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Error loading scan')),
      ),
      data: (scans) {
        final result = scans.where((s) => s.id == scanId).firstOrNull;

        if (result == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Scan not found')),
          );
        }

        return _ResultDetailContent(result: result);
      },
    );
  }
}

class _ResultDetailContent extends ConsumerWidget {
  final QRResult result;

  const _ResultDetailContent({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Result'),
        actions: [
          IconButton(
            icon: Icon(
              result.isFavorite ? Icons.star : Icons.star_border,
            ),
            onPressed: () async {
              await ref.read(scanHistoryProvider.notifier).toggleFavorite(result.id);
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _share(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: result.type.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(result.type.icon, size: 18, color: result.type.color),
                  const SizedBox(width: 8),
                  Text(
                    result.type.displayName,
                    style: textTheme.labelLarge?.copyWith(color: result.type.color),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
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
            if (result.metadata != null) ...[
              const SizedBox(height: 16),
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
                                child: Text(entry.value, style: textTheme.bodyMedium),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Scanned on ${_formatDate(result.scannedAt)}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            _ActionButtons(result: result),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _share(BuildContext context) async {
    await SharePlus.instance.share(
      ShareParams(text: result.formattedValue, subject: 'QR Scan Result'),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
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
      await ref.read(scanHistoryProvider.notifier).deleteScan(result.id);
      if (context.mounted) context.pop();
    }
  }
}

class _ActionButtons extends StatelessWidget {
  final QRResult result;

  const _ActionButtons({required this.result});

  @override
  Widget build(BuildContext context) {
    final canOpen = result.type != QRResultType.text &&
        result.type != QRResultType.wifi &&
        result.type != QRResultType.vcard &&
        result.type != QRResultType.calendar;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _copy(context),
            icon: const Icon(Icons.copy),
            label: const Text('Copy to Clipboard'),
          ),
        ),
        if (canOpen) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _open(context),
              icon: const Icon(Icons.open_in_new),
              label: Text(_getOpenLabel()),
            ),
          ),
        ],
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
      case QRResultType.sms:
        return 'Send SMS';
      case QRResultType.geo:
        return 'Open in Maps';
      default:
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
      context: context,
    );

    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this content')),
      );
    }
  }
}
