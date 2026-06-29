import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/scan_history_repository.dart';
import '../../../scanner/domain/enums/qr_result_type.dart';
import '../../../scanner/domain/models/qr_result.dart';

final scanHistoryRepositoryProvider = Provider<ScanHistoryRepository>((ref) {
  return ScanHistoryRepository();
});

final scanHistoryProvider =
    AsyncNotifierProvider<ScanHistoryNotifier, List<QRResult>>(
  ScanHistoryNotifier.new,
);

class ScanHistoryNotifier extends AsyncNotifier<List<QRResult>> {
  @override
  Future<List<QRResult>> build() async {
    final repository = ref.read(scanHistoryRepositoryProvider);
    return repository.getAllScans();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(scanHistoryRepositoryProvider);
      return repository.getAllScans();
    });
  }

  Future<void> deleteScan(String id) async {
    final repository = ref.read(scanHistoryRepositoryProvider);
    await repository.deleteScan(id);
    await refresh();
  }

  Future<void> toggleFavorite(String id) async {
    final repository = ref.read(scanHistoryRepositoryProvider);
    await repository.toggleFavorite(id);
    await refresh();
  }

  Future<void> clearAll() async {
    final repository = ref.read(scanHistoryRepositoryProvider);
    await repository.clearAll();
    await refresh();
  }

  Future<String> exportAsJson() async {
    final repository = ref.read(scanHistoryRepositoryProvider);
    return repository.exportAsJson();
  }
}

enum HistoryFilter { all, favorites, url, wifi, contact }

List<QRResult> filterScans(
  List<QRResult> scans, {
  required String query,
  required HistoryFilter filter,
}) {
  var filtered = scans;

  switch (filter) {
    case HistoryFilter.favorites:
      filtered = filtered.where((s) => s.isFavorite).toList();
    case HistoryFilter.url:
      filtered = filtered.where((s) => s.type == QRResultType.url).toList();
    case HistoryFilter.wifi:
      filtered = filtered.where((s) => s.type == QRResultType.wifi).toList();
    case HistoryFilter.contact:
      filtered = filtered.where((s) => s.type == QRResultType.vcard).toList();
    case HistoryFilter.all:
      break;
  }

  if (query.isNotEmpty) {
    final lower = query.toLowerCase();
    filtered = filtered
        .where(
          (s) =>
              s.rawValue.toLowerCase().contains(lower) ||
              s.formattedValue.toLowerCase().contains(lower) ||
              s.type.displayName.toLowerCase().contains(lower),
        )
        .toList();
  }

  return filtered;
}
