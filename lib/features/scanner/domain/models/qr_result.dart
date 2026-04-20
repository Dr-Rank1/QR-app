import 'package:hive/hive.dart';

import 'enums/qr_result_type.dart';

part 'qr_result.g.dart';

@HiveType(typeId: 0)
class QRResult extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String rawValue;

  @HiveField(2)
  final int typeIndex;

  @HiveField(3)
  final DateTime scannedAt;

  @HiveField(4)
  final String? displayValue;

  @HiveField(5)
  final Map<String, String>? metadata;

  QRResult({
    required this.id,
    required this.rawValue,
    required this.typeIndex,
    required this.scannedAt,
    this.displayValue,
    this.metadata,
  });

  QRResultType get type => QRResultType.values[typeIndex];

  String get formattedValue {
    if (displayValue != null && displayValue!.isNotEmpty) {
      return displayValue!;
    }
    return rawValue;
  }

  String get subtitle {
    switch (type) {
      case QRResultType.url:
        return rawValue;
      case QRResultType.phone:
        return rawValue;
      case QRResultType.email:
        return rawValue;
      case QRResultType.wifi:
        return metadata?['ssid'] ?? rawValue;
      case QRResultType.text:
        return rawValue.length > 50
            ? '${rawValue.substring(0, 50)}...'
            : rawValue;
    }
  }

  QRResult copyWith({
    String? id,
    String? rawValue,
    int? typeIndex,
    DateTime? scannedAt,
    String? displayValue,
    Map<String, String>? metadata,
  }) {
    return QRResult(
      id: id ?? this.id,
      rawValue: rawValue ?? this.rawValue,
      typeIndex: typeIndex ?? this.typeIndex,
      scannedAt: scannedAt ?? this.scannedAt,
      displayValue: displayValue ?? this.displayValue,
      metadata: metadata ?? this.metadata,
    );
  }
}