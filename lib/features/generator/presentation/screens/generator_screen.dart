import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

enum QRPreset { text, url, wifi, phone, email, sms }

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
  QRPreset _preset = QRPreset.text;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _generateQR(String data) {
    setState(() => _qrData = data);
  }

  void _applyPreset(QRPreset preset) {
    setState(() => _preset = preset);
    const templates = {
      QRPreset.text: '',
      QRPreset.url: 'https://example.com',
      QRPreset.wifi: 'WIFI:T:WPA;S:MyNetwork;P:password;;',
      QRPreset.phone: 'tel:+1234567890',
      QRPreset.email: 'mailto:hello@example.com',
      QRPreset.sms: 'sms:+1234567890?body=Hello',
    };
    final template = templates[preset] ?? '';
    _textController.text = template;
    _generateQR(template);
  }

  Future<void> _saveAndShare() async {
    if (_qrData.isEmpty) return;

    try {
      final image = await _screenshotController.capture();
      if (image == null) return;

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/qr_code.png');
      await file.writeAsBytes(image);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'QR Code',
        ),
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Screenshot(
              controller: _screenshotController,
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                alignment: Alignment.center,
                child: QrImageView(
                  data: _qrData.isEmpty ? ' ' : _qrData,
                  version: QrVersions.auto,
                  size: _qrSize,
                  backgroundColor: Colors.white,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: _qrColor,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: _qrColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Preset', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: QRPreset.values.map((preset) {
                return ChoiceChip(
                  label: Text(_presetLabel(preset)),
                  selected: _preset == preset,
                  onSelected: (_) => _applyPreset(preset),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: _hintForPreset(_preset),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _textController.clear();
                    _generateQR('');
                  },
                ),
              ),
              onChanged: _generateQR,
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('QR Color: '),
                ...[Colors.black, Colors.blue, Colors.red, Colors.green, Colors.purple]
                    .map((color) => GestureDetector(
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
                        )),
              ],
            ),
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
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _qrData.isEmpty ? null : _saveAndShare,
              icon: const Icon(Icons.share),
              label: const Text('Share QR Code'),
            ),
          ],
        ),
      ),
    );
  }

  String _presetLabel(QRPreset preset) {
    switch (preset) {
      case QRPreset.text:
        return 'Text';
      case QRPreset.url:
        return 'URL';
      case QRPreset.wifi:
        return 'Wi-Fi';
      case QRPreset.phone:
        return 'Phone';
      case QRPreset.email:
        return 'Email';
      case QRPreset.sms:
        return 'SMS';
    }
  }

  String _hintForPreset(QRPreset preset) {
    switch (preset) {
      case QRPreset.text:
        return 'Enter any text';
      case QRPreset.url:
        return 'https://your-website.com';
      case QRPreset.wifi:
        return 'WIFI:T:WPA;S:Network;P:password;;';
      case QRPreset.phone:
        return 'tel:+1234567890';
      case QRPreset.email:
        return 'mailto:you@example.com';
      case QRPreset.sms:
        return 'sms:+1234567890?body=Hello';
    }
  }
}
