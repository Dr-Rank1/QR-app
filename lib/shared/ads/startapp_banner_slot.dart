import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:startapp_sdk/startapp.dart';

import 'ads_provider.dart';

/// Fixed-height banner slot for non-camera screens.
class StartAppBannerSlot extends ConsumerStatefulWidget {
  final String adTag;
  final bool visible;

  const StartAppBannerSlot({
    super.key,
    required this.adTag,
    this.visible = true,
  });

  @override
  ConsumerState<StartAppBannerSlot> createState() => _StartAppBannerSlotState();
}

class _StartAppBannerSlotState extends ConsumerState<StartAppBannerSlot> {
  StartAppBannerAd? _bannerAd;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.visible) {
      _loadBanner();
    }
  }

  @override
  void didUpdateWidget(StartAppBannerSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.visible) {
      _bannerAd = null;
      return;
    }
    if (oldWidget.adTag != widget.adTag || oldWidget.visible != widget.visible) {
      _loadBanner();
    }
  }

  Future<void> _loadBanner() async {
    if (!widget.visible || _loading) return;
    _loading = true;
    final ads = ref.read(adsServiceProvider);
    await ads.ensureBanner(adTag: widget.adTag);
    if (!mounted) return;
    setState(() {
      _bannerAd = ads.bannerAd;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: Center(child: StartAppBanner(_bannerAd!)),
        ),
      ),
    );
  }
}
