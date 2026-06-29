import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/generator/domain/services/qr_generation_service.dart';
import '../../features/settings/presentation/providers/settings_provider.dart';
import 'onboarding_storage.dart';
import 'share_service.dart';

final shareServiceProvider = Provider<ShareService>((ref) {
  return ShareService();
});

final qrGenerationServiceProvider = Provider<QrGenerationService>((ref) {
  return QrGenerationService();
});

final onboardingStorageProvider = Provider<OnboardingStorage>((ref) {
  final box = ref.watch(settingsBoxProvider);
  return OnboardingStorage(box);
});
