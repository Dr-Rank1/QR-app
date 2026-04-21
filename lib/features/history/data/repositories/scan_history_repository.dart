import 'package:hive_flutter/hive_flutter.dart';

import '../../../scanner/domain/models/qr_result.dart';

class ScanHistoryRepository {
  static const String _boxName = 'scan_history';
  static const int _maxItems = 50;
  static const int _pageSize = 20; // Performance: Page size for pagination

  late Box<QRResult> _box;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(QRResultAdapter());
    }

    _box = await Hive.openBox<QRResult>(_boxName);
    _isInitialized = true;

    // Trim to max items
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

  // Performance: Pagination - load 20 items at a time
  Future<List<QRResult>> getScansPage({int page = 0}) async {
    await initialize();

    final allScans = _box.values.toList();
    allScans.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));

    final offset = page * _pageSize;
    if (offset >= allScans.length) return [];

    return allScans.skip(offset).take(_pageSize).toList();
  }

  // Performance: Get total count without loading all
  Future<int> getTotalCount() async {
    await initialize();
    return _box.length;
  }

  // Legacy method for backward compatibility
  Future<List<QRResult>> getAllScans() async {
    await initialize();

    final scans = _box.values.toList();
    scans.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    return scans;
  }

  // Get recent scans (optimized with limit)
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

  Future<void> clearAll() async {
    await initialize();
    await _box.clear();
  }

  Stream<List<QRResult>> watchScans() async* {
    await initialize();

    // Emit initial value
    yield await getAllScans();

    // Watch for changes
    yield* _box.watch().asyncMap((_) => getAllScans());
  }
}