import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animations/animations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/scanner/presentation/screens/result_detail_screen.dart';
import '../features/onboarding/presentation/screens/onboarding_screen.dart';
import 'main_shell.dart';

class AppRoutes {
  static const onboarding = '/onboarding';
  static const scanner = '/';
  static const resultDetail = '/result/:id';

  static String resultDetailPath(String id) => '/result/$id';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.onboarding,
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeThroughTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.scanner,
        name: 'scanner',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const MainShell(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeThroughTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.resultDetail,
        name: 'resultDetail',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return CustomTransitionPage(
            key: state.pageKey,
            child: ResultDetailScreen(scanId: id),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SharedAxisTransition(
                animation: animation,
                secondaryAnimation: secondaryAnimation,
                transitionType: SharedAxisTransitionType.vertical,
                child: child,
              );
            },
          );
        },
      ),
    ],
    redirect: (context, state) async {
      final prefs = await SharedPreferences.getInstance();
      final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

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
