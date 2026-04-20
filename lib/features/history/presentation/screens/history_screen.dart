import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../scanner/domain/enums/qr_result_type.dart';
import '../providers/history_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(scanHistoryProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => _showClearDialog(context, ref),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text('Error loading history'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(scanHistoryProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (scans) {
          if (scans.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.qr_code_scanner,
              title: 'No Scans Yet',
              subtitle: 'QR codes you scan will appear here.',
              action: FilledButton.icon(
                onPressed: () => context.go(AppRoutes.scanner),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Start Scanning'),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(scanHistoryProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: scans.length,
              itemBuilder: (context, index) {
                final scan = scans[index];
                return _HistoryListTile(
                  scan: scan,
                  onTap: () => context.push(
                    AppRoutes.resultDetailPath(scan.id),
                  ),
                  onDelete: () async {
                    await ref
                        .read(scanHistoryProvider.notifier)
                        .deleteScan(scan.id);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _showClearDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All History'),
        content: const Text(
          'Are you sure you want to delete all scan history? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(scanHistoryProvider.notifier).clearAll();
    }
  }
}

class _HistoryListTile extends StatelessWidget {
  final dynamic scan;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryListTile({
    required this.scan,
    required this.onTap,
    required this.onDelete,
  });

  IconData _getIcon() {
    switch (scan.type) {
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getIcon(),
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          scan.formattedValue,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '${scan.type.displayName} • ${_formatDate(scan.scannedAt)}',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}