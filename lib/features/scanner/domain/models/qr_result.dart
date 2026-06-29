import 'package:hive/hive.dart';

import '../enums/qr_result_type.dart';

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

  @HiveField(6, defaultValue: false)
  final bool isFavorite;

  QRResult({
    required this.id,
    required this.rawValue,
    required this.typeIndex,
    required this.scannedAt,
    this.displayValue,
    this.metadata,
    this.isFavorite = false,
  });

  QRResultType get type => QRResultType.values[typeIndex.clamp(0, QRResultType.values.length - 1)];

  String get formattedValue {
    if (displayValue != null && displayValue!.isNotEmpty) {
      return displayValue!;
    }
    return rawValue;
  }

  String get subtitle {
    switch (type) {
      case QRResultType.url:
      case QRResultType.phone:
      case QRResultType.email:
        return rawValue;
      case QRResultType.wifi:
        return metadata?['ssid'] ?? rawValue;
      case QRResultType.sms:
        return metadata?['number'] ?? rawValue;
      case QRResultType.geo:
        return metadata?['lat'] != null
            ? '${metadata!['lat']}, ${metadata!['lng']}'
            : rawValue;
      case QRResultType.vcard:
        return metadata?['name'] ?? 'Contact card';
      case QRResultType.calendar:
        return metadata?['title'] ?? 'Calendar event';
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
    bool? isFavorite,
  }) {
    return QRResult(
      id: id ?? this.id,
      rawValue: rawValue ?? this.rawValue,
      typeIndex: typeIndex ?? this.typeIndex,
      scannedAt: scannedAt ?? this.scannedAt,
      displayValue: displayValue ?? this.displayValue,
      metadata: metadata ?? this.metadata,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
