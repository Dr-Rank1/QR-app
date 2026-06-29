import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../app/navigation_provider.dart';
import '../../app/router.dart';
import '../../features/generator/presentation/providers/generator_provider.dart';
import '../../features/history/presentation/providers/history_provider.dart';
import '../../features/scanner/presentation/providers/scanner_provider.dart';
import '../../features/settings/presentation/providers/settings_provider.dart';
import '../security/payload_sanitizer.dart';
import 'deep_link_service.dart';

/// Listens for platform deep links (`qrvault://` and HTTPS app links).
class DeepLinkListener extends ConsumerStatefulWidget {
  final Widget child;

  const DeepLinkListener({super.key, required this.child});

  @override
  ConsumerState<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends ConsumerState<DeepLinkListener> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<List<SharedMediaFile>>? _sharedMediaSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleUri(initialUri);
      }
      _linkSubscription = _appLinks.uriLinkStream.listen(_handleUri);

      final initialMedia = await ReceiveSharingIntent.instance.getInitialMedia();
      await _handleSharedMedia(initialMedia);
      _sharedMediaSubscription =
          ReceiveSharingIntent.instance.getMediaStream().listen(_handleSharedMedia);
    });
  }

  Future<void> _handleSharedMedia(List<SharedMediaFile> files) async {
    for (final file in files) {
      if (file.type == SharedMediaType.text ||
          file.mimeType == 'text/plain' ||
          file.type == SharedMediaType.url) {
        final payload = file.path.trim();
        if (payload.isNotEmpty) {
          await _handleAction(ScanDeepLink(payload));
        }
      }
    }
  }

  Future<void> _handleUri(Uri uri) async {
    final action = DeepLinkService.parse(uri);
    if (action != null) {
      await _handleAction(action);
    }
  }

  Future<void> _handleAction(DeepLinkAction action) async {
    if (!mounted) return;

    switch (action) {
      case OpenScannerDeepLink():
        ref.read(selectedTabIndexProvider.notifier).state = 0;
      case ScanDeepLink(:final payload):
        await _processInboundPayload(payload);
      case GenerateDeepLink(:final payload):
        ref.read(selectedTabIndexProvider.notifier).state = 1;
        ref.read(generatorProvider.notifier).setInboundPayload(payload);
    }
  }

  Future<void> _processInboundPayload(String payload) async {
    final sanitized = PayloadSanitizer.sanitizeRaw(payload);
    if (!sanitized.isAllowed) return;

    ref.read(selectedTabIndexProvider.notifier).state = 0;
    final settings = ref.read(settingsProvider);
    final result = await ref
        .read(scannerProvider.notifier)
        .processBarcode(sanitized.value, settings);
    if (result == null || !mounted) return;

    ref.invalidate(scanHistoryProvider);
    ref.read(routerProvider).push(AppRoutes.resultDetailPath(result.id));
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _sharedMediaSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
