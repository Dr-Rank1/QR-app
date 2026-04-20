import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../scanner/domain/models/qr_result.dart';

enum SyncStatus {
  idle,
  syncing,
  synced,
  pending,
  error,
}

class SyncState {
  final SyncStatus status;
  final DateTime? lastSyncedAt;
  final String? errorMessage;
  final int pendingCount;

  const SyncState({
    this.status = SyncStatus.idle,
    this.lastSyncedAt,
    this.errorMessage,
    this.pendingCount = 0,
  });

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncedAt,
    String? errorMessage,
    int? pendingCount,
  }) {
    return SyncState(
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: errorMessage,
      pendingCount: pendingCount ?? this.pendingCount,
    );
  }
}

class SyncService {
  FirebaseFirestore? _firestore;
  final String _pendingBoxName = 'pending_sync';
  final int _maxRetries = 3;

  Future<void> initialize() async {
    // Initialize Firebase
    // Note: This requires google-services.json on Android and GoogleService-Info.plist on iOS
    try {
      await FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    } catch (_) {
      // Not using emulator
    }
  }

  Future<String> _getUserId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) return user.uid;

      // Sign in anonymously
      final credential = await FirebaseAuth.instance.signInAnonymously();
      return credential.user!.uid;
    } catch (e) {
      // Fallback to local user ID
      return 'local_user';
    }
  }

  /// Push local records to cloud
  Future<void> pushPending() async {
    try {
      final uid = await _getUserId();
      final pendingBox = await Hive.openBox(_pendingBoxName);
      final pendingIds = pendingBox.values.toList();

      for (final id in pendingIds) {
        try {
          final scan = await _getScanById(id);
          if (scan != null && scan.syncedAt == null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('scans')
                .doc(id)
                .set(_scanToJson(scan));

            // Update syncedAt
            await _updateSyncedAt(id);
          }
        } catch (e) {
          // Continue with next
        }
      }

      await pendingBox.clear();
    } on FirebaseException catch (e) {
      throw _handleFirebaseError(e);
    }
  }

  /// Pull cloud records to local
  Future<void> pullRemote() async {
    try {
      final uid = await _getUserId();
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('scans')
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final localScan = await _getScanById(doc.id);

        if (localScan == null) {
          // New remote record - add to local
          await _saveScan(_scanFromJson(data));
        } else {
          // Merge with last-write-wins
          final remoteUpdated = (data['updatedAt'] as Timestamp?)?.toDate();
          final localUpdated = localScan.scannedAt;

          if (remoteUpdated != null && remoteUpdated.isAfter(localUpdated)) {
            await _saveScan(_scanFromJson(data));
          }
        }
      }
    } on FirebaseException catch (e) {
      throw _handleFirebaseError(e);
    }
  }

  /// Full sync - push then pull
  Future<void> fullSync() async {
    await pushPending();
    await pullRemote();
  }

  /// Add scan ID to pending queue
  Future<void> queueForSync(String scanId) async {
    final pendingBox = await Hive.openBox(_pendingBoxName);
    await pendingBox.put(scanId, scanId);
  }

  /// Get pending count
  Future<int> getPendingCount() async {
    final pendingBox = await Hive.openBox(_pendingBoxName);
    return pendingBox.length;
  }

  /// Retry with exponential backoff
  Future<void> syncWithRetry(Future<void> Function() syncFunction) async {
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        await syncFunction();
        return;
      } catch (e) {
        if (attempt == _maxRetries - 1) rethrow;
        await Future.delayed(Duration(seconds: (1 << attempt) * 2));
      }
    }
  }

  String _handleFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'No permission to sync. Please sign in.';
      case 'quota-exceeded':
        return 'Sync quota exceeded. Try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Sync failed: ${e.message}';
    }
  }

  // Helper methods to interact with scans
  Future<QRResult?> _getScanById(String id) async {
    final box = await Hive.openBox<QRResult>('scan_history');
    return box.get(id);
  }

  Future<void> _saveScan(QRResult scan) async {
    final box = await Hive.openBox<QRResult>('scan_history');
    await box.put(scan.id, scan);
  }

  Future<void> _updateSyncedAt(String id) async {
    final box = await Hive.openBox<QRResult>('scan_history');
    final scan = box.get(id);
    if (scan != null) {
      final updated = scan.copyWith(syncedAt: DateTime.now());
      await box.put(id, updated);
    }
  }

  Map<String, dynamic> _scanToJson(QRResult scan) {
    return {
      'id': scan.id,
      'rawValue': scan.rawValue,
      'typeIndex': scan.typeIndex,
      'scannedAt': Timestamp.fromDate(scan.scannedAt),
      'syncedAt': scan.syncedAt != null ? Timestamp.fromDate(scan.syncedAt!) : null,
      'isDeleted': scan.isDeleted,
      'updatedAt': Timestamp.fromDate(scan.scannedAt),
    };
  }

  QRResult _scanFromJson(Map<String, dynamic> json) {
    return QRResult(
      id: json['id'],
      rawValue: json['rawValue'],
      typeIndex: json['typeIndex'],
      scannedAt: (json['scannedAt'] as Timestamp).toDate(),
      syncedAt: (json['syncedAt'] as Timestamp?)?.toDate(),
    );
  }
}