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

  Future<File> writeTempSvg(String svg) async {
    return _writeTempTextFile(contents: svg, extension: 'svg');
  }

  Future<void> shareSvg(String svg, {String subject = 'QR Code'}) async {
    final file = await writeTempSvg(svg);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(file.path, mimeType: 'image/svg+xml', name: 'qr_code.svg'),
        ],
        subject: subject,
        text: subject,
      ),
    );
  }

  Future<File> _writeTempTextFile({
    required String contents,
    required String extension,
  }) async {
    final tempRoot = await getTemporaryDirectory();
    final cacheDir = Directory('${tempRoot.path}/$_cacheFolderName');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    final file = File(
      '${cacheDir.path}/qr_${DateTime.now().millisecondsSinceEpoch}.$extension',
    );
    await file.writeAsString(contents, flush: true);
    return file;
  }

  Future<void> shareContactCard(String vcardPayload) async {
    var payload = vcardPayload.trim();
    if (!payload.toUpperCase().contains('BEGIN:VCARD')) {
      payload = 'BEGIN:VCARD\nVERSION:3.0\nFN:Contact\nEND:VCARD';
    }
    final file = await _writeTempTextFile(contents: payload, extension: 'vcf');
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(file.path, mimeType: 'text/vcard', name: 'contact.vcf'),
        ],
        subject: 'Contact',
      ),
    );
  }

  Future<void> shareCalendarEvent(String eventPayload) async {
    var payload = eventPayload.trim();
    if (!payload.toUpperCase().contains('BEGIN:VCALENDAR')) {
      if (payload.toUpperCase().contains('BEGIN:VEVENT')) {
        payload = 'BEGIN:VCALENDAR\nVERSION:2.0\n$payload\nEND:VCALENDAR';
      }
    }
    final file = await _writeTempTextFile(contents: payload, extension: 'ics');
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(file.path, mimeType: 'text/calendar', name: 'event.ics'),
        ],
        subject: 'Calendar event',
      ),
    );
  }
}
