import 'dart:developer';

import 'package:workmanager/workmanager.dart';

import 'api_service.dart';
import 'health_connect_service.dart';
import 'settings_service.dart';

const String weeklySyncTask = 'trackit.weeklySync';
const String dailySyncTask = 'trackit.dailySync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    log('Background sync task started: $task');

    try {
      final settings = SettingsService();
      final url = await settings.serverUrl;
      final days = await settings.daysToFetch;
      final autoSync = await settings.autoSyncEnabled;

      if (!autoSync || url == null || url.isEmpty) {
        log('Auto sync disabled or no server URL configured');
        return Future.value(true);
      }

      final health = HealthConnectService();
      final records = await health.fetchLastNDays(days);
      log('Fetched ${records.length} records in background');

      if (records.isEmpty) {
        return Future.value(true);
      }

      final api = ApiService(baseUrl: url);
      final created = await api.uploadRecords(records);
      log('Uploaded $created records in background');

      return Future.value(true);
    } catch (e, stack) {
      log('Background sync failed: $e', stackTrace: stack);
      return Future.value(false);
    }
  });
}

class BackgroundSyncService {
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  }

  static Future<void> scheduleWeekly() async {
    await Workmanager().registerPeriodicTask(
      weeklySyncTask,
      weeklySyncTask,
      frequency: const Duration(days: 7),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    log('Weekly background sync scheduled');
  }

  static Future<void> scheduleDaily() async {
    await Workmanager().registerPeriodicTask(
      dailySyncTask,
      dailySyncTask,
      frequency: const Duration(days: 1),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    log('Daily background sync scheduled');
  }

  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
    log('Background sync cancelled');
  }

  static Future<void> runOneTimeTest() async {
    await Workmanager().registerOneOffTask(
      'trackit.testSync',
      dailySyncTask,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    log('One-time background sync test scheduled');
  }
}
