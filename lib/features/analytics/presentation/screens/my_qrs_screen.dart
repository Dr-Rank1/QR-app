import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/app_spacing.dart';
import '../../../../app/theme.dart';
import '../../../../shared/services/service_providers.dart';
import '../../../../shared/utils/app_haptics.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../generator/domain/qr_payload_builder.dart';
import '../../../generator/domain/services/qr_generation_service.dart';
import '../providers/generated_qr_provider.dart';

/// Local gallery of generated QRs with placeholder scan analytics.
class MyQrsScreen extends ConsumerWidget {
  const MyQrsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(generatedQrProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: items.isEmpty
          ? _EmptyState()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    12,
                    AppSpacing.screenHorizontal,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${items.length} SAVED',
                          style: AppTheme.monoLabel(context, size: 10),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Clear My QRs?'),
                              content: const Text(
                                'Removes locally saved generated codes.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Clear'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await ref.read(generatedQrProvider.notifier).clear();
                          }
                        },
                        child: Text(
                          'CLEAR ALL',
                          style: AppTheme.monoLabel(
                            context,
                            size: 10,
                            color: colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      12,
                      AppSpacing.screenHorizontal,
                      24,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _GeneratedQrTile(
                        item: item,
                        onShare: () async {
                          final png = await ref
                              .read(qrGenerationServiceProvider)
                              .renderQrPng(
                                item.payload,
                                options: QrRenderOptions(
                                  size: 280,
                                  foregroundColor: item.fg,
                                  backgroundColor: item.bg,
                                ),
                              );
                          await ref
                              .read(shareServiceProvider)
                              .shareQrImage(png);
                          await AppHaptics.success();
                        },
                        onDelete: () async {
                          await ref
                              .read(generatedQrProvider.notifier)
                              .delete(item.id);
                          if (context.mounted) {
                            AppSnackBar.showInfo(
                              context,
                              'Removed from My QRs',
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final muted = colorScheme.onSurfaceVariant.withValues(alpha: 0.35);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insights_outlined, size: 56, color: muted),
            const SizedBox(height: 24),
            Text(
              'EMPTY',
              style: AppTheme.monoLabel(
                context,
                size: 11,
                weight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate a QR code and tap “Save to My QRs”.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: muted,
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneratedQrTile extends StatelessWidget {
  final GeneratedQr item;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _GeneratedQrTile({
    required this.item,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              color: item.bg,
              padding: const EdgeInsets.all(6),
              child: QrImageView(
                data: item.payload,
                size: 52,
                backgroundColor: item.bg,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: item.fg,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: item.fg,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.type.label.toUpperCase(),
                    style: AppTheme.monoLabel(context, size: 9),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'SCANS',
                        style: AppTheme.monoLabel(context, size: 8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.scanCount == 0 ? '—' : '${item.scanCount}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'PRO SOON',
                        style: AppTheme.monoLabel(
                          context,
                          size: 8,
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Share',
              onPressed: onShare,
              icon: const Icon(AppIcons.share, size: 18),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: const Icon(AppIcons.delete, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
