import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../settings/presentation/providers/settings_provider.dart';
import '../../domain/qr_payload_builder.dart';

/// Named color + content-type combo for regenerating branded QRs quickly.
class QrPreset {
  final String id;
  final String name;
  final GeneratorContentType type;
  final Color foregroundColor;
  final Color backgroundColor;
  final bool embedLogo;
  final DateTime createdAt;

  const QrPreset({
    required this.id,
    required this.name,
    required this.type,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.embedLogo,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'typeIndex': type.index,
        'foreground': foregroundColor.toARGB32(),
        'background': backgroundColor.toARGB32(),
        'embedLogo': embedLogo,
        'createdAt': createdAt.toIso8601String(),
      };

  factory QrPreset.fromJson(Map<String, dynamic> json) {
    final typeIndex = (json['typeIndex'] as int? ?? 0)
        .clamp(0, GeneratorContentType.values.length - 1);
    return QrPreset(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: (json['name'] as String? ?? 'Preset').trim(),
      type: GeneratorContentType.values[typeIndex],
      foregroundColor: Color(json['foreground'] as int? ?? 0xFF000000),
      backgroundColor: Color(json['background'] as int? ?? 0xFFFFFFFF),
      embedLogo: json['embedLogo'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class QrPresetRepository {
  static const _key = 'qr_presets';
  final Box _box;

  QrPresetRepository(this._box);

  List<QrPreset> loadAll() {
    final raw = _box.get(_key);
    if (raw is! String || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => QrPreset.fromJson(Map<String, dynamic>.from(item)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<QrPreset> presets) async {
    final encoded = jsonEncode(presets.map((p) => p.toJson()).toList());
    await _box.put(_key, encoded);
  }

  Future<QrPreset> add({
    required String name,
    required GeneratorContentType type,
    required Color foregroundColor,
    required Color backgroundColor,
    required bool embedLogo,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Preset name is required');
    }

    final presets = loadAll();
    final preset = QrPreset(
      id: const Uuid().v4(),
      name: trimmed,
      type: type,
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
      embedLogo: embedLogo,
      createdAt: DateTime.now(),
    );
    presets.insert(0, preset);
    await saveAll(presets);
    return preset;
  }

  Future<void> delete(String id) async {
    final presets = loadAll()..removeWhere((p) => p.id == id);
    await saveAll(presets);
  }
}

class QrPresetNotifier extends StateNotifier<List<QrPreset>> {
  final QrPresetRepository _repository;

  QrPresetNotifier(this._repository) : super(_repository.loadAll());

  Future<QrPreset> savePreset({
    required String name,
    required GeneratorContentType type,
    required Color foregroundColor,
    required Color backgroundColor,
    required bool embedLogo,
  }) async {
    final preset = await _repository.add(
      name: name,
      type: type,
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
      embedLogo: embedLogo,
    );
    state = _repository.loadAll();
    return preset;
  }

  Future<void> deletePreset(String id) async {
    await _repository.delete(id);
    state = _repository.loadAll();
  }
}

final qrPresetRepositoryProvider = Provider<QrPresetRepository>((ref) {
  final box = ref.watch(settingsBoxProvider);
  return QrPresetRepository(box);
});

final qrPresetProvider =
    StateNotifierProvider<QrPresetNotifier, List<QrPreset>>((ref) {
  return QrPresetNotifier(ref.watch(qrPresetRepositoryProvider));
});
