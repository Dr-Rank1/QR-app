import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../scanner/domain/enums/qr_result_type.dart';
import '../providers/history_provider.dart';

class EnhancedHistoryScreen extends ConsumerStatefulWidget {
  const EnhancedHistoryScreen({super.key});

  @override
  ConsumerState<EnhancedHistoryScreen> createState() =>
      _EnhancedHistoryScreenState();
}

class _EnhancedHistoryScreenState
    extends ConsumerState<EnhancedHistoryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getTypeColor(QRResultType type) {
    switch (type) {
      case QRResultType.url:
        return const Color(0xFF2196F3); // Blue
      case QRResultType.phone:
        return const Color(0xFF4CAF50); // Green
      case QRResultType.email:
        return const Color(0xFFFF9800); // Orange
      case QRResultType.wifi:
        return const Color(0xFF9C27B0); // Purple
      case QRResultType.text:
        return const Color(0xFF607D8B); // Grey
    }
  }

  IconData _getTypeIcon(QRResultType type) {
    switch (type) {
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
              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              const Text('Error loading history'),
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

          // Get recent scans (top 3)
          final recentScans = scans.take(3).toList();
          final olderScans = scans.skip(3).toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(scanHistoryProvider);
            },
            child: CustomScrollView(
              slivers: [
                // Recent scans section
                if (recentScans.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Recently Scanned',
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
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
                            typeColor: _getTypeColor(scan.type),
                            icon: _getTypeIcon(scan.type),
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

                // All scans header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(
                      'All Scans',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),

                // Scan list with staggered animation
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final scan = olderScans[index];
                        return _EnhancedHistoryListTile(
                          scan: scan,
                          typeColor: _getTypeColor(scan.type),
                          icon: _getTypeIcon(scan.type),
                          index: index,
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
                      childCount: olderScans.length,
                    ),
                  ),
                ),
              ],
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
          child: Container(
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

class _EnhancedHistoryListTile extends StatefulWidget {
  final dynamic scan;
  final Color typeColor;
  final IconData icon;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _EnhancedHistoryListTile({
    required this.scan,
    required this.typeColor,
    required this.icon,
    required this.index,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_EnhancedHistoryListTile> createState() => _EnhancedHistoryListTileState();
}

class _EnhancedHistoryListTileState extends State<_EnhancedHistoryListTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Stagger the animation based on index
    Future.delayed(
      Duration(milliseconds: 50 * widget.index),
      () {
        if (mounted) _controller.forward();
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              // Color accent bar
              Container(
                width: 4,
                height: 72,
                decoration: BoxDecoration(
                  color: widget.typeColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Card
              Expanded(
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: widget.typeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.typeColor,
                      ),
                    ),
                    title: Text(
                      widget.scan.formattedValue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      '${widget.scan.type.displayName} • ${_formatDate(widget.scan.scannedAt)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: widget.onDelete,
                    ),
                    onTap: widget.onTap,
                  ),
                ),
              ),
            ],
          ),
        ),
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