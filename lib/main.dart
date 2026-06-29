import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'features/history/data/repositories/scan_history_repository.dart';
import 'features/scanner/domain/models/qr_result.dart';
import 'features/settings/presentation/providers/settings_provider.dart';
import 'shared/ads/interstitial_ad_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint('Ad initialization failed: $e');
  }

  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(QRResultAdapter());
  }

  await Hive.openBox('settings');
  await ScanHistoryRepository().initialize();

  interstitialAdManager.initialize();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    const ProviderScope(
      child: QRScannerApp(),
    ),
  );
}

class QRScannerApp extends ConsumerWidget {
  const QRScannerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'QR Vault',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
