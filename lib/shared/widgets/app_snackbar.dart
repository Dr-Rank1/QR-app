import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/app_messenger.dart';

/// Floating snackbars with sharp monochrome chrome.
abstract final class AppSnackBar {
  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message,
      icon: Icons.check_circle_outline_rounded,
      background: Theme.of(context).colorScheme.inverseSurface,
      foreground: Theme.of(context).colorScheme.onInverseSurface,
    );
  }

  static void showInfo(BuildContext context, String message) {
    _show(
      context,
      message,
      icon: Icons.info_outline_rounded,
      background: Theme.of(context).colorScheme.inverseSurface,
      foreground: Theme.of(context).colorScheme.onInverseSurface,
    );
  }

  static void showError(BuildContext context, String message) {
    _show(
      context,
      message,
      icon: Icons.error_outline_rounded,
      background: Theme.of(context).colorScheme.error,
      foreground: Theme.of(context).colorScheme.onError,
    );
  }

  static void _show(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color background,
    required Color foreground,
  }) {
    void present() {
      final messenger = rootScaffoldMessengerKey.currentState ??
          ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: background,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 72),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          content: Row(
            children: [
              Icon(icon, color: foreground, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => present());
  }
}
