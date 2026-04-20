import 'package:workmanager/workmanager.dart';

import 'sync_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'periodicSync':
        try {
          final syncService = SyncService();
          await syncService.initialize();
          await syncService.fullSync();
          return true;
        } catch (e) {
          return false;
        }
      default:
        return true;
    }
  });
}

class BackgroundSyncConfig {
  static const String _periodicSyncTask = 'periodicSync';
  static const Duration _syncInterval = Duration(hours: 6);

  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    await registerPeriodicSync();
  }

  static Future<void> registerPeriodicSync() async {
    await Workmanager().registerPeriodicTask(
      _periodicSyncTask,
      _periodicSyncTask,
      frequency: _syncInterval,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  static Future<void> cancelPeriodicSync() async {
    await Workmanager().cancelByUniqueName(_periodicSyncTask);
  }

  static Future<void> runImmediateSync() async {
    await Workmanager().registerOneOffTask(
      'immediateSync',
      _periodicSyncTask,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }
}