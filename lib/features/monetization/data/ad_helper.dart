import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  // Banner Ad Unit ID - use test IDs in debug, real IDs in release
  static String get bannerAdUnitId {
    if (kDebugMode) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Test banner
    }
    return 'ca-app-pub-xxxxxxxx/yyyyyyyyyyyy'; // Replace with real ID
  }

  // Interstitial Ad Unit ID
  static String get interstitialAdUnitId {
    if (kDebugMode) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Test interstitial
    }
    return 'ca-app-pub-xxxxxxxx/yyyyyyyyyyyy'; // Replace with real ID
  }

  // Initialize AdMob
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  // Banner ad sizes
  static const AdSize bannerSize = AdSize.banner; // 320x50
  static const AdSize mediumBannerSize = AdSize.mediumRectangle; // 300x250

  // Create banner request
  static AdRequest get bannerRequest => const AdRequest(
    keywords: ['qr', 'scanner', 'barcode'],
    contentUrl: 'https://example.com',
    nonPersonalizedAds: false,
  );

  // Create interstitial request
  static AdRequest get interstitialRequest => const AdRequest(
    keywords: ['qr', 'scanner', 'barcode'],
    contentUrl: 'https://example.com',
    nonPersonalizedAds: false,
  );
}

// Ad state management
class AdState {
  final bool isBannerLoaded;
  final bool isInterstitialReady;
  final String? bannerError;
  final String? interstitialError;

  const AdState({
    this.isBannerLoaded = false,
    this.isInterstitialReady = false,
    this.bannerError,
    this.interstitialError,
  });

  AdState copyWith({
    bool? isBannerLoaded,
    bool? isInterstitialReady,
    String? bannerError,
    String? interstitialError,
  }) {
    return AdState(
      isBannerLoaded: isBannerLoaded ?? this.isBannerLoaded,
      isInterstitialReady: isInterstitialReady ?? this.isInterstitialReady,
      bannerError: bannerError,
      interstitialError: interstitialError,
    );
  }
}