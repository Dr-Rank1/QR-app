import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_spacing.dart';
import '../features/scanner/presentation/screens/scanner_screen.dart';
import '../features/generator/presentation/screens/generator_screen.dart';
import '../features/history/presentation/screens/enhanced_history_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../shared/widgets/app_icons.dart';
import '../shared/widgets/tab_crossfade_stack.dart';
import 'navigation_provider.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _destinations = [
    (
      icon: AppIcons.scanner,
      selectedIcon: AppIcons.scannerFilled,
      label: 'Scanner',
      semanticsLabel: 'Scanner tab',
    ),
    (
      icon: AppIcons.generator,
      selectedIcon: AppIcons.generatorFilled,
      label: 'Generator',
      semanticsLabel: 'Generator tab',
    ),
    (
      icon: AppIcons.history,
      selectedIcon: AppIcons.historyFilled,
      label: 'History',
      semanticsLabel: 'History tab',
    ),
    (
      icon: AppIcons.settings,
      selectedIcon: AppIcons.settingsFilled,
      label: 'Settings',
      semanticsLabel: 'Settings tab',
    ),
  ];

  static const _screens = [
    ScannerScreen(),
    GeneratorScreen(),
    EnhancedHistoryScreen(),
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal - 4,
            0,
            AppSpacing.screenHorizontal - 4,
            8,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Material(
              color: colorScheme.surfaceContainerHigh,
              elevation: 4,
              shadowColor: colorScheme.shadow.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Row(
                  children: List.generate(_destinations.length, (index) {
                    final dest = _destinations[index];
                    final selected = selectedIndex == index;
                    return Expanded(
                      child: _NavItem(
                        icon: dest.icon,
                        selectedIcon: dest.selectedIcon,
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
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String semanticsLabel;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: colorScheme.primary.withValues(alpha: 0.14),
          highlightColor: colorScheme.primary.withValues(alpha: 0.07),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: selected
                ? BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  )
                : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: AppIcons.sizeNav,
                  color: selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
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
