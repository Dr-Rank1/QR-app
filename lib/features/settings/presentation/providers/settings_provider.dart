import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsState {
  final bool vibrateOnScan;
  final bool soundOnScan;
  final bool keepScreenOn;
  final ThemeMode themeMode;

  const SettingsState({
    this.vibrateOnScan = true,
    this.soundOnScan = true,
    this.keepScreenOn = true,
    this.themeMode = ThemeMode.system,
  });

  bool get isDarkMode => themeMode == ThemeMode.dark;

  SettingsState copyWith({
    bool? vibrateOnScan,
    bool? soundOnScan,
    bool? keepScreenOn,
    ThemeMode? themeMode,
  }) {
    return SettingsState(
      vibrateOnScan: vibrateOnScan ?? this.vibrateOnScan,
      soundOnScan: soundOnScan ?? this.soundOnScan,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class SettingsStateNotifier extends StateNotifier<SettingsState> {
  final Box _box;

  SettingsStateNotifier(this._box) : super(_loadInitial(_box));

  static SettingsState _loadInitial(Box box) {
    final themeModeIndex = box.get('themeMode') as int?;
    ThemeMode themeMode;
    if (themeModeIndex != null &&
        themeModeIndex >= 0 &&
        themeModeIndex < ThemeMode.values.length) {
      themeMode = ThemeMode.values[themeModeIndex];
    } else {
      final legacyDark = box.get('darkMode', defaultValue: false) as bool;
      themeMode = legacyDark ? ThemeMode.dark : ThemeMode.system;
    }

    return SettingsState(
      vibrateOnScan: box.get('vibrateOnScan', defaultValue: true),
      soundOnScan: box.get('soundOnScan', defaultValue: true),
      keepScreenOn: box.get('keepScreenOn', defaultValue: true),
      themeMode: themeMode,
    );
  }

  void setThemeMode(ThemeMode mode) {
    _box.put('themeMode', mode.index);
    _box.put('darkMode', mode == ThemeMode.dark);
    state = state.copyWith(themeMode: mode);
  }

  void toggleLightDark(Brightness currentBrightness) {
    setThemeMode(
      currentBrightness == Brightness.dark
          ? ThemeMode.light
          : ThemeMode.dark,
    );
  }

  void setVibrateOnScan(bool value) {
    _box.put('vibrateOnScan', value);
    state = state.copyWith(vibrateOnScan: value);
  }

  void setSoundOnScan(bool value) {
    _box.put('soundOnScan', value);
    state = state.copyWith(soundOnScan: value);
  }

  void setKeepScreenOn(bool value) {
    _box.put('keepScreenOn', value);
    state = state.copyWith(keepScreenOn: value);
  }
}

final settingsBoxProvider = Provider<Box>((ref) {
  return Hive.box('settings');
});

final settingsProvider =
    StateNotifierProvider<SettingsStateNotifier, SettingsState>((ref) {
  final box = ref.watch(settingsBoxProvider);
  return SettingsStateNotifier(box);
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsProvider).themeMode;
});
