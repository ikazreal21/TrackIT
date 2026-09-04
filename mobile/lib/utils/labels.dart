import 'package:flutter/material.dart';

import '../models/health_data.dart';
import '../theme.dart';

/// Human labels, dot colors and number formatting shared by tabs.
class TypeMeta {
  const TypeMeta(this.label, this.color);
  final String label;
  final Color color;
}

const Map<String, TypeMeta> typeMeta = {
  'HEART_RATE': TypeMeta('Heart rate', AppColors.orange),
  'STEPS': TypeMeta('Steps', AppColors.teal),
  'DISTANCE_DELTA': TypeMeta('Distance', AppColors.ringBlue),
  'ACTIVE_ENERGY_BURNED': TypeMeta('Active calories', AppColors.orange),
  'TOTAL_CALORIES_BURNED': TypeMeta('Total calories', AppColors.orange),
  'BASAL_ENERGY_BURNED': TypeMeta('Basal calories', AppColors.orange),
  'SLEEP_SESSION': TypeMeta('Sleep', AppColors.periwinkle),
  'SLEEP_ASLEEP': TypeMeta('Asleep', AppColors.periwinkle),
  'SLEEP_LIGHT': TypeMeta('Light sleep', AppColors.periwinkle),
  'SLEEP_DEEP': TypeMeta('Deep sleep', Color(0xFF3F4A9E)),
  'SLEEP_REM': TypeMeta('REM sleep', Color(0xFF6C7BD6)),
  'SLEEP_AWAKE': TypeMeta('Awake', Color(0xFFE8EAF2)),
  'WEIGHT': TypeMeta('Weight', AppColors.teal),
  'HEIGHT': TypeMeta('Height', AppColors.textMuted),
};

String typeLabel(String type) =>
    typeMeta[type]?.label ?? type.replaceAll('_', ' ').toLowerCase();

Color typeColor(String type) =>
    typeMeta[type]?.color ?? AppColors.textMuted;

/// Whole numbers: no decimals. Fractional values: rounded to 1 decimal.
String fmtInt(num v) => v.round().toString();

String fmt1(num v) {
  final r = (v * 10).round() / 10;
  return r % 1 == 0 ? r.toInt().toString() : r.toStringAsFixed(1);
}

/// Display value + unit for a record. Sleep uses the record interval
/// because phone sleep values arrive in minutes, not seconds.
(String, String) recordDisplay(HealthRecord r) {
  final type = r.type;
  final value = r.value;
  switch (type) {
    case 'STEPS':
    case 'HEART_RATE':
    case 'ACTIVE_ENERGY_BURNED':
    case 'TOTAL_CALORIES_BURNED':
    case 'BASAL_ENERGY_BURNED':
      return (fmtInt(value), '');
    case 'DISTANCE_DELTA':
      return value >= 1000
          ? (fmt1(value / 1000), 'km')
          : (fmtInt(value), 'm');
    case 'SLEEP_SESSION':
    case 'SLEEP_ASLEEP':
    case 'SLEEP_LIGHT':
    case 'SLEEP_DEEP':
    case 'SLEEP_REM':
      final secs =
          r.dateTo.difference(r.dateFrom).inSeconds.clamp(0, 86400 * 2);
      return (fmt1(secs / 3600), 'h');
    case 'WEIGHT':
      return (fmt1(value), 'kg');
    default:
      return (fmt1(value), '');
  }
}
