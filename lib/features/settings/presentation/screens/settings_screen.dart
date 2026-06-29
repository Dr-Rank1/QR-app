import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const _SectionHeader(title: 'Scanning'),
          SwitchListTile(
            title: const Text('Vibrate on Scan'),
            subtitle: const Text('Haptic feedback when a code is detected'),
            value: settings.vibrateOnScan,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setVibrateOnScan(value);
            },
          ),
          SwitchListTile(
            title: const Text('Sound on Scan'),
            subtitle: const Text('Play a sound when a code is detected'),
            value: settings.soundOnScan,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setSoundOnScan(value);
            },
          ),
          SwitchListTile(
            title: const Text('Keep Screen On'),
            subtitle: const Text('Prevent screen from sleeping while scanning'),
            value: settings.keepScreenOn,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setKeepScreenOn(value);
            },
          ),
          const _SectionHeader(title: 'Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Use dark theme'),
            value: settings.darkMode,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setDarkMode(value);
            },
          ),
          const _SectionHeader(title: 'About'),
          const ListTile(
            title: Text('Version'),
            subtitle: Text('1.0.0'),
          ),
          ListTile(
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _showPrivacyPolicy(context),
          ),
        ],
      ),
    );
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

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
