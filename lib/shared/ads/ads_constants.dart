import 'dart:io';

import 'package:flutter/foundation.dart';

/// Unity Ads configuration and placement IDs.
class AdsConstants {
  static const String androidGameId = '6197945';
  static const String iosGameId = '6197944';

  /// Live production ads as requested (live, not testing).
  static const bool testMode = false;

  static String get gameId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) return androidGameId;
    if (Platform.isIOS) return iosGameId;
    return '';
  }

  static String get bannerPlacementId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) return 'Banner_Android';
    if (Platform.isIOS) return 'Banner_iOS';
    return '';
  }

  static String get interstitialPlacementId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) return 'Interstitial_Android';
    if (Platform.isIOS) return 'Interstitial_iOS';
    return '';
  }

  static String get rewardedPlacementId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) return 'Rewarded_Android';
    if (Platform.isIOS) return 'Rewarded_iOS';
    return '';
  }

  static const Duration interstitialCooldown = Duration(minutes: 3);
  static const int interstitialEveryNthResultExit = 3;

  // Placement getters and aliases
  static String get bannerPlacement => bannerPlacementId;
  static String get interstitialPlacement => interstitialPlacementId;
  static String get rewardedPlacement => rewardedPlacementId;

  static String get bannerGenerator => bannerPlacementId;
  static String get bannerHistory => bannerPlacementId;
  static String get bannerMyQrs => bannerPlacementId;
  static String get bannerSettings => bannerPlacementId;
  static String get interstitialResultExit => interstitialPlacementId;
  static String get rewardedSvgExport => rewardedPlacementId;
  static String get rewardedLogoEmbed => rewardedPlacementId;
  static String get rewardedUrlShortener => rewardedPlacementId;
  static String get rewardedPremiumTemplate => rewardedPlacementId;

  static const premiumTemplateNames = <String>{
    'Ocean',
    'Bloom',
    'Forest',
    'Solar',
  };
}

enum RewardedFeature {
  svgExport,
  logoEmbed,
  urlShortener,
  premiumTemplate,
}
