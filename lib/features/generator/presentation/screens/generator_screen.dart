import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class GeneratorScreen extends ConsumerStatefulWidget {
  const GeneratorScreen({super.key});

  @override
  ConsumerState<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends ConsumerState<GeneratorScreen> {
  final _textController = TextEditingController();
  final _screenshotController = ScreenshotController();
  String _qrData = '';
  Color _qrColor = Colors.black;
  double _qrSize = 200;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _generateQR(String data) {
    setState(() {
      _qrData = data;
    });
  }

  Future<void> _saveAndShare() async {
    if (_qrData.isEmpty) return;

    try {
      final image = await _screenshotController.capture();
      if (image == null) return;

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/qr_code.png');
      await file.writeAsBytes(image);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'QR Code',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate QR'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // QR Code Display
            Screenshot(
              controller: _screenshotController,
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: QrImageView(
                  data: _qrData.isEmpty ? ' ' : _qrData,
                  version: QrVersions.auto,
                  size: _qrSize,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Input Field
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Enter text or URL',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _textController.clear();
                    _generateQR('');
                  },
                ),
              ),
              onChanged: _generateQR,
              maxLines: 3,
            ),

            const SizedBox(height: 16),

            // Color Picker Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('QR Color: '),
                Wrap(
                  children: [
                    Colors.black,
                    Colors.blue,
                    Colors.red,
                    Colors.green,
                    Colors.purple,
                  ].map((color) {
                    return GestureDetector(
                      onTap: () => setState(() => _qrColor = color),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: _qrColor == color
                              ? Border.all(color: Colors.blue, width: 3)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Size Slider
            Row(
              children: [
                const Text('Size:'),
                Expanded(
                  child: Slider(
                    value: _qrSize,
                    min: 100,
                    max: 300,
                    onChanged: (value) => setState(() => _qrSize = value),
                  ),
                ),
                Text('${_qrSize.toInt()}'),
              ],
            ),

            const SizedBox(height: 24),

            // Share Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _qrData.isEmpty ? null : _saveAndShare,
                icon: const Icon(Icons.share),
                label: const Text('Share QR Code'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
