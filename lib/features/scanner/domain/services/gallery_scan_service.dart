import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'
    as mlkit;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../shared/security/secure_logger.dart';

/// Outcome of decoding a QR code from a gallery image.
sealed class GalleryScanOutcome {}

class GalleryScanSuccess extends GalleryScanOutcome {
  final String payload;

  GalleryScanSuccess(this.payload);
}

class GalleryScanNoCode extends GalleryScanOutcome {}

class GalleryScanCancelled extends GalleryScanOutcome {}

class GalleryScanFailure extends GalleryScanOutcome {
  final String message;
  final Object? error;

  GalleryScanFailure(this.message, [this.error]);
}

/// Picks gallery images and decodes QR codes offline.
class GalleryScanService {
  static const _maxBytes = 12 * 1024 * 1024;
  static const _maxDimension = 2048;
  static const _retryDimension = 1280;
  static const _upscaleDimension = 2400;
  static final _picker = ImagePicker();

  final mlkit.BarcodeScanner _mlKitScanner = mlkit.BarcodeScanner(
    formats: const [mlkit.BarcodeFormat.qrCode],
  );

  Future<void> dispose() async {
    await _mlKitScanner.close();
  }

  Future<GalleryScanOutcome> pickAndDecode() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (picked == null) {
        SecureLogger.log('GalleryScan: user cancelled picker');
        return GalleryScanCancelled();
      }

      SecureLogger.log('GalleryScan: picked ${picked.path} (${picked.name})');
      return decodeFromXFile(picked);
    } catch (error, stackTrace) {
      SecureLogger.logError(error, stackTrace);
      return GalleryScanFailure('Could not open gallery. Please try again.', error);
    }
  }

  Future<GalleryScanOutcome> decodeFromXFile(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        SecureLogger.log('GalleryScan: picked file is empty');
        return GalleryScanFailure('Selected image is empty');
      }

      if (bytes.length > _maxBytes) {
        SecureLogger.log(
          'GalleryScan: image too large (${bytes.length} bytes)',
        );
        return GalleryScanFailure(
          'Image is too large. Try a smaller photo or crop the QR code.',
        );
      }

      final rawTempPath = await _writeRawBytes(bytes, file.name);
      SecureLogger.log('GalleryScan: raw temp file at $rawTempPath');

      final rawPayload = await _decodeAllStrategies(
        filePath: rawTempPath,
        raster: null,
      );
      if (rawPayload != null) {
        return GalleryScanSuccess(rawPayload);
      }

      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        SecureLogger.log('GalleryScan: could not decode image bytes');
        return GalleryScanFailure(
          'Unsupported image format. Try JPG or PNG.',
        );
      }

      final attempts = <({int maxDimension, String label, img.Image image})>[
        (maxDimension: _maxDimension, label: 'primary', image: decoded),
        (maxDimension: _retryDimension, label: 'retry', image: decoded),
      ];

      final longest =
          decoded.width > decoded.height ? decoded.width : decoded.height;
      if (longest < 900) {
        attempts.add((
          maxDimension: _upscaleDimension,
          label: 'upscale',
          image: img.copyResize(
            decoded,
            width: (decoded.width * 1.8).round(),
            height: (decoded.height * 1.8).round(),
            interpolation: img.Interpolation.linear,
          ),
        ));
      }

      for (final attempt in attempts) {
        final preparedPath = await _writePreparedImage(
          attempt.image,
          maxDimension: attempt.maxDimension,
          label: attempt.label,
        );
        SecureLogger.log('GalleryScan: analyzing ${attempt.label} image');

        final payload = await _decodeAllStrategies(
          filePath: preparedPath,
          raster: attempt.image,
        );
        if (payload != null) {
          return GalleryScanSuccess(payload);
        }
      }

      SecureLogger.log('GalleryScan: no QR code detected');
      return GalleryScanNoCode();
    } catch (error, stackTrace) {
      SecureLogger.logError(error, stackTrace);
      return GalleryScanFailure(
        'Could not read image. Please try another photo.',
        error,
      );
    }
  }

  Future<String> _writeRawBytes(Uint8List bytes, String originalName) async {
    final tempDir = await getTemporaryDirectory();
    final extension = _extensionFor(originalName);
    final outFile = File(
      '${tempDir.path}/gallery_raw_${DateTime.now().millisecondsSinceEpoch}.$extension',
    );
    await outFile.writeAsBytes(bytes, flush: true);
    return outFile.path;
  }

  Future<String?> _decodeAllStrategies({
    required String filePath,
    required img.Image? raster,
  }) async {
    final mlKitFromFile = await _decodeWithMlKitFromPath(filePath);
    if (mlKitFromFile != null) return mlKitFromFile;

    if (raster != null) {
      final mlKitFromBytes = await _decodeWithMlKitFromImage(raster);
      if (mlKitFromBytes != null) return mlKitFromBytes;
    }

    return _decodeWithMobileScanner(filePath);
  }

  Future<String> _writePreparedImage(
    img.Image source, {
    required int maxDimension,
    required String label,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final outFile = File(
      '${tempDir.path}/gallery_scan_${label}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    final resized = _resizeIfNeeded(source, maxDimension);
    final encoded = img.encodeJpg(resized, quality: 95);
    await outFile.writeAsBytes(encoded, flush: true);
    return outFile.path;
  }

  img.Image _resizeIfNeeded(img.Image source, int maxDimension) {
    final longest =
        source.width > source.height ? source.width : source.height;
    if (longest <= maxDimension) return source;

    final scale = maxDimension / longest;
    return img.copyResize(
      source,
      width: (source.width * scale).round(),
      height: (source.height * scale).round(),
      interpolation: img.Interpolation.linear,
    );
  }

  Future<String?> _decodeWithMlKitFromPath(String path) async {
    try {
      if (!File(path).existsSync()) {
        SecureLogger.log('GalleryScan: file missing at $path');
        return null;
      }
      final inputImage = mlkit.InputImage.fromFilePath(path);
      final barcodes = await _mlKitScanner.processImage(inputImage);
      SecureLogger.log(
        'GalleryScan: ML Kit file scan found ${barcodes.length} barcode(s)',
      );
      return _firstBarcodeValue(barcodes);
    } catch (error, stackTrace) {
      SecureLogger.logError(error, stackTrace);
      return null;
    }
  }

  Future<String?> _decodeWithMlKitFromImage(img.Image source) async {
    try {
      final bgra = source.convert(numChannels: 4);
      final bytes = Uint8List.fromList(
        bgra.getBytes(order: img.ChannelOrder.bgra),
      );
      final inputImage = mlkit.InputImage.fromBytes(
        bytes: bytes,
        metadata: mlkit.InputImageMetadata(
          size: Size(bgra.width.toDouble(), bgra.height.toDouble()),
          rotation: mlkit.InputImageRotation.rotation0deg,
          format: mlkit.InputImageFormat.bgra8888,
          bytesPerRow: bgra.width * 4,
        ),
      );
      final barcodes = await _mlKitScanner.processImage(inputImage);
      SecureLogger.log(
        'GalleryScan: ML Kit bytes scan found ${barcodes.length} barcode(s)',
      );
      return _firstBarcodeValue(barcodes);
    } catch (error, stackTrace) {
      SecureLogger.logError(error, stackTrace);
      return null;
    }
  }

  String? _firstBarcodeValue(List<mlkit.Barcode> barcodes) {
    for (final barcode in barcodes) {
      final value = barcode.rawValue ?? barcode.displayValue;
      if (value != null && value.isNotEmpty) {
        SecureLogger.log('GalleryScan: ML Kit decoded payload');
        return value;
      }
    }
    return null;
  }

  Future<String?> _decodeWithMobileScanner(String path) async {
    final analyzer = MobileScannerController(
      autoStart: false,
      formats: const [BarcodeFormat.qrCode],
    );
    try {
      final capture = await analyzer.analyzeImage(
        path,
        formats: const [BarcodeFormat.qrCode],
      );
      if (capture == null) {
        SecureLogger.log('GalleryScan: mobile_scanner returned null');
        return null;
      }

      for (final barcode in capture.barcodes) {
        final value = barcode.rawValue;
        if (value != null && value.isNotEmpty) {
          SecureLogger.log('GalleryScan: mobile_scanner fallback found QR code');
          return value;
        }
      }
      SecureLogger.log(
        'GalleryScan: mobile_scanner found ${capture.barcodes.length} empty barcode(s)',
      );
      return null;
    } on MobileScannerBarcodeException catch (error) {
      SecureLogger.log('GalleryScan: mobile_scanner barcode exception: $error');
      return null;
    } catch (error, stackTrace) {
      SecureLogger.logError(error, stackTrace);
      return null;
    } finally {
      await analyzer.dispose();
    }
  }

  String _extensionFor(String name) {
    final dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) return 'jpg';
    final ext = name.substring(dot + 1).toLowerCase();
    if (ext == 'png' || ext == 'jpg' || ext == 'jpeg' || ext == 'webp') {
      return ext == 'jpeg' ? 'jpg' : ext;
    }
    return 'jpg';
  }
}
