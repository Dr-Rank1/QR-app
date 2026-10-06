import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';

import '../../../../app/app_spacing.dart';
import '../../../../app/theme.dart';
import '../../../../shared/ads/ads_constants.dart';
import '../../../../shared/ads/ads_provider.dart';
import '../../../../shared/ads/ads_reward_dialog.dart';
import '../../../../shared/services/service_providers.dart';
import '../../../../shared/utils/app_haptics.dart';
import '../../../../shared/utils/permission_handler.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../analytics/presentation/providers/generated_qr_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../domain/qr_payload_builder.dart';
import '../../domain/services/qr_generation_service.dart';
import '../providers/generator_provider.dart';
import '../providers/preset_provider.dart';

class GeneratorScreen extends ConsumerStatefulWidget {
  const GeneratorScreen({super.key});

  @override
  ConsumerState<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends ConsumerState<GeneratorScreen> {
  final _fieldControllers = <String, TextEditingController>{};
  final double _qrSize = 200;
  bool _embedLogo = false;
  Uint8List? _logoBytes;
  final bool _roundedModules = false;
  bool _isShortening = false;
  bool _logoFeatureUnlocked = false;
  bool _premiumTemplatesUnlocked = false;
  Color _foregroundColor = Colors.black;
  Color _backgroundColor = Colors.white;

  QrGenerationService get _qrService => ref.read(qrGenerationServiceProvider);

  QrRenderOptions get _renderOptions => QrRenderOptions(
        size: _qrSize,
        embedLogo: _embedLogo,
        logoBytes: _logoBytes,
        roundedModules: _roundedModules,
        foregroundColor: _foregroundColor,
        backgroundColor: _backgroundColor,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncFieldControllers(ref.read(generatorProvider));
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncFieldControllers(GeneratorState state) {
    for (final entry in state.fields.entries) {
      _fieldControllers.putIfAbsent(
        entry.key,
        () => TextEditingController(text: entry.value),
      );
      final controller = _fieldControllers[entry.key]!;
      if (controller.text != entry.value) {
        controller.text = entry.value;
      }
    }
  }

  Future<void> _persistGenerated(String payload) async {
    final state = ref.read(generatorProvider);
    final title = switch (state.type) {
      GeneratorContentType.url => state.fields['url'] ?? 'URL',
      GeneratorContentType.text => state.fields['message'] ?? 'Text',
      GeneratorContentType.wifi => state.fields['ssid'] ?? 'Wi-Fi',
      GeneratorContentType.phone => state.fields['number'] ?? 'Phone',
      GeneratorContentType.email => state.fields['to'] ?? 'Email',
      GeneratorContentType.sms => state.fields['number'] ?? 'SMS',
      GeneratorContentType.contact => state.fields['name'] ?? 'Contact',
      GeneratorContentType.location => state.fields['coords'] ?? 'Location',
      GeneratorContentType.event => state.fields['title'] ?? 'Event',
    };
    await ref.read(generatedQrProvider.notifier).add(
          title: title,
          payload: payload,
          type: state.type,
          foreground: _foregroundColor,
          background: _backgroundColor,
        );
  }

  Future<bool> _ensureLogoUnlocked() async {
    if (_logoFeatureUnlocked) return true;
    final unlocked = await requestRewardedFeature(
      context,
      ref,
      feature: RewardedFeature.logoEmbed,
      title: 'Unlock logo overlay',
      message:
          'Watch a short video to embed a logo in the center of your QR code.',
    );
    if (unlocked && mounted) {
      setState(() => _logoFeatureUnlocked = true);
    }
    return unlocked;
  }

  Future<bool> _ensurePremiumTemplatesUnlocked() async {
    if (_premiumTemplatesUnlocked) return true;
    final unlocked = await requestRewardedFeature(
      context,
      ref,
      feature: RewardedFeature.premiumTemplate,
      title: 'Unlock color templates',
      message:
          'Watch a short video to unlock Ocean, Bloom, Forest, and Solar templates.',
    );
    if (unlocked && mounted) {
      setState(() => _premiumTemplatesUnlocked = true);
    }
    return unlocked;
  }

  Future<void> _shareSvgWithReward(String payload) async {
    if (payload.trim().isEmpty) return;
    final unlocked = await requestRewardedFeature(
      context,
      ref,
      feature: RewardedFeature.svgExport,
      title: 'Export SVG',
      message: 'Watch a short video to export your QR code as SVG.',
    );
    if (!unlocked || !mounted) return;
    await _shareSvg(payload);
  }

  Future<void> _shareSvg(String payload) async {
    if (payload.trim().isEmpty) return;
    try {
      final svg = ref.read(qrSvgExporterProvider).buildSvg(
            payload,
            options: _renderOptions,
          );
      await ref.read(shareServiceProvider).shareSvg(svg);
      await AppHaptics.success();
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Could not export SVG');
      }
    }
  }

  Future<void> _shareImage(String payload) async {
    if (payload.trim().isEmpty) return;

    try {
      final shareService = ref.read(shareServiceProvider);
      final pngBytes = await _qrService.renderQrPng(
        payload,
        options: _renderOptions,
      );
      await shareService.shareQrImage(pngBytes);
      await _persistGenerated(payload);
      await AppHaptics.success();
      if (mounted) {
        unawaited(
          ref
              .read(adsServiceProvider)
              .maybeShowInterstitialOnGeneratorAction(),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Could not share image');
      }
    }
  }

  Future<void> _pickLogo() async {
    if (!await _ensureLogoUnlocked()) return;

    final permission = await AppPermissionHandler.ensureGalleryPermission();
    if (!mounted) return;
    if (permission != PermissionRequestResult.granted) {
      await showPermissionDeniedSheet(
        context,
        type: AppPermissionType.gallery,
        permanentlyDenied:
            permission == PermissionRequestResult.permanentlyDenied,
      );
      return;
    }

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 90,
    );
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _embedLogo = true;
      _logoBytes = bytes;
    });
    await AppHaptics.light();
    if (mounted) {
      AppSnackBar.showSuccess(context, 'Logo added to QR center');
    }
  }

  void _clearLogo() {
    setState(() {
      _logoBytes = null;
      _embedLogo = false;
    });
  }

  Future<void> _savePreset(GeneratorContentType type) async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Save preset'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Preset name',
              hintText: 'Brand blue link',
            ),
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(nameController.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    if (name == null || !mounted) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      AppSnackBar.showInfo(context, 'Enter a name for this preset');
      return;
    }

    try {
      await ref.read(qrPresetProvider.notifier).savePreset(
            name: trimmed,
            type: type,
            foregroundColor: _foregroundColor,
            backgroundColor: _backgroundColor,
            embedLogo: _embedLogo,
          );
      await AppHaptics.success();
      if (mounted) {
        AppSnackBar.showSuccess(context, 'Preset saved');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Could not save preset');
      }
    }
  }

  void _applyPreset(QrPreset preset) {
    ref.read(generatorProvider.notifier).setType(preset.type);
    setState(() {
      _foregroundColor = preset.foregroundColor;
      _backgroundColor = preset.backgroundColor;
      _embedLogo = preset.embedLogo;
      if (!_embedLogo) _logoBytes = null;
    });
    AppHaptics.light();
    AppSnackBar.showSuccess(context, 'Applied “${preset.name}”');
  }

  Future<void> _shortenUrl() async {
    final state = ref.read(generatorProvider);
    if (state.type != GeneratorContentType.url) return;

    final url = state.fields['url']?.trim() ?? '';
    if (url.isEmpty || url == 'https://') {
      AppSnackBar.showInfo(context, 'Enter a URL to shorten');
      return;
    }

    final unlocked = await requestRewardedFeature(
      context,
      ref,
      feature: RewardedFeature.urlShortener,
      title: 'Shorten URL',
      message: 'Watch a short video to shorten this link before encoding.',
    );
    if (!unlocked || !mounted) return;

    setState(() => _isShortening = true);
    try {
      final short = await ref.read(urlShortenerServiceProvider).shorten(url);
      if (!mounted) return;
      ref.read(generatorProvider.notifier).updateField('url', short);
      final controller = _fieldControllers['url'];
      if (controller != null) controller.text = short;
      await AppHaptics.success();
      if (mounted) {
        AppSnackBar.showSuccess(context, 'URL shortened for a cleaner QR');
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Could not shorten URL. Check connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isShortening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(generatorProvider);
    final notifier = ref.read(generatorProvider.notifier);
    final presets = ref.watch(qrPresetProvider);
    final payload = state.payload;
    final hasQrCode = state.isValid && !state.hasValidationErrors;

    ref.listen(generatorProvider.select((s) => s.type), (prev, next) {
      if (prev != next) {
        for (final c in _fieldControllers.values) {
          c.dispose();
        }
        _fieldControllers.clear();
        _syncFieldControllers(ref.read(generatorProvider));
      }
    });

    ref.listen(generatorProvider.select((s) => s.isValid), (prev, next) {
      if (prev == false && next == true && !state.hasValidationErrors) {
        AppHaptics.light();
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          children: [
            _QrPreviewCard(
              selectedType: state.type,
              hasQrCode: hasQrCode,
              screenshotChild: Screenshot(
                controller: _qrService.screenshotController,
                child: _AsyncQrPreview(
                  data: payload,
                  hasValidationErrors: state.hasValidationErrors,
                  foregroundColor: _foregroundColor,
                  backgroundColor: _backgroundColor,
                  options: _renderOptions,
                ),
              ),
              onShare: hasQrCode ? () => _shareImage(payload) : null,
              onExportSvg: hasQrCode ? () => _shareSvgWithReward(payload) : null,
              onSave: hasQrCode
                  ? () async {
                      await _persistGenerated(payload);
                      await AppHaptics.success();
                      if (!context.mounted) return;
                      AppSnackBar.showSuccess(context, 'Saved to My QRs');
                      unawaited(
                        ref.read(adsServiceProvider).maybeShowInterstitialOnGeneratorAction(),
                      );
                    }
                  : null,
            ),
            const SizedBox(height: 32),
            const _SectionTitle('DATA TYPE'),
            const SizedBox(height: 12),
            _TypeSelector(selected: state.type, onSelected: notifier.setType),
            const SizedBox(height: 32),
            const _SectionTitle('CONTENT'),
            const SizedBox(height: 12),
            _ContentFormCard(
              type: state.type,
              fields: state.fields,
              fieldErrors: state.fieldErrors,
              controllers: _fieldControllers,
              onChanged: notifier.updateField,
              isShortening: _isShortening,
              onShorten: _shortenUrl,
              showShortener: state.type == GeneratorContentType.url && ref.watch(settingsProvider).urlShortenerEnabled,
            ),
            const SizedBox(height: 32),
            const _SectionTitle('CUSTOMIZE APPEARANCE'),
            const SizedBox(height: 12),
            _DesignCard(
              foregroundColor: _foregroundColor,
              backgroundColor: _backgroundColor,
              embedLogo: _embedLogo,
              logoBytes: _logoBytes,
              onFgChanged: (c) => setState(() => _foregroundColor = c),
              onBgChanged: (c) => setState(() => _backgroundColor = c),
              onApplyTemplate: (name, fg, bg) async {
                if (AdsConstants.premiumTemplateNames.contains(name) && !await _ensurePremiumTemplatesUnlocked()) return;
                if (!mounted) return;
                setState(() {
                  _foregroundColor = fg;
                  _backgroundColor = bg;
                });
                await AppHaptics.light();
              },
              onLogoToggle: (value) async {
                if (value && !await _ensureLogoUnlocked()) return;
                if (!mounted) return;
                setState(() {
                  _embedLogo = value;
                  if (!value) _logoBytes = null;
                });
              },
              onPickLogo: _pickLogo,
              onUseAppIcon: () async {
                if (!await _ensureLogoUnlocked()) return;
                if (!mounted) return;
                setState(() {
                  _embedLogo = true;
                  _logoBytes = null;
                });
              },
              onClearLogo: _clearLogo,
            ),
            const SizedBox(height: 32),
            const _SectionTitle('PRESETS'),
            const SizedBox(height: 12),
            _PresetStrip(
              presets: presets,
              onApply: _applyPreset,
              onDelete: (id) async {
                await ref.read(qrPresetProvider.notifier).deletePreset(id);
                if (!context.mounted) return;
                AppSnackBar.showInfo(context, 'Preset deleted');
              },
              onSave: () => _savePreset(state.type),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTheme.monoLabel(context).copyWith(
        letterSpacing: 1.2,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _QrPreviewCard extends StatelessWidget {
  final GeneratorContentType selectedType;
  final bool hasQrCode;
  final Widget screenshotChild;
  final VoidCallback? onShare;
  final VoidCallback? onExportSvg;
  final VoidCallback? onSave;

  const _QrPreviewCard({
    required this.selectedType,
    required this.hasQrCode,
    required this.screenshotChild,
    this.onShare,
    this.onExportSvg,
    this.onSave,
  });

  static Color _accentColorForType(GeneratorContentType type) {
    switch (type) {
      case GeneratorContentType.url: return const Color(0xFF3b82f6);
      case GeneratorContentType.email: return const Color(0xFFf97316);
      case GeneratorContentType.phone: return const Color(0xFF22c55e);
      case GeneratorContentType.sms: return const Color(0xFFeab308);
      case GeneratorContentType.contact: return const Color(0xFFec4899);
      case GeneratorContentType.wifi: return const Color(0xFF06b6d4);
      case GeneratorContentType.location: return const Color(0xFFef4444);
      case GeneratorContentType.event: return const Color(0xFF8b5cf6);
      case GeneratorContentType.text: return const Color(0xFF737373);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = _accentColorForType(selectedType);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outline.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: colorScheme.outline.withOpacity(0.5))),
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 15,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: screenshotChild,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionItem(
                  icon: Icons.share_rounded,
                  label: 'Share PNG',
                  onTap: onShare,
                  color: accentColor,
                ),
                _ActionItem(
                  icon: Icons.code_rounded,
                  label: 'Export SVG',
                  onTap: onExportSvg,
                  color: accentColor,
                ),
                _ActionItem(
                  icon: Icons.bookmark_add_rounded,
                  label: 'Save QR',
                  onTap: onSave,
                  color: accentColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  const _ActionItem({
    required this.icon,
    required this.label,
    this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final colorScheme = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: enabled ? color.withOpacity(0.15) : colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: enabled ? color : colorScheme.onSurfaceVariant,
                  size: 26,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: enabled ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  final GeneratorContentType selected;
  final ValueChanged<GeneratorContentType> onSelected;

  const _TypeSelector({
    required this.selected,
    required this.onSelected,
  });

  static IconData _iconFor(GeneratorContentType type) {
    switch (type) {
      case GeneratorContentType.text: return Icons.text_fields_rounded;
      case GeneratorContentType.url: return Icons.public_rounded;
      case GeneratorContentType.wifi: return Icons.wifi_rounded;
      case GeneratorContentType.phone: return Icons.phone_rounded;
      case GeneratorContentType.email: return Icons.email_rounded;
      case GeneratorContentType.sms: return Icons.sms_rounded;
      case GeneratorContentType.contact: return Icons.contact_page_rounded;
      case GeneratorContentType.location: return Icons.location_on_rounded;
      case GeneratorContentType.event: return Icons.event_rounded;
    }
  }

  static Color _colorFor(GeneratorContentType type) {
    return _QrPreviewCard._accentColorForType(type);
  }

  @override
  Widget build(BuildContext context) {
    final types = GeneratorContentTypeX.studioTypes;

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: types.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final t = types[i];
          final isSelected = selected == t;
          final color = _colorFor(t);
          final colorScheme = Theme.of(context).colorScheme;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelected(t),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 96,
                decoration: BoxDecoration(
                  color: isSelected ? color : colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? color : colorScheme.outline.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ] : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _iconFor(t),
                      color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ContentFormCard extends StatelessWidget {
  final GeneratorContentType type;
  final Map<String, String> fields;
  final Map<String, String?> fieldErrors;
  final Map<String, TextEditingController> controllers;
  final void Function(String key, String value) onChanged;
  final bool isShortening;
  final VoidCallback onShorten;
  final bool showShortener;

  const _ContentFormCard({
    required this.type,
    required this.fields,
    required this.fieldErrors,
    required this.controllers,
    required this.onChanged,
    required this.isShortening,
    required this.onShorten,
    required this.showShortener,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ContentForm(
            type: type,
            fields: fields,
            fieldErrors: fieldErrors,
            controllers: controllers,
            onChanged: onChanged,
          ),
          if (showShortener) ...[
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: isShortening ? null : onShorten,
              icon: isShortening
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link_rounded, size: 20),
              label: Text(isShortening ? 'SHORTENING...' : 'SHORTEN URL'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Long links create dense QRs. Shorten for better scannability.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ]
        ],
      ),
    );
  }
}

class _DesignCard extends StatelessWidget {
  final Color foregroundColor;
  final Color backgroundColor;
  final bool embedLogo;
  final Uint8List? logoBytes;
  final ValueChanged<Color> onFgChanged;
  final ValueChanged<Color> onBgChanged;
  final Future<void> Function(String name, Color fg, Color bg) onApplyTemplate;
  final ValueChanged<bool> onLogoToggle;
  final VoidCallback onPickLogo;
  final VoidCallback onUseAppIcon;
  final VoidCallback onClearLogo;

  const _DesignCard({
    required this.foregroundColor,
    required this.backgroundColor,
    required this.embedLogo,
    required this.logoBytes,
    required this.onFgChanged,
    required this.onBgChanged,
    required this.onApplyTemplate,
    required this.onLogoToggle,
    required this.onPickLogo,
    required this.onUseAppIcon,
    required this.onClearLogo,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TEMPLATES', style: AppTheme.monoLabel(context)),
                const SizedBox(height: 16),
                _BuiltInTemplatesStrip(onApply: onApplyTemplate),
                
                const SizedBox(height: 32),
                Text('QR COLOR', style: AppTheme.monoLabel(context)),
                const SizedBox(height: 16),
                _ColorSwatchPicker(
                  selectedColor: foregroundColor,
                  onColorSelected: onFgChanged,
                ),
                
                const SizedBox(height: 32),
                Text('BACKGROUND', style: AppTheme.monoLabel(context)),
                const SizedBox(height: 16),
                _ColorSwatchPicker(
                  selectedColor: backgroundColor,
                  onColorSelected: onBgChanged,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outline.withOpacity(0.3)),
          _LogoOverlayControls(
            enabled: embedLogo,
            hasCustomLogo: logoBytes != null,
            logoBytes: logoBytes,
            onToggle: onLogoToggle,
            onPickLogo: onPickLogo,
            onUseAppIcon: onUseAppIcon,
            onClear: onClearLogo,
          ),
        ],
      ),
    );
  }
}

class _ColorSwatchPicker extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  const _ColorSwatchPicker({
    required this.selectedColor,
    required this.onColorSelected,
  });

  static const List<Color> _palette = [
    Color(0xFF000000), Color(0xFFFFFFFF), Color(0xFFef4444),
    Color(0xFFf97316), Color(0xFFeab308), Color(0xFF22c55e),
    Color(0xFF3b82f6), Color(0xFF8b5cf6), Color(0xFFec4899),
    Color(0xFF06b6d4), Color(0xFF14b8a6), Color(0xFFa3e635),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: _palette.map((color) {
        final isSelected = selectedColor == color;
        return InkWell(
          onTap: () => onColorSelected(color),
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? colorScheme.primary : colorScheme.outline.withOpacity(0.3),
                width: isSelected ? 3 : 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ] : null,
            ),
            child: isSelected
                ? Icon(
                    Icons.check_rounded,
                    size: 26,
                    color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class _AsyncQrPreview extends StatefulWidget {
  final String data;
  final bool hasValidationErrors;
  final Color foregroundColor;
  final Color backgroundColor;
  final QrRenderOptions options;

  const _AsyncQrPreview({
    required this.data,
    required this.hasValidationErrors,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.options,
  });

  @override
  State<_AsyncQrPreview> createState() => _AsyncQrPreviewState();
}

class _AsyncQrPreviewState extends State<_AsyncQrPreview> {
  String _renderData = '';
  bool _isGenerating = false;
  int _generationToken = 0;

  @override
  void initState() {
    super.initState();
    _scheduleGenerate(widget.data, widget.hasValidationErrors);
  }

  @override
  void didUpdateWidget(_AsyncQrPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.hasValidationErrors != widget.hasValidationErrors ||
        oldWidget.foregroundColor != widget.foregroundColor ||
        oldWidget.backgroundColor != widget.backgroundColor ||
        oldWidget.options != widget.options) {
      _scheduleGenerate(widget.data, widget.hasValidationErrors);
    }
  }

  void _scheduleGenerate(String data, bool hasValidationErrors) {
    final trimmed = data.trim();
    if (trimmed.isEmpty || hasValidationErrors) {
      setState(() {
        _renderData = '';
        _isGenerating = false;
      });
      return;
    }

    final token = ++_generationToken;
    setState(() => _isGenerating = true);

    Future<void>.microtask(() async {
      await Future<void>.delayed(Duration.zero);
      if (!mounted || token != _generationToken) return;
      setState(() {
        _renderData = trimmed;
        _isGenerating = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isGenerating) {
      return SizedBox(
        width: 180,
        height: 180,
        child: const Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      );
    }

    return _QrPreview(
      data: _renderData,
      foregroundColor: widget.foregroundColor,
      backgroundColor: widget.backgroundColor,
      options: widget.options,
    );
  }
}

class _QrPreview extends StatelessWidget {
  final String data;
  final Color foregroundColor;
  final Color backgroundColor;
  final QrRenderOptions options;

  const _QrPreview({
    required this.data,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (data.trim().isEmpty) {
      return SizedBox(
        width: 180,
        height: 180,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_2_rounded,
              size: 64,
              color: colorScheme.outline.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 12),
            Text(
              'QR PREVIEW',
              style: AppTheme.monoLabel(
                context,
                size: 10,
                color: colorScheme.outline.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 180,
      height: 180,
      color: backgroundColor,
      padding: const EdgeInsets.all(12),
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        size: 156,
        backgroundColor: backgroundColor,
        errorCorrectionLevel: options.errorCorrectionLevel,
        embeddedImage: options.embeddedImage,
        embeddedImageStyle: options.embedLogo
            ? const QrEmbeddedImageStyle(size: Size(32, 32))
            : null,
        eyeStyle: QrEyeStyle(
          eyeShape: options.roundedModules ? QrEyeShape.circle : QrEyeShape.square,
          color: foregroundColor,
        ),
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: options.roundedModules ? QrDataModuleShape.circle : QrDataModuleShape.square,
          color: foregroundColor,
        ),
      ),
    );
  }
}

class _PresetStrip extends StatelessWidget {
  final List<QrPreset> presets;
  final ValueChanged<QrPreset> onApply;
  final ValueChanged<String> onDelete;
  final VoidCallback onSave;

  const _PresetStrip({
    required this.presets,
    required this.onApply,
    required this.onDelete,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 104,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _SavePresetCard(onTap: onSave),
              ...presets.map(
                (preset) => Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _PresetCard(
                    preset: preset,
                    onTap: () => onApply(preset),
                    onLongPress: () => onDelete(preset.id),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (presets.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Tap to apply • Long-press to delete',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }
}

class _SavePresetCard extends StatelessWidget {
  final VoidCallback onTap;

  const _SavePresetCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 104,
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.primary.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(20),
          color: colorScheme.primaryContainer.withOpacity(0.3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, color: colorScheme.primary, size: 36),
            const SizedBox(height: 12),
            Text(
              'SAVE',
              style: AppTheme.monoLabel(context, size: 10).copyWith(color: colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  final QrPreset preset;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PresetCard({
    required this.preset,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(20),
          color: colorScheme.surfaceContainer,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: preset.foregroundColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
                  ),
                ),
                const SizedBox(width: -10),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: preset.backgroundColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    preset.type.label.toUpperCase(),
                    style: AppTheme.monoLabel(context, size: 8),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              preset.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuiltInTemplatesStrip extends StatelessWidget {
  final Future<void> Function(String name, Color fg, Color bg) onApply;

  const _BuiltInTemplatesStrip({required this.onApply});

  static const _templates = <({String name, Color fg, Color bg})>[
    (name: 'Classic', fg: Color(0xFF000000), bg: Color(0xFFFFFFFF)),
    (name: 'Night', fg: Color(0xFFFFFFFF), bg: Color(0xFF0A0A0A)),
    (name: 'Ocean', fg: Color(0xFF06B6D4), bg: Color(0xFF0D1B2A)),
    (name: 'Bloom', fg: Color(0xFFEC4899), bg: Color(0xFFFFF0F6)),
    (name: 'Forest', fg: Color(0xFF22C55E), bg: Color(0xFF0A1F0A)),
    (name: 'Solar', fg: Color(0xFFEAB308), bg: Color(0xFF1A1200)),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _templates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final t = _templates[index];
          return InkWell(
            onTap: () => onApply(t.name, t.fg, t.bg),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 100,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(16),
                color: colorScheme.surface,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 20, height: 20, decoration: BoxDecoration(color: t.fg, shape: BoxShape.circle, border: Border.all(color: colorScheme.outline.withOpacity(0.2)))),
                      const SizedBox(width: -8),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: t.bg,
                          shape: BoxShape.circle,
                          border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    t.name.toUpperCase(),
                    style: AppTheme.monoLabel(context, size: 10),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LogoOverlayControls extends StatelessWidget {
  final bool enabled;
  final bool hasCustomLogo;
  final Uint8List? logoBytes;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickLogo;
  final VoidCallback onUseAppIcon;
  final VoidCallback onClear;

  const _LogoOverlayControls({
    required this.enabled,
    required this.hasCustomLogo,
    required this.logoBytes,
    required this.onToggle,
    required this.onPickLogo,
    required this.onUseAppIcon,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          title: Text(
            'Embed logo',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Add an icon to the center of your QR',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          value: enabled,
          onChanged: onToggle,
        ),
        if (enabled) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outline.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(16),
                    color: colorScheme.surfaceContainerHighest,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: logoBytes != null
                      ? Image.memory(logoBytes!, fit: BoxFit.cover)
                      : Image.asset('assets/app_icon.png', fit: BoxFit.cover),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onPickLogo,
                        icon: const Icon(Icons.image_search_rounded, size: 18),
                        label: const Text('CHOOSE IMAGE'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: hasCustomLogo ? onUseAppIcon : onClear,
                        icon: Icon(hasCustomLogo ? Icons.restore_rounded : Icons.clear_rounded, size: 18),
                        label: Text(hasCustomLogo ? 'APP ICON' : 'REMOVE'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          foregroundColor: hasCustomLogo ? null : colorScheme.error,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ContentForm extends StatelessWidget {
  final GeneratorContentType type;
  final Map<String, String> fields;
  final Map<String, String?> fieldErrors;
  final Map<String, TextEditingController> controllers;
  final void Function(String key, String value) onChanged;

  const _ContentForm({
    required this.type,
    required this.fields,
    required this.fieldErrors,
    required this.controllers,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case GeneratorContentType.text:
        return _field(context, 'message', 'Text', maxLines: 4);
      case GeneratorContentType.url:
        return _field(context, 'url', 'Website URL', keyboard: TextInputType.url);
      case GeneratorContentType.wifi:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(context, 'ssid', 'Network name'),
            const SizedBox(height: 16),
            _field(context, 'password', 'Password', obscure: true),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'WPA', label: Text('WPA')),
                ButtonSegment(value: 'WEP', label: Text('WEP')),
                ButtonSegment(value: 'nopass', label: Text('Open')),
              ],
              selected: {fields['encryption'] ?? 'WPA'},
              onSelectionChanged: (s) => onChanged('encryption', s.first),
            ),
          ],
        );
      case GeneratorContentType.phone:
        return _field(context, 'number', 'Phone number', keyboard: TextInputType.phone);
      case GeneratorContentType.email:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(context, 'to', 'Email', keyboard: TextInputType.emailAddress),
            const SizedBox(height: 16),
            _field(context, 'subject', 'Subject'),
            const SizedBox(height: 16),
            _field(context, 'body', 'Message', maxLines: 4),
          ],
        );
      case GeneratorContentType.sms:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(context, 'number', 'Phone number', keyboard: TextInputType.phone),
            const SizedBox(height: 16),
            _field(context, 'message', 'Message', maxLines: 4),
          ],
        );
      case GeneratorContentType.contact:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(context, 'name', 'Name'),
            const SizedBox(height: 16),
            _field(context, 'phone', 'Phone', keyboard: TextInputType.phone),
            const SizedBox(height: 16),
            _field(context, 'email', 'Email', keyboard: TextInputType.emailAddress),
          ],
        );
      case GeneratorContentType.location:
        return _field(context, 'coords', 'Latitude, longitude', keyboard: TextInputType.text);
      case GeneratorContentType.event:
        return _field(context, 'title', 'Event title');
    }
  }

  Widget _field(
    BuildContext context,
    String key,
    String label, {
    int maxLines = 1,
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    final controller = controllers.putIfAbsent(
      key,
      () => TextEditingController(text: fields[key] ?? ''),
    );
    final error = fieldErrors[key];

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.isNotEmpty;

        return TextField(
          controller: controller,
          maxLines: maxLines,
          obscureText: obscure,
          keyboardType: keyboard,
          decoration: InputDecoration(
            labelText: label,
            alignLabelWithHint: maxLines > 1,
            floatingLabelAlignment: FloatingLabelAlignment.start,
            errorText: error,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            suffixIcon: hasText
                ? IconButton(
                    icon: const Icon(Icons.cancel_rounded, size: 20),
                    tooltip: 'Clear',
                    onPressed: () {
                      controller.clear();
                      onChanged(key, '');
                    },
                  )
                : null,
          ),
          onChanged: (v) => onChanged(key, v),
        );
      },
    );
  }
}
