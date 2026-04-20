import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:shared_preferences/shared_preferences.dart';

// RevenueCat API key - use environment variable in production
const String _revenueCatApiKey = 'your_revenuecat_api_key';

class PremiumState {
  final bool isPremium;
  final bool isLoading;
  final String? errorMessage;

  const PremiumState({
    this.isPremium = false,
    this.isLoading = false,
    this.errorMessage,
  });

  PremiumState copyWith({
    bool? isPremium,
    bool? isLoading,
    String? errorMessage,
  }) {
    return PremiumState(
      isPremium: isPremium ?? this.isPremium,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class PremiumNotifier extends StateNotifier<PremiumState> {
  PremiumNotifier() : super(const PremiumState(isLoading: true)) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Purchases.setDebugLogsEnabled(kDebugMode);
      
      final configuration = PurchasesConfiguration(_revenueCatApiKey);
      await Purchases.configure(configuration);

      // Check current entitlement status
      await _checkPremiumStatus();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _checkPremiumStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final entitlements = customerInfo.entitlements.active;

      // Check for premium entitlement
      final isPremium = entitlements.containsKey('premium') ||
          entitlements.containsKey('pro') ||
          customerInfo.originalPurchaseDate != null;

      state = state.copyWith(
        isPremium: isPremium,
        isLoading: false,
      );

      // Cache premium status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_premium', isPremium);
    } catch (e) {
      // Fallback to cached status
      final prefs = await SharedPreferences.getInstance();
      final cachedPremium = prefs.getBool('is_premium') ?? false;
      state = state.copyWith(
        isPremium: cachedPremium,
        isLoading: false,
      );
    }
  }

  Future<bool> purchasePremium(String packageId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final offerings = await Purchases.getOfferings();
      final package = offerings.current?.availablePackages.firstWhere(
        (p) => p.identifier == packageId,
        orElse: () => offerings.current!.availablePackages.first,
      );

      if (package != null) {
        await Purchases.purchasePackage(package);
        await _checkPremiumStatus();
        return state.isPremium;
      }

      state = state.copyWith(isLoading: false);
      return false;
    } catch (e) {
      final error = PurchasesErrorHelper.getErrorCode(e);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Purchase failed: ${error.name}',
      );
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final customerInfo = await Purchases.restorePurchases();
      final entitlements = customerInfo.entitlements.active;

      final isPremium = entitlements.containsKey('premium') ||
          entitlements.containsKey('pro');

      state = state.copyWith(
        isPremium: isPremium,
        isLoading: false,
      );

      // Cache premium status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_premium', isPremium);

      return isPremium;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Restore failed: ${e.toString()}',
      );
      return false;
    }
  }
}

final premiumProvider = StateNotifierProvider<PremiumNotifier, PremiumState>((ref) {
  return PremiumNotifier();
});

// Convenience provider for just checking premium status
final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(premiumProvider).isPremium;
});

// Scan counter for interstitial ads (free users only)
final scanCounterProvider = StateProvider<int>((ref) => 0);

// Check if should show interstitial ad (every 5 scans for free users)
final shouldShowInterstitialProvider = Provider<bool>((ref) {
  final isPremium = ref.watch(isPremiumProvider);
  if (isPremium) return false;

  final count = ref.watch(scanCounterProvider);
  return count > 0 && count % 5 == 0;
});

// Free tier limit check
const int freeTierScanLimit = 20;

final isAtScanLimitProvider = Provider<bool>((ref) {
  final isPremium = ref.watch(isPremiumProvider);
  if (isPremium) return false;

  // This would need to be connected to the actual scan count
  return false; // Will be updated by history provider
});