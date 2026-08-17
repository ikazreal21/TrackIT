import 'package:health/health.dart';

/// Serializable health data point that can be sent to the local server.
class HealthRecord {
  final String type;
  final num value;
  final String unit;
  final DateTime dateFrom;
  final DateTime dateTo;

  HealthRecord({
    required this.type,
    required this.value,
    required this.unit,
    required this.dateFrom,
    required this.dateTo,
  });

  /// Wraps a Health Connect [point] into our serializable model,
  /// mapping its enum [HealthDataType] to a stable string key.
  factory HealthRecord.fromHealthPoint(HealthDataPoint point) {
    num pointValue = 0;
    if (point.value is num) {
      pointValue = point.value as num;
    } else if (point.value is NumericHealthValue) {
      pointValue = (point.value as NumericHealthValue).numericValue;
    }
    return HealthRecord(
      type: point.type.name,
      value: pointValue,
      unit: point.unit?.name ?? '',
      dateFrom: point.dateFrom,
      dateTo: point.dateTo,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'value': value,
        'unit': unit,
        'date_from': dateFrom.toUtc().toIso8601String(),
        'date_to': dateTo.toUtc().toIso8601String(),
      };

  @override
  String toString() =>
      '$type: $value $unit ($dateFrom -> $dateTo)';
}