import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NetworkState {
  final bool isOnline;
  final List<ConnectivityResult> connectionType;
  final bool wasOffline;

  const NetworkState({
    this.isOnline = true,
    this.connectionType = const [],
    this.wasOffline = false,
  });

  NetworkState copyWith({
    bool? isOnline,
    List<ConnectivityResult>? connectionType,
    bool? wasOffline,
  }) {
    return NetworkState(
      isOnline: isOnline ?? this.isOnline,
      connectionType: connectionType ?? this.connectionType,
      wasOffline: wasOffline ?? this.wasOffline,
    );
  }
}

class NetworkNotifier extends StateNotifier<NetworkState> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  NetworkNotifier() : super(const NetworkState()) {
    _init();
  }

  Future<void> _init() async {
    // Check initial connectivity
    final results = await _connectivity.checkConnectivity();
    _handleResults(results);

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(_handleResults);
  }

  void _handleResults(List<ConnectivityResult> results) {
    final isOnline = results.isNotEmpty && !results.contains(ConnectivityResult.none);
    final wasOffline = !state.isOnline && isOnline;

    state = state.copyWith(
      isOnline: isOnline,
      connectionType: results,
      wasOffline: wasOffline,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final networkProvider = StateNotifierProvider<NetworkNotifier, NetworkState>((ref) {
  return NetworkNotifier();
});

final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(networkProvider).isOnline;
});