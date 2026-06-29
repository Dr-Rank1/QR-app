import 'package:hive_flutter/hive_flutter.dart';

import '../security/sensitive_metadata.dart';

class CrashLogEntry {
  final String id;
  final DateTime timestamp;
  final String message;
  final String stackTrace;
  final String? context;

  const CrashLogEntry({
    required this.id,
    required this.timestamp,
    required this.message,
    required this.stackTrace,
    this.context,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'message': message,
        'stackTrace': stackTrace,
        'context': context,
      };

  factory CrashLogEntry.fromMap(Map<dynamic, dynamic> map) {
    return CrashLogEntry(
      id: map['id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      message: map['message'] as String,
      stackTrace: map['stackTrace'] as String,
      context: map['context'] as String?,
    );
  }

  String toExportBlock() {
    final buffer = StringBuffer()
      ..writeln('--- Crash ${timestamp.toIso8601String()} ---')
      ..writeln('Context: ${context ?? 'unknown'}')
      ..writeln('Message: $message')
      ..writeln(stackTrace)
      ..writeln();
    return buffer.toString();
  }
}

/// Local-only crash capture for closed testing. No backend or analytics.
class CrashReporter {
  static const _boxName = 'crash_logs';
  static const _maxEntries = 50;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    _initialized = true;
  }

  static Box get _box => Hive.box(_boxName);

  static Future<void> recordError(
    Object error,
    StackTrace stack, {
    String? context,
  }) async {
    await initialize();

    final message = SensitiveMetadata.redactMessage('$error');
    final trace = SensitiveMetadata.redactMessage(stack.toString());

    final entry = CrashLogEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      message: message,
      stackTrace: trace,
      context: context,
    );

    await _box.put(entry.id, entry.toMap());
    await _trimOldEntries();
  }

  static Future<void> _trimOldEntries() async {
    final keys = _box.keys.cast<String>().toList()
      ..sort((a, b) => b.compareTo(a));
    if (keys.length <= _maxEntries) return;
    for (final key in keys.sublist(_maxEntries)) {
      await _box.delete(key);
    }
  }

  static List<CrashLogEntry> getLogs() {
    if (!_initialized && !Hive.isBoxOpen(_boxName)) return [];
    return _box.values
        .map((value) => CrashLogEntry.fromMap(Map<dynamic, dynamic>.from(value as Map)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  static Future<void> clearLogs() async {
    await initialize();
    await _box.clear();
  }

  static String exportLogs() {
    final logs = getLogs();
    if (logs.isEmpty) return 'No crash logs recorded.';
    return logs.map((e) => e.toExportBlock()).join();
  }
}
