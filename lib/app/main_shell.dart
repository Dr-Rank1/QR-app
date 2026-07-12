import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/scanner/presentation/screens/scanner_screen.dart';
import '../features/generator/presentation/screens/generator_screen.dart';
import '../features/history/presentation/screens/enhanced_history_screen.dart';
import '../features/analytics/presentation/screens/my_qrs_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../shared/widgets/tab_crossfade_stack.dart';
import 'navigation_provider.dart';
import 'theme.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _destinations = [
    (label: 'Scan', semanticsLabel: 'Scanner tab'),
    (label: 'Generate', semanticsLabel: 'Generator tab'),
    (label: 'History', semanticsLabel: 'History tab'),
    (label: 'My QRs', semanticsLabel: 'My QRs analytics tab'),
    (label: 'Settings', semanticsLabel: 'Settings tab'),
  ];

  static const _screens = [
    ScannerScreen(),
    GeneratorScreen(),
    EnhancedHistoryScreen(),
    MyQrsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedTabIndexProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: TabCrossfadeStack(
        index: selectedIndex,
        children: _screens,
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
              height: 52,
              child: Row(
                children: List.generate(_destinations.length, (index) {
                  final dest = _destinations[index];
                  final selected = selectedIndex == index;
                  return Expanded(
                    child: _MonoNavItem(
                      label: dest.label,
                      semanticsLabel: dest.semanticsLabel,
                      selected: selected,
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
  final VoidCallback onTap;

  const _MonoNavItem({
    required this.label,
    required this.semanticsLabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: selected ? '$semanticsLabel, selected' : semanticsLabel,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.monoLabel(
                context,
                size: 9,
                color: selected
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            if (selected)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 1,
                  color: colorScheme.onSurface,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
