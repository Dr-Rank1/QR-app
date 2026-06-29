import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/app_spacing.dart';
import '../../../../app/router.dart';
import '../../../../shared/utils/app_haptics.dart';
import '../../../../shared/utils/qr_type_ui.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/theme_mode_toggle.dart';
import '../../../scanner/domain/enums/qr_result_type.dart';
import '../../../scanner/domain/models/qr_result.dart';
import '../providers/history_provider.dart';

class EnhancedHistoryScreen extends ConsumerStatefulWidget {
  const EnhancedHistoryScreen({super.key});

  @override
  ConsumerState<EnhancedHistoryScreen> createState() =>
      _EnhancedHistoryScreenState();
}

class _EnhancedHistoryScreenState extends ConsumerState<EnhancedHistoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportHistory() async {
    final scans = ref.read(scanHistoryProvider).valueOrNull ?? [];
    if (scans.isEmpty) {
      if (mounted) {
        AppSnackBar.showInfo(context, 'Nothing to export');
      }
      return;
    }

    final json = await ref.read(scanHistoryProvider.notifier).exportAsJson();
    await SharePlus.instance.share(
      ShareParams(text: json, subject: 'QR Vault Export'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(scanHistoryProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          const ThemeModeToggle(),
          PopupMenuButton<_HistoryMenuAction>(
            tooltip: 'More',
            onSelected: (action) {
              switch (action) {
                case _HistoryMenuAction.export:
                  _exportHistory();
                case _HistoryMenuAction.clearAll:
                  _showClearConfirmation(context, ref);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _HistoryMenuAction.export,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(AppIcons.export, size: 22),
                  title: Text('Export'),
                ),
              ),
              PopupMenuItem(
                value: _HistoryMenuAction.clearAll,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    AppIcons.delete,
                    size: 22,
                    color: colorScheme.error,
                  ),
                  title: Text(
                    'Clear all',
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              8,
              AppSpacing.screenHorizontal,
              4,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search vault…',
                isDense: true,
                prefixIcon: const Icon(AppIcons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(AppIcons.close, size: 18),
                        tooltip: 'Clear',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 40,
                      color: colorScheme.error.withValues(alpha: 0.8),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load history',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => ref.invalidate(scanHistoryProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (scans) {
                final filtered = filterScans(
                  scans,
                  query: _query,
                  filter: HistoryFilter.all,
                );

                if (filtered.isEmpty) {
                  return _VaultEmptyState(
                    isSearching: scans.isNotEmpty && _query.isNotEmpty,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(scanHistoryProvider),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      8,
                      AppSpacing.screenHorizontal,
                      24,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final scan = filtered[index];
                      return _VaultHistoryTile(
                        scan: scan,
                        onTap: () => context.push(
                          AppRoutes.resultDetailPath(scan.id),
                        ),
                        onDelete: () => ref
                            .read(scanHistoryProvider.notifier)
                            .deleteScan(scan.id),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showClearConfirmation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              0,
              AppSpacing.screenHorizontal,
              16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Clear vault?',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  'All saved scans will be permanently removed from this device.',
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: const Text('Clear all'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      await ref.read(scanHistoryProvider.notifier).clearAll();
      if (mounted) {
        AppSnackBar.showSuccess(context, 'Vault cleared');
      }
    }
  }
}

enum _HistoryMenuAction { export, clearAll }

class _VaultEmptyState extends StatelessWidget {
  final bool isSearching;

  const _VaultEmptyState({required this.isSearching});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final muted = colorScheme.onSurfaceVariant.withValues(alpha: 0.45);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching ? Icons.search_off_rounded : Icons.inventory_2_outlined,
              size: 44,
              color: muted,
            ),
            const SizedBox(height: 16),
            Text(
              isSearching ? 'No matches' : 'Vault is empty',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
            ),
            if (!isSearching) ...[
              const SizedBox(height: 6),
              Text(
                'Scanned codes will appear here',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: muted,
                      height: 1.4,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VaultHistoryTile extends StatelessWidget {
  final QRResult scan;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;

  const _VaultHistoryTile({
    required this.scan,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(scan.id),
      direction: DismissDirection.horizontal,
      background: _DismissBackground(
        alignment: Alignment.centerLeft,
        color: colorScheme.error,
        iconColor: colorScheme.onError,
      ),
      secondaryBackground: _DismissBackground(
        alignment: Alignment.centerRight,
        color: colorScheme.error,
        iconColor: colorScheme.onError,
      ),
      confirmDismiss: (_) async {
        await AppHaptics.light();
        await onDelete();
        return true;
      },
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(
                  scan.type.icon,
                  size: 20,
                  color: scan.type.color.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _displayTitle(scan),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _relativeDate(scan.scannedAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _displayTitle(QRResult scan) {
    var title = scan.formattedValue.trim();

    if (scan.type == QRResultType.url) {
      title = title
          .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
          .replaceFirst(RegExp(r'^www\.', caseSensitive: false), '');
      final slash = title.indexOf('/');
      if (slash > 0) title = title.substring(0, slash);
    }

    if (scan.type == QRResultType.wifi) {
      title = scan.metadata?['ssid'] ?? 'Wi-Fi network';
    }

    if (title.length > 64) {
      return '${title.substring(0, 64)}…';
    }
    return title;
  }

  static String _relativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scannedDay = DateTime(date.year, date.month, date.day);
    final days = today.difference(scannedDay).inDays;

    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '$days days ago';
    if (days < 30) return '${days ~/ 7} wk ago';
    if (days < 365) return '${days ~/ 30} mo ago';
    return '${days ~/ 365} yr ago';
  }
}

class _DismissBackground extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  final Color iconColor;

  const _DismissBackground({
    required this.alignment,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(AppIcons.delete, color: iconColor, size: 22),
    );
  }
}
