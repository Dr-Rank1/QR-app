// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qr_result.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QRResultAdapter extends TypeAdapter<QRResult> {
  @override
  final int typeId = 0;

  @override
  QRResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QRResult(
      id: fields[0] as String,
      rawValue: fields[1] as String,
      typeIndex: fields[2] as int,
      scannedAt: fields[3] as DateTime,
      displayValue: fields[4] as String?,
      metadata: (fields[5] as Map?)?.cast<String, String>(),
      isFavorite: fields[6] == null ? false : fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, QRResult obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.rawValue)
      ..writeByte(2)
      ..write(obj.typeIndex)
      ..writeByte(3)
      ..write(obj.scannedAt)
      ..writeByte(4)
      ..write(obj.displayValue)
      ..writeByte(5)
      ..write(obj.metadata)
      ..writeByte(6)
      ..write(obj.isFavorite);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QRResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
