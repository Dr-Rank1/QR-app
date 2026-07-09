import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';

import '../../../../app/app_spacing.dart';
import '../../../../app/theme.dart';
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
  final double _qrSize = 200;
  final bool _embedLogo = false;
  final bool _roundedModules = false;
  Color _foregroundColor = Colors.black;
  Color _backgroundColor = Colors.white;

  QrGenerationService get _qrService => ref.read(qrGenerationServiceProvider);

  QrRenderOptions get _renderOptions => QrRenderOptions(
        size: _qrSize,
        embedLogo: _embedLogo,
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
                Text('CONTENT', style: AppTheme.monoLabel(context)),
                const SizedBox(height: 8),
                _ContentForm(
                  type: state.type,
                  fields: state.fields,
                  fieldErrors: state.fieldErrors,
                  controllers: _fieldControllers,
                  onChanged: notifier.updateField,
                ),
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
                      await AppHaptics.success();
                    } : null,
                    child: const Text('SAVE'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: hasQrCode ? () => _shareImage(payload) : null,
                    child: const Text('SHARE'),
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
        embeddedImage:
            options.embedLogo ? const AssetImage('assets/app_icon.png') : null,
        embeddedImageStyle: options.embedLogo
            ? const QrEmbeddedImageStyle(
                size: Size(24, 24),
              )
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
