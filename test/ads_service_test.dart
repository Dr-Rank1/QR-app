import 'package:flutter_test/flutter_test.dart';
import 'package:qr_vault/shared/ads/ads_constants.dart';
import 'package:qr_vault/shared/ads/ads_service.dart';

void main() {
  group('AdsConstants Unity Ads configuration', () {
    test('game IDs match Unity Dashboard configuration', () {
      expect(AdsConstants.androidGameId, equals('6197945'));
      expect(AdsConstants.iosGameId, equals('6197944'));
    });

    test('ads are configured for live production mode (not test mode)', () {
      expect(AdsConstants.testMode, isFalse);
    });

    test('cooldown and frequency thresholds are properly set', () {
      expect(AdsConstants.interstitialCooldown, equals(const Duration(minutes: 3)));
      expect(AdsConstants.interstitialEveryNthResultExit, equals(3));
    });

    test('premium template names set is populated', () {
      expect(AdsConstants.premiumTemplateNames, contains('Ocean'));
      expect(AdsConstants.premiumTemplateNames, contains('Bloom'));
    });
  });

  group('AdsService initialization & lifecycle', () {
    test('instantiates and handles lifecycle safely', () async {
      final service = AdsService();
      expect(service.isInitialized, isFalse);

      await service.initialize();
      // On non-mobile/test environment, gracefully completes
      expect(service.isInitialized, isTrue);

      // Verify safe calls that should not throw
      await service.maybeShowInterstitialOnResultExit();
      final rewardResult = await service.requestReward(RewardedFeature.svgExport);
      expect(rewardResult, isFalse); // Non-mobile / no ad server returns false cleanly

      await service.dispose();
    });
  });
}
