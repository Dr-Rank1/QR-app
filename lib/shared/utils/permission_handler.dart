import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AppPermissionHandler {
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> checkCameraPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  static Future<bool> isCameraPermissionDenied() async {
    final status = await Permission.camera.status;
    return status.isPermanentlyDenied;
  }

  static Future<void> openAppSettings() async {
    await openAppSettings();
  }

  static Future<PermissionStatus> getCameraPermissionStatus() async {
    return await Permission.camera.status;
  }
}

Future<void> showPermissionDeniedDialog(BuildContext context) async {
  final colorScheme = Theme.of(context).colorScheme;

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(
        Icons.camera_alt_outlined,
        size: 48,
        color: colorScheme.error,
      ),
      title: const Text('Camera Permission Required'),
      content: const Text(
        'This app requires camera access to scan QR codes. '
        'Please grant camera permission in your device settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            openAppSettings();
          },
          child: const Text('Open Settings'),
        ),
      ],
    ),
  );
}