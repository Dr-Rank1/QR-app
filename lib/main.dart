import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/router.dart';
import 'app/app_messenger.dart';
import 'app/theme.dart';
import 'features/history/data/repositories/scan_history_repository.dart';
import 'features/scanner/domain/models/qr_result.dart';
import 'features/settings/presentation/providers/settings_provider.dart';
import 'shared/security/secure_logger.dart';
import 'shared/services/crash_reporter.dart';
import 'shared/services/deep_link_listener.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      CrashReporter.recordError(
        details.exception,
        details.stack ?? StackTrace.current,
        context: 'FlutterError',
      );
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(CrashReporter.recordError(error, stack, context: 'PlatformDispatcher'));
      return true;
    };

    try {
      await Hive.initFlutter();

      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(QRResultAdapter());
      }

      await Hive.openBox('settings');
      await ScanHistoryRepository().initialize();
      await CrashReporter.initialize();
    } catch (e, stack) {
      SecureLogger.logError(e, stack);
      await CrashReporter.recordError(e, stack, context: 'Startup');
    }

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
  }, (error, stack) {
    unawaited(CrashReporter.recordError(error, stack, context: 'Zone'));
  });
}

class QRScannerApp extends ConsumerWidget {
  const QRScannerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final lightTheme = AppTheme.lightTheme();
    final darkTheme = AppTheme.darkTheme();
    final brightness = _resolveBrightness(themeMode);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            brightness == Brightness.dark ? Brightness.dark : Brightness.light,
      ),
    );

    return DeepLinkListener(
      child: MaterialApp.router(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        title: 'QR Vault',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        themeAnimationDuration: const Duration(milliseconds: 380),
        themeAnimationCurve: Curves.easeInOutCubic,
        routerConfig: router,
      ),
    );
  }

  Brightness _resolveBrightness(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.dark => Brightness.dark,
      ThemeMode.light => Brightness.light,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
  }
}
