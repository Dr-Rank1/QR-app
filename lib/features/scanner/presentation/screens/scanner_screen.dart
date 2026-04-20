import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/router.dart';
import '../../../../shared/widgets/premium_scan_overlay.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/animated_result_icons.dart';
import '../../domain/enums/qr_result_type.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../providers/scanner_provider.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with WidgetsBindingObserver {
  MobileScannerController? _controller;
  bool _hasPermission = false;
  bool _isCheckingPermission = true;
  bool _isPermanentlyDenied = false;
  bool _showResultBottomSheet = false;
  
  // Performance: throttle barcode analysis to max once every 300ms
  int _lastScanTime = 0;
  static const int _scanThrottleMs = 300;
  
  // Performance: cooldown lock to prevent duplicate detections
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _controller?.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _controller?.stop();
        break;
      default:
        break;
    }
  }

  Future<void> _checkPermission() async {
    setState(() => _isCheckingPermission = true);

    final status = await Permission.camera.status;

    if (status.isGranted) {
      setState(() {
        _hasPermission = true;
        _isCheckingPermission = false;
      });
      _initializeController();
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _isPermanentlyDenied = true;
        _isCheckingPermission = false;
      });
    } else {
      final result = await Permission.camera.request();
      setState(() {
        _hasPermission = result.isGranted;
        _isPermanentlyDenied = result.isPermanentlyDenied;
        _isCheckingPermission = false;
      });
      if (result.isGranted) {
        _initializeController();
      }
    }
  }

  void _initializeController() {
    final state = ref.read(scannerProvider);
    _controller = MobileScannerController(
      facing: state.cameraFacing,
      torchEnabled: state.isTorchOn,
    );
    ref.read(scannerProvider.notifier).setReady();
  }

  void _onDetect(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    // Performance: Throttle to max once every 300ms
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastScanTime < _scanThrottleMs) return;
    _lastScanTime = now;

    // Performance: Cooldown lock to prevent duplicate detections
    if (_isProcessing) return;

    final barcode = barcodes.first;
    final rawValue = barcode.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    // Set processing lock
    _isProcessing = true;

    // Haptic feedback
    final settings = ref.read(settingsProvider);
    if (settings.vibrateOnScan) {
      HapticFeedback.mediumImpact();
    }

    ref.read(scannerProvider.notifier).processBarcode(rawValue);
    
    // Release cooldown after processing completes
    Future.delayed(const Duration(milliseconds: 500), () {
      _isProcessing = false;
    });
  }

  void _showResultSheet() {
    setState(() => _showResultBottomSheet = true);
  }

  void _hideResultSheet() {
    setState(() => _showResultBottomSheet = false);
    ref.read(scannerProvider.notifier).clearLastScan();
  }

  @override
  Widget build(BuildContext context) {
    final scannerState = ref.watch(scannerProvider);
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    ref.listen(scannerProvider, (previous, next) {
      if (previous?.lastScan == null && next.lastScan != null) {
        if (settings.soundOnScan) {
          SystemSound.play(SystemSoundType.click);
        }
        _showResultSheet();
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: _buildBody(colorScheme, scannerState, reduceMotion),
    );
  }

  Widget _buildBody(
    ColorScheme colorScheme,
    ScannerState scannerState,
    bool reduceMotion,
  ) {
    if (_isCheckingPermission) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isPermanentlyDenied) {
      return EmptyStateWidget(
        icon: Icons.camera_alt_outlined,
        title: 'Camera Permission Needed',
        subtitle: 'Please grant camera permission in settings to scan QR codes.',
        action: FilledButton(
          onPressed: () => openAppSettings(),
          child: const Text('Open Settings'),
        ),
      );
    }

    if (!_hasPermission) {
      return EmptyStateWidget(
        icon: Icons.camera_alt_outlined,
        title: 'Camera Permission Required',
        subtitle: 'This app needs camera access to scan QR codes.',
        action: FilledButton(
          onPressed: _checkPermission,
          child: const Text('Grant Permission'),
        ),
      );
    }

    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        // Camera preview
        MobileScanner(
          controller: _controller!,
          onDetect: _onDetect,
          errorBuilder: (context, error, stack) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Camera Error',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(error.errorDetails ?? 'Unknown error'),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _checkPermission,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          },
        ),

        // Premium scan overlay
        LayoutBuilder(
          builder: (context, constraints) {
            return PremiumScanOverlay(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              primaryColor: colorScheme.primary,
            );
          },
        ),

        // Frosted glass toolbar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _FrostedGlassToolbar(
            onHistory: () => context.push(AppRoutes.history),
            onSettings: () => context.push(AppRoutes.settings),
          ),
        ),

        // Controls at bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlButton(
                    icon: scannerState.isTorchOn
                        ? Icons.flash_on
                        : Icons.flash_off,
                    label: 'Flash',
                    onPressed: () {
                      _controller?.toggleTorch();
                      ref.read(scannerProvider.notifier).toggleTorch();
                    },
                  ),
                  _ControlButton(
                    icon: Icons.cameraswitch,
                    label: 'Switch',
                    onPressed: () {
                      _controller?.switchCamera();
                      ref.read(scannerProvider.notifier).switchCamera();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        // Result bottom sheet
        if (_showResultBottomSheet)
          _buildResultBottomSheet(context, colorScheme, reduceMotion),
      ],
    );
  }

  Widget _buildResultBottomSheet(
    BuildContext context,
    ColorScheme colorScheme,
    bool reduceMotion,
  ) {
    final lastScan = ref.read(scannerProvider).lastScan;
    if (lastScan == null) return const SizedBox.shrink();

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity! > 300) {
          _hideResultSheet();
        }
      },
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: _ResultBottomSheetContent(
                  result: lastScan,
                  onDismiss: _hideResultSheet,
                  reduceMotion: reduceMotion,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FrostedGlassToolbar extends StatelessWidget {
  final VoidCallback onHistory;
  final VoidCallback onSettings;

  const _FrostedGlassToolbar({
    required this.onHistory,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            bottom: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Scan QR Code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.history, color: Colors.white),
                    onPressed: onHistory,
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: onSettings,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: IconButton(
            icon: Icon(icon),
            iconSize: 28,
            color: Colors.white,
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ResultBottomSheetContent extends StatelessWidget {
  final dynamic result;
  final VoidCallback onDismiss;
  final bool reduceMotion;

  const _ResultBottomSheetContent({
    required this.result,
    required this.onDismiss,
    required this.reduceMotion,
  });

  Color _getTypeColor(QRResultType type) {
    switch (type) {
      case QRResultType.url:
        return const Color(0xFF2196F3);
      case QRResultType.phone:
        return const Color(0xFF4CAF50);
      case QRResultType.email:
        return const Color(0xFFFF9800);
      case QRResultType.wifi:
        return const Color(0xFF9C27B0);
      case QRResultType.text:
        return const Color(0xFF607D8B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final typeColor = _getTypeColor(result.type);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Animated icon and type
          Center(
            child: AnimatedResultIcon(
              type: result.type,
              size: 80,
              color: typeColor,
            ),
          ),
          const SizedBox(height: 16),

          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                result.type.displayName,
                style: textTheme.labelLarge?.copyWith(
                  color: typeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Value
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              result.formattedValue,
              style: textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 8),

          // Timestamp
          Center(
            child: Text(
              'Scanned ${_formatDate(result.scannedAt)}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: result.rawValue));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    onDismiss();
                    context.push(AppRoutes.resultDetailPath(result.id));
                  },
                  icon: const Icon(Icons.open_in_full),
                  label: const Text('Details'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Scan again
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onDismiss,
              child: const Text('Scan Another'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} minutes ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours} hours ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}