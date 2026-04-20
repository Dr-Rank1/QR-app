import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/scan_history_repository.dart';
import '../../domain/models/qr_result.dart';

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
    return await repository.getAllScans();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(scanHistoryRepositoryProvider);
      return await repository.getAllScans();
    });
  }

  Future<void> deleteScan(String id) async {
    final repository = ref.read(scanHistoryRepositoryProvider);
    await repository.deleteScan(id);
    await refresh();
  }

  Future<void> clearAll() async {
    final repository = ref.read(scanHistoryRepositoryProvider);
    await repository.clearAll();
    await refresh();
  }
}