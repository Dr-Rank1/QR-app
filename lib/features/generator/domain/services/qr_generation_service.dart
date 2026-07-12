import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';

import '../qr_payload_builder.dart';

/// Visual options applied when rendering QR previews and exports.
class QrRenderOptions {
  final double size;
  final bool embedLogo;
  final Uint8List? logoBytes;
  final bool roundedModules;
  final Color foregroundColor;
  final Color backgroundColor;

  const QrRenderOptions({
    this.size = 200,
    this.embedLogo = false,
    this.logoBytes,
    this.roundedModules = false,
    this.foregroundColor = Colors.black,
    this.backgroundColor = Colors.white,
  });

  QrRenderOptions copyWith({
    double? size,
    bool? embedLogo,
    Uint8List? logoBytes,
    bool clearLogoBytes = false,
    bool? roundedModules,
    Color? foregroundColor,
    Color? backgroundColor,
  }) {
    return QrRenderOptions(
      size: size ?? this.size,
      embedLogo: embedLogo ?? this.embedLogo,
      logoBytes: clearLogoBytes ? null : (logoBytes ?? this.logoBytes),
      roundedModules: roundedModules ?? this.roundedModules,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }

  ImageProvider? get embeddedImage {
    if (!embedLogo) return null;
    if (logoBytes != null && logoBytes!.isNotEmpty) {
      return MemoryImage(logoBytes!);
    }
    return const AssetImage('assets/app_icon.png');
  }

  int get errorCorrectionLevel =>
      embedLogo ? QrErrorCorrectLevel.H : QrErrorCorrectLevel.M;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is QrRenderOptions &&
            other.size == size &&
            other.embedLogo == embedLogo &&
            other.logoBytes == logoBytes &&
            other.roundedModules == roundedModules &&
            other.foregroundColor == foregroundColor &&
            other.backgroundColor == backgroundColor;
  }

  @override
  int get hashCode => Object.hash(
        size,
        embedLogo,
        logoBytes,
        roundedModules,
        foregroundColor,
        backgroundColor,
      );
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
    final logo = options.embeddedImage;
    final logoSize = options.size * 0.2;

    return ColoredBox(
      color: options.backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: QrImageView(
          data: data,
          version: QrVersions.auto,
          size: options.size,
          backgroundColor: options.backgroundColor,
          errorCorrectionLevel: options.errorCorrectionLevel,
          embeddedImage: logo,
          embeddedImageStyle: logo != null
              ? QrEmbeddedImageStyle(size: Size(logoSize, logoSize))
              : null,
          eyeStyle: QrEyeStyle(
            eyeShape: options.roundedModules
                ? QrEyeShape.circle
                : QrEyeShape.square,
            color: options.foregroundColor,
          ),
          dataModuleStyle: QrDataModuleStyle(
            dataModuleShape: options.roundedModules
                ? QrDataModuleShape.circle
                : QrDataModuleShape.square,
            color: options.foregroundColor,
          ),
        ),
      ),
    );
  }
}
