import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ads_provider.dart';

/// Initializes Start.io once when the app boots.
class AdsBootstrap extends ConsumerStatefulWidget {
  final Widget child;

  const AdsBootstrap({super.key, required this.child});

  @override
  ConsumerState<AdsBootstrap> createState() => _AdsBootstrapState();
}

class _AdsBootstrapState extends ConsumerState<AdsBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adsServiceProvider).initialize();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
