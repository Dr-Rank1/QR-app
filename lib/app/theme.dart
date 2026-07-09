import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Monochrome QR Studio palette from the Figma UI reference.
class AppTheme {
  static const backgroundLight = Color(0xFFFFFFFF);
  static const backgroundDark = Color(0xFF0A0A0A);
  static const foregroundLight = Color(0xFF0A0A0A);
  static const foregroundDark = Color(0xFFFAFAFA);
  static const muted = Color(0xFF737373);
  static const secondaryLight = Color(0xFFF5F5F5);
  static const secondaryDark = Color(0xFF1A1A1A);
  static const destructive = Color(0xFFEF4444);

  /// Kept for scanner fullscreen chrome that must stay near-black.
  static const vaultBackground = backgroundDark;

  static ThemeData lightTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: foregroundLight,
      onPrimary: backgroundLight,
      primaryContainer: secondaryLight,
      onPrimaryContainer: foregroundLight,
      secondary: secondaryLight,
      onSecondary: foregroundLight,
      secondaryContainer: secondaryLight,
      onSecondaryContainer: foregroundLight,
      tertiary: muted,
      onTertiary: backgroundLight,
      error: destructive,
      onError: backgroundLight,
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF7F1D1D),
      surface: backgroundLight,
      onSurface: foregroundLight,
      onSurfaceVariant: muted,
      outline: Color(0x1A000000),
      outlineVariant: Color(0x1A000000),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: foregroundLight,
      onInverseSurface: backgroundLight,
      inversePrimary: foregroundDark,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: backgroundLight,
      surfaceContainerLow: backgroundLight,
      surfaceContainer: secondaryLight,
      surfaceContainerHigh: secondaryLight,
      surfaceContainerHighest: Color(0xFFE5E5E5),
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData darkTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: foregroundDark,
      onPrimary: backgroundDark,
      primaryContainer: secondaryDark,
      onPrimaryContainer: foregroundDark,
      secondary: secondaryDark,
      onSecondary: foregroundDark,
      secondaryContainer: secondaryDark,
      onSecondaryContainer: foregroundDark,
      tertiary: muted,
      onTertiary: backgroundDark,
      error: destructive,
      onError: backgroundLight,
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: Color(0xFFFEE2E2),
      surface: backgroundDark,
      onSurface: foregroundDark,
      onSurfaceVariant: muted,
      outline: Color(0x1AFFFFFF),
      outlineVariant: Color(0x1AFFFFFF),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: foregroundDark,
      onInverseSurface: backgroundDark,
      inversePrimary: foregroundLight,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: backgroundDark,
      surfaceContainerLow: backgroundDark,
      surfaceContainer: secondaryDark,
      surfaceContainerHigh: secondaryDark,
      surfaceContainerHighest: Color(0xFF262626),
    );
    return _buildTheme(colorScheme);
  }

  static TextStyle monoLabel(
    BuildContext context, {
    double size = 10,
    Color? color,
    FontWeight weight = FontWeight.w500,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: 2.4,
      color: color ?? scheme.onSurfaceVariant,
      height: 1.3,
    );
  }

  static TextStyle displayTitle(
    BuildContext context, {
    double size = 24,
    Color? color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.8,
      color: color ?? scheme.onSurface,
      height: 1.1,
    );
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final inter = GoogleFonts.interTextTheme();
    final mono = GoogleFonts.jetBrainsMonoTextTheme();

    final textTheme = inter.copyWith(
      headlineSmall: inter.headlineSmall?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.8,
        color: colorScheme.onSurface,
      ),
      titleLarge: inter.titleLarge?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.6,
        color: colorScheme.onSurface,
      ),
      titleMedium: mono.titleMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: colorScheme.onSurface,
      ),
      titleSmall: mono.titleSmall?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: colorScheme.onSurface,
      ),
      bodyLarge: mono.bodyLarge?.copyWith(
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: colorScheme.onSurface,
      ),
      bodyMedium: mono.bodyMedium?.copyWith(
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: colorScheme.onSurface,
      ),
      bodySmall: mono.bodySmall?.copyWith(
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurfaceVariant,
      ),
      labelLarge: mono.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 2.0,
        color: colorScheme.onSurface,
      ),
      labelMedium: mono.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 2.0,
        color: colorScheme.onSurfaceVariant,
      ),
      labelSmall: mono.labelSmall?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 2.4,
        color: colorScheme.onSurfaceVariant,
      ),
    );

    const zero = BorderRadius.zero;
    final hairline = BorderSide(color: colorScheme.outline);

    ButtonStyle sharpButton({
      required Color foreground,
      required Color background,
      BorderSide? side,
    }) {
      return ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(foreground),
        backgroundColor: WidgetStatePropertyAll(background),
        elevation: const WidgetStatePropertyAll(0),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: zero),
        ),
        side: side == null ? null : WidgetStatePropertyAll(side),
        textStyle: WidgetStatePropertyAll(
          GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.4,
          ),
        ),
      );
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      highlightColor: colorScheme.onSurface.withValues(alpha: 0.04),
      splashColor: colorScheme.onSurface.withValues(alpha: 0.08),
      iconTheme: IconThemeData(
        color: colorScheme.onSurfaceVariant,
        size: 22,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: textTheme.titleLarge,
        shape: Border(bottom: hairline),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: zero,
          side: hairline,
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(borderRadius: zero),
        side: hairline,
        selectedColor: colorScheme.primary,
        checkmarkColor: colorScheme.onPrimary,
        backgroundColor: colorScheme.surface,
        labelStyle: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.6,
          color: colorScheme.onSurface,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: sharpButton(
          foreground: colorScheme.onPrimary,
          background: colorScheme.primary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: sharpButton(
          foreground: colorScheme.onPrimary,
          background: colorScheme.primary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: sharpButton(
          foreground: colorScheme.onSurface,
          background: Colors.transparent,
          side: hairline,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          shape: const RoundedRectangleBorder(borderRadius: zero),
          textStyle: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.0,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: zero),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: zero,
          borderSide: hairline,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: zero,
          borderSide: hairline,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: zero,
          borderSide: BorderSide(color: colorScheme.onSurface, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: zero,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: zero,
          borderSide: BorderSide(color: colorScheme.error, width: 1),
        ),
        hintStyle: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          color: colorScheme.onSurfaceVariant,
        ),
        labelStyle: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          letterSpacing: 1.6,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          color: colorScheme.onInverseSurface,
        ),
        shape: const RoundedRectangleBorder(borderRadius: zero),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: zero,
          side: hairline,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: zero),
      ),
      listTileTheme: ListTileThemeData(
        shape: const RoundedRectangleBorder(borderRadius: zero),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minVerticalPadding: 12,
        minLeadingWidth: 28,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return Colors.transparent;
        }),
        trackOutlineColor: WidgetStatePropertyAll(colorScheme.outline),
        trackOutlineWidth: const WidgetStatePropertyAll(1),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.onSurface,
        circularTrackColor: colorScheme.outline,
      ),
    );
  }
}
