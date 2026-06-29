import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/app_spacing.dart';
import '../../../../app/navigation_provider.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../domain/enums/qr_result_type.dart';
import '../../domain/models/qr_result.dart';
import '../../../../shared/utils/qr_parser.dart';
import '../../../../shared/utils/qr_type_ui.dart';
import '../../../../shared/utils/url_safety.dart';
import '../../../../shared/security/sensitive_metadata.dart';
import '../../../../shared/utils/app_haptics.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/theme_mode_toggle.dart';

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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.close),
          tooltip: 'Back to Scanner',
          onPressed: () {
            ref.read(selectedTabIndexProvider.notifier).state = 0;
            context.pop();
          },
        ),
        title: const Text('Scan Result'),
        actions: [
          IconButton(
            icon: Icon(
              result.isFavorite ? AppIcons.starFilled : AppIcons.star,
            ),
            tooltip: 'Favorite',
            onPressed: () async {
              await ref
                  .read(scanHistoryProvider.notifier)
                  .toggleFavorite(result.id);
            },
          ),
          const ThemeModeToggle(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PayloadCard(result: result),
            if (result.type == QRResultType.url &&
                UrlSafety.looksSuspicious(result.rawValue)) ...[
              const SizedBox(height: 12),
              Card(
                color: colorScheme.errorContainer,
                elevation: 0,
                child: ListTile(
                  leading: Icon(
                    Icons.warning_amber_outlined,
                    color: colorScheme.onErrorContainer,
                  ),
                  title: Text(
                    'Suspicious link',
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                  subtitle: Text(
                    'This URL uses a shortener. Verify the domain before opening.',
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                ),
              ),
            ],
            if (result.metadata != null &&
                result.type != QRResultType.url &&
                result.type != QRResultType.text) ...[
              const SizedBox(height: 12),
              _MetadataCard(result: result),
            ],
            const SizedBox(height: 24),
            _ActionButtons(result: result),
          ],
        ),
      ),
    );
  }
}

class _PayloadCard extends StatelessWidget {
  final QRResult result;

  const _PayloadCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: result.type.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    result.type.icon,
                    color: result.type.color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.type.displayName,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Decoded payload',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: result.type == QRResultType.url
                    ? _UrlPayloadText(url: result.formattedValue)
                    : SelectableText(
                        result.formattedValue,
                        style: textTheme.bodyLarge?.copyWith(height: 1.45),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Scanned ${_formatTimestamp(result.scannedAt)}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour:$minute';
  }
}

class _UrlPayloadText extends StatelessWidget {
  final String url;

  const _UrlPayloadText({required this.url});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final domain = UrlSafety.extractDomain(url);
    final display = url.trim();

    if (domain == null || !display.toLowerCase().contains(domain)) {
      return SelectableText(
        display,
        style: textTheme.bodyLarge?.copyWith(height: 1.45),
      );
    }

    final index = display.toLowerCase().indexOf(domain);
    final before = display.substring(0, index);
    final domainText = display.substring(index, index + domain.length);
    final after = display.substring(index + domain.length);

    return SelectableText.rich(
      TextSpan(
        style: textTheme.bodyLarge?.copyWith(height: 1.45),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: domainText,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }
}

class _MetadataCard extends StatelessWidget {
  final QRResult result;

  const _MetadataCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final metadata = SensitiveMetadata.redactForDisplay(result.metadata);

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Details',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            ...metadata.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 88,
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
                        style: textTheme.bodyMedium?.copyWith(height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends ConsumerWidget {
  final QRResult result;

  const _ActionButtons({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPrimary = _hasPrimaryAction(result.type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasPrimary)
          FilledButton.icon(
            onPressed: () => _primaryAction(context),
            icon: Icon(_primaryIcon(result.type)),
            label: Text(_primaryLabel(result.type)),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _copy(context),
                icon: const Icon(AppIcons.copy, size: 20),
                label: const Text('Copy'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _share(context),
                icon: const Icon(AppIcons.share, size: 20),
                label: const Text('Share'),
              ),
            ),
            if (result.type == QRResultType.url) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _webSearch(context),
                  icon: const Icon(Icons.search_outlined, size: 20),
                  label: const Text('Search'),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _delete(context, ref),
          icon: const Icon(AppIcons.delete, size: 20),
          label: const Text('Delete scan'),
        ),
      ],
    );
  }

  bool _hasPrimaryAction(QRResultType type) {
    return type == QRResultType.url ||
        type == QRResultType.wifi ||
        type == QRResultType.phone ||
        type == QRResultType.email ||
        type == QRResultType.sms ||
        type == QRResultType.geo;
  }

  IconData _primaryIcon(QRResultType type) {
    switch (type) {
      case QRResultType.url:
        return AppIcons.openExternal;
      case QRResultType.wifi:
        return Icons.wifi_outlined;
      case QRResultType.phone:
        return Icons.phone_outlined;
      case QRResultType.email:
        return Icons.email_outlined;
      case QRResultType.sms:
        return Icons.sms_outlined;
      case QRResultType.geo:
        return Icons.map_outlined;
      default:
        return AppIcons.openExternal;
    }
  }

  String _primaryLabel(QRResultType type) {
    switch (type) {
      case QRResultType.url:
        return 'Open Link';
      case QRResultType.wifi:
        return 'Connect to Wi-Fi';
      case QRResultType.phone:
        return 'Call Number';
      case QRResultType.email:
        return 'Open Email';
      case QRResultType.sms:
        return 'Send SMS';
      case QRResultType.geo:
        return 'Open in Maps';
      default:
        return 'Open';
    }
  }

  Future<void> _primaryAction(BuildContext context) async {
    if (result.type == QRResultType.wifi) {
      await _copyWifiDetails(context);
      if (context.mounted) {
        AppSnackBar.showSuccess(
          context,
          'Wi-Fi details copied — open Settings to connect',
        );
      }
      return;
    }

    final success = await QRContentParser.tryOpen(
      result.type,
      result.rawValue,
      result.metadata,
      context: context,
    );

    if (!success && context.mounted) {
      AppSnackBar.showError(context, 'Could not open this content');
    }
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: result.rawValue));
    await AppHaptics.light();
    if (context.mounted) {
      AppSnackBar.showSuccess(context, 'Copied to clipboard');
    }
  }

  Future<void> _copyWifiDetails(BuildContext context) async {
    final meta = result.metadata;
    final buffer = StringBuffer()
      ..writeln('Network: ${meta?['ssid'] ?? 'Unknown'}')
      ..writeln('Password: ${meta?['password'] ?? ''}')
      ..writeln('Security: ${meta?['encryption'] ?? 'WPA'}');
    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
  }

  Future<void> _share(BuildContext context) async {
    await SharePlus.instance.share(
      ShareParams(text: result.formattedValue, subject: 'QR Scan Result'),
    );
  }

  Future<void> _webSearch(BuildContext context) async {
    final query = Uri.encodeComponent(result.rawValue);
    final uri = Uri.parse('https://www.google.com/search?q=$query');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        AppSnackBar.showError(context, 'Could not open web search');
      }
    }
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
