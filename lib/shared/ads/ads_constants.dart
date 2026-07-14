/// Start.io configuration and placement tags.
class AdsConstants {
  static const String appId = '206402880';

  static const Duration interstitialCooldown = Duration(minutes: 3);
  static const int interstitialEveryNthResultExit = 3;

  static const String bannerGenerator = 'generator_tab';
  static const String bannerHistory = 'history_tab';
  static const String bannerMyQrs = 'myqrs_tab';
  static const String bannerSettings = 'settings';

  static const String rewardedSvgExport = 'reward_svg_export';
  static const String rewardedLogoEmbed = 'reward_logo_embed';
  static const String rewardedUrlShortener = 'reward_url_shortener';
  static const String rewardedPremiumTemplate = 'reward_premium_template';

  static const String interstitialResultExit = 'interstitial_result_exit';

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
