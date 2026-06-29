import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../shared/security/payload_sanitizer.dart';import '../../domain/qr_payload_builder.dart';
import '../../../settings/presentation/providers/settings_provider.dart';

class GeneratorState {
  final GeneratorContentType type;
  final Map<String, String> fields;

  const GeneratorState({
    required this.type,
    required this.fields,
  });

  factory GeneratorState.initial() {
    const type = GeneratorContentType.url;
    return GeneratorState(
      type: type,
      fields: QRPayloadBuilder.defaultFields(type),
    );
  }

  String get payload => QRPayloadBuilder.build(type, fields);

  bool get isValid => QRPayloadBuilder.isValid(type, fields);

  Map<String, String?> get fieldErrors =>
      QRPayloadBuilder.fieldErrors(type, fields);

  bool get hasValidationErrors =>
      fieldErrors.values.any((error) => error != null);

  GeneratorState copyWith({
    GeneratorContentType? type,
    Map<String, String>? fields,
  }) {
    return GeneratorState(
      type: type ?? this.type,
      fields: fields ?? this.fields,
    );
  }
}

class GeneratorNotifier extends StateNotifier<GeneratorState> {
  final Box _box;

  GeneratorNotifier(this._box) : super(_loadFromBox(_box));

  static GeneratorState _loadFromBox(Box box) {
    final typeIndex = box.get(
      'generatorType',
      defaultValue: GeneratorContentType.url.index,
    ) as int;
    final safeIndex = typeIndex.clamp(0, GeneratorContentType.values.length - 1);
    final type = GeneratorContentType.values[safeIndex];

    final stored = box.get('generatorFields');
    if (stored is Map) {
      final fields = <String, String>{};
      for (final entry in stored.entries) {
        fields[entry.key.toString()] = entry.value.toString();
      }
      if (fields.isNotEmpty) {
        return GeneratorState(type: type, fields: fields);
      }
    }

    return GeneratorState(
      type: type,
      fields: QRPayloadBuilder.defaultFields(type),
    );
  }

  void _persist() {
    _box.put('generatorType', state.type.index);
    _box.put('generatorFields', Map<String, String>.from(state.fields));
  }

  void setType(GeneratorContentType type) {
    state = GeneratorState(
      type: type,
      fields: QRPayloadBuilder.defaultFields(type),
    );
    _persist();
  }

  void updateField(String key, String value) {
    final fields = Map<String, String>.from(state.fields)..[key] = value;
    state = state.copyWith(fields: fields);
    _persist();
  }

  void setInboundPayload(String rawPayload) {
    final sanitized = PayloadSanitizer.sanitizeRaw(rawPayload);
    if (!sanitized.isAllowed) return;

    state = GeneratorState(
      type: GeneratorContentType.text,
      fields: {'message': sanitized.value},
    );
    _persist();
  }
}

final generatorProvider =
    StateNotifierProvider<GeneratorNotifier, GeneratorState>((ref) {
  final box = ref.watch(settingsBoxProvider);
  return GeneratorNotifier(box);
});
