import 'package:health/health.dart';

import '../models/health_data.dart';

class HealthConnectService {
  final Health _health = Health();
  bool _isConfigured = false;

  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.WEIGHT,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.HEIGHT,
  ];

  Future<void> _configure() async {
    if (!_isConfigured) {
      await _health.configure();
      _isConfigured = true;
    }
  }

  Future<(bool, String)> get isSupported async {
    try {
      await _configure();
      final status = await _health.getHealthConnectSdkStatus();
      final statusStr = status?.name ?? 'unknown';
      return (status == HealthConnectSdkStatus.sdkAvailable, statusStr);
    } catch (e) {
      return (false, e.toString());
    }
  }

  Future<(bool, String)> requestAuthorization() async {
    try {
      await _configure();
      final permissions = List.filled(_types.length, HealthDataAccess.READ);
      final authorized = await _health.requestAuthorization(
        _types,
        permissions: permissions,
      );
      return (authorized, authorized ? 'ok' : 'denied by user');
    } catch (e) {
      return (false, e.toString());
    }
  }

  Future<List<HealthRecord>> fetchRange({
    required DateTime from,
    required DateTime to,
  }) async {
    final records = <HealthRecord>[];

    for (final type in _types) {
      try {
        final points = await _health.getHealthDataFromTypes(
          types: [type],
          startTime: from,
          endTime: to,
        );
        records.addAll(points.map(HealthRecord.fromHealthPoint));
      } catch (e) {
        continue;
      }
    }
    return records;
  }

  Future<List<HealthRecord>> fetchLastNDays(int days) {
    final to = DateTime.now();
    final from = to.subtract(Duration(days: days));
    return fetchRange(from: from, to: to);
  }
}