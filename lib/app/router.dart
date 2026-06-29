import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../features/scanner/presentation/screens/result_detail_screen.dart';
import '../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../shared/services/onboarding_storage.dart';
import 'main_shell.dart';

class AppRoutes {
  static const onboarding = '/onboarding';
  static const scanner = '/';
  static const resultDetail = '/result/:id';

  static String resultDetailPath(String id) => '/result/$id';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

Page<void> _fadePage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

Page<void> _slideUpPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final offsetAnimation = Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

      return SlideTransition(
        position: offsetAnimation,
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.onboarding,
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        pageBuilder: (context, state) => _fadePage(
          key: state.pageKey,
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.scanner,
        name: 'scanner',
        pageBuilder: (context, state) => _fadePage(
          key: state.pageKey,
          child: const MainShell(),
        ),
      ),
      GoRoute(
        path: AppRoutes.resultDetail,
        name: 'resultDetail',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return _slideUpPage(
            key: state.pageKey,
            child: ResultDetailScreen(scanId: id),
          );
        },
      ),
    ],
    redirect: (context, state) {
      final onboardingCompleted = OnboardingStorage(Hive.box('settings')).isCompleted;

      if (onboardingCompleted && state.matchedLocation == AppRoutes.onboarding) {
        return AppRoutes.scanner;
      }

      if (!onboardingCompleted && state.matchedLocation != AppRoutes.onboarding) {
        return AppRoutes.onboarding;
      }

      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(state.uri.toString()),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go(AppRoutes.scanner),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
