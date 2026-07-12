import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import 'qr_generation_service.dart';

/// Builds printable SVG QR codes from payload + render options.
class QrSvgExporter {
  const QrSvgExporter();

  String buildSvg(
    String payload, {
    QrRenderOptions options = const QrRenderOptions(),
    double viewBoxSize = 256,
  }) {
    final trimmed = payload.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Cannot export an empty QR payload');
    }

    final errorLevel = options.embedLogo
        ? QrErrorCorrectLevel.H
        : QrErrorCorrectLevel.M;
    final qrCode = QrCode.fromData(
      data: trimmed,
      errorCorrectLevel: errorLevel,
    );
    final qrImage = QrImage(qrCode);
    final modules = qrImage.moduleCount;
    final cell = viewBoxSize / modules;

    final fg = _toHex(options.foregroundColor);
    final bg = _toHex(options.backgroundColor);

    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<svg xmlns="http://www.w3.org/2000/svg" '
        'xmlns:xlink="http://www.w3.org/1999/xlink" '
        'width="$viewBoxSize" height="$viewBoxSize" '
        'viewBox="0 0 $viewBoxSize $viewBoxSize" '
        'shape-rendering="crispEdges">',
      )
      ..writeln('<rect width="100%" height="100%" fill="$bg"/>');

    for (var row = 0; row < modules; row++) {
      for (var col = 0; col < modules; col++) {
        if (!qrImage.isDark(row, col)) continue;
        final x = (col * cell).toStringAsFixed(3);
        final y = (row * cell).toStringAsFixed(3);
        final size = cell.toStringAsFixed(3);
        buffer.writeln(
          '<rect x="$x" y="$y" width="$size" height="$size" fill="$fg"/>',
        );
      }
    }

    if (options.embedLogo) {
      final logoSvg = _logoOverlay(options, viewBoxSize);
      if (logoSvg != null) buffer.writeln(logoSvg);
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }

  String? _logoOverlay(QrRenderOptions options, double viewBoxSize) {
    final logoSize = viewBoxSize * 0.2;
    final origin = (viewBoxSize - logoSize) / 2;
    final pad = logoSize * 0.12;

    final buffer = StringBuffer()
      ..writeln(
        '<rect x="${(origin - pad).toStringAsFixed(2)}" '
        'y="${(origin - pad).toStringAsFixed(2)}" '
        'width="${(logoSize + pad * 2).toStringAsFixed(2)}" '
        'height="${(logoSize + pad * 2).toStringAsFixed(2)}" '
        'fill="${_toHex(options.backgroundColor)}"/>',
      );

    final bytes = options.logoBytes;
    if (bytes != null && bytes.isNotEmpty) {
      final b64 = base64Encode(bytes);
      buffer.writeln(
        '<image x="${origin.toStringAsFixed(2)}" '
        'y="${origin.toStringAsFixed(2)}" '
        'width="${logoSize.toStringAsFixed(2)}" '
        'height="${logoSize.toStringAsFixed(2)}" '
        'preserveAspectRatio="xMidYMid meet" '
        'xlink:href="data:image/png;base64,$b64"/>',
      );
      return buffer.toString();
    }

    // App-icon asset isn't available as bytes here; leave quiet center pad.
    return buffer.toString();
  }

  String _toHex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0')}';
  }

  Uint8List encodeUtf8(String svg) => Uint8List.fromList(utf8.encode(svg));
}
