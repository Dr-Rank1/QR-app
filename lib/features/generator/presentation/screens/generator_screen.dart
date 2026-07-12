import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';

import '../../../../app/app_spacing.dart';
import '../../../../app/theme.dart';
import '../../../../shared/services/service_providers.dart';
import '../../../../shared/utils/app_haptics.dart';
import '../../../../shared/utils/permission_handler.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/theme_mode_toggle.dart';
import '../../../analytics/presentation/providers/generated_qr_provider.dart';
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
      GeneratorContentType.url => state.fields['url'] ?? 'Link',
      GeneratorContentType.text => state.fields['message'] ?? 'Text',
      GeneratorContentType.wifi => state.fields['ssid'] ?? 'Wi-Fi',
      GeneratorContentType.phone => state.fields['number'] ?? 'Phone',
      GeneratorContentType.email => state.fields['to'] ?? 'Email',
      GeneratorContentType.sms => state.fields['number'] ?? 'SMS',
      GeneratorContentType.contact => state.fields['name'] ?? 'Contact',
    };
    await ref.read(generatedQrProvider.notifier).add(
          title: title,
          payload: payload,
          type: state.type,
          foreground: _foregroundColor,
          background: _backgroundColor,
        );
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share image: $e')),
        );
      }
    }
  }

  Future<void> _pickLogo() async {
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
      appBar: AppBar(
        title: const Text('QR Studio'),
        actions: [
          IconButton(
            tooltip: 'Share PNG',
            onPressed: hasQrCode ? () => _shareImage(payload) : null,
            icon: const Icon(AppIcons.share),
          ),
          const ThemeModeToggle(),
        ],
      ),
      body: Column(
        children: [
          _QrPreviewBand(
            selectedType: state.type,
            hasQrCode: hasQrCode,
            hasValidationErrors: state.hasValidationErrors,
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
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              children: [
                const SizedBox(height: 20),
                Text('TYPE', style: AppTheme.monoLabel(context)),
                const SizedBox(height: 8),
                _TypeGrid(
                  selected: state.type,
                  onSelected: notifier.setType,
                ),
                const SizedBox(height: 24),
                Text('PRESETS', style: AppTheme.monoLabel(context)),
                const SizedBox(height: 8),
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
                const SizedBox(height: 24),
                Text('CONTENT', style: AppTheme.monoLabel(context)),
                const SizedBox(height: 8),
                _ContentForm(
                  type: state.type,
                  fields: state.fields,
                  fieldErrors: state.fieldErrors,
                  controllers: _fieldControllers,
                  onChanged: notifier.updateField,
                ),
                if (state.type == GeneratorContentType.url) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isShortening ? null : _shortenUrl,
                      icon: _isShortening
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.link_outlined, size: 18),
                      label: Text(
                        _isShortening ? 'SHORTENING…' : 'SHORTEN URL',
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Long links create dense QRs. Shorten before encoding.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
                const SizedBox(height: 24),
                Text('QR COLOR', style: AppTheme.monoLabel(context)),
                const SizedBox(height: 8),
                _ColorSwatchPicker(
                  selectedColor: _foregroundColor,
                  onColorSelected: (color) =>
                      setState(() => _foregroundColor = color),
                ),
                const SizedBox(height: 20),
                Text('BACKGROUND', style: AppTheme.monoLabel(context)),
                const SizedBox(height: 8),
                _ColorSwatchPicker(
                  selectedColor: _backgroundColor,
                  onColorSelected: (color) =>
                      setState(() => _backgroundColor = color),
                ),
                const SizedBox(height: 24),
                Text('CENTER LOGO', style: AppTheme.monoLabel(context)),
                const SizedBox(height: 8),
                _LogoOverlayControls(
                  enabled: _embedLogo,
                  hasCustomLogo: _logoBytes != null,
                  logoBytes: _logoBytes,
                  onToggle: (value) {
                    setState(() {
                      _embedLogo = value;
                      if (!value) _logoBytes = null;
                    });
                  },
                  onPickLogo: _pickLogo,
                  onUseAppIcon: () {
                    setState(() {
                      _embedLogo = true;
                      _logoBytes = null;
                    });
                  },
                  onClear: _clearLogo,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: hasQrCode ? () async {
                      final pngBytes = await _qrService.renderQrPng(
                        payload,
                        options: _renderOptions.copyWith(
                          foregroundColor: _foregroundColor,
                          backgroundColor: _backgroundColor,
                        ),
                      );
                      final shareService = ref.read(shareServiceProvider);
                      await shareService.shareQrImage(pngBytes);
                      await _persistGenerated(payload);
                      await AppHaptics.success();
                      if (!context.mounted) return;
                      AppSnackBar.showSuccess(context, 'Saved to My QRs');
                    } : null,
                    child: const Text('SAVE'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: hasQrCode ? () => _shareImage(payload) : null,
                    child: const Text('SHARE PNG'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: hasQrCode ? () => _shareSvg(payload) : null,
                    child: const Text('EXPORT SVG'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QrPreviewBand extends StatelessWidget {
  final GeneratorContentType selectedType;
  final bool hasQrCode;
  final bool hasValidationErrors;
  final Widget screenshotChild;

  const _QrPreviewBand({
    required this.selectedType,
    required this.hasQrCode,
    required this.hasValidationErrors,
    required this.screenshotChild,
  });

  static Color _accentColorForType(GeneratorContentType type) {
    switch (type) {
      case GeneratorContentType.url:
        return const Color(0xFF3b82f6);
      case GeneratorContentType.email:
        return const Color(0xFFf97316);
      case GeneratorContentType.phone:
        return const Color(0xFF22c55e);
      case GeneratorContentType.sms:
        return const Color(0xFFeab308);
      case GeneratorContentType.contact:
        return const Color(0xFFec4899);
      case GeneratorContentType.wifi:
        return const Color(0xFF06b6d4);
      case GeneratorContentType.text:
        return const Color(0xFF737373);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = _accentColorForType(selectedType);

    return Container(
      height: 192,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: accentColor, width: 3),
          bottom: BorderSide(color: colorScheme.outline),
        ),
      ),
      child: Center(
        child: screenshotChild,
      ),
    );
  }
}

class _TypeGrid extends StatelessWidget {
  final GeneratorContentType selected;
  final ValueChanged<GeneratorContentType> onSelected;

  const _TypeGrid({
    required this.selected,
    required this.onSelected,
  });

  static IconData _iconFor(GeneratorContentType type) {
    switch (type) {
      case GeneratorContentType.text:
        return Icons.text_fields_outlined;
      case GeneratorContentType.url:
        return Icons.public_outlined;
      case GeneratorContentType.wifi:
        return Icons.lock_outlined;
      case GeneratorContentType.phone:
        return Icons.phone_outlined;
      case GeneratorContentType.email:
        return Icons.email_outlined;
      case GeneratorContentType.sms:
        return Icons.sms_outlined;
      case GeneratorContentType.contact:
        return Icons.contact_page_outlined;
    }
  }

  static Color _colorFor(GeneratorContentType type) {
    switch (type) {
      case GeneratorContentType.url:
        return const Color(0xFF3b82f6);
      case GeneratorContentType.email:
        return const Color(0xFFf97316);
      case GeneratorContentType.phone:
        return const Color(0xFF22c55e);
      case GeneratorContentType.sms:
        return const Color(0xFFeab308);
      case GeneratorContentType.contact:
        return const Color(0xFFec4899);
      case GeneratorContentType.wifi:
        return const Color(0xFF06b6d4);
      case GeneratorContentType.text:
        return const Color(0xFF737373);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final types = GeneratorContentType.values;

    return Container(
      color: colorScheme.outline,
      child: Row(
        children: [
          for (int i = 0; i < types.length; i++) ...[
            if (i > 0) SizedBox(width: 1),
            Expanded(
              child: _TypeCell(
                type: types[i],
                isSelected: selected == types[i],
                icon: _iconFor(types[i]),
                color: _colorFor(types[i]),
                onTap: () => onSelected(types[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypeCell extends StatelessWidget {
  final GeneratorContentType type;
  final bool isSelected;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TypeCell({
    required this.type,
    required this.isSelected,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 72,
        color: isSelected ? color : colorScheme.surface,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              type.label.toUpperCase(),
              style: AppTheme.monoLabel(
                context,
                size: 8,
                color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
    Color(0xFF000000),
    Color(0xFFFFFFFF),
    Color(0xFFef4444),
    Color(0xFFf97316),
    Color(0xFFeab308),
    Color(0xFF22c55e),
    Color(0xFF3b82f6),
    Color(0xFF8b5cf6),
    Color(0xFFec4899),
    Color(0xFF06b6d4),
    Color(0xFF14b8a6),
    Color(0xFFa3e635),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _palette.map((color) {
        final isSelected = selectedColor == color;
        return InkWell(
          onTap: () => onColorSelected(color),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(
                color: isSelected
                    ? colorScheme.onSurface
                    : colorScheme.outline,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    size: 20,
                    color: color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
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
        width: 160,
        height: 160,
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
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
        width: 160,
        height: 160,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_2_outlined,
              size: 48,
              color: colorScheme.outline.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 8),
            Text(
              'QR PREVIEW',
              style: AppTheme.monoLabel(
                context,
                size: 9,
                color: colorScheme.outline.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 160,
      height: 160,
      color: backgroundColor,
      padding: const EdgeInsets.all(12),
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        size: 136,
        backgroundColor: backgroundColor,
        errorCorrectionLevel: options.errorCorrectionLevel,
        embeddedImage: options.embeddedImage,
        embeddedImageStyle: options.embedLogo
            ? const QrEmbeddedImageStyle(size: Size(28, 28))
            : null,
        eyeStyle: QrEyeStyle(
          eyeShape:
              options.roundedModules ? QrEyeShape.circle : QrEyeShape.square,
          color: foregroundColor,
        ),
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: options.roundedModules
              ? QrDataModuleShape.circle
              : QrDataModuleShape.square,
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
          height: 88,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _SavePresetCard(onTap: onSave),
              ...presets.map(
                (preset) => Padding(
                  padding: const EdgeInsets.only(left: 8),
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
          const SizedBox(height: 6),
          Text(
            'Tap to apply · long-press to delete',
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
      child: Container(
        width: 92,
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: colorScheme.onSurface),
            const SizedBox(height: 6),
            Text(
              'SAVE',
              style: AppTheme.monoLabel(context, size: 9),
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
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  color: preset.foregroundColor,
                  foregroundDecoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outline),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 16,
                  height: 16,
                  color: preset.backgroundColor,
                  foregroundDecoration: BoxDecoration(
                    border: Border.all(color: colorScheme.outline),
                  ),
                ),
                const Spacer(),
                Text(
                  preset.type.label.toUpperCase(),
                  style: AppTheme.monoLabel(context, size: 8),
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

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            title: Text(
              'Embed logo',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            subtitle: Text(
              'Uses high error correction so scans stay reliable',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            value: enabled,
            onChanged: onToggle,
          ),
          if (enabled) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outline),
                      color: colorScheme.surfaceContainer,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: logoBytes != null
                        ? Image.memory(logoBytes!, fit: BoxFit.cover)
                        : Image.asset('assets/app_icon.png', fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasCustomLogo ? 'Custom image' : 'App icon',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Shown in the QR center',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onPickLogo,
                      child: const Text('CHOOSE IMAGE'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: hasCustomLogo ? onUseAppIcon : onClear,
                      child: Text(hasCustomLogo ? 'APP ICON' : 'REMOVE'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
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
            const SizedBox(height: 12),
            _field(context, 'password', 'Password', obscure: true),
            const SizedBox(height: 12),
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
        return _field(
          context,
          'number',
          'Phone number',
          keyboard: TextInputType.phone,
        );
      case GeneratorContentType.email:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(context, 'to', 'Email', keyboard: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _field(context, 'subject', 'Subject'),
            const SizedBox(height: 12),
            _field(context, 'body', 'Message', maxLines: 3),
          ],
        );
      case GeneratorContentType.sms:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(
              context,
              'number',
              'Phone number',
              keyboard: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _field(context, 'message', 'Message', maxLines: 3),
          ],
        );
      case GeneratorContentType.contact:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(context, 'name', 'Name'),
            const SizedBox(height: 12),
            _field(context, 'phone', 'Phone', keyboard: TextInputType.phone),
            const SizedBox(height: 12),
            _field(context, 'email', 'Email', keyboard: TextInputType.emailAddress),
          ],
        );
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
            suffixIcon: hasText
                ? IconButton(
                    icon: const Icon(AppIcons.close, size: 20),
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
