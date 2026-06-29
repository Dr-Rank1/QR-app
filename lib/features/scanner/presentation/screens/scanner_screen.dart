import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../app/router.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../providers/scanner_provider.dart';
import '../../../../shared/ads/interstitial_ad_manager.dart';
import '../../../../shared/utils/permission_handler.dart';
import '../../../../shared/widgets/scan_overlay.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  MobileScannerController? _controller;
  bool _hasScanned = false;
  bool _permissionChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermission();
      _updateWakelock();
      interstitialAdManager.initialize();
    });
  }

  Future<void> _checkPermission() async {
    final granted = await AppPermissionHandler.checkCameraPermission() ||
        await AppPermissionHandler.requestCameraPermission();

    if (!mounted) return;

    ref.read(scannerProvider.notifier).setCameraPermission(granted);
    setState(() => _permissionChecked = true);

    if (!granted) {
      if (await AppPermissionHandler.isCameraPermissionDenied()) {
        if (mounted) await showPermissionDeniedDialog(context);
      }
      return;
    }

    _initController();
  }

  void _initController() {
    final scannerState = ref.read(scannerProvider);
    _controller?.dispose();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: scannerState.cameraFacing,
      torchEnabled: scannerState.isTorchOn,
    );
    ref.read(scannerProvider.notifier).setReady();
  }

  void _updateWakelock() {
    final settings = ref.read(settingsProvider);
    if (settings.keepScreenOn) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_hasScanned) return;

    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code == null) continue;

      _hasScanned = true;
      final settings = ref.read(settingsProvider);
      final result = await ref
          .read(scannerProvider.notifier)
          .processBarcode(code, settings);

      if (!mounted || result == null) {
        _hasScanned = false;
        return;
      }

      ref.invalidate(scanHistoryProvider);
      interstitialAdManager.incrementAndShow();

      if (mounted) {
        await context.push(AppRoutes.resultDetailPath(result.id));
      }

      if (mounted) {
        setState(() => _hasScanned = false);
        ref.read(scannerProvider.notifier).clearLastScan();
      }
      break;
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    final capture = await _controller?.analyzeImage(image.path);
    if (capture != null) {
      await _onDetect(capture);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No QR code found in image')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scannerState = ref.watch(scannerProvider);

    ref.listen(settingsProvider, (_, __) {
      _updateWakelock();
    });

    ref.listen(scannerProvider.select((s) => s.isTorchOn), (prev, next) {
      _controller?.toggleTorch();
    });

    ref.listen(scannerProvider.select((s) => s.cameraFacing), (prev, next) {
      if (prev != next) _initController();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: _pickFromGallery,
            tooltip: 'Scan from gallery',
          ),
          IconButton(
            icon: Icon(scannerState.isTorchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: scannerState.hasCameraPermission
                ? () => ref.read(scannerProvider.notifier).toggleTorch()
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            onPressed: scannerState.hasCameraPermission
                ? () => ref.read(scannerProvider.notifier).switchCamera()
                : null,
          ),
        ],
      ),
      body: !_permissionChecked
          ? const Center(child: CircularProgressIndicator())
          : !scannerState.hasCameraPermission
              ? _PermissionDeniedBody(onRetry: _checkPermission)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_controller != null)
                          MobileScanner(
                            controller: _controller,
                            onDetect: _onDetect,
                          ),
                        ScanOverlay(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          scanLineColor: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}

class _PermissionDeniedBody extends StatelessWidget {
  final VoidCallback onRetry;

  const _PermissionDeniedBody({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            const Text(
              'Camera access is required to scan QR codes',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Grant Permission'),
            ),
            TextButton(
              onPressed: AppPermissionHandler.openAppSettings,
              child: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
