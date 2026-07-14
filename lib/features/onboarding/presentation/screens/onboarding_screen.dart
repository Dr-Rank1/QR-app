import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../shared/services/service_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      step: '01 / 03',
      icon: Icons.qr_code_scanner_outlined,
      title: 'Scan anything',
      description:
          'Point your camera at any QR code. Smart detection identifies the type and offers the right action.',
    ),
    _OnboardingPage(
      step: '02 / 03',
      icon: Icons.qr_code_outlined,
      title: 'Generate & customize',
      description:
          'Build QR codes for 8 content types. Pick colors, apply your logo, save PNG or SVG.',
    ),
    _OnboardingPage(
      step: '03 / 03',
      icon: Icons.inventory_2_outlined,
      title: 'History & My QRs',
      description:
          'Every scan is saved to History. Generated codes live in My QRs for quick reuse.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    await ref.read(onboardingStorageProvider).markCompleted();
    if (mounted) {
      context.go(AppRoutes.scanner);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final page = _pages[_currentPage];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _completeOnboarding,
                child: Text(
                  'SKIP',
                  style: AppTheme.monoLabel(
                    context,
                    size: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _OnboardingPageView(
                    page: _pages[index],
                    reduceMotion: reduceMotion,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) {
                      final selected = _currentPage == index;
                      return AnimatedContainer(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: selected ? 28 : 8,
                        height: 2,
                        color: selected
                            ? colorScheme.onSurface
                            : colorScheme.outline,
                      );
                    }),
                  ),
                  const SizedBox(height: 28),
                  if (_currentPage < _pages.length - 1)
                    Row(
                      children: [
                        TextButton(
                          onPressed: _completeOnboarding,
                          child: Text(
                            'SKIP',
                            style: AppTheme.monoLabel(context, size: 11),
                          ),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () {
                            _pageController.nextPage(
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                            );
                          },
                          child: Text('NEXT · ${page.title}'.toUpperCase()),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _completeOnboarding,
                        child: const Text('GET STARTED'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final String step;
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingPage({
    required this.step,
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _OnboardingPageView extends StatelessWidget {
  final _OnboardingPage page;
  final bool reduceMotion;

  const _OnboardingPageView({
    required this.page,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            page.step,
            style: AppTheme.monoLabel(
              context,
              size: 12,
              weight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outline),
              color: colorScheme.surfaceContainer,
            ),
            child: Icon(page.icon, size: 56, color: colorScheme.onSurface),
          ),
          const SizedBox(height: 36),
          Text(
            page.title.toUpperCase(),
            style: AppTheme.displayTitle(context, size: 32),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
