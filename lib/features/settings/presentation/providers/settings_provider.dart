import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsState {
  final bool darkMode;
  final bool vibrateOnScan;
  final bool soundOnScan;
  final bool keepScreenOn;
  final ThemeMode themeMode;

  const SettingsState({
    this.darkMode = false,
    this.vibrateOnScan = true,
    this.soundOnScan = true,
    this.keepScreenOn = true,
    this.themeMode = ThemeMode.system,
  });

  SettingsState copyWith({
    bool? darkMode,
    bool? vibrateOnScan,
    bool? soundOnScan,
    bool? keepScreenOn,
    ThemeMode? themeMode,
  }) {
    return SettingsState(
      darkMode: darkMode ?? this.darkMode,
      vibrateOnScan: vibrateOnScan ?? this.vibrateOnScan,
      soundOnScan: soundOnScan ?? this.soundOnScan,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class SettingsStateNotifier extends StateNotifier<SettingsState> {
  final Box _box;

  SettingsStateNotifier(this._box)
      : super(SettingsState(
          darkMode: _box.get('darkMode', defaultValue: false),
          vibrateOnScan: _box.get('vibrateOnScan', defaultValue: true),
          soundOnScan: _box.get('soundOnScan', defaultValue: true),
          keepScreenOn: _box.get('keepScreenOn', defaultValue: true),
          themeMode: ThemeMode.values[_box.get('themeMode', defaultValue: 0)],
        ));

  void setDarkMode(bool value) {
    _box.put('darkMode', value);
    state = state.copyWith(
      darkMode: value,
      themeMode: value ? ThemeMode.dark : ThemeMode.light,
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

  void setThemeMode(ThemeMode mode) {
    _box.put('themeMode', mode.index);
    state = state.copyWith(themeMode: mode);
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
