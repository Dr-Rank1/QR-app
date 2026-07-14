import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ads_service.dart';

final adsServiceProvider = Provider<AdsService>((ref) {
  final service = AdsService();
  ref.onDispose(service.dispose);
  return service;
});
