import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/presentation/providers/settings_provider.dart';
import '../utils/app_haptics.dart';

/// Animated sun/moon control for switching between light and dark themes.
class ThemeModeToggle extends ConsumerWidget {
  const ThemeModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final brightness = _effectiveBrightness(context, themeMode);
    final isDark = brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: isDark ? 'Switch to light theme' : 'Switch to dark theme',
      child: Tooltip(
        message: isDark ? 'Light mode' : 'Dark mode',
        child: IconButton(
          onPressed: () async {
            await AppHaptics.light();
            ref.read(settingsProvider.notifier).setThemeMode(
                  isDark ? ThemeMode.light : ThemeMode.dark,
                );
          },
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return RotationTransition(
                turns: Tween<double>(begin: 0.85, end: 1).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey(isDark),
            ),
          ),
        ),
      ),
    );
  }

  Brightness _effectiveBrightness(BuildContext context, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.dark => Brightness.dark,
      ThemeMode.light => Brightness.light,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context),
    };
  }
}
