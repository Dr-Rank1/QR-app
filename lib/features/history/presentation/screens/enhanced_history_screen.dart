import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/router.dart';
import '../../../../app/navigation_provider.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/utils/qr_type_ui.dart';
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
  HistoryFilter _filter = HistoryFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportHistory() async {
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
        title: const Text('Scan History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_outlined),
            tooltip: 'Export',
            onPressed: _exportHistory,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => _showClearDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search scans...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: HistoryFilter.values.map((filter) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_filterLabel(filter)),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                    const SizedBox(height: 16),
                    const Text('Error loading history'),
                    FilledButton(
                      onPressed: () => ref.invalidate(scanHistoryProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (scans) {
                final filtered = filterScans(scans, query: _query, filter: _filter);

                if (filtered.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.qr_code_scanner,
                    title: scans.isEmpty ? 'No Scans Yet' : 'No Results',
                    subtitle: scans.isEmpty
                        ? 'QR codes you scan will appear here.'
                        : 'Try a different search or filter.',
                    action: scans.isEmpty
                        ? FilledButton.icon(
                            onPressed: () =>
                                ref.read(selectedTabIndexProvider.notifier).state = 0,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Start Scanning'),
                          )
                        : null,
                  );
                }

                final recentScans = filtered.take(3).toList();

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(scanHistoryProvider),
                  child: CustomScrollView(
                    slivers: [
                      if (recentScans.isNotEmpty && _query.isEmpty && _filter == HistoryFilter.all) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: Text(
                              'Recently Scanned',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 80,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: recentScans.length,
                              itemBuilder: (context, index) {
                                final scan = recentScans[index];
                                return _RecentScanChip(
                                  typeColor: scan.type.color,
                                  icon: scan.type.icon,
                                  label: scan.formattedValue.length > 15
                                      ? '${scan.formattedValue.substring(0, 15)}...'
                                      : scan.formattedValue,
                                  onTap: () => context.push(
                                    AppRoutes.resultDetailPath(scan.id),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'All Scans (${filtered.length})',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final scan = filtered[index];
                              return _HistoryListTile(
                                scan: scan,
                                onTap: () => context.push(
                                  AppRoutes.resultDetailPath(scan.id),
                                ),
                                onDelete: () => ref
                                    .read(scanHistoryProvider.notifier)
                                    .deleteScan(scan.id),
                                onFavorite: () => ref
                                    .read(scanHistoryProvider.notifier)
                                    .toggleFavorite(scan.id),
                              );
                            },
                            childCount: filtered.length,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _filterLabel(HistoryFilter filter) {
    switch (filter) {
      case HistoryFilter.all:
        return 'All';
      case HistoryFilter.favorites:
        return 'Favorites';
      case HistoryFilter.url:
        return 'URLs';
      case HistoryFilter.wifi:
        return 'Wi-Fi';
      case HistoryFilter.contact:
        return 'Contacts';
    }
  }

  Future<void> _showClearDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All History'),
        content: const Text(
          'Are you sure you want to delete all scan history? This cannot be undone.',
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

class _RecentScanChip extends StatelessWidget {
  final Color typeColor;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RecentScanChip({
    required this.typeColor,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: typeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: typeColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: typeColor,
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
}

class _HistoryListTile extends StatelessWidget {
  final QRResult scan;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onFavorite;

  const _HistoryListTile({
    required this.scan,
    required this.onTap,
    required this.onDelete,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(scan.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: colorScheme.error,
        child: Icon(Icons.delete, color: colorScheme.onError),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scan.type.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(scan.type.icon, color: scan.type.color),
          ),
          title: Text(
            scan.formattedValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text('${scan.type.displayName} • ${_formatDate(scan.scannedAt)}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  scan.isFavorite ? Icons.star : Icons.star_border,
                  color: scan.isFavorite ? Colors.amber : null,
                ),
                onPressed: onFavorite,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
