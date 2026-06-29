import 'package:mobile_scanner/mobile_scanner.dart';

/// Describes the outcome of planning a front/back camera switch.
class CameraSwitchPlan {
  final CameraFacing nextFacing;
  final bool torchAfterSwitch;
  final bool shouldTurnOffTorchBeforeSwitch;

  const CameraSwitchPlan({
    required this.nextFacing,
    required this.torchAfterSwitch,
    required this.shouldTurnOffTorchBeforeSwitch,
  });
}

/// Encapsulates camera hardware operations and switch/torch rules.
class CameraScanService {
  MobileScannerController? _controller;

  MobileScannerController? get controller => _controller;

  static CameraFacing toggleFacing(CameraFacing current) {
    return current == CameraFacing.back
        ? CameraFacing.front
        : CameraFacing.back;
  }

  static bool isTorchAvailable(CameraFacing facing) {
    return facing == CameraFacing.back;
  }

  static CameraSwitchPlan planSwitch({
    required CameraFacing currentFacing,
    required bool isTorchOn,
  }) {
    final nextFacing = toggleFacing(currentFacing);
    final switchingToFront = nextFacing == CameraFacing.front;

    return CameraSwitchPlan(
      nextFacing: nextFacing,
      torchAfterSwitch: switchingToFront ? false : isTorchOn,
      shouldTurnOffTorchBeforeSwitch: switchingToFront && isTorchOn,
    );
  }

  static bool isTorchActionEnabled({
    required bool hasCameraPermission,
    required CameraFacing facing,
    bool isProcessing = false,
    bool isSwitchingCamera = false,
  }) {
    return hasCameraPermission &&
        !isProcessing &&
        !isSwitchingCamera &&
        isTorchAvailable(facing);
  }

  Future<MobileScannerController> startController({
    required CameraFacing facing,
    required bool torchOn,
  }) async {
    await disposeController();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: facing,
      torchEnabled: isTorchAvailable(facing) && torchOn,
    );
    return _controller!;
  }

  Future<void> disposeController() async {
    await _controller?.dispose();
    _controller = null;
  }

  Future<void> toggleTorch() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      await controller.toggleTorch();
    } on MobileScannerException {
      // Preview not ready yet.
    }
  }

  /// Switches cameras in-place when possible; recreates the controller on failure.
  Future<void> switchCamera({
    required CameraFacing currentFacing,
    required bool isTorchOn,
    required void Function(CameraFacing facing) onFacingChanged,
    required void Function(bool torchOn) onTorchChanged,
  }) async {
    final controller = _controller;
    if (controller == null) return;

    final plan = planSwitch(
      currentFacing: currentFacing,
      isTorchOn: isTorchOn,
    );

    if (plan.shouldTurnOffTorchBeforeSwitch) {
      onTorchChanged(false);
      try {
        await controller.toggleTorch();
      } on MobileScannerException {
        //
      }
    }

    try {
      await controller.switchCamera();
      onFacingChanged(plan.nextFacing);
      if (plan.nextFacing == CameraFacing.front) {
        onTorchChanged(false);
      }
    } on MobileScannerException {
      onFacingChanged(plan.nextFacing);
      if (plan.nextFacing == CameraFacing.front) {
        onTorchChanged(false);
      }
      await startController(
        facing: plan.nextFacing,
        torchOn: plan.torchAfterSwitch,
      );
    }
  }
}
