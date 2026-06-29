import 'package:flutter/foundation.dart';

import 'sensitive_metadata.dart';

/// Console logging that never prints Wi-Fi passwords or other secrets.
abstract final class SecureLogger {
  static void log(String message) {
    if (kReleaseMode) return;
    debugPrint(SensitiveMetadata.redactMessage(message));
  }

  static void logError(Object error, [StackTrace? stackTrace]) {
    final message = StringBuffer('Error: ${SensitiveMetadata.redactMessage('$error')}');
    if (stackTrace != null) {
      message
        ..writeln()
        ..write(SensitiveMetadata.redactMessage(stackTrace.toString()));
    }
    if (kReleaseMode) return;
    debugPrint(message.toString());
  }
}
