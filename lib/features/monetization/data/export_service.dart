import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../scanner/domain/models/qr_result.dart';

class ExportService {
  /// Export scans to CSV file
  static Future<String?> exportToCsv(List<QRResult> scans) async {
    try {
      // Create CSV data
      final List<List<dynamic>> rows = [
        ['ID', 'Type', 'Value', 'Scanned At', 'Metadata'],
        ...scans.map((scan) => [
          scan.id,
          scan.type.name,
          scan.rawValue,
          scan.scannedAt.toIso8601String(),
          scan.metadata?.toString() ?? '',
        ]),
      ];

      final csv = const ListToCsvConverter().convert(rows);

      // Save to temp directory
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/qr_scans_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv);

      return file.path;
    } catch (e) {
      return null;
    }
  }

  /// Export scans to PDF file
  static Future<String?> exportToPdf(List<QRResult> scans) async {
    try {
      final pdf = pw.Document();

      // Create PDF content
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'QR Scan History',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Exported on ${DateTime.now().toString().split('.')[0]}',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Divider(),
              pw.SizedBox(height: 16),
            ],
          ),
          build: (context) => [
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              cellPadding: const pw.EdgeInsets.all(8),
              headers: ['Type', 'Value', 'Date'],
              data: scans.map((scan) => [
                scan.type.displayName,
                scan.rawValue.length > 30 
                    ? '${scan.rawValue.substring(0, 30)}...' 
                    : scan.rawValue,
                _formatDate(scan.scannedAt),
              ]).toList(),
            ),
          ],
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ),
      );

      // Save to temp directory
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/qr_scans_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      return file.path;
    } catch (e) {
      return null;
    }
  }

  /// Share exported file
  static Future<void> shareFile(String filePath) async {
    await Share.shareXFiles([XFile(filePath)]);
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}