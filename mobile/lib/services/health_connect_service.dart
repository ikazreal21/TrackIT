import 'package:health/health.dart';

import '../models/health_data.dart';

class HealthConnectService {
  final Health _health = Health();
  bool _configured = false;

  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.WEIGHT,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.HEIGHT,
  ];

  Future<void> _ensureConfigured() async {
    if (!_configured) {
      await _health.configure();
      _configured = true;
    }
  }

  Future<bool> get isSupported async {
    try {
      await _ensureConfigured();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestAuthorization() async {
    try {
      await _ensureConfigured();
      final authorized = await _health.requestAuthorization(_types);
      return authorized;
    } catch (_) {
      return false;
    }
  }

  Future<List<HealthRecord>> fetchRange({
    required DateTime from,
    required DateTime to,
  }) async {
    await _ensureConfigured();
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