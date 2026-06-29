import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Native share intents using temporary cache files only.
class ShareService {
  static const _cacheFolderName = 'qr_share';

  Future<File> writeTempPng(Uint8List bytes) async {
    final tempRoot = await getTemporaryDirectory();
    final cacheDir = Directory('${tempRoot.path}/$_cacheFolderName');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final file = File(
      '${cacheDir.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> shareText(String text) async {
    if (text.trim().isEmpty) return;
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> sharePngFile(
    File file, {
    String? subject,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png', name: 'qr_code.png')],
        subject: subject,
        text: subject,
      ),
    );
  }

  Future<void> shareQrImage(
    Uint8List pngBytes, {
    String subject = 'QR Code',
  }) async {
    final file = await writeTempPng(pngBytes);
    await sharePngFile(file, subject: subject);
  }
}
