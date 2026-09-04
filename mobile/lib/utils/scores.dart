import '../models/health_data.dart';

/// Pure score math behind the Home tab gauges. Everything is computed from
/// locally stored Health Connect records — no network involved.

const _sleepTypes = {
  'SLEEP_SESSION',
  'SLEEP_ASLEEP',
  'SLEEP_LIGHT',
  'SLEEP_DEEP',
  'SLEEP_REM',
};

DateTime _day(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Interval seconds for a record. Sleep values from Health Connect arrive
/// in minutes (older data may use seconds), so durations are derived from
/// the record interval instead of trusting `value`.
double _intervalSecs(HealthRecord r) =>
    r.dateTo.difference(r.dateFrom).inSeconds.toDouble().clamp(0, 86400 * 2).toDouble();

/// A night of sleep, keyed by the evening date it started on.
class SleepNight {
  SleepNight(this.evening, this.secondsByStage);
  final DateTime evening;
  final Map<String, double> secondsByStage;

  double get totalSeconds =>
      secondsByStage.values.fold(0.0, (a, b) => a + b);

  double get hours => totalSeconds / 3600;
}

/// Groups sleep records into nights. A record belongs to the night of its
/// start date, unless it starts before noon (tail end of last night).
List<SleepNight> sleepNights(List<HealthRecord> records) {
  final byNight = <DateTime, Map<String, double>>{};
  for (final r in records) {
    if (!_sleepTypes.contains(r.type)) continue;
    // Prefer session-level totals; stage rows are used for breakdowns.
    if (r.type != 'SLEEP_SESSION' && r.type != 'SLEEP_ASLEEP') continue;
    final local = r.dateFrom.toLocal();
    var evening = _day(local);
    if (local.hour < 12) {
      evening = evening.subtract(const Duration(days: 1));
    }
    byNight.putIfAbsent(evening, () => {})[r.type] =
        (byNight[evening]![r.type] ?? 0) + _intervalSecs(r);
  }
  final nights = byNight.entries
      .map((e) => SleepNight(e.key, e.value))
      .toList()
    ..sort((a, b) => a.evening.compareTo(b.evening));
  return nights;
}

/// Stage-level seconds for one night (for the hypnogram + breakdown).
Map<String, double> nightStages(
    List<HealthRecord> records, DateTime evening) {
  const stageTypes = {
    'SLEEP_AWAKE',
    'SLEEP_ASLEEP',
    'SLEEP_LIGHT',
    'SLEEP_DEEP',
    'SLEEP_REM',
  };
  final out = <String, double>{};
  for (final r in records) {
    if (!stageTypes.contains(r.type)) continue;
    final local = r.dateFrom.toLocal();
    var night = _day(local);
    if (local.hour < 12) night = night.subtract(const Duration(days: 1));
    if (night != evening) continue;
    out[r.type] = (out[r.type] ?? 0) + _intervalSecs(r);
  }
  // Fall back to session totals as a single "asleep" block.
  if (out.isEmpty) {
    double sessionSecs = 0;
    for (final r in records) {
      if (r.type != 'SLEEP_SESSION' && r.type != 'SLEEP_ASLEEP') continue;
      final local = r.dateFrom.toLocal();
      var night = _day(local);
      if (local.hour < 12) night = night.subtract(const Duration(days: 1));
      if (night == evening) sessionSecs += _intervalSecs(r);
    }
    if (sessionSecs > 0) out['SLEEP_ASLEEP'] = sessionSecs;
  }
  return out;
}

/// Raw segments (start/end/stage) for the hypnogram timeline.
List<({DateTime start, DateTime end, String stage})> nightSegments(
    List<HealthRecord> records, DateTime evening) {
  const stageTypes = {
    'SLEEP_AWAKE',
    'SLEEP_ASLEEP',
    'SLEEP_LIGHT',
    'SLEEP_DEEP',
    'SLEEP_REM',
  };
  final segs = <({DateTime start, DateTime end, String stage})>[];
  for (final r in records) {
    if (!stageTypes.contains(r.type)) continue;
    final local = r.dateFrom.toLocal();
    var night = _day(local);
    if (local.hour < 12) night = night.subtract(const Duration(days: 1));
    if (night != evening) continue;
    segs.add((
      start: r.dateFrom.toLocal(),
      end: r.dateTo.toLocal(),
      stage: r.type,
    ));
  }
  segs.sort((a, b) => a.start.compareTo(b.start));
  // Collapse a bare session record into one asleep block.
  if (segs.isEmpty) {
    for (final r in records) {
      if (r.type != 'SLEEP_SESSION' && r.type != 'SLEEP_ASLEEP') continue;
      final local = r.dateFrom.toLocal();
      var night = _day(local);
      if (local.hour < 12) night = night.subtract(const Duration(days: 1));
      if (night == evening) {
        segs.add((
          start: r.dateFrom.toLocal(),
          end: r.dateTo.toLocal(),
          stage: 'SLEEP_ASLEEP',
        ));
      }
    }
  }
  return segs;
}

class DayTotals {
  DayTotals({
    this.steps = 0,
    this.distanceM = 0,
    this.activeCal = 0,
    this.totalCal = 0,
    this.hrSum = 0,
    this.hrCount = 0,
    this.hrMin = double.infinity,
    this.hrMax = double.negativeInfinity,
  });
  double steps;
  double distanceM;
  double activeCal;
  double totalCal;
  double hrSum;
  int hrCount;
  double hrMin;
  double hrMax;

  double? get avgHr => hrCount == 0 ? null : hrSum / hrCount;
}

/// Aggregates activity + heart records per local calendar day.
Map<DateTime, DayTotals> dayTotals(List<HealthRecord> records) {
  final out = <DateTime, DayTotals>{};
  for (final r in records) {
    final day = _day(r.dateFrom.toLocal());
    final t = out.putIfAbsent(day, DayTotals.new);
    switch (r.type) {
      case 'STEPS':
        t.steps += r.value.toDouble();
      case 'DISTANCE_DELTA':
        t.distanceM += r.value.toDouble();
      case 'ACTIVE_ENERGY_BURNED':
        t.activeCal += r.value.toDouble();
      case 'TOTAL_CALORIES_BURNED':
        t.totalCal += r.value.toDouble();
      case 'HEART_RATE':
        final v = r.value.toDouble();
        t.hrSum += v;
        t.hrCount++;
        if (v < t.hrMin) t.hrMin = v;
        if (v > t.hrMax) t.hrMax = v;
    }
  }
  return out;
}

/// 0–100 sleep score from hours. 8h is perfect, tapers past 9h.
double? sleepScore(double hours) {
  if (hours <= 0) return null;
  if (hours > 9) return (100 - (hours - 9) * 15).clamp(0, 100).toDouble();
  return (hours / 8 * 100).clamp(0, 100).toDouble();
}

/// 0–100 exertion score from steps + active calories.
double? strainScore(DayTotals t) {
  if (t.steps == 0 && t.activeCal == 0) return null;
  return (t.steps / 12000 * 60 + t.activeCal / 600 * 40)
      .clamp(0, 100)
      .toDouble();
}

/// Recovery blends last-night sleep with today's (inverse) strain.
double? recoveryScore(double? sleep, double? strain) {
  if (sleep == null && strain == null) return null;
  if (sleep == null) return (100 - strain!).clamp(0, 100).toDouble();
  if (strain == null) return sleep;
  return (sleep * 0.65 + (100 - strain) * 0.35).clamp(0, 100).toDouble();
}

/// Percent change of [current] vs [baseline]. Null when not computable.
double? deltaPct(double? current, double? baseline) {
  if (current == null || baseline == null || baseline == 0) return null;
  return (current - baseline) / baseline * 100;
}

String bandFor(double score) {
  if (score >= 85) return 'Optimal';
  if (score >= 70) return 'Good';
  if (score >= 55) return 'Fair';
  return 'Poor';
}

String sleepInsight(double? score) {
  if (score == null) return 'No sleep recorded. Fetch your stats to fill this in.';
  if (score >= 85) {
    return 'Your sleep quality was excellent last night. Keep up your good sleep habits.';
  }
  if (score >= 70) {
    return 'Solid night. A slightly earlier bedtime could push this higher.';
  }
  if (score >= 55) {
    return 'Below your usual. Watch late screens and caffeine today.';
  }
  return 'Rough night. Prioritize an early bedtime to recover.';
}

String strainInsight(double? score) {
  if (score == null) {
    return 'No activity recorded yet. Fetch your stats to fill this in.';
  }
  if (score >= 85) return 'Big day of training. Fuel up and sleep well tonight.';
  if (score >= 70) return 'Strong output today. Keep the momentum going.';
  if (score >= 55) return 'Moderate day. A walk or short session fits well.';
  return 'Your strain level is low today. Consider taking it easy and prioritize recovery.';
}
