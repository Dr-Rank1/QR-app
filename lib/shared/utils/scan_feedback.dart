import 'package:flutter/services.dart';

import '../../features/settings/presentation/providers/settings_provider.dart';

class ScanFeedback {
  static void onScan(SettingsState settings) {
    if (settings.vibrateOnScan) {
      HapticFeedback.mediumImpact();
    }
    if (settings.soundOnScan) {
      SystemSound.play(SystemSoundType.click);
    }
  }
}
