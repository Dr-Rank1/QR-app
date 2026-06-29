import 'package:flutter/material.dart';

import '../../app/app_spacing.dart';
import '../../features/scanner/domain/enums/qr_result_type.dart';
import '../../features/scanner/domain/models/qr_result.dart';

class ScanStats {
  final int total;
  final int favorites;
  final Map<QRResultType, int> byType;
  final int today;

  const ScanStats({
    required this.total,
    required this.favorites,
    required this.byType,
    required this.today,
  });

  factory ScanStats.fromScans(List<QRResult> scans) {
    final byType = <QRResultType, int>{};
    final todayStart = DateTime.now();
    final today = DateTime(todayStart.year, todayStart.month, todayStart.day);
    var todayCount = 0;

    for (final scan in scans) {
      byType[scan.type] = (byType[scan.type] ?? 0) + 1;
      if (!scan.scannedAt.isBefore(today)) todayCount++;
    }

    return ScanStats(
      total: scans.length,
      favorites: scans.where((s) => s.isFavorite).length,
      byType: byType,
      today: todayCount,
    );
  }

  QRResultType? get topType {
    if (byType.isEmpty) return null;
    return byType.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}

class ScanStatsBanner extends StatelessWidget {
  final ScanStats stats;

  const ScanStatsBanner({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.total == 0) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final top = stats.topType;

    return Card(
      margin: EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        8,
        AppSpacing.screenHorizontal,
        0,
      ),
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _StatBlock(
                label: 'Total',
                value: '${stats.total}',
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            Expanded(
              child: _StatBlock(
                label: 'Today',
                value: '${stats.today}',
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            Expanded(
              child: _StatBlock(
                label: 'Favorites',
                value: '${stats.favorites}',
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            if (top != null)
              Expanded(
                child: _StatBlock(
                  label: 'Top type',
                  value: top.displayName,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBlock({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
