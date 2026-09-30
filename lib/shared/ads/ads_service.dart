import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

import 'ads_constants.dart';

/// Manages Unity Ads initialization, interstitial, and rewarded placements.
class AdsService {
  bool _initialized = false;
  bool _initializing = false;

  bool _interstitialLoaded = false;
  bool _interstitialLoading = false;

  bool _rewardedLoaded = false;
  bool _rewardedLoading = false;

  DateTime? _lastInterstitialAt;
  int _resultExitCount = 0;

  bool get isInitialized => _initialized;

  bool get isSupportedPlatform {
    if (kIsWeb) return false;
    return (Platform.isAndroid || Platform.isIOS) &&
        AdsConstants.gameId.isNotEmpty;
  }

  Future<void> initialize() async {
    if (_initialized || _initializing) return;

    if (!isSupportedPlatform) {
      _initialized = true;
      return;
    }

    _initializing = true;

    try {
      await UnityAds.init(
        gameId: AdsConstants.gameId,
        testMode: AdsConstants.testMode,
        onComplete: () {
          _initialized = true;
          _initializing = false;
          if (kDebugMode) {
            debugPrint('Unity Ads initialized successfully (live mode)');
          }
          unawaited(_preloadInterstitial());
          unawaited(_preloadRewarded());
        },
        onFailed: (error, errorMessage) {
          _initialized = false;
          _initializing = false;
          if (kDebugMode) {
            debugPrint('Unity Ads init failed: $error - $errorMessage');
          }
        },
      );
    } catch (error) {
      _initialized = false;
      _initializing = false;
      if (kDebugMode) {
        debugPrint('Unity Ads init exception: $error');
      }
    }
  }

  Future<void> _preloadInterstitial() async {
    if (!isSupportedPlatform || _interstitialLoaded || _interstitialLoading) {
      return;
    }

    final placementId = AdsConstants.interstitialPlacementId;
    if (placementId.isEmpty) return;

    _interstitialLoading = true;
    try {
      await UnityAds.load(
        placementId: placementId,
        onComplete: (id) {
          _interstitialLoaded = true;
          _interstitialLoading = false;
          if (kDebugMode) {
            debugPrint('Unity Ads interstitial loaded: $id');
          }
        },
        onFailed: (id, error, errorMessage) {
          _interstitialLoaded = false;
          _interstitialLoading = false;
          if (kDebugMode) {
            debugPrint('Unity Ads interstitial load failed: $errorMessage');
          }
        },
      );
    } catch (error) {
      _interstitialLoaded = false;
      _interstitialLoading = false;
      if (kDebugMode) {
        debugPrint('Unity Ads interstitial load exception: $error');
      }
    }
  }

  Future<void> _preloadRewarded() async {
    if (!isSupportedPlatform || _rewardedLoaded || _rewardedLoading) {
      return;
    }

    final placementId = AdsConstants.rewardedPlacementId;
    if (placementId.isEmpty) return;

    _rewardedLoading = true;
    try {
      await UnityAds.load(
        placementId: placementId,
        onComplete: (id) {
          _rewardedLoaded = true;
          _rewardedLoading = false;
          if (kDebugMode) {
            debugPrint('Unity Ads rewarded loaded: $id');
          }
        },
        onFailed: (id, error, errorMessage) {
          _rewardedLoaded = false;
          _rewardedLoading = false;
          if (kDebugMode) {
            debugPrint('Unity Ads rewarded load failed: $errorMessage');
          }
        },
      );
    } catch (error) {
      _rewardedLoaded = false;
      _rewardedLoading = false;
      if (kDebugMode) {
        debugPrint('Unity Ads rewarded load exception: $error');
      }
    }
  }

  Future<void> maybeShowInterstitialOnResultExit() async {
    if (!isSupportedPlatform) return;

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

    final placementId = AdsConstants.interstitialPlacementId;
    if (placementId.isEmpty) return;

    if (!_interstitialLoaded) {
      unawaited(_preloadInterstitial());
      return;
    }

    _interstitialLoaded = false;
    final completer = Completer<void>();

    try {
      await UnityAds.showVideoAd(
        placementId: placementId,
        onStart: (id) {
          _lastInterstitialAt = DateTime.now();
        },
        onComplete: (id) {
          if (!completer.isCompleted) completer.complete();
        },
        onSkipped: (id) {
          if (!completer.isCompleted) completer.complete();
        },
        onFailed: (id, error, errorMessage) {
          if (kDebugMode) {
            debugPrint('Unity Ads interstitial show failed: $errorMessage');
          }
          if (!completer.isCompleted) completer.complete();
        },
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Unity Ads interstitial show exception: $error');
      }
      if (!completer.isCompleted) completer.complete();
    } finally {
      unawaited(_preloadInterstitial());
    }
  }

  Future<bool> requestReward(RewardedFeature feature) async {
    if (!isSupportedPlatform) return false;

    final placementId = AdsConstants.rewardedPlacementId;
    if (placementId.isEmpty) return false;

    final completer = Completer<bool>();

    Future<void> show() async {
      _rewardedLoaded = false;
      try {
        await UnityAds.showVideoAd(
          placementId: placementId,
          onComplete: (id) {
            if (!completer.isCompleted) completer.complete(true);
          },
          onSkipped: (id) {
            if (!completer.isCompleted) completer.complete(false);
          },
          onFailed: (id, error, errorMessage) {
            if (kDebugMode) {
              debugPrint('Unity Ads rewarded show failed: $errorMessage');
            }
            if (!completer.isCompleted) completer.complete(false);
          },
        );
      } catch (error) {
        if (!completer.isCompleted) completer.complete(false);
      }
    }

    if (_rewardedLoaded) {
      unawaited(show());
    } else {
      try {
        await UnityAds.load(
          placementId: placementId,
          onComplete: (id) => unawaited(show()),
          onFailed: (id, error, errorMessage) {
            if (!completer.isCompleted) completer.complete(false);
          },
        );
      } catch (error) {
        if (!completer.isCompleted) completer.complete(false);
      }
    }

    try {
      final rewarded = await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => false,
      );
      unawaited(_preloadRewarded());
      return rewarded;
    } catch (_) {
      unawaited(_preloadRewarded());
      return false;
    }
  }

  Future<void> dispose() async {
    _interstitialLoaded = false;
    _interstitialLoading = false;
    _rewardedLoaded = false;
    _rewardedLoading = false;
  }
}
