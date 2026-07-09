import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../features/settings/presentation/providers/settings_provider.dart';
import '../utils/app_haptics.dart';

/// Segmented System / Light / Dark selector for Settings.
class ThemeModeSelector extends ConsumerWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.zero,
          border: Border.all(color: colorScheme.outline),
        ),
        child: Row(
          children: [
            _ThemeOption(
              icon: Icons.brightness_auto_outlined,
              label: 'SYSTEM',
              selected: themeMode == ThemeMode.system,
              onTap: () => ref
                  .read(settingsProvider.notifier)
                  .setThemeMode(ThemeMode.system),
            ),
            Container(width: 1, height: 48, color: colorScheme.outline),
            _ThemeOption(
              icon: Icons.light_mode_outlined,
              label: 'LIGHT',
              selected: themeMode == ThemeMode.light,
              onTap: () => ref
                  .read(settingsProvider.notifier)
                  .setThemeMode(ThemeMode.light),
            ),
            Container(width: 1, height: 48, color: colorScheme.outline),
            _ThemeOption(
              icon: Icons.dark_mode_outlined,
              label: 'DARK',
              selected: themeMode == ThemeMode.dark,
              onTap: () => ref
                  .read(settingsProvider.notifier)
                  .setThemeMode(ThemeMode.dark),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.zero,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              await AppHaptics.selection();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      icon,
                      key: ValueKey('$label-$selected'),
                      size: 20,
                      color: selected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: AppTheme.monoLabel(
                      context,
                      size: 8,
                      weight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
