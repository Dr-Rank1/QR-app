import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';

import '../qr_payload_builder.dart';

/// Visual options applied when rendering QR previews and exports.
class QrRenderOptions {
  final double size;
  final bool embedLogo;
  final bool roundedModules;

  const QrRenderOptions({
    this.size = 200,
    this.embedLogo = false,
    this.roundedModules = false,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is QrRenderOptions &&
            other.size == size &&
            other.embedLogo == embedLogo &&
            other.roundedModules == roundedModules;
  }

  @override
  int get hashCode => Object.hash(size, embedLogo, roundedModules);
}

/// Renders QR codes off the main widget tree for sharing and previews.
class QrGenerationService {
  final ScreenshotController screenshotController;

  QrGenerationService({ScreenshotController? screenshotController})
      : screenshotController = screenshotController ?? ScreenshotController();

  Future<Uint8List> renderQrPng(
    String payload, {
    double pixelRatio = 3,
    QrRenderOptions options = const QrRenderOptions(),
  }) async {
    final trimmed = payload.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Cannot render an empty QR payload');
    }

    await Future<void>.delayed(Duration.zero);

    return screenshotController.captureFromWidget(
      QrPreviewImage(data: trimmed, options: options),
      pixelRatio: pixelRatio,
    );
  }

  String buildPayload(GeneratorContentType type, Map<String, String> fields) {
    return QRPayloadBuilder.build(type, fields);
  }

  Map<String, String?> validateFields(
    GeneratorContentType type,
    Map<String, String> fields,
  ) {
    return QRPayloadBuilder.fieldErrors(type, fields);
  }
}

/// Standalone QR widget used for off-screen rendering.
class QrPreviewImage extends StatelessWidget {
  final String data;
  final QrRenderOptions options;

  const QrPreviewImage({
    super.key,
    required this.data,
    this.options = const QrRenderOptions(),
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: QrImageView(
          data: data,
          version: QrVersions.auto,
          size: options.size,
          backgroundColor: Colors.white,
          embeddedImage: options.embedLogo
              ? const AssetImage('assets/app_icon.png')
              : null,
          embeddedImageStyle: options.embedLogo
              ? QrEmbeddedImageStyle(
                  size: Size(options.size * 0.18, options.size * 0.18),
                )
              : null,
          eyeStyle: QrEyeStyle(
            eyeShape: options.roundedModules
                ? QrEyeShape.circle
                : QrEyeShape.square,
            color: Colors.black,
          ),
          dataModuleStyle: QrDataModuleStyle(
            dataModuleShape: options.roundedModules
                ? QrDataModuleShape.circle
                : QrDataModuleShape.square,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
