import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../monetization/presentation/providers/purchases_provider.dart';

enum QRGeneratorType {
  text,
  url,
  phone,
  email,
  wifi,
  vCard,
}

class GeneratorScreen extends ConsumerStatefulWidget {
  const GeneratorScreen({super.key});

  @override
  ConsumerState<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends ConsumerState<GeneratorScreen> {
  QRGeneratorType _selectedType = QRGeneratorType.text;
  final _formKey = GlobalKey<FormState>();
  final _screenshotController = ScreenshotController();

  // Form controllers
  final _textController = TextEditingController();
  final _urlController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailToController = TextEditingController();
  final _emailSubjectController = TextEditingController();
  final _emailBodyController = TextEditingController();
  final _wifiSsidController = TextEditingController();
  final _wifiPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactCompanyController = TextEditingController();
  final _contactWebsiteController = TextEditingController();

  // Wi-Fi security
  String _wifiSecurity = 'WPA';

  // QR customization
  int _qrSize = 200;
  String _errorCorrection = 'M';
  Color _foregroundColor = Colors.black;
  bool _useRoundedStyle = false;
  bool _useSmoothStyle = false;

  // Debounce timer
  Timer? _debounceTimer;
  String _generatedQR = '';

  @override
  void dispose() {
    _textController.dispose();
    _urlController.dispose();
    _phoneController.dispose();
    _emailToController.dispose();
    _emailSubjectController.dispose();
    _emailBodyController.dispose();
    _wifiSsidController.dispose();
    _wifiPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    _contactCompanyController.dispose();
    _contactWebsiteController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  String _generateQRString() {
    switch (_selectedType) {
      case QRGeneratorType.text:
        return _textController.text;
      case QRGeneratorType.url:
        final url = _urlController.text;
        if (!url.startsWith('http://') && !url.startsWith('https://')) {
          return 'https://$url';
        }
        return url;
      case QRGeneratorType.phone:
        return 'tel:${_phoneController.text}';
      case QRGeneratorType.email:
        final to = _emailToController.text;
        final subject = _emailSubjectController.text;
        final body = _emailBodyController.text;
        return 'mailto:$to?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
      case QRGeneratorType.wifi:
        final ssid = _wifiSsidController.text;
        final password = _wifiPasswordController.text;
        final hidden = _selectedType == QRGeneratorType.text ? 'false' : 'true';
        return 'WIFI:T:$_wifiSecurity;S:${Uri.encodeComponent(ssid)};P:${Uri.encodeComponent(password)};H:$hidden;;';
      case QRGeneratorType.vCard:
        return _generateVCard();
    }
  }

  String _generateVCard() {
    final firstName = _firstNameController.text;
    final lastName = _lastNameController.text;
    final phone = _contactPhoneController.text;
    final email = _contactEmailController.text;
    final company = _contactCompanyController.text;
    final website = _contactWebsiteController.text;

    return '''BEGIN:VCARD
VERSION:3.0
N:$lastName;$firstName;;;
FN:$firstName $lastName
TEL;TYPE=CELL:$phone
EMAIL:$email
ORG:$company
URL:$website
END:VCARD''';
  }

  void _onFormChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {});
    });
  }

  void _updateQR() {
    setState(() {
      _generatedQR = _generateQRString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(isPremiumProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Generator'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Type selector
              _TypeSelector(
                selectedType: _selectedType,
                onTypeChanged: (type) {
                  setState(() => _selectedType = type);
                  _onFormChanged();
                },
              ),
              const SizedBox(height: 16),

              // Dynamic form
              _buildForm(),
              const SizedBox(height: 24),

              // QR Preview
              _QRPreview(
                generatedQR: _generatedQR,
                size: _qrSize,
                foregroundColor: _foregroundColor,
                useRoundedStyle: _useRoundedStyle,
                useSmoothStyle: _useSmoothStyle,
                screenshotController: _screenshotController,
              ),
              const SizedBox(height: 16),

              // Customization
              _CustomizationOptions(
                qrSize: _qrSize,
                errorCorrection: _errorCorrection,
                foregroundColor: _foregroundColor,
                useRoundedStyle: _useRoundedStyle,
                useSmoothStyle: _useSmoothStyle,
                isPremium: isPremium,
                onSizeChanged: (v) => setState(() => _qrSize = v),
                onErrorCorrectionChanged: (v) => setState(() => _errorCorrection = v),
                onForegroundColorChanged: (v) => setState(() => _foregroundColor = v),
                onRoundedStyleChanged: (v) => setState(() => _useRoundedStyle = v),
                onSmoothStyleChanged: (v) => setState(() => _useSmoothStyle = v),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _generatedQR.isEmpty ? null : () => _saveToGallery(),
                      icon: const Icon(Icons.save_alt),
                      label: const Text('Save'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _generatedQR.isEmpty ? null : () => _shareQR(),
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    switch (_selectedType) {
      case QRGeneratorType.text:
        return TextFormField(
          controller: _textController,
          decoration: const InputDecoration(
            labelText: 'Text',
            hintText: 'Enter text to encode',
          ),
          maxLines: 3,
          onChanged: (_) => _onFormChanged(),
        );
      case QRGeneratorType.url:
        return TextFormField(
          controller: _urlController,
          decoration: InputDecoration(
            labelText: 'URL',
            hintText: 'https://example.com',
            prefixIcon: _isValidUrl(_urlController.text)
                ? const Icon(Icons.link, color: Colors.green)
                : null,
          ),
          keyboardType: TextInputType.url,
          onChanged: (_) => _onFormChanged(),
        );
      case QRGeneratorType.phone:
        return TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            hintText: '+1234567890',
          ),
          keyboardType: TextInputType.phone,
          onChanged: (_) => _onFormChanged(),
        );
      case QRGeneratorType.email:
        return Column(
          children: [
            TextFormField(
              controller: _emailToController,
              decoration: const InputDecoration(labelText: 'To'),
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => _onFormChanged(),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailSubjectController,
              decoration: const InputDecoration(labelText: 'Subject (optional)'),
              onChanged: (_) => _onFormChanged(),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailBodyController,
              decoration: const InputDecoration(labelText: 'Body (optional)'),
              maxLines: 2,
              onChanged: (_) => _onFormChanged(),
            ),
          ],
        );
      case QRGeneratorType.wifi:
        return Column(
          children: [
            TextFormField(
              controller: _wifiSsidController,
              decoration: const InputDecoration(labelText: 'Network Name (SSID)'),
              onChanged: (_) => _onFormChanged(),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _wifiPasswordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              onChanged: (_) => _onFormChanged(),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _wifiSecurity,
              decoration: const InputDecoration(labelText: 'Security Type'),
              items: const [
                DropdownMenuItem(value: 'WPA', child: Text('WPA/WPA2')),
                DropdownMenuItem(value: 'WEP', child: Text('WEP')),
                DropdownMenuItem(value: 'nopass', child: Text('None')),
              ],
              onChanged: (v) {
                setState(() => _wifiSecurity = v!);
                _onFormChanged();
              },
            ),
          ],
        );
      case QRGeneratorType.vCard:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(labelText: 'First Name'),
                    onChanged: (_) => _onFormChanged(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(labelText: 'Last Name'),
                    onChanged: (_) => _onFormChanged(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _contactPhoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
              onChanged: (_) => _onFormChanged(),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _contactEmailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => _onFormChanged(),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _contactCompanyController,
              decoration: const InputDecoration(labelText: 'Company (optional)'),
              onChanged: (_) => _onFormChanged(),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _contactWebsiteController,
              decoration: const InputDecoration(labelText: 'Website (optional)'),
              keyboardType: TextInputType.url,
              onChanged: (_) => _onFormChanged(),
            ),
          ],
        );
    }
  }

  bool _isValidUrl(String text) {
    if (text.isEmpty) return false;
    return text.startsWith('http://') ||
        text.startsWith('https://') ||
        text.contains('.');
  }

  Future<void> _saveToGallery() async {
    try {
      final image = await _screenshotController.capture();
      if (image == null) return;

      final result = await ImageGallerySaver.saveImage(
        image,
        quality: 100,
        name: 'qr_code_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to gallery')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  Future<void> _shareQR() async {
    try {
      final image = await _screenshotController.capture();
      if (image == null) return;

      final directory = await getTemporaryDirectory();
      final file = await File('${directory.path}/qr_code.png').writeAsBytes(image);

      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    }
  }
}

class _TypeSelector extends StatelessWidget {
  final QRGeneratorType selectedType;
  final ValueChanged<QRGeneratorType> onTypeChanged;

  const _TypeSelector({
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: QRGeneratorType.values.map((type) {
          final isSelected = type == selectedType;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_getLabel(type)),
              selected: isSelected,
              onSelected: (_) => onTypeChanged(type),
              avatar: Icon(_getIcon(type), size: 18),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getLabel(QRGeneratorType type) {
    switch (type) {
      case QRGeneratorType.text:
        return 'Text';
      case QRGeneratorType.url:
        return 'URL';
      case QRGeneratorType.phone:
        return 'Phone';
      case QRGeneratorType.email:
        return 'Email';
      case QRGeneratorType.wifi:
        return 'Wi-Fi';
      case QRGeneratorType.vCard:
        return 'Contact';
    }
  }

  IconData _getIcon(QRGeneratorType type) {
    switch (type) {
      case QRGeneratorType.text:
        return Icons.text_fields;
      case QRGeneratorType.url:
        return Icons.link;
      case QRGeneratorType.phone:
        return Icons.phone;
      case QRGeneratorType.email:
        return Icons.email;
      case QRGeneratorType.wifi:
        return Icons.wifi;
      case QRGeneratorType.vCard:
        return Icons.contact_phone;
    }
  }
}

class _QRPreview extends StatelessWidget {
  final String generatedQR;
  final int size;
  final Color foregroundColor;
  final bool useRoundedStyle;
  final bool useSmoothStyle;
  final ScreenshotController screenshotController;

  const _QRPreview({
    required this.generatedQR,
    required this.size,
    required this.foregroundColor,
    required this.useRoundedStyle,
    required this.useSmoothStyle,
    required this.screenshotController,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Screenshot(
        controller: screenshotController,
        child: generatedQR.isEmpty
            ? Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('Enter text to generate QR'),
                ),
              )
            : useSmoothStyle
                ? PrettyQr(
                    data: generatedQR,
                    size: size.toDouble(),
                    roundicorners: useRoundedStyle,
                    elementColor: foregroundColor,
                  )
                : QrImageView(
                    data: generatedQR,
                    size: size.toDouble(),
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeColor: Colors.black,
                      dataCellStyle: QrDataCellStyle(
                        dataCellColor: Colors.black,
                      ),
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataCellColor: foregroundColor,
                    ),
                  ),
      ),
    );
  }
}

class _CustomizationOptions extends StatelessWidget {
  final int qrSize;
  final String errorCorrection;
  final Color foregroundColor;
  final bool useRoundedStyle;
  final bool useSmoothStyle;
  final bool isPremium;
  final ValueChanged<int> onSizeChanged;
  final ValueChanged<String> onErrorCorrectionChanged;
  final ValueChanged<Color> onForegroundColorChanged;
  final ValueChanged<bool> onRoundedStyleChanged;
  final ValueChanged<bool> onSmoothStyleChanged;

  const _CustomizationOptions({
    required this.qrSize,
    required this.errorCorrection,
    required this.foregroundColor,
    required this.useRoundedStyle,
    required this.useSmoothStyle,
    required this.isPremium,
    required this.onSizeChanged,
    required this.onErrorCorrectionChanged,
    required this.onForegroundColorChanged,
    required this.onRoundedStyleChanged,
    required this.onSmoothStyleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customization',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),

        // Size slider
        Row(
          children: [
            const Text('Size: '),
            Expanded(
              child: Slider(
                value: qrSize.toDouble(),
                min: 150,
                max: 400,
                divisions: 5,
                label: '$qrSize',
                onChanged: (v) => onSizeChanged(v.round()),
              ),
            ),
            Text('$qrSize'),
          ],
        ),

        // Error correction
        const Text('Error Correction:'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'L', label: Text('L')),
            ButtonSegment(value: 'M', label: Text('M')),
            ButtonSegment(value: 'Q', label: Text('Q')),
            ButtonSegment(value: 'H', label: Text('H')),
          ],
          selected: {errorCorrection},
          onSelectionChanged: (s) => onErrorCorrectionChanged(s.first),
        ),

        const SizedBox(height: 8),

        // Color picker
        const Text('Color:'),
        Wrap(
          spacing: 8,
          children: [
            Colors.black,
            const Color(0xFF1565C0),
            const Color(0xFF2E7D32),
            const Color(0xFFC62828),
          ].map((color) {
            final isSelected = color.value == foregroundColor.value;
            return ChoiceChip(
              label: const SizedBox.shrink(),
              selected: isSelected,
              onSelected: (_) => onForegroundColorChanged(color),
              avatar: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }).toList(),
        ),

        // Premium features
        if (isPremium) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Rounded Style'),
            value: useRoundedStyle,
            onChanged: onRoundedStyleChanged,
          ),
          SwitchListTile(
            title: const Text('Smooth Style'),
            value: useSmoothStyle,
            onChanged: onSmoothStyleChanged,
          ),
        ] else
          SwitchListTile(
            title: Row(
              children: [
                const Text('Rounded Style'),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'PRO',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            value: useRoundedStyle,
            onChanged: null,
          ),
      ],
    );
  }
}