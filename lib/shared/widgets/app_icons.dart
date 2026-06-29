import 'package:flutter/material.dart';

/// Outlined icon set for consistent stroke-style iconography app-wide.
abstract final class AppIcons {
  static const double sizeNav = 26;
  static const double sizeAction = 24;
  static const double sizeList = 22;

  // Navigation (outlined)
  static const scanner = Icons.qr_code_scanner_outlined;
  static const generator = Icons.qr_code_outlined;
  static const history = Icons.history_outlined;
  static const settings = Icons.settings_outlined;

  // Navigation (filled — active tab)
  static const scannerFilled = Icons.qr_code_scanner;
  static const generatorFilled = Icons.qr_code;
  static const historyFilled = Icons.history;
  static const settingsFilled = Icons.settings;

  // Scanner actions
  static const gallery = Icons.photo_library_outlined;
  static const flashOn = Icons.flash_on_outlined;
  static const flashOff = Icons.flash_off_outlined;
  static const switchCamera = Icons.flip_camera_android_outlined;

  // Common actions
  static const copy = Icons.copy_outlined;
  static const share = Icons.share_outlined;
  static const delete = Icons.delete_outline;
  static const export = Icons.upload_outlined;
  static const clear = Icons.delete_sweep_outlined;
  static const star = Icons.star_outline;
  static const starFilled = Icons.star;
  static const search = Icons.search_outlined;
  static const close = Icons.close_outlined;
  static const openExternal = Icons.open_in_new;
}

/// Soft localized ripple for tappable surfaces.
class SoftRipple extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;

  const SoftRipple({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: borderRadius,
        splashColor: colorScheme.primary.withValues(alpha: 0.12),
        highlightColor: colorScheme.primary.withValues(alpha: 0.06),
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}
