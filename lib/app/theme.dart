import 'package:flutter/material.dart';

/// Vault-inspired palette: deep slate surfaces with electric teal accents.
class AppTheme {
  static const vaultBackground = Color(0xFF0B0F14);
  static const vaultSurface = Color(0xFF121820);
  static const vaultSurfaceHigh = Color(0xFF1A2330);
  static const vaultAccent = Color(0xFF00E5C7);
  static const vaultAccentDim = Color(0xFF00BFA5);
  static const vaultOnAccent = Color(0xFF00241F);

  static const lightBackground = Color(0xFFF6F8FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceHigh = Color(0xFFEEF2F6);
  static const lightText = Color(0xFF0F172A);
  static const lightTextMuted = Color(0xFF64748B);

  static ThemeData lightTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: vaultAccentDim,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFB2F5EA),
      onPrimaryContainer: Color(0xFF00332C),
      secondary: Color(0xFF0284C7),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFDFF4FF),
      onSecondaryContainer: Color(0xFF003A57),
      tertiary: Color(0xFF6366F1),
      onTertiary: Colors.white,
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: lightBackground,
      onSurface: lightText,
      onSurfaceVariant: lightTextMuted,
      outline: Color(0xFFCBD5E1),
      outlineVariant: Color(0xFFE2E8F0),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: lightText,
      onInverseSurface: lightBackground,
      inversePrimary: vaultAccent,
      surfaceTint: vaultAccentDim,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: lightSurface,
      surfaceContainer: Color(0xFFF1F5F9),
      surfaceContainerHigh: lightSurfaceHigh,
      surfaceContainerHighest: Color(0xFFE2E8F0),
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData darkTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: vaultAccent,
      onPrimary: vaultOnAccent,
      primaryContainer: Color(0xFF003D35),
      onPrimaryContainer: Color(0xFF7DFFEC),
      secondary: Color(0xFF7DD3FC),
      onSecondary: Color(0xFF00344A),
      secondaryContainer: Color(0xFF004D6B),
      onSecondaryContainer: Color(0xFFC5E9FF),
      tertiary: Color(0xFFB4C5FF),
      onTertiary: Color(0xFF1A2A5E),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: vaultBackground,
      onSurface: Color(0xFFE6EDF5),
      onSurfaceVariant: Color(0xFF9AA8B8),
      outline: Color(0xFF3D4A5C),
      outlineVariant: Color(0xFF2A3442),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFFE6EDF5),
      onInverseSurface: Color(0xFF1A2330),
      inversePrimary: vaultAccentDim,
      surfaceTint: vaultAccent,
      surfaceContainerLowest: Color(0xFF070A0E),
      surfaceContainerLow: vaultSurface,
      surfaceContainer: Color(0xFF151C26),
      surfaceContainerHigh: vaultSurfaceHigh,
      surfaceContainerHighest: Color(0xFF232D3C),
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final textTheme = TextTheme(
      headlineSmall: TextStyle(
        fontWeight: FontWeight.bold,
        letterSpacing: -0.2,
        color: colorScheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.bold,
        letterSpacing: -0.3,
        color: colorScheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleSmall: TextStyle(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      bodyLarge: TextStyle(
        fontWeight: FontWeight.normal,
        height: 1.45,
        color: colorScheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontWeight: FontWeight.normal,
        height: 1.4,
        color: colorScheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontWeight: FontWeight.normal,
        color: colorScheme.onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: colorScheme.onSurface,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      highlightColor: colorScheme.primary.withValues(alpha: 0.06),
      splashColor: colorScheme.primary.withValues(alpha: 0.12),
      iconTheme: IconThemeData(
        color: colorScheme.onSurfaceVariant,
        size: 24,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide(color: colorScheme.outlineVariant),
        selectedColor: colorScheme.primary,
        checkmarkColor: colorScheme.onPrimary,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary, size: 24);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          splashFactory: InkRipple.splashFactory,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          splashFactory: InkRipple.splashFactory,
          foregroundColor: colorScheme.primary,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return colorScheme.primary.withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return colorScheme.primary.withValues(alpha: 0.06);
            }
            return null;
          }),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          splashFactory: InkRipple.splashFactory,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return colorScheme.primary.withValues(alpha: 0.14);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return colorScheme.primary.withValues(alpha: 0.07);
            }
            return null;
          }),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.65),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.error.withValues(alpha: 0.65),
            width: 1.5,
          ),
        ),
        errorStyle: TextStyle(color: colorScheme.error.withValues(alpha: 0.9)),
        floatingLabelAlignment: FloatingLabelAlignment.start,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minVerticalPadding: 12,
        minLeadingWidth: 28,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHighest.withValues(alpha: 0.9);
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return colorScheme.outline.withValues(alpha: 0.35);
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        circularTrackColor: colorScheme.surfaceContainerHighest,
      ),
    );
  }
}
