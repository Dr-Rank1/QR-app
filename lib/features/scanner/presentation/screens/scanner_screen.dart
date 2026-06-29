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
import '../../../../shared/widgets/app_icons.dart';
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

    if (!granted) {
      return;
    }

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
      if (mode == _ScanMode.gallery) {
        _pickFromGallery();
      }
      return;
    }

    setState(() => _scanMode = mode);
    if (mode == _ScanMode.gallery) {
      _pickFromGallery();
    }
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

    ref.listen(settingsProvider, (_, __) {
      _updateWakelock();
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: AppTheme.vaultBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          title: const Text('QR Vault'),
          actions: [
            if (scannerState.hasCameraPermission && _scanMode == _ScanMode.live)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _ScannerToolbarButton(
                  icon: scannerState.isTorchOn
                      ? AppIcons.flashOn
                      : AppIcons.flashOff,
                  semanticsLabel: scannerState.isTorchOn
                      ? 'Turn flashlight off'
                      : 'Turn flashlight on',
                  tooltip: 'Toggle flash',
                  onPressed: torchEnabled ? _toggleTorch : null,
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
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_scanMode == _ScanMode.live && _controller != null)
                            MobileScanner(
                              controller: _controller,
                              onDetect: _onDetect,
                              placeholderBuilder: (context) => const ColoredBox(
                                color: AppTheme.vaultBackground,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(
                                        color: AppTheme.vaultAccent,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'Starting camera…',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              errorBuilder: (context, error) {
                                return ColoredBox(
                                  color: AppTheme.vaultBackground,
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.videocam_off_outlined,
                                            color: Colors.white70,
                                            size: 48,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            error.errorDetails?.message ??
                                                'Camera unavailable',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          FilledButton(
                                            onPressed: _startController,
                                            child: const Text('Retry camera'),
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
                            const ColoredBox(color: AppTheme.vaultBackground),
                          if (_scanMode == _ScanMode.live)
                            ScanOverlay(
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              scanLineColor: colorScheme.primary,
                              detected: isProcessing,
                            ),
                          if (_scanMode == _ScanMode.live)
                            Positioned(
                              left: 24,
                              right: 24,
                              bottom: 112,
                              child: Text(
                                'Align the QR code inside the frame',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color:
                                          Colors.white.withValues(alpha: 0.92),
                                      shadows: const [
                                        Shadow(
                                          blurRadius: 8,
                                          color: Colors.black54,
                                        ),
                                      ],
                                    ),
                              ),
                            ),
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 28,
                            child: _ScanModeBar(
                              mode: _scanMode,
                              locked: controlsLocked,
                              onModeChanged: _onModeChanged,
                            ),
                          ),
                          if (isProcessing || _isGalleryScanning)
                            Container(
                              color: Colors.black54,
                              child: Center(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 40,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 28,
                                    vertical: 24,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.vaultSurfaceHigh
                                        .withValues(alpha: 0.96),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: colorScheme.primary
                                          .withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(
                                        color: AppTheme.vaultAccent,
                                        strokeWidth: 3,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _isGalleryScanning
                                            ? 'Decoding image…'
                                            : 'Processing scan…',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 24,
            offset: Offset(0, 8),
            color: Colors.black38,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            Expanded(
              child: _ScanModeChip(
                icon: Icons.qr_code_scanner_rounded,
                label: 'Live scan',
                selected: mode == _ScanMode.live,
                enabled: !locked,
                onTap: () => onModeChanged(_ScanMode.live),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _ScanModeChip(
                icon: AppIcons.gallery,
                label: 'Gallery',
                selected: mode == _ScanMode.gallery,
                enabled: !locked,
                onTap: () => onModeChanged(_ScanMode.gallery),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ScanModeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Material(
      color: selected
          ? accent.withValues(alpha: 0.18)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? accent
                    : Colors.white.withValues(alpha: enabled ? 0.75 : 0.35),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? accent
                      : Colors.white.withValues(alpha: enabled ? 0.85 : 0.35),
                ),
              ),
            ],
          ),
        ),
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

    return ColoredBox(
      color: AppTheme.vaultBackground,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  AppIcons.gallery,
                  size: 40,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Scan from gallery',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a photo containing a QR code. Decoding runs entirely on your device.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: isScanning ? null : onPick,
                icon: const Icon(AppIcons.gallery),
                label: const Text('Choose image'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerToolbarButton extends StatelessWidget {
  final IconData icon;
  final String semanticsLabel;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ScannerToolbarButton({
    required this.icon,
    required this.semanticsLabel,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticsLabel,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.black.withValues(alpha: 0.45),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            splashColor: Colors.white.withValues(alpha: 0.18),
            highlightColor: Colors.white.withValues(alpha: 0.08),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                icon,
                color: enabled ? Colors.white : Colors.white38,
                size: 22,
              ),
            ),
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

    return Semantics(
      container: true,
      label: 'Camera permission required',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size: 64,
                color: colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                permanentlyDenied
                    ? 'Camera access is turned off'
                    : 'Camera access is required',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                permanentlyDenied
                    ? 'To scan QR codes, allow camera access for this app in your device settings.'
                    : 'QR scanning needs your camera. Grant permission to continue, or open Settings if you previously denied access.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onScanFromGallery,
                  icon: const Icon(AppIcons.gallery),
                  label: const Text('Scan from gallery'),
                ),
              ),
              const SizedBox(height: 12),
              if (permanentlyDenied) ...[
                FilledButton.icon(
                  onPressed: AppPermissionHandler.openAppSettings,
                  icon: const Icon(AppIcons.settings),
                  label: const Text('Open App Settings'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Try Again'),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Grant Permission'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: AppPermissionHandler.openAppSettings,
                  icon: const Icon(AppIcons.settings),
                  label: const Text('Open App Settings'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
