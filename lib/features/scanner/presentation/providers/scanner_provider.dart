import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/qr_result.dart';
import '../../domain/enums/qr_result_type.dart';
import '../../../history/data/repositories/scan_history_repository.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../../shared/utils/qr_parser.dart';

enum ScannerStatus {
  initializing,
  ready,
  scanning,
  processing,
  error,
}

class ScannerState {
  final ScannerStatus status;
  final bool isTorchOn;
  final CameraFacing cameraFacing;
  final String? errorMessage;
  final QRResult? lastScan;

  const ScannerState({
    this.status = ScannerStatus.initializing,
    this.isTorchOn = false,
    this.cameraFacing = CameraFacing.back,
    this.errorMessage,
    this.lastScan,
  });

  ScannerState copyWith({
    ScannerStatus? status,
    bool? isTorchOn,
    CameraFacing? cameraFacing,
    String? errorMessage,
    QRResult? lastScan,
  }) {
    return ScannerState(
      status: status ?? this.status,
      isTorchOn: isTorchOn ?? this.isTorchOn,
      cameraFacing: cameraFacing ?? this.cameraFacing,
      errorMessage: errorMessage ?? this.errorMessage,
      lastScan: lastScan ?? this.lastScan,
    );
  }
}

class ScannerStateNotifier extends StateNotifier<ScannerState> {
  final ScanHistoryRepository _historyRepository;
  final SettingsStateNotifier _settingsNotifier;
  final Uuid _uuid = const Uuid();

  ScannerStateNotifier(
    this._historyRepository,
    this._settingsNotifier,
  ) : super(const ScannerState());

  void setInitializing() {
    state = state.copyWith(status: ScannerStatus.initializing);
  }

  void setReady() {
    state = state.copyWith(status: ScannerStatus.ready);
  }

  void setError(String message) {
    state = state.copyWith(
      status: ScannerStatus.error,
      errorMessage: message,
    );
  }

  void toggleTorch() {
    state = state.copyWith(isTorchOn: !state.isTorchOn);
  }

  void switchCamera() {
    state = state.copyWith(
      cameraFacing: state.cameraFacing == CameraFacing.back
          ? CameraFacing.front
          : CameraFacing.back,
    );
  }

  Future<void> processBarcode(String rawValue) async {
    if (state.status == ScannerStatus.processing) return;

    state = state.copyWith(status: ScannerStatus.processing);

    // Parse the QR content
    final parsed = QRContentParser.parse(rawValue);

    // Create QR result
    final result = QRResult(
      id: _uuid.v4(),
      rawValue: parsed.value,
      typeIndex: parsed.type.index,
      scannedAt: DateTime.now(),
      metadata: parsed.metadata,
    );

    // Get display value based on type
    String? displayValue;
    switch (parsed.type) {
      case QRResultType.url:
        displayValue = parsed.value;
        break;
      case QRResultType.phone:
        displayValue = parsed.value;
        break;
      case QRResultType.email:
        displayValue = parsed.value.replaceAll('mailto:', '');
        break;
      case QRResultType.wifi:
        displayValue = 'Wi-Fi: ${parsed.metadata?['ssid']}';
        break;
      case QRResultType.text:
        displayValue = null;
        break;
    }

    final finalResult = result.copyWith(displayValue: displayValue);

    // Save to history
    await _historyRepository.addScan(finalResult);

    state = state.copyWith(
      status: ScannerStatus.ready,
      lastScan: finalResult,
    );
  }

  void clearLastScan() {
    state = state.copyWith(lastScan: null);
  }

  void reset() {
    state = ScannerState(
      isTorchOn: state.isTorchOn,
      cameraFacing: state.cameraFacing,
    );
  }
}

final _scanHistoryRepositoryProvider = Provider<ScanHistoryRepository>((ref) {
  return ScanHistoryRepository();
});

final _settingsProvider = Provider<SettingsStateNotifier>((ref) {
  return ref.watch(settingsProvider.notifier);
});

final scannerProvider =
    StateNotifierProvider<ScannerStateNotifier, ScannerState>((ref) {
  final historyRepository = ref.watch(_scanHistoryRepositoryProvider);
  final settingsNotifier = ref.watch(_settingsProvider);
  return ScannerStateNotifier(historyRepository, settingsNotifier);
});