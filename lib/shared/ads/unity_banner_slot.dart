import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

import 'ads_constants.dart';

/// Fixed-height Unity Ads banner slot for non-camera screens.
class UnityBannerSlot extends StatefulWidget {
  final String? placementId;
  final String? adTag;
  final bool visible;

  const UnityBannerSlot({
    super.key,
    this.placementId,
    this.adTag,
    this.visible = true,
  });

  @override
  State<UnityBannerSlot> createState() => _UnityBannerSlotState();
}

class _UnityBannerSlotState extends State<UnityBannerSlot> {
  bool _adLoaded = false;
  bool _adFailed = false;

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible || !_isSupportedPlatform || _adFailed) {
      return const SizedBox.shrink();
    }

    final placementId = widget.placementId ?? AdsConstants.bannerPlacementId;
    if (placementId.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: BannerSize.standard.height.toDouble(),
          child: Center(
            child: UnityBannerAd(
              placementId: placementId,
              size: BannerSize.standard,
              onLoad: (id) {
                if (mounted && !_adLoaded) {
                  setState(() => _adLoaded = true);
                }
              },
              onFailed: (id, error, errorMessage) {
                if (kDebugMode) {
                  debugPrint('Unity banner load failed ($id): $errorMessage');
                }
                if (mounted && !_adFailed) {
                  setState(() => _adFailed = true);
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Backward compatibility alias
typedef StartAppBannerSlot = UnityBannerSlot;
