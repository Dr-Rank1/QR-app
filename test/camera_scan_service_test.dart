import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_vault/features/scanner/domain/services/camera_scan_service.dart';

void main() {
  group('CameraScanService switch planning', () {
    test('toggles between back and front cameras', () {
      expect(
        CameraScanService.toggleFacing(CameraFacing.back),
        CameraFacing.front,
      );
      expect(
        CameraScanService.toggleFacing(CameraFacing.front),
        CameraFacing.back,
      );
    });

    test('turns torch off when switching to front camera', () {
      final plan = CameraScanService.planSwitch(
        currentFacing: CameraFacing.back,
        isTorchOn: true,
      );

      expect(plan.nextFacing, CameraFacing.front);
      expect(plan.torchAfterSwitch, isFalse);
      expect(plan.shouldTurnOffTorchBeforeSwitch, isTrue);
    });

    test('preserves torch state when switching to back camera', () {
      final plan = CameraScanService.planSwitch(
        currentFacing: CameraFacing.front,
        isTorchOn: false,
      );

      expect(plan.nextFacing, CameraFacing.back);
      expect(plan.torchAfterSwitch, isFalse);
      expect(plan.shouldTurnOffTorchBeforeSwitch, isFalse);
    });
  });

  group('CameraScanService torch availability', () {
    test('torch is only available on back camera', () {
      expect(CameraScanService.isTorchAvailable(CameraFacing.back), isTrue);
      expect(CameraScanService.isTorchAvailable(CameraFacing.front), isFalse);
    });

    test('torch action disabled on front camera to prevent preview errors', () {
      expect(
        CameraScanService.isTorchActionEnabled(
          hasCameraPermission: true,
          facing: CameraFacing.front,
        ),
        isFalse,
      );
      expect(
        CameraScanService.isTorchActionEnabled(
          hasCameraPermission: true,
          facing: CameraFacing.back,
        ),
        isTrue,
      );
    });

    test('torch action disabled while switching cameras', () {
      expect(
        CameraScanService.isTorchActionEnabled(
          hasCameraPermission: true,
          facing: CameraFacing.back,
          isSwitchingCamera: true,
        ),
        isFalse,
      );
    });
  });
}
