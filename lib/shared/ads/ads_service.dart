import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:startapp_sdk/startapp.dart';

import 'ads_constants.dart';

/// Manages Start.io banner, interstitial, and rewarded placements.
class AdsService {
  final StartAppSdk _sdk = StartAppSdk();

  StartAppBannerAd? _bannerAd;
  String? _bannerTag;
  StartAppInterstitialAd? _interstitialAd;

  bool _initialized = false;
  DateTime? _lastInterstitialAt;
  int _resultExitCount = 0;

  bool get isInitialized => _initialized;
  StartAppBannerAd? get bannerAd => _bannerAd;

  Future<void> initialize() async {
    if (_initialized) return;
    if (kDebugMode) {
      await _sdk.setTestAdsEnabled(true);
    }
    _initialized = true;
    unawaited(_preloadInterstitial());
  }

  Future<void> ensureBanner({required String adTag}) async {
    if (_bannerAd != null && _bannerTag == adTag) return;
    _bannerAd?.dispose();
    _bannerAd = null;
    _bannerTag = adTag;

    try {
      _bannerAd = await _sdk.loadBannerAd(
        StartAppBannerType.BANNER,
        prefs: StartAppAdPreferences(adTag: adTag),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Start.io banner load failed ($adTag): $error');
      }
      _bannerAd = null;
    }
  }

  Future<void> clearBanner() async {
    _bannerAd?.dispose();
    _bannerAd = null;
    _bannerTag = null;
  }

  Future<void> _preloadInterstitial() async {
    if (_interstitialAd != null) return;
    try {
      _interstitialAd = await _sdk.loadInterstitialAd(
        prefs: const StartAppAdPreferences(
          adTag: AdsConstants.interstitialResultExit,
        ),
        onAdNotDisplayed: () {
          _interstitialAd?.dispose();
          _interstitialAd = null;
          unawaited(_preloadInterstitial());
        },
        onAdHidden: () {
          _interstitialAd?.dispose();
          _interstitialAd = null;
          unawaited(_preloadInterstitial());
        },
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Start.io interstitial preload failed: $error');
      }
      _interstitialAd = null;
    }
  }

  Future<void> maybeShowInterstitialOnResultExit() async {
    _resultExitCount++;
    if (_resultExitCount % AdsConstants.interstitialEveryNthResultExit != 0) {
      return;
    }

    final lastShown = _lastInterstitialAt;
    if (lastShown != null &&
        DateTime.now().difference(lastShown) <
            AdsConstants.interstitialCooldown) {
      return;
    }

    final ad = _interstitialAd;
    if (ad == null) {
      unawaited(_preloadInterstitial());
      return;
    }

    try {
      final shown = await ad.show();
      if (shown) {
        _lastInterstitialAt = DateTime.now();
        _interstitialAd = null;
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Start.io interstitial show failed: $error');
      }
      ad.dispose();
      _interstitialAd = null;
    } finally {
      unawaited(_preloadInterstitial());
    }
  }

  Future<bool> requestReward(RewardedFeature feature) async {
    final adTag = switch (feature) {
      RewardedFeature.svgExport => AdsConstants.rewardedSvgExport,
      RewardedFeature.logoEmbed => AdsConstants.rewardedLogoEmbed,
      RewardedFeature.urlShortener => AdsConstants.rewardedUrlShortener,
      RewardedFeature.premiumTemplate => AdsConstants.rewardedPremiumTemplate,
    };

    final completer = Completer<bool>();
    var rewarded = false;
    StartAppRewardedVideoAd? ad;

    try {
      ad = await _sdk.loadRewardedVideoAd(
        prefs: StartAppAdPreferences(adTag: adTag),
        onVideoCompleted: () {
          rewarded = true;
          if (!completer.isCompleted) completer.complete(true);
        },
        onAdNotDisplayed: () {
          if (!completer.isCompleted) completer.complete(false);
        },
        onAdHidden: () {
          if (!rewarded && !completer.isCompleted) completer.complete(false);
        },
      );

      final shown = await ad.show();
      if (!shown) {
        ad.dispose();
        return false;
      }

      return completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => rewarded,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Start.io rewarded failed ($adTag): $error');
      }
      return false;
    } finally {
      ad?.dispose();
    }
  }

  Future<void> dispose() async {
    _bannerAd?.dispose();
    _bannerAd = null;
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
