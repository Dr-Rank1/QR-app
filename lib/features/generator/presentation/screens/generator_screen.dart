import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';

import '../../../../app/app_spacing.dart';
import '../../../../shared/services/service_providers.dart';
import '../../../../shared/utils/app_haptics.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/theme_mode_toggle.dart';
import '../../domain/qr_payload_builder.dart';
import '../../domain/services/qr_generation_service.dart';
import '../providers/generator_provider.dart';

class GeneratorScreen extends ConsumerStatefulWidget {
  const GeneratorScreen({super.key});

  @override
  ConsumerState<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends ConsumerState<GeneratorScreen> {
  final _fieldControllers = <String, TextEditingController>{};
  double _qrSize = 200;
  bool _embedLogo = false;
  bool _roundedModules = false;
  bool _advancedExpanded = false;

  QrGenerationService get _qrService => ref.read(qrGenerationServiceProvider);

  QrRenderOptions get _renderOptions => QrRenderOptions(
        size: _qrSize,
        embedLogo: _embedLogo,
        roundedModules: _roundedModules,
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

  Future<void> _shareImage(String payload) async {
    if (payload.trim().isEmpty) return;

    try {
      final shareService = ref.read(shareServiceProvider);
      final pngBytes = await _qrService.renderQrPng(
        payload,
        options: _renderOptions,
      );
      await shareService.shareQrImage(pngBytes);
      await AppHaptics.success();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share image: $e')),
        );
      }
    }
  }

  Future<void> _shareText(String payload) async {
    if (payload.trim().isEmpty) return;

    try {
      await ref.read(shareServiceProvider).shareText(payload);
      await AppHaptics.success();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share content: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(generatorProvider);
    final notifier = ref.read(generatorProvider.notifier);
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
        actions: const [ThemeModeToggle()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: _QrPreviewCard(
                hasQrCode: hasQrCode,
                hasValidationErrors: state.hasValidationErrors,
                screenshotChild: Screenshot(
                  controller: _qrService.screenshotController,
                  child: _AsyncQrPreview(
                    data: payload,
                    hasValidationErrors: state.hasValidationErrors,
                    options: _renderOptions,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _TypeSelector(
            selected: state.type,
            onSelected: notifier.setType,
          ),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Details', style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(height: 12),
          _ContentForm(
            type: state.type,
            fields: state.fields,
            fieldErrors: state.fieldErrors,
            controllers: _fieldControllers,
            onChanged: notifier.updateField,
          ),
          const SizedBox(height: 16),
          _AdvancedOptionsPanel(
            expanded: _advancedExpanded,
            qrSize: _qrSize,
            embedLogo: _embedLogo,
            roundedModules: _roundedModules,
            onExpansionChanged: (value) =>
                setState(() => _advancedExpanded = value),
            onQrSizeChanged: (value) => setState(() => _qrSize = value),
            onEmbedLogoChanged: (value) => setState(() => _embedLogo = value),
            onRoundedModulesChanged: (value) =>
                setState(() => _roundedModules = value),
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: hasQrCode
                ? Row(
                    key: const ValueKey('secondary-actions'),
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: payload),
                            );
                            await AppHaptics.success();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Copied to clipboard'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(AppIcons.copy),
                          label: const Text('Copy'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _shareText(payload),
                          icon: const Icon(AppIcons.share),
                          label: const Text('Share data'),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(key: ValueKey('no-secondary-actions')),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: hasQrCode ? () => _shareImage(payload) : null,
              icon: const Icon(Icons.image_outlined),
              label: const Text('Share as image'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _QrPreviewCard extends StatelessWidget {
  final bool hasQrCode;
  final bool hasValidationErrors;
  final Widget screenshotChild;

  const _QrPreviewCard({
    required this.hasQrCode,
    required this.hasValidationErrors,
    required this.screenshotChild,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  screenshotChild,
                  if (!hasQrCode) ...[
                    const SizedBox(height: 14),
                    Text(
                      hasValidationErrors
                          ? 'Fix the highlighted fields to preview your code'
                          : 'Enter details below to generate your QR code',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: hasValidationErrors
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                    ),
                  ],
                ],
              ),
            ),
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final types = GeneratorContentType.values;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: types.map((type) {
          final isSelected = selected == type;
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: InkWell(
              onTap: () => onSelected(type),
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 64,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHigh,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: colorScheme.primary.withValues(alpha: 0.28),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        _iconFor(type),
                        size: 24,
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      type.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AdvancedOptionsPanel extends StatelessWidget {
  final bool expanded;
  final double qrSize;
  final bool embedLogo;
  final bool roundedModules;
  final ValueChanged<bool> onExpansionChanged;
  final ValueChanged<double> onQrSizeChanged;
  final ValueChanged<bool> onEmbedLogoChanged;
  final ValueChanged<bool> onRoundedModulesChanged;

  const _AdvancedOptionsPanel({
    required this.expanded,
    required this.qrSize,
    required this.embedLogo,
    required this.roundedModules,
    required this.onExpansionChanged,
    required this.onQrSizeChanged,
    required this.onEmbedLogoChanged,
    required this.onRoundedModulesChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: expanded,
          onExpansionChanged: onExpansionChanged,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            'Advanced options',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          subtitle: Text(
            'Size, logo, module style',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          children: [
            Row(
              children: [
                Text('Size', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: qrSize,
                    min: 160,
                    max: 260,
                    divisions: 5,
                    label: qrSize.round().toString(),
                    onChanged: onQrSizeChanged,
                  ),
                ),
                Text(
                  '${qrSize.round()}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Embed app logo'),
              subtitle: const Text('Place a small logo in the center'),
              value: embedLogo,
              onChanged: onEmbedLogoChanged,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Rounded modules'),
              subtitle: const Text('Use circular dots instead of squares'),
              value: roundedModules,
              onChanged: onRoundedModulesChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _AsyncQrPreview extends StatefulWidget {
  final String data;
  final bool hasValidationErrors;
  final QrRenderOptions options;

  const _AsyncQrPreview({
    required this.data,
    required this.hasValidationErrors,
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
        width: widget.options.size,
        height: widget.options.size,
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    return _QrPreview(data: _renderData, options: widget.options);
  }
}

class _QrPreview extends StatelessWidget {
  final String data;
  final QrRenderOptions options;

  const _QrPreview({
    required this.data,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (data.trim().isEmpty) {
      return SizedBox(
        width: options.size,
        height: options.size,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_2_outlined,
              size: 72,
              color: colorScheme.outline.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 12),
            Text(
              'QR preview',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.outline.withValues(alpha: 0.7),
                    letterSpacing: 0.4,
                  ),
            ),
          ],
        ),
      );
    }

    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: options.size,
      backgroundColor: Colors.white,
      embeddedImage:
          options.embedLogo ? const AssetImage('assets/app_icon.png') : null,
      embeddedImageStyle: options.embedLogo
          ? QrEmbeddedImageStyle(
              size: Size(options.size * 0.18, options.size * 0.18),
            )
          : null,
      eyeStyle: QrEyeStyle(
        eyeShape:
            options.roundedModules ? QrEyeShape.circle : QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: QrDataModuleStyle(
        dataModuleShape: options.roundedModules
            ? QrDataModuleShape.circle
            : QrDataModuleShape.square,
        color: Colors.black,
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
