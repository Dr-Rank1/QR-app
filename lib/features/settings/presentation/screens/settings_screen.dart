import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../monetization/presentation/providers/purchases_provider.dart';
import '../../../monetization/data/export_service.dart';
import '../../../history/data/repositories/scan_history_repository.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isPremium = ref.watch(isPremiumProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Settings'),
            if (isPremium) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'PRO',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      body: ListView(
        children: [
          // Premium section (only for non-premium users)
          if (!isPremium)
            _PremiumBannerCard(
              onTap: () => context.push('/paywall'),
            ),

          // Scan feedback section
          _SectionHeader(title: 'Scan Feedback'),
          SwitchListTile(
            title: const Text('Vibration'),
            subtitle: const Text('Vibrate on successful scan'),
            value: settings.vibrateOnScan,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setVibrateOnScan(value);
            },
          ),
          SwitchListTile(
            title: const Text('Sound'),
            subtitle: const Text('Play sound on successful scan'),
            value: settings.soundOnScan,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setSoundOnScan(value);
            },
          ),

          const Divider(),

          // Data section
          _SectionHeader(title: 'Data'),
          _PremiumListTile(
            icon: Icons.download,
            title: 'Export History',
            subtitle: 'Export to CSV or PDF',
            isPremium: isPremium,
            onTap: () => _showExportOptions(context, ref),
          ),
          _PremiumListTile(
            icon: Icons.folder,
            title: 'Custom Tags',
            subtitle: 'Organize scans with tags',
            isPremium: isPremium,
            onTap: () => _showPremiumFeatureDialog(context),
          ),
          _PremiumListTile(
            icon: Icons.qr_code,
            title: 'Batch QR Generator',
            subtitle: 'Generate multiple QR codes at once',
            isPremium: isPremium,
            onTap: () => _showPremiumFeatureDialog(context),
          ),

          const Divider(),

          // Display section
          _SectionHeader(title: 'Display'),
          SwitchListTile(
            title: const Text('Keep Screen On'),
            subtitle: const Text('Prevent screen from turning off while scanning'),
            value: settings.keepScreenOn,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setKeepScreenOn(value);
            },
          ),
          ListTile(
            title: const Text('Theme'),
            subtitle: Text(_getThemeLabel(settings.themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemeDialog(context, ref),
          ),

          const Divider(),

          // Premium section (for premium users)
          if (isPremium) ...[
            _SectionHeader(title: 'Cloud Backup'),
            ListTile(
              leading: const Icon(Icons.cloud_upload),
              title: const Text('Cloud Backup'),
              subtitle: const Text('Coming soon'),
              enabled: false,
            ),
            const Divider(),
          ],

          // About section
          _SectionHeader(title: 'About'),
          ListTile(
            title: const Text('Version'),
            subtitle: const Text('1.0.0${isPremium ? ' Premium' : ''}'),
          ),
          ListTile(
            title: const Text('Open Source Licenses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'QR Scanner',
                applicationVersion: '1.0.0',
              );
            },
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsProvider);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('System'),
              value: ThemeMode.system,
              groupValue: settings.themeMode,
              onChanged: (value) {
                ref.read(settingsProvider.notifier).setThemeMode(value!);
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              groupValue: settings.themeMode,
              onChanged: (value) {
                ref.read(settingsProvider.notifier).setThemeMode(value!);
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              groupValue: settings.themeMode,
              onChanged: (value) {
                ref.read(settingsProvider.notifier).setThemeMode(value!);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExportOptions(BuildContext context, WidgetRef ref) async {
    final isPremium = ref.read(isPremiumProvider);

    if (!isPremium) {
      _showPremiumFeatureDialog(context);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Export as CSV'),
              onTap: () async {
                Navigator.of(context).pop();
                await _exportToCsv(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export as PDF'),
              onTap: () async {
                Navigator.of(context).pop();
                await _exportToPdf(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToCsv(BuildContext context) async {
    final repo = ScanHistoryRepository();
    final scans = await repo.getAllScans();

    if (scans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No scans to export')),
      );
      return;
    }

    final path = await ExportService.exportToCsv(scans);
    if (path != null) {
      await ExportService.shareFile(path);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed')),
        );
      }
    }
  }

  Future<void> _exportToPdf(BuildContext context) async {
    final repo = ScanHistoryRepository();
    final scans = await repo.getAllScans();

    if (scans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No scans to export')),
      );
      return;
    }

    final path = await ExportService.exportToPdf(scans);
    if (path != null) {
      await ExportService.shareFile(path);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed')),
        );
      }
    }
  }

  void _showPremiumFeatureDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.workspace_premium, color: Colors.amber),
            const SizedBox(width: 8),
            const Text('Premium Feature'),
          ],
        ),
        content: const Text(
          'This feature is available for Premium subscribers. '
          'Upgrade now to unlock all features and remove ads!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/paywall');
            },
            child: const Text('Go Premium'),
          ),
        ],
      ),
    );
  }

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }
}

class _PremiumBannerCard extends StatelessWidget {
  final VoidCallback onTap;

  const _PremiumBannerCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: colorScheme.primaryContainer,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.workspace_premium,
                    color: colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Go Premium',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Remove ads, export history, and more!',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isPremium;
  final VoidCallback onTap;

  const _PremiumListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isPremium,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Stack(
        children: [
          Icon(icon),
          if (!isPremium)
            Positioned(
              right: -2,
              top: -2,
              child: Icon(
                Icons.lock,
                size: 12,
                color: colorScheme.error,
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Text(title),
          if (!isPremium) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'PRO',
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}