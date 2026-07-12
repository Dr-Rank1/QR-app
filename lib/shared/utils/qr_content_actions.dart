import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/scanner/domain/enums/qr_result_type.dart';
import '../../features/scanner/domain/models/qr_result.dart';
import '../services/share_service.dart';
import '../widgets/app_icons.dart';
import 'app_haptics.dart';
import 'qr_parser.dart';

/// Smart primary/secondary actions derived from detected QR content type.
class QRContentActions {
  QRContentActions._();

  static bool hasPrimary(QRResultType type) {
    switch (type) {
      case QRResultType.url:
      case QRResultType.phone:
      case QRResultType.email:
      case QRResultType.wifi:
      case QRResultType.sms:
      case QRResultType.geo:
      case QRResultType.vcard:
      case QRResultType.calendar:
        return true;
      case QRResultType.text:
        return false;
    }
  }

  static IconData primaryIcon(QRResultType type) {
    switch (type) {
      case QRResultType.url:
        return AppIcons.openExternal;
      case QRResultType.wifi:
        return Icons.wifi_outlined;
      case QRResultType.phone:
        return Icons.phone_outlined;
      case QRResultType.email:
        return Icons.email_outlined;
      case QRResultType.sms:
        return Icons.sms_outlined;
      case QRResultType.geo:
        return Icons.map_outlined;
      case QRResultType.vcard:
        return Icons.person_add_alt_1_outlined;
      case QRResultType.calendar:
        return Icons.event_available_outlined;
      case QRResultType.text:
        return AppIcons.copy;
    }
  }

  static String primaryLabel(
    QRResultType type, {
    Map<String, String>? metadata,
  }) {
    switch (type) {
      case QRResultType.url:
        return 'Open Link';
      case QRResultType.wifi:
        return 'Copy Wi-Fi Details';
      case QRResultType.phone:
        return 'Call';
      case QRResultType.email:
        return 'Send Email';
      case QRResultType.sms:
        return 'Send SMS';
      case QRResultType.geo:
        return 'Open in Maps';
      case QRResultType.vcard:
        return 'Add Contact';
      case QRResultType.calendar:
        final location = metadata?['location'];
        if (location != null && location.isNotEmpty) {
          return 'Open Location';
        }
        return 'Share Event';
      case QRResultType.text:
        return 'Copy';
    }
  }

  static List<QRSecondaryAction> secondaryActions(QRResult result) {
    final actions = <QRSecondaryAction>[];
    final meta = result.metadata;

    if (result.type == QRResultType.vcard) {
      final phone = meta?['phone'];
      final email = meta?['email'];
      if (phone != null && phone.isNotEmpty) {
        actions.add(
          QRSecondaryAction(
            label: 'Call',
            icon: Icons.phone_outlined,
            type: QRResultType.phone,
            value: phone,
          ),
        );
      }
      if (email != null && email.isNotEmpty) {
        actions.add(
          QRSecondaryAction(
            label: 'Email',
            icon: Icons.email_outlined,
            type: QRResultType.email,
            value: email.startsWith('mailto:') ? email : 'mailto:$email',
          ),
        );
      }
    }

    if (result.type == QRResultType.calendar) {
      final location = meta?['location'];
      if (location != null && location.isNotEmpty) {
        actions.add(
          QRSecondaryAction(
            label: 'Maps',
            icon: Icons.map_outlined,
            type: QRResultType.geo,
            value: 'geo:0,0?q=${Uri.encodeComponent(location)}',
            metadata: {'url': location},
          ),
        );
      }
    }

    return actions;
  }

  static Future<PrimaryActionResult> runPrimary(
    BuildContext context,
    QRResult result, {
    ShareService? shareService,
  }) async {
    switch (result.type) {
      case QRResultType.wifi:
        await Clipboard.setData(
          ClipboardData(text: wifiCredentials(result.metadata)),
        );
        await AppHaptics.light();
        return PrimaryActionResult.success(
          'Wi-Fi details copied — open Settings to connect',
        );

      case QRResultType.vcard:
        final share = shareService ?? ShareService();
        await share.shareContactCard(result.rawValue);
        return PrimaryActionResult.success(
          'Share the contact card to save it',
        );

      case QRResultType.calendar:
        final location = result.metadata?['location'];
        if (location != null && location.isNotEmpty) {
          final opened = await QRContentParser.tryOpen(
            QRResultType.geo,
            'geo:0,0?q=${Uri.encodeComponent(location)}',
            {'url': location},
            context: context,
          );
          return opened
              ? PrimaryActionResult.silentSuccess()
              : PrimaryActionResult.failure('Could not open location');
        }
        final share = shareService ?? ShareService();
        await share.shareCalendarEvent(result.rawValue);
        return PrimaryActionResult.success(
          'Share the event to add it to your calendar',
        );

      case QRResultType.url:
      case QRResultType.phone:
      case QRResultType.email:
      case QRResultType.sms:
      case QRResultType.geo:
        final opened = await QRContentParser.tryOpen(
          result.type,
          result.rawValue,
          result.metadata,
          context: context,
        );
        return opened
            ? PrimaryActionResult.silentSuccess()
            : PrimaryActionResult.failure('Could not open this content');

      case QRResultType.text:
        await Clipboard.setData(ClipboardData(text: result.rawValue));
        await AppHaptics.light();
        return PrimaryActionResult.success('Copied to clipboard');
    }
  }

  static String wifiCredentials(Map<String, String>? meta) {
    return 'Network: ${meta?['ssid'] ?? 'Unknown'}\n'
        'Password: ${meta?['password'] ?? ''}\n'
        'Security: ${meta?['encryption'] ?? meta?['type'] ?? 'WPA'}';
  }
}

class PrimaryActionResult {
  final bool success;
  final String? message;
  final bool silent;

  const PrimaryActionResult._({
    required this.success,
    this.message,
    this.silent = false,
  });

  factory PrimaryActionResult.success(String message) =>
      PrimaryActionResult._(success: true, message: message);

  factory PrimaryActionResult.silentSuccess() =>
      const PrimaryActionResult._(success: true, silent: true);

  factory PrimaryActionResult.failure(String message) =>
      PrimaryActionResult._(success: false, message: message);
}

class QRSecondaryAction {
  final String label;
  final IconData icon;
  final QRResultType type;
  final String value;
  final Map<String, String>? metadata;

  const QRSecondaryAction({
    required this.label,
    required this.icon,
    required this.type,
    required this.value,
    this.metadata,
  });
}
