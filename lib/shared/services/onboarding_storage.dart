import 'package:hive_flutter/hive_flutter.dart';

/// Local-only onboarding flag stored in the Hive settings box.
class OnboardingStorage {
  static const _key = 'onboarding_completed';

  final Box _box;

  OnboardingStorage(this._box);

  bool get isCompleted =>
      _box.get(_key, defaultValue: false) as bool;

  Future<void> markCompleted() async {
    await _box.put(_key, true);
  }
}
