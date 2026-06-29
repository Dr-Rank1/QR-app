import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_vault/features/scanner/domain/services/camera_scan_service.dart';

void main() {
  testWidgets('front camera state disables torch control', (tester) async {
    var torchPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TorchProbe(
            facing: CameraFacing.front,
            onTorchPressed: () => torchPressed = true,
          ),
        ),
      ),
    );

    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('torch_probe')), warnIfMissed: false);
    await tester.pump();
    expect(torchPressed, isFalse);
  });

  testWidgets('back camera state enables torch control', (tester) async {
    var torchPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TorchProbe(
            facing: CameraFacing.back,
            onTorchPressed: () => torchPressed = true,
          ),
        ),
      ),
    );

    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('torch_probe')));
    await tester.pump();
    expect(torchPressed, isTrue);
  });
}

class _TorchProbe extends StatelessWidget {
  final CameraFacing facing;
  final VoidCallback onTorchPressed;

  const _TorchProbe({
    required this.facing,
    required this.onTorchPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = CameraScanService.isTorchActionEnabled(
      hasCameraPermission: true,
      facing: facing,
    );

    return Semantics(
      key: const Key('torch_probe'),
      button: true,
      enabled: enabled,
      label: 'Turn flashlight on',
      child: ElevatedButton(
        onPressed: enabled ? onTorchPressed : null,
        child: const Text('Torch'),
      ),
    );
  }
}
