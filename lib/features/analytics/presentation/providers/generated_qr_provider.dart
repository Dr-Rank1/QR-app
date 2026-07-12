import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../generator/domain/qr_payload_builder.dart';

/// A locally saved generated QR, ready for future scan-count analytics.
class GeneratedQr {
  final String id;
  final String title;
  final String payload;
  final GeneratorContentType type;
  final int foregroundColor;
  final int backgroundColor;
  final DateTime createdAt;
  /// Placeholder until backend scan tracking ships.
  final int scanCount;

  const GeneratedQr({
    required this.id,
    required this.title,
    required this.payload,
    required this.type,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.createdAt,
    this.scanCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'payload': payload,
        'typeIndex': type.index,
        'foreground': foregroundColor,
        'background': backgroundColor,
        'createdAt': createdAt.toIso8601String(),
        'scanCount': scanCount,
      };

  factory GeneratedQr.fromJson(Map<String, dynamic> json) {
    final typeIndex = (json['typeIndex'] as int? ?? 0)
        .clamp(0, GeneratorContentType.values.length - 1);
    return GeneratedQr(
      id: json['id'] as String? ?? const Uuid().v4(),
      title: (json['title'] as String? ?? 'QR').trim(),
      payload: json['payload'] as String? ?? '',
      type: GeneratorContentType.values[typeIndex],
      foregroundColor: json['foreground'] as int? ?? 0xFF000000,
      backgroundColor: json['background'] as int? ?? 0xFFFFFFFF,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      scanCount: json['scanCount'] as int? ?? 0,
    );
  }

  Color get fg => Color(foregroundColor);
  Color get bg => Color(backgroundColor);
}

class GeneratedQrRepository {
  static const _key = 'generated_qrs';
  static const _maxItems = 100;
  final Box _box;

  GeneratedQrRepository(this._box);

  List<GeneratedQr> loadAll() {
    final raw = _box.get(_key);
    if (raw is! String || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => GeneratedQr.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<GeneratedQr> items) async {
    final trimmed = items.take(_maxItems).toList();
    await _box.put(_key, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
  }

  Future<GeneratedQr> add({
    required String title,
    required String payload,
    required GeneratorContentType type,
    required Color foreground,
    required Color background,
  }) async {
    final items = loadAll();
    final item = GeneratedQr(
      id: const Uuid().v4(),
      title: title.trim().isEmpty ? type.label : title.trim(),
      payload: payload,
      type: type,
      foregroundColor: foreground.toARGB32(),
      backgroundColor: background.toARGB32(),
      createdAt: DateTime.now(),
    );
    items.insert(0, item);
    await _save(items);
    return item;
  }

  Future<void> delete(String id) async {
    final items = loadAll()..removeWhere((e) => e.id == id);
    await _save(items);
  }

  Future<void> clear() async => _save([]);
}

class GeneratedQrNotifier extends StateNotifier<List<GeneratedQr>> {
  final GeneratedQrRepository _repository;

  GeneratedQrNotifier(this._repository) : super(_repository.loadAll());

  Future<GeneratedQr> add({
    required String title,
    required String payload,
    required GeneratorContentType type,
    required Color foreground,
    required Color background,
  }) async {
    final item = await _repository.add(
      title: title,
      payload: payload,
      type: type,
      foreground: foreground,
      background: background,
    );
    state = _repository.loadAll();
    return item;
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    state = _repository.loadAll();
  }

  Future<void> clear() async {
    await _repository.clear();
    state = [];
  }
}

final generatedQrRepositoryProvider = Provider<GeneratedQrRepository>((ref) {
  return GeneratedQrRepository(ref.watch(settingsBoxProvider));
});

final generatedQrProvider =
    StateNotifierProvider<GeneratedQrNotifier, List<GeneratedQr>>((ref) {
  return GeneratedQrNotifier(ref.watch(generatedQrRepositoryProvider));
});
