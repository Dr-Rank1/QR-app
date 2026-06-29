import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/qr_result.dart';
import '../../domain/enums/qr_result_type.dart';
import '../../../history/data/repositories/scan_history_repository.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../../shared/utils/qr_parser.dart';
import '../../../../shared/utils/scan_feedback.dart';

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
  final bool hasCameraPermission;

  const ScannerState({
    this.status = ScannerStatus.initializing,
    this.isTorchOn = false,
    this.cameraFacing = CameraFacing.back,
    this.errorMessage,
    this.lastScan,
    this.hasCameraPermission = false,
  });

  ScannerState copyWith({
    ScannerStatus? status,
    bool? isTorchOn,
    CameraFacing? cameraFacing,
    String? errorMessage,
    QRResult? lastScan,
    bool? hasCameraPermission,
    bool clearLastScan = false,
  }) {
    return ScannerState(
      status: status ?? this.status,
      isTorchOn: isTorchOn ?? this.isTorchOn,
      cameraFacing: cameraFacing ?? this.cameraFacing,
      errorMessage: errorMessage,
      lastScan: clearLastScan ? null : (lastScan ?? this.lastScan),
      hasCameraPermission: hasCameraPermission ?? this.hasCameraPermission,
    );
  }
}

class ScannerStateNotifier extends StateNotifier<ScannerState> {
  final ScanHistoryRepository _historyRepository;
  final Uuid _uuid = const Uuid();

  ScannerStateNotifier(this._historyRepository) : super(const ScannerState());

  void setReady() {
    state = state.copyWith(status: ScannerStatus.ready);
  }

  void setError(String message) {
    state = state.copyWith(
      status: ScannerStatus.error,
      errorMessage: message,
    );
  }

  void setCameraPermission(bool granted) {
    state = state.copyWith(
      hasCameraPermission: granted,
      status: granted ? ScannerStatus.ready : ScannerStatus.error,
      errorMessage: granted ? null : 'Camera permission denied',
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

  Future<QRResult?> processBarcode(String rawValue, SettingsState settings) async {
    if (state.status == ScannerStatus.processing) return null;

    state = state.copyWith(status: ScannerStatus.processing);

    final parsed = QRContentParser.parse(rawValue);

    final result = QRResult(
      id: _uuid.v4(),
      rawValue: parsed.value,
      typeIndex: parsed.type.index,
      scannedAt: DateTime.now(),
      metadata: parsed.metadata,
    );

    String? displayValue;
    switch (parsed.type) {
      case QRResultType.url:
      case QRResultType.phone:
        displayValue = parsed.value;
      case QRResultType.email:
        displayValue = parsed.value.replaceAll('mailto:', '');
      case QRResultType.wifi:
        displayValue = 'Wi-Fi: ${parsed.metadata?['ssid'] ?? 'Network'}';
      case QRResultType.sms:
        displayValue = 'SMS: ${parsed.metadata?['number'] ?? parsed.value}';
      case QRResultType.geo:
        displayValue = parsed.metadata?['lat'] != null
            ? 'Location: ${parsed.metadata!['lat']}, ${parsed.metadata!['lng']}'
            : parsed.value;
      case QRResultType.vcard:
        displayValue = parsed.metadata?['name'] ?? 'Contact card';
      case QRResultType.calendar:
        displayValue = parsed.metadata?['title'] ?? 'Calendar event';
      case QRResultType.text:
        displayValue = null;
    }

    final finalResult = result.copyWith(displayValue: displayValue);

    await _historyRepository.addScan(finalResult);
    ScanFeedback.onScan(settings);

    state = state.copyWith(
      status: ScannerStatus.ready,
      lastScan: finalResult,
    );

    return finalResult;
  }

  void clearLastScan() {
    state = state.copyWith(clearLastScan: true);
  }

  void reset() {
    state = ScannerState(
      isTorchOn: state.isTorchOn,
      cameraFacing: state.cameraFacing,
      hasCameraPermission: state.hasCameraPermission,
      status: state.hasCameraPermission ? ScannerStatus.ready : ScannerStatus.error,
    );
  }
}

final scannerProvider =
    StateNotifierProvider<ScannerStateNotifier, ScannerState>((ref) {
  final historyRepository = ref.watch(scanHistoryRepositoryProvider);
  return ScannerStateNotifier(historyRepository);
});
