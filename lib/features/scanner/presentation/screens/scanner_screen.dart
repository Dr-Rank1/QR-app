import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../app/app_spacing.dart';
import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../domain/services/camera_scan_service.dart';
import '../../domain/services/gallery_scan_service.dart';
import '../providers/scanner_provider.dart';
import '../../../../shared/security/secure_logger.dart';
import '../../../../shared/utils/permission_handler.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/scan_overlay.dart';

enum _ScanMode { live, gallery }

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final _cameraService = CameraScanService();
  final _galleryService = GalleryScanService();
  bool _hasScanned = false;
  bool _permissionChecked = false;
  bool _permissionPermanentlyDenied = false;
  bool _isGalleryScanning = false;
  _ScanMode _scanMode = _ScanMode.live;
  DateTime? _lastScanAt;

  MobileScannerController? get _controller => _cameraService.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermission();
      _updateWakelock();
    });
  }

  Future<void> _checkPermission() async {
    var granted = await AppPermissionHandler.checkCameraPermission();
    if (!granted) {
      granted = await AppPermissionHandler.requestCameraPermission();
    }
    final permanentlyDenied =
        await AppPermissionHandler.isCameraPermissionDenied();
    if (!mounted) return;

    ref.read(scannerProvider.notifier).setCameraPermission(granted);
    setState(() {
      _permissionChecked = true;
      _permissionPermanentlyDenied = permanentlyDenied;
    });
    if (!granted) return;
    await _startController();
  }

  Future<void> _startController() async {
    final scannerState = ref.read(scannerProvider);
    await _cameraService.startController(
      facing: scannerState.cameraFacing,
      torchOn: scannerState.isTorchOn,
    );
    ref.read(scannerProvider.notifier).setReady();
    if (mounted) setState(() {});
  }

  Future<void> _toggleTorch() async {
    final state = ref.read(scannerProvider);
    if (!CameraScanService.isTorchAvailable(state.cameraFacing)) return;
    ref.read(scannerProvider.notifier).setTorchOn(!state.isTorchOn);
    await _cameraService.toggleTorch();
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
    _galleryService.dispose();
    _cameraService.disposeController();
    super.dispose();
  }

  bool _shouldIgnoreScan() {
    final last = _lastScanAt;
    if (last == null) return false;
    return DateTime.now().difference(last) < const Duration(seconds: 2);
  }

  Future<void> _processScan(String code, {bool fromGallery = false}) async {
    if (_hasScanned) return;
    _hasScanned = true;
    _lastScanAt = DateTime.now();

    try {
      final settings = ref.read(settingsProvider);
      final result = await ref
          .read(scannerProvider.notifier)
          .processBarcode(code, settings);
      if (!mounted) return;

      if (result == null) {
        final errorMessage = ref.read(scannerProvider).errorMessage;
        AppSnackBar.showError(
          context,
          errorMessage ??
              (fromGallery
                  ? 'Could not process the QR code from this image.'
                  : 'Could not process QR code.'),
        );
        return;
      }

      ref.invalidate(scanHistoryProvider);
      await context.push(AppRoutes.resultDetailPath(result.id));
    } catch (error, stackTrace) {
      SecureLogger.logError(error, stackTrace);
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Something went wrong while saving the scan.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _hasScanned = false);
        ref.read(scannerProvider.notifier).clearLastScan();
      }
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_hasScanned ||
        _shouldIgnoreScan() ||
        _isGalleryScanning ||
        _scanMode != _ScanMode.live) {
      return;
    }
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code == null || code.isEmpty) continue;
      await _processScan(code);
      break;
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isGalleryScanning || _hasScanned) return;

    final permission = await AppPermissionHandler.ensureGalleryPermission();
    if (!mounted) return;
    if (permission != PermissionRequestResult.granted) {
      await showPermissionDeniedSheet(
        context,
        type: AppPermissionType.gallery,
        permanentlyDenied:
            permission == PermissionRequestResult.permanentlyDenied,
      );
      return;
    }

    setState(() => _isGalleryScanning = true);
    try {
      final outcome = await _galleryService.pickAndDecode();
      if (!mounted) return;
      switch (outcome) {
        case GalleryScanCancelled():
          break;
        case GalleryScanNoCode():
          AppSnackBar.showInfo(
            context,
            'No QR code detected in this image. Please try another.',
          );
        case GalleryScanFailure(:final message):
          AppSnackBar.showError(context, message);
        case GalleryScanSuccess(:final payload):
          await _processScan(payload, fromGallery: true);
      }
    } catch (error, stackTrace) {
      SecureLogger.logError(error, stackTrace);
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Failed to decode image. Please try another photo.',
        );
      }
    } finally {
      if (mounted) setState(() => _isGalleryScanning = false);
    }
  }

  void _onModeChanged(_ScanMode mode) {
    if (_scanMode == mode) {
      if (mode == _ScanMode.gallery) _pickFromGallery();
      return;
    }
    setState(() => _scanMode = mode);
    if (mode == _ScanMode.gallery) _pickFromGallery();
  }

  @override
  Widget build(BuildContext context) {
    final scannerState = ref.watch(scannerProvider);
    final isProcessing = scannerState.status == ScannerStatus.processing;
    final colorScheme = Theme.of(context).colorScheme;
    final torchEnabled = CameraScanService.isTorchActionEnabled(
      hasCameraPermission: scannerState.hasCameraPermission,
      facing: scannerState.cameraFacing,
      isProcessing: isProcessing || _isGalleryScanning,
    );
    final controlsLocked = isProcessing || _isGalleryScanning || _hasScanned;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen(settingsProvider, (_, __) => _updateWakelock());

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: Text(
            'SCANNER',
            style: AppTheme.monoLabel(
              context,
              size: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          actions: [
            if (scannerState.hasCameraPermission && _scanMode == _ScanMode.live)
              TextButton(
                onPressed: torchEnabled ? _toggleTorch : null,
                child: Text(
                  scannerState.isTorchOn ? 'FLASH ON' : 'FLASH',
                  style: AppTheme.monoLabel(
                    context,
                    size: 11,
                    color: torchEnabled
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
          ],
        ),
        body: !_permissionChecked
            ? const Center(child: CircularProgressIndicator())
            : !scannerState.hasCameraPermission
                ? _PermissionDeniedBody(
                    onRetry: _checkPermission,
                    permanentlyDenied: _permissionPermanentlyDenied,
                    onScanFromGallery: _pickFromGallery,
                  )
                : Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                if (_scanMode == _ScanMode.live &&
                                    _controller != null)
                                  MobileScanner(
                                    controller: _controller,
                                    onDetect: _onDetect,
                                    placeholderBuilder: (_) => ColoredBox(
                                      color: colorScheme.surface,
                                      child: Center(
                                        child: Text(
                                          'STARTING CAMERA',
                                          style: AppTheme.monoLabel(context),
                                        ),
                                      ),
                                    ),
                                    errorBuilder: (context, error) {
                                      return ColoredBox(
                                        color: colorScheme.surface,
                                        child: Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(24),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  (error.errorDetails?.message ??
                                                          'Camera unavailable')
                                                      .toUpperCase(),
                                                  textAlign: TextAlign.center,
                                                  style: AppTheme.monoLabel(
                                                    context,
                                                    size: 11,
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                OutlinedButton(
                                                  onPressed: _startController,
                                                  child: const Text('RETRY'),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                else if (_scanMode == _ScanMode.gallery)
                                  _GalleryPlaceholder(
                                    isScanning: _isGalleryScanning,
                                    onPick: _pickFromGallery,
                                  )
                                else
                                  ColoredBox(color: colorScheme.surface),
                                if (_scanMode == _ScanMode.live)
                                  ScanOverlay(
                                    width: constraints.maxWidth,
                                    height: constraints.maxHeight,
                                    scanLineColor: Colors.white,
                                    detected: isProcessing,
                                  ),
                                if (isProcessing || _isGalleryScanning)
                                  ColoredBox(
                                    color: Colors.black54,
                                    child: Center(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: colorScheme.surface,
                                          border: Border.all(
                                            color: colorScheme.outline,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 28,
                                            vertical: 24,
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const SizedBox(
                                                width: 28,
                                                height: 28,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                (_isGalleryScanning
                                                        ? 'Decoding image'
                                                        : 'Processing scan')
                                                    .toUpperCase(),
                                                style: AppTheme.monoLabel(
                                                  context,
                                                  size: 11,
                                                  color: colorScheme.onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: colorScheme.outline),
                          ),
                        ),
                        child: Column(
                          children: [
                            _ScanModeBar(
                              mode: _scanMode,
                              locked: controlsLocked,
                              onModeChanged: _onModeChanged,
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'AWAITING SCAN',
                                  style: AppTheme.monoLabel(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _ScanModeBar extends StatelessWidget {
  final _ScanMode mode;
  final bool locked;
  final ValueChanged<_ScanMode> onModeChanged;

  const _ScanModeBar({
    required this.mode,
    required this.locked,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: _ScanModeChip(
            label: 'Live',
            selected: mode == _ScanMode.live,
            enabled: !locked,
            onTap: () => onModeChanged(_ScanMode.live),
          ),
        ),
        Container(width: 1, height: 44, color: colorScheme.outline),
        Expanded(
          child: _ScanModeChip(
            label: 'Gallery',
            selected: mode == _ScanMode.gallery,
            enabled: !locked,
            onTap: () => onModeChanged(_ScanMode.gallery),
          ),
        ),
      ],
    );
  }
}

class _ScanModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ScanModeChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: enabled ? onTap : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: 44,
            child: Center(
              child: Text(
                label.toUpperCase(),
                style: AppTheme.monoLabel(
                  context,
                  size: 11,
                  color: selected
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant.withValues(
                          alpha: enabled ? 1 : 0.35,
                        ),
                ),
              ),
            ),
          ),
          if (selected)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(height: 1, color: colorScheme.onSurface),
            ),
        ],
      ),
    );
  }
}

class _GalleryPlaceholder extends StatelessWidget {
  final bool isScanning;
  final VoidCallback onPick;

  const _GalleryPlaceholder({
    required this.isScanning,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final faded = colorScheme.onSurface.withValues(alpha: 0.1);

    return ColoredBox(
      color: colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'QR',
                style: AppTheme.displayTitle(context, size: 88, color: faded),
              ),
              Text(
                'GALLERY',
                style: AppTheme.monoLabel(context),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: isScanning ? null : onPick,
                child: const Text('CHOOSE IMAGE'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionDeniedBody extends StatelessWidget {
  final VoidCallback onRetry;
  final bool permanentlyDenied;
  final VoidCallback onScanFromGallery;

  const _PermissionDeniedBody({
    required this.onRetry,
    required this.permanentlyDenied,
    required this.onScanFromGallery,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'QR',
              style: AppTheme.displayTitle(
                context,
                size: 72,
                color: colorScheme.onSurface.withValues(alpha: 0.1),
              ),
            ),
            Text('CAMERA REQUIRED', style: AppTheme.monoLabel(context)),
            const SizedBox(height: 16),
            Text(
              permanentlyDenied
                  ? 'Allow camera access in device settings to scan codes.'
                  : 'Grant camera permission to continue, or scan from gallery.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onScanFromGallery,
                child: const Text('SCAN FROM GALLERY'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: permanentlyDenied
                    ? AppPermissionHandler.openAppSettings
                    : onRetry,
                child: Text(
                  permanentlyDenied ? 'OPEN SETTINGS' : 'GRANT PERMISSION',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
