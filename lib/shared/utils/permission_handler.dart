import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

enum AppPermissionType { camera, gallery }

enum PermissionRequestResult {
  granted,
  denied,
  permanentlyDenied,
}

/// Runtime permission helpers for camera and gallery access.
abstract final class AppPermissionHandler {
  static Future<bool> requestCameraPermission() async {
    final status = await ph.Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> checkCameraPermission() async {
    final status = await ph.Permission.camera.status;
    return status.isGranted;
  }

  static Future<bool> isCameraPermissionDenied() async {
    final status = await ph.Permission.camera.status;
    return status.isPermanentlyDenied;
  }

  /// Gallery access on Android 13+ uses the system photo picker (no permission).
  /// iOS requires photo library access before `image_picker` can read images.
  static Future<PermissionRequestResult> ensureGalleryPermission() async {
    if (!Platform.isIOS) {
      return PermissionRequestResult.granted;
    }

    var status = await ph.Permission.photos.status;
    if (status.isGranted || status.isLimited) {
      return PermissionRequestResult.granted;
    }

    status = await ph.Permission.photos.request();
    if (status.isGranted || status.isLimited) {
      return PermissionRequestResult.granted;
    }
    if (status.isPermanentlyDenied) {
      return PermissionRequestResult.permanentlyDenied;
    }
    return PermissionRequestResult.denied;
  }

  static Future<bool> isGalleryPermissionPermanentlyDenied() async {
    if (!Platform.isIOS) return false;
    final status = await ph.Permission.photos.status;
    return status.isPermanentlyDenied;
  }

  static Future<void> openAppSettings() async {
    await ph.openAppSettings();
  }

  static Future<ph.PermissionStatus> getCameraPermissionStatus() async {
    return ph.Permission.camera.status;
  }
}

Future<void> showPermissionDeniedDialog(BuildContext context) async {
  await showPermissionDeniedSheet(
    context,
    type: AppPermissionType.camera,
    permanentlyDenied: true,
  );
}

/// User-friendly bottom sheet when camera or gallery permission is blocked.
Future<void> showPermissionDeniedSheet(
  BuildContext context, {
  required AppPermissionType type,
  required bool permanentlyDenied,
}) async {
  final colorScheme = Theme.of(context).colorScheme;
  final copy = _copyFor(type, permanentlyDenied);

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                copy.icon,
                size: 52,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                copy.title,
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                copy.message,
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 24),
              if (permanentlyDenied)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    AppPermissionHandler.openAppSettings();
                  },
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Open App Settings'),
                )
              else
                FilledButton.icon(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: Icon(copy.icon),
                  label: Text(copy.retryLabel),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PermissionCopy {
  final IconData icon;
  final String title;
  final String message;
  final String retryLabel;

  const _PermissionCopy({
    required this.icon,
    required this.title,
    required this.message,
    required this.retryLabel,
  });
}

_PermissionCopy _copyFor(AppPermissionType type, bool permanentlyDenied) {
  switch (type) {
    case AppPermissionType.camera:
      return _PermissionCopy(
        icon: Icons.camera_alt_outlined,
        title: permanentlyDenied
            ? 'Camera access is turned off'
            : 'Camera access is required',
        message: permanentlyDenied
            ? 'Allow camera access for QR Vault in your device settings to scan codes with the live camera.'
            : 'QR Vault needs your camera to scan codes in real time. Grant permission when prompted.',
        retryLabel: 'Try again',
      );
    case AppPermissionType.gallery:
      return _PermissionCopy(
        icon: Icons.photo_library_outlined,
        title: permanentlyDenied
            ? 'Photo access is turned off'
            : 'Photo access is required',
        message: permanentlyDenied
            ? 'Allow photo library access for QR Vault in your device settings to scan QR codes from saved images.'
            : 'QR Vault needs access to your photo library to decode QR codes from gallery images.',
        retryLabel: 'Grant access',
      );
  }
}
