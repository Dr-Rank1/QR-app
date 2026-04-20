import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../features/monetization/presentation/providers/purchases_provider.dart';

class InterstitialAdManager {
  static final InterstitialAdManager _instance = InterstitialAdManager._internal();
  factory InterstitialAdManager() => _instance;
  InterstitialAdManager._internal();

  static const String _adUnitId = 'ca-app-pub-9418386170210711/8796632272';
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  int _scanCount = 0;

  void initialize() {
    _loadInterstitialAd();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Interstitial ad failed to load: ${error.name}');
          ad.dispose();
        },
      ),
    );
  }

  void incrementAndShow() {
    final isPremium = _checkPremium();
    if (isPremium) return;

    _scanCount++;

    if (_scanCount % 5 == 0 && _isAdLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          _loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('Interstitial ad failed to show: ${error.name}');
          ad.dispose();
          _loadInterstitialAd();
        },
      );

      _interstitialAd!.show();
      _isAdLoaded = false;
      _scanCount = 0;
    }
  }

  bool _checkPremium() {
    // This is a simplified check - in production use proper Riverpod
    return false;
  }

  void dispose() {
    _interstitialAd?.dispose();
  }
}

// Global singleton instance
final interstitialAdManager = InterstitialAdManager();