import 'package:flutter/material.dart';

import '../../app/app_messenger.dart';

/// Consistent floating snackbars for success, info, and error feedback.
abstract final class AppSnackBar {
  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message,
      icon: Icons.check_circle_outline_rounded,
      background: Theme.of(context).colorScheme.primaryContainer,
      foreground: Theme.of(context).colorScheme.onPrimaryContainer,
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
      background: Theme.of(context).colorScheme.errorContainer,
      foreground: Theme.of(context).colorScheme.onErrorContainer,
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
          elevation: 8,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              Icon(icon, color: foreground, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w500,
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
