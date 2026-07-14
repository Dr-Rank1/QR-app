import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/app_spacing.dart';
import '../../../../app/app_info.dart';
import '../../../../app/theme.dart';
import '../../../../shared/ads/ads_constants.dart';
import '../../../../shared/ads/startapp_banner_slot.dart';
import '../../../../shared/services/crash_reporter.dart';
import '../../../../shared/services/service_providers.dart';
import '../../../../shared/utils/qr_type_ui.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/theme_mode_selector.dart';
import '../../../analytics/presentation/providers/generated_qr_provider.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../../scanner/domain/enums/qr_result_type.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.of(context).canPop()
            ? TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  '← BACK',
                  style: AppTheme.monoLabel(context, size: 11),
                ),
              )
            : null,
        leadingWidth: 88,
        title: Text(
          'SETTINGS',
          style: AppTheme.monoLabel(context, size: 11, weight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          const _SettingsSectionHeader(label: 'Appearance'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: const [
              _ThemeModeHeader(),
              ThemeModeSelector(),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const _SettingsSectionHeader(label: 'Scanner'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _SettingsToggleTile(
                icon: Icons.open_in_new,
                title: 'Auto-open URLs',
                subtitle: 'Open detected links automatically after scan',
                value: settings.autoOpenUrls,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).setAutoOpenUrls(value);
                },
              ),
              _SettingsToggleTile(
                icon: Icons.vibration_outlined,
                title: 'Haptic feedback',
                subtitle: 'Vibrate when a code is detected',
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
          const _SettingsSectionHeader(label: 'Generator'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _SettingsToggleTile(
                icon: Icons.link_outlined,
                title: 'URL shortener',
                subtitle: 'Shorten long URLs before encoding',
                value: settings.urlShortenerEnabled,
                onChanged: (value) {
                  ref
                      .read(settingsProvider.notifier)
                      .setUrlShortenerEnabled(value);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const _SettingsSectionHeader(label: 'Data'),
          const SizedBox(height: 8),
          _SettingsCard(
            children: [
              _DestructiveSettingsTile(
                icon: Icons.delete_forever_outlined,
                title: 'Clear scan history',
                subtitle: 'Permanently remove all saved scans from this device',
                onTap: () => _confirmClearHistory(context, ref),
              ),
              _DestructiveSettingsTile(
                icon: Icons.qr_code_outlined,
                title: 'Clear My QRs',
                subtitle: 'Remove all saved generated codes',
                onTap: () => _confirmClearMyQrs(context, ref),
              ),
              _SettingsNavTile(
                icon: Icons.restart_alt_outlined,
                title: 'Replay onboarding',
                subtitle: 'Show the intro flow again on next launch',
                onTap: () async {
                  await ref.read(onboardingStorageProvider).reset();
                  if (context.mounted) {
                    AppSnackBar.showSuccess(
                      context,
                      'Onboarding will show next launch',
                    );
                  }
                },
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
          const SizedBox(height: 32),
          const StartAppBannerSlot(adTag: AdsConstants.bannerSettings),
          const SizedBox(height: 16),
          _BrandFooter(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _confirmClearMyQrs(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear My QRs?'),
        content: const Text('Removes all saved generated codes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(generatedQrProvider.notifier).clear();
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'My QRs cleared');
      }
    }
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
      style: AppTheme.monoLabel(context, size: 10, weight: FontWeight.w500),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    final dividedChildren = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      dividedChildren.add(children[i]);
      if (i < children.length - 1) {
        dividedChildren.add(Divider(
          height: 1,
          thickness: 1,
          color: colorScheme.outline,
          indent: 16,
          endIndent: 16,
        ));
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outline),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: dividedChildren,
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
        child: Padding(
          padding: const EdgeInsets.all(16),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    );
  }
}

class _BrandFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allTypes = QRResultType.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QR Studio',
          style: AppTheme.displayTitle(context, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          'Version ${AppInfo.versionLabel}',
          style: AppTheme.monoLabel(context, size: 9),
        ),
        const SizedBox(height: 20),
        Text(
          'TYPE COLORS',
          style: AppTheme.monoLabel(context, size: 9),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allTypes.map((type) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 2,
                  height: 14,
                  color: type.color,
                ),
                const SizedBox(width: 6),
                Text(
                  type.name.toUpperCase(),
                  style: AppTheme.monoLabel(
                    context,
                    size: 8,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
