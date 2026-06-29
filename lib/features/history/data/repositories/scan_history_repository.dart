import 'package:hive_flutter/hive_flutter.dart';

import '../../../scanner/domain/enums/qr_result_type.dart';
import '../../../scanner/domain/models/qr_result.dart';

class ScanHistoryRepository {
  static ScanHistoryRepository? _instance;

  factory ScanHistoryRepository() {
    _instance ??= ScanHistoryRepository._internal();
    return _instance!;
  }

  ScanHistoryRepository._internal();

  static const String _boxName = 'scan_history';
  static const int _maxItems = 50;
  static const int _pageSize = 20;

  late Box<QRResult> _box;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(QRResultAdapter());
    }

    _box = await Hive.openBox<QRResult>(_boxName);
    _isInitialized = true;
    await _trimOldScans();
  }

  Future<void> _trimOldScans() async {
    if (_box.length <= _maxItems) return;

    final scans = _box.values.toList();
    scans.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));

    final toDelete = scans.skip(_maxItems).toList();
    for (final scan in toDelete) {
      await scan.delete();
    }
  }

  Future<List<QRResult>> getScansPage({int page = 0}) async {
    await initialize();

    final allScans = _box.values.toList();
    allScans.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));

    final offset = page * _pageSize;
    if (offset >= allScans.length) return [];

    return allScans.skip(offset).take(_pageSize).toList();
  }

  Future<int> getTotalCount() async {
    await initialize();
    return _box.length;
  }

  Future<List<QRResult>> getAllScans() async {
    await initialize();

    final scans = _box.values.toList();
    scans.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return scans;
  }

  Future<List<QRResult>> getRecentScans({int limit = 3}) async {
    await initialize();

    final scans = _box.values.toList();
    scans.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return scans.take(limit).toList();
  }

  Future<QRResult?> getScan(String id) async {
    await initialize();
    return _box.get(id);
  }

  Future<void> addScan(QRResult scan) async {
    await initialize();
    await _box.put(scan.id, scan);
    await _trimOldScans();
  }

  Future<void> deleteScan(String id) async {
    await initialize();
    await _box.delete(id);
  }

  Future<void> toggleFavorite(String id) async {
    await initialize();
    final scan = _box.get(id);
    if (scan != null) {
      await _box.put(id, scan.copyWith(isFavorite: !scan.isFavorite));
    }
  }

  Future<void> clearAll() async {
    await initialize();
    await _box.clear();
  }

  Future<String> exportAsJson() async {
    final scans = await getAllScans();
    final buffer = StringBuffer('[\n');
    for (var i = 0; i < scans.length; i++) {
      final scan = scans[i];
      buffer.writeln('  {');
      buffer.writeln('    "id": "${scan.id}",');
      buffer.writeln('    "rawValue": ${_escapeJson(scan.rawValue)},');
      buffer.writeln('    "type": "${scan.type.displayName}",');
      buffer.writeln('    "scannedAt": "${scan.scannedAt.toIso8601String()}",');
      buffer.writeln('    "isFavorite": ${scan.isFavorite}');
      buffer.write('  }');
      if (i < scans.length - 1) buffer.write(',');
      buffer.writeln();
    }
    buffer.write(']');
    return buffer.toString();
  }

  String _escapeJson(String value) {
    return '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('\n', '\\n')}"';
  }

  Stream<List<QRResult>> watchScans() async* {
    await initialize();
    yield await getAllScans();
    yield* _box.watch().asyncMap((_) => getAllScans());
  }
}
