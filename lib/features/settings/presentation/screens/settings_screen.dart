import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/app_spacing.dart';
import '../../../../app/app_info.dart';
import '../../../../shared/services/crash_reporter.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/theme_mode_selector.dart';
import '../../../../shared/widgets/theme_mode_toggle.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: const [ThemeModeToggle()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          const _SettingsSectionHeader(label: 'Scanning'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _SettingsToggleTile(
                icon: Icons.vibration_outlined,
                title: 'Vibrate on Scan',
                subtitle: 'Haptic feedback when a code is detected',
                value: settings.vibrateOnScan,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).setVibrateOnScan(value);
                },
              ),
              _SettingsToggleTile(
                icon: Icons.volume_up_outlined,
                title: 'Sound on Scan',
                subtitle: 'Play a sound when a code is detected',
                value: settings.soundOnScan,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).setSoundOnScan(value);
                },
              ),
              _SettingsToggleTile(
                icon: Icons.stay_current_portrait_outlined,
                title: 'Keep Screen On',
                subtitle: 'Prevent screen from sleeping while scanning',
                value: settings.keepScreenOn,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).setKeepScreenOn(value);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const _SettingsSectionHeader(label: 'Appearance'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: const [
              _ThemeModeHeader(),
              ThemeModeSelector(),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const _SettingsSectionHeader(label: 'Data'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _DestructiveSettingsTile(
                icon: Icons.delete_forever_outlined,
                title: 'Clear Scan History',
                subtitle: 'Permanently remove all saved scans from this device',
                onTap: () => _confirmClearHistory(context, ref),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const _SettingsSectionHeader(label: 'Diagnostics'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _SettingsNavTile(
                icon: Icons.bug_report_outlined,
                title: 'Crash logs',
                subtitle:
                    '${CrashReporter.getLogs().length} local entries (closed testing)',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _exportCrashLogs(context),
                        icon: const Icon(AppIcons.export),
                        label: const Text('Export logs'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _clearCrashLogs(context),
                        icon: const Icon(AppIcons.delete),
                        label: const Text('Clear logs'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const _SettingsSectionHeader(label: 'About'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _SettingsNavTile(
                icon: Icons.info_outline,
                title: 'Version',
                subtitle: AppInfo.versionLabel,
              ),
              _SettingsNavTile(
                icon: Icons.policy_outlined,
                title: 'Privacy Policy',
                trailing: const Icon(AppIcons.openExternal, size: 20),
                onTap: () => _showPrivacyPolicy(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _confirmClearHistory(BuildContext context, WidgetRef ref) async {
    final colorScheme = Theme.of(context).colorScheme;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              0,
              AppSpacing.screenHorizontal,
              16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Clear scan history?',
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  'This permanently removes every saved scan. This cannot be undone.',
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: const Text('Delete all history'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      await ref.read(scanHistoryProvider.notifier).clearAll();
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Scan history cleared');
      }
    }
  }

  Future<void> _exportCrashLogs(BuildContext context) async {
    final export = CrashReporter.exportLogs();
    await SharePlus.instance.share(
      ShareParams(text: export, subject: 'QR Vault crash logs'),
    );
  }

  Future<void> _clearCrashLogs(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear crash logs'),
        content: const Text('Remove all locally stored crash reports?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await CrashReporter.clearLogs();
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Crash logs cleared');
      }
    }
  }

  Future<void> _showPrivacyPolicy(BuildContext context) async {
    final policy = await rootBundle.loadString('assets/privacy_policy.txt');
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: SingleChildScrollView(child: Text(policy)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeHeader extends StatelessWidget {
  const _ThemeModeHeader();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Icon(
            Icons.palette_outlined,
            size: AppIcons.sizeList,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Choose light, dark, or match your device',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  final String label;

  const _SettingsSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _SettingsToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: AppIcons.sizeList, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestructiveSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DestructiveSettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: colorScheme.error, size: AppIcons.sizeList),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.error.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsNavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsNavTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(icon, size: AppIcons.sizeList, color: colorScheme.onSurfaceVariant),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
