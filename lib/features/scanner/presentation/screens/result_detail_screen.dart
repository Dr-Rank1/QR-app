import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/app_spacing.dart';
import '../../../../app/navigation_provider.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../domain/enums/qr_result_type.dart';
import '../../domain/models/qr_result.dart';
import '../../../../shared/ads/ads_provider.dart';
import '../../../../shared/utils/qr_content_actions.dart';
import '../../../../shared/utils/qr_parser.dart';
import '../../../../shared/utils/qr_type_ui.dart';
import '../../../../shared/utils/url_safety.dart';
import '../../../../shared/security/sensitive_metadata.dart';
import '../../../../shared/utils/app_haptics.dart';
import '../../../../app/theme.dart';
import '../../../../shared/services/service_providers.dart';
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

Future<void> _exitResultScreen(BuildContext context, WidgetRef ref) async {
  await ref.read(adsServiceProvider).maybeShowInterstitialOnResultExit();
  if (!context.mounted) return;
  ref.read(selectedTabIndexProvider.notifier).state = 0;
  context.pop();
}

class _ResultDetailContent extends ConsumerWidget {
  final QRResult result;

  const _ResultDetailContent({required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_exitResultScreen(context, ref));
      },
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.close),
          tooltip: 'Back to Scanner',
          onPressed: () => unawaited(_exitResultScreen(context, ref)),
        ),
        title: Text(
          'RESULT',
          style: AppTheme.monoLabel(
            context,
            size: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
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
          IconButton(
            icon: const Icon(AppIcons.share),
            tooltip: 'Share',
            onPressed: () async {
              await ref
                  .read(shareServiceProvider)
                  .shareText(result.formattedValue);
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
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 40,
                  color: result.type.color,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.type.displayName.toUpperCase(),
                        style: AppTheme.monoLabel(
                          context,
                          size: 11,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'DECODED PAYLOAD',
                        style: AppTheme.monoLabel(context),
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
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DETAILS',
              style: AppTheme.monoLabel(context),
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
    final hasPrimary = QRContentActions.hasPrimary(result.type);
    final secondary = QRContentActions.secondaryActions(result);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasPrimary)
          FilledButton.icon(
            onPressed: () => _primaryAction(context, ref),
            icon: Icon(QRContentActions.primaryIcon(result.type)),
            label: Text(
              QRContentActions.primaryLabel(
                result.type,
                metadata: result.metadata,
              ).toUpperCase(),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),
        if (secondary.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < secondary.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _runSecondary(context, secondary[i]),
                    icon: Icon(secondary[i].icon, size: 18),
                    label: Text(secondary[i].label.toUpperCase()),
                  ),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _copy(context),
                child: const Text('COPY'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _share(context, ref),
                child: const Text('SHARE'),
              ),
            ),
            if (result.type == QRResultType.url) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _webSearch(context),
                  child: const Text('SEARCH'),
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

  Future<void> _primaryAction(BuildContext context, WidgetRef ref) async {
    final outcome = await QRContentActions.runPrimary(
      context,
      result,
      shareService: ref.read(shareServiceProvider),
    );
    if (!context.mounted || outcome.silent) return;
    if (outcome.success) {
      if (outcome.message != null) {
        AppSnackBar.showSuccess(context, outcome.message!);
      }
    } else if (outcome.message != null) {
      AppSnackBar.showError(context, outcome.message!);
    }
  }

  Future<void> _runSecondary(
    BuildContext context,
    QRSecondaryAction action,
  ) async {
    final success = await QRContentParser.tryOpen(
      action.type,
      action.value,
      action.metadata,
      context: context,
    );
    if (!success && context.mounted) {
      AppSnackBar.showError(context, 'Could not open ${action.label}');
    }
  }

  Future<void> _copy(BuildContext context) async {
    final text = result.type == QRResultType.wifi
        ? QRContentActions.wifiCredentials(result.metadata)
        : result.rawValue;
    await Clipboard.setData(ClipboardData(text: text));
    await AppHaptics.light();
    if (context.mounted) {
      AppSnackBar.showSuccess(context, 'Copied to clipboard');
    }
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    await ref.read(shareServiceProvider).shareText(result.formattedValue);
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
