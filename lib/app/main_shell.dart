import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/scanner/presentation/screens/scanner_screen.dart';
import '../features/generator/presentation/screens/generator_screen.dart';
import '../features/history/presentation/screens/enhanced_history_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../../shared/ads/banner_ad_widget.dart';
import 'navigation_provider.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedTabIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: const [
          ScannerScreen(),
          GeneratorScreen(),
          EnhancedHistoryScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              ref.read(selectedTabIndexProvider.notifier).state = index;
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.qr_code_scanner_outlined),
                selectedIcon: Icon(Icons.qr_code_scanner),
                label: 'Scanner',
              ),
              NavigationDestination(
                icon: Icon(Icons.qr_code_outlined),
                selectedIcon: Icon(Icons.qr_code),
                label: 'Generator',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }
}
