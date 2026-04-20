import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../providers/purchases_provider.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  final VoidCallback? onDismiss;

  const PaywallScreen({super.key, this.onDismiss});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  Package? _monthlyPackage;
  Package? _annualPackage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        final packages = offerings.current!.availablePackages;
        for (final package in packages) {
          if (package.packageType == PackageType.monthly) {
            _monthlyPackage = package;
          } else if (package.packageType == PackageType.annual) {
            _annualPackage = package;
          }
        }
      }
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final premiumState = ref.watch(premiumProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header with dismiss button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.onDismiss != null)
                    IconButton(
                      onPressed: widget.onDismiss,
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Crown icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.workspace_premium,
                        size: 40,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Go Premium',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'Unlock all features and remove ads',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Feature comparison
                    _FeatureList(),

                    const SizedBox(height: 32),

                    // Pricing plans
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else ...[
                      // Monthly plan
                      _PricingCard(
                        title: 'Monthly',
                        price: _monthlyPackage?.storeProduct.priceString ?? '\$4.99/mo',
                        isRecommended: false,
                        onPurchase: () => _purchase(_monthlyPackage),
                        isLoading: premiumState.isLoading,
                      ),
                      const SizedBox(height: 12),

                      // Annual plan with savings
                      _PricingCard(
                        title: 'Annual',
                        price: _annualPackage?.storeProduct.priceString ?? '\$39.99/yr',
                        savings: 'Save 33%',
                        isRecommended: true,
                        onPurchase: () => _purchase(_annualPackage),
                        isLoading: premiumState.isLoading,
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Restore purchases
                    TextButton(
                      onPressed: premiumState.isLoading
                          ? null
                          : () => _restorePurchases(),
                      child: const Text('Restore Purchases'),
                    ),

                    if (premiumState.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          premiumState.errorMessage!,
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _purchase(Package? package) async {
    if (package == null) return;

    final success = await ref
        .read(premiumProvider.notifier)
        .purchasePremium(package.identifier);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Welcome to Premium!')),
      );
      widget.onDismiss?.call();
    }
  }

  Future<void> _restorePurchases() async {
    final restored = await ref.read(premiumProvider.notifier).restorePurchases();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            restored
                ? 'Purchases restored!'
                : 'No previous purchases found',
          ),
        ),
      );
    }
  }
}

class _FeatureList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final features = [
      _FeatureItem(
        icon: Icons.infinity,
        title: 'Unlimited History',
        isPremium: true,
      ),
      _FeatureItem(
        icon: Icons.block,
        title: 'No Ads',
        isPremium: true,
      ),
      _FeatureItem(
        icon: Icons.download,
        title: 'Export to CSV/PDF',
        isPremium: true,
      ),
      _FeatureItem(
        icon: Icons.folder,
        title: 'Custom Tags & Folders',
        isPremium: true,
      ),
      _FeatureItem(
        icon: Icons.qr_code,
        title: 'Batch QR Generator',
        isPremium: true,
      ),
      _FeatureItem(
        icon: Icons.cloud_upload,
        title: 'Cloud Backup',
        isPremium: true,
        isComingSoon: true,
      ),
    ];

    return Column(
      children: features
          .map((f) => _FeatureRow(feature: f))
          .toList(),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final bool isPremium;
  final bool isComingSoon;

  _FeatureItem({
    required this.icon,
    required this.title,
    required this.isPremium,
    this.isComingSoon = false,
  });
}

class _FeatureRow extends StatelessWidget {
  final _FeatureItem feature;

  const _FeatureRow({required this.feature});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: feature.isPremium
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              feature.icon,
              size: 20,
              color: feature.isPremium
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              feature.title,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          if (feature.isComingSoon)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Coming Soon',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onTertiaryContainer,
                ),
              ),
            )
          else
            Icon(
              feature.isPremium ? Icons.check_circle : Icons.cancel,
              color: feature.isPremium ? Colors.green : Colors.grey,
            ),
        ],
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  final String title;
  final String price;
  final String? savings;
  final bool isRecommended;
  final VoidCallback onPurchase;
  final bool isLoading;

  const _PricingCard({
    required this.title,
    required this.price,
    this.savings,
    this.isRecommended = false,
    required this.onPurchase,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: isRecommended ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isRecommended
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: isLoading ? null : onPurchase,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isRecommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'RECOMMENDED',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    if (savings != null)
                      Text(
                        savings!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                        ),
                      ),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                FilledButton(
                  onPressed: onPurchase,
                  child: const Text('Subscribe'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}