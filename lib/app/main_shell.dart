import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/analytics/presentation/providers/generated_qr_provider.dart';
import '../features/analytics/presentation/screens/my_qrs_screen.dart';
import '../features/generator/presentation/screens/generator_screen.dart';
import '../features/history/presentation/providers/history_provider.dart';
import '../features/history/presentation/screens/enhanced_history_screen.dart';
import '../features/scanner/presentation/screens/scanner_screen.dart';
import '../shared/widgets/tab_crossfade_stack.dart';
import '../shared/ads/ads_constants.dart';
import '../shared/ads/startapp_banner_slot.dart';
import 'navigation_provider.dart';
import 'router.dart';
import 'theme.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _titles = ['Scanner', 'Generator', 'History', 'My QRs'];

  static const _destinations = [
    (label: 'Scan', semanticsLabel: 'Scanner tab'),
    (label: 'Generate', semanticsLabel: 'Generator tab'),
    (label: 'History', semanticsLabel: 'History tab'),
    (label: 'My QRs', semanticsLabel: 'My QRs tab'),
  ];

  static const _screens = [
    ScannerScreen(),
    GeneratorScreen(),
    EnhancedHistoryScreen(),
    MyQrsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedTabIndexProvider).clamp(0, 3);
    final colorScheme = Theme.of(context).colorScheme;
    final historyCount =
        ref.watch(scanHistoryProvider).valueOrNull?.length ?? 0;
    final myQrsCount = ref.watch(generatedQrProvider).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[selectedIndex].toUpperCase(),
          style: AppTheme.monoLabel(
            context,
            size: 11,
            weight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: () => context.push(AppRoutes.settings),
            child: Text(
              'SETTINGS',
              style: AppTheme.monoLabel(
                context,
                size: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: TabCrossfadeStack(
              index: selectedIndex,
              children: _screens,
            ),
          ),
          StartAppBannerSlot(
            visible: selectedIndex > 0,
            adTag: switch (selectedIndex) {
              1 => AdsConstants.bannerGenerator,
              2 => AdsConstants.bannerHistory,
              3 => AdsConstants.bannerMyQrs,
              _ => AdsConstants.bannerGenerator,
            },
          ),
        ],
      ),
      bottomNavigationBar: Material(
        color: colorScheme.surface,
        child: SafeArea(
          top: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colorScheme.outline)),
            ),
            child: SizedBox(
              height: 56,
              child: Row(
                children: List.generate(_destinations.length, (index) {
                  final dest = _destinations[index];
                  final selected = selectedIndex == index;
                  final count = switch (index) {
                    2 => historyCount,
                    3 => myQrsCount,
                    _ => null,
                  };
                  return Expanded(
                    child: _MonoNavItem(
                      label: dest.label,
                      semanticsLabel: dest.semanticsLabel,
                      selected: selected,
                      count: count,
                      onTap: () {
                        ref.read(selectedTabIndexProvider.notifier).state =
                            index;
                      },
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonoNavItem extends StatelessWidget {
  final String label;
  final String semanticsLabel;
  final bool selected;
  final int? count;
  final VoidCallback onTap;

  const _MonoNavItem({
    required this.label,
    required this.semanticsLabel,
    required this.selected,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = selected
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: selected ? '$semanticsLabel, selected' : semanticsLabel,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (selected)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(height: 1, color: colorScheme.onSurface),
              ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.monoLabel(context, size: 9, color: color),
                ),
                if (count != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$count',
                    style: AppTheme.monoLabel(
                      context,
                      size: 8,
                      color: color.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
