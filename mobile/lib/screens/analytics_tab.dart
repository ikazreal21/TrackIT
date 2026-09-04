import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/health_data.dart';
import '../theme.dart';
import '../utils/labels.dart';
import '../widgets/stat_card.dart';

enum _Range { day, week, month, custom }

/// Analytics tab: Day / Week / Month / Custom range with a date navigator.
/// All stat cards reflect the selected window — never lifetime totals.
class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({super.key, required this.records});

  final List<HealthRecord> records;

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  _Range _range = _Range.week;
  late DateTime _anchor;
  late DateTime _customStart;
  late DateTime _customEnd;

  // Memoized window filter — rebuilt only when inputs change.
  List<HealthRecord>? _cachedRecords;
  _Range? _cachedRange;
  DateTime? _cachedAnchor;
  DateTime? _cachedCustomStart;
  DateTime? _cachedCustomEnd;
  List<HealthRecord>? _cachedInView;

  List<HealthRecord> _inViewMemo() {
    if (identical(widget.records, _cachedRecords) &&
        _cachedRange == _range &&
        _cachedAnchor == _anchor &&
        _cachedCustomStart == _customStart &&
        _cachedCustomEnd == _customEnd &&
        _cachedInView != null) {
      return _cachedInView!;
    }
    final (s, e) = _window();
    _cachedInView = widget.records
        .where((r) => !r.dateFrom.isBefore(s) && r.dateFrom.isBefore(e))
        .toList();
    _cachedRecords = widget.records;
    _cachedRange = _range;
    _cachedAnchor = _anchor;
    _cachedCustomStart = _customStart;
    _cachedCustomEnd = _customEnd;
    return _cachedInView!;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchor = DateTime(now.year, now.month, now.day);
    _customEnd = _anchor;
    _customStart = _anchor.subtract(const Duration(days: 6));
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  (DateTime, DateTime) _window() {
    switch (_range) {
      case _Range.day:
        return (_anchor, _anchor.add(const Duration(days: 1)));
      case _Range.week:
        return (_anchor.subtract(const Duration(days: 6)),
            _anchor.add(const Duration(days: 1)));
      case _Range.month:
        return (_anchor.subtract(const Duration(days: 29)),
            _anchor.add(const Duration(days: 1)));
      case _Range.custom:
        return (_customStart, _customEnd.add(const Duration(days: 1)));
    }
  }

  int get _spanDays {
    final (s, e) = _window();
    return e.difference(s).inDays.clamp(1, 10000);
  }

  List<HealthRecord> get _inView => _inViewMemo();

  String _rangeLabel() {
    final (s, e) = _window();
    final last = e.subtract(const Duration(days: 1));
    if (_range == _Range.day) return DateFormat('EEE, MMM d').format(s);
    return '${DateFormat('MMM d').format(s)} – ${DateFormat('MMM d').format(last)}';
  }

  List<HealthRecord> _of(List<HealthRecord> rs, Set<String> types) =>
      rs.where((r) => types.contains(r.type)).toList();

  num _sum(List<HealthRecord> rs) => rs.fold<num>(0, (s, r) => s + r.value);

  /// Sleep hours from record intervals (values arrive in minutes from
  /// Health Connect, so `value` can't be trusted for sleep).
  double _sleepSecs(List<HealthRecord> rs) => rs.fold<double>(
      0,
      (s, r) => s +
          r.dateTo.difference(r.dateFrom).inSeconds.clamp(0, 86400 * 2));

  Future<void> _pickAnchor() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(2000),
      lastDate: _today,
    );
    if (picked != null && mounted) {
      setState(
          () => _anchor = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickCustomBound(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _customStart : _customEnd,
      firstDate: DateTime(2000),
      lastDate: _today,
    );
    if (picked == null || !mounted) return;
    final d = DateTime(picked.year, picked.month, picked.day);
    setState(() {
      if (isStart) {
        _customStart = d;
        if (_customStart.isAfter(_customEnd)) _customEnd = _customStart;
      } else {
        _customEnd = d;
        if (_customEnd.isBefore(_customStart)) _customStart = _customEnd;
      }
    });
  }

  void _shiftAnchor(int days) {
    final next = _anchor.add(Duration(days: days));
    if (next.isAfter(_today)) return;
    setState(() => _anchor = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inView = _inView;
    final span = _spanDays;
    final atToday = !_anchor.isBefore(_today);

    final steps = _of(inView, {'STEPS'});
    final dist = _of(inView, {'DISTANCE_DELTA'});
    final cals = _of(inView, {
      'ACTIVE_ENERGY_BURNED',
      'TOTAL_CALORIES_BURNED',
      'BASAL_ENERGY_BURNED'
    });
    final sleep = _of(inView, {
      'SLEEP_SESSION',
      'SLEEP_ASLEEP',
      'SLEEP_LIGHT',
      'SLEEP_DEEP',
      'SLEEP_REM'
    });
    final hr = _of(inView, {'HEART_RATE'});
    final weight = _of(inView, {'WEIGHT'})..sort((a, b) => b.dateFrom.compareTo(a.dateFrom));

    final stepsTotal = _sum(steps);
    final distM = _sum(dist);
    final calTotal = _sum(cals);
    final sleepH = _sleepSecs(sleep) / 3600;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_Range>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(
                    TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                segments: const [
                  ButtonSegment(value: _Range.day, label: Text('Day')),
                  ButtonSegment(value: _Range.week, label: Text('Week')),
                  ButtonSegment(value: _Range.month, label: Text('Month')),
                  ButtonSegment(value: _Range.custom, label: Text('Custom')),
                ],
                selected: {_range},
                onSelectionChanged: (s) => setState(() => _range = s.first),
              ),
            ),
          ),
          if (_range == _Range.custom)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickCustomBound(true),
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: Text(
                          DateFormat('MMM d, y').format(_customStart)),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('→',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickCustomBound(false),
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label:
                          Text(DateFormat('MMM d, y').format(_customEnd)),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _shiftAnchor(_range == _Range.day
                        ? -1
                        : _range == _Range.week
                            ? -7
                            : -30),
                  ),
                  TextButton.icon(
                    onPressed: _pickAnchor,
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: Text(_rangeLabel(),
                        style: theme.textTheme.titleMedium),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: atToday
                        ? null
                        : () => _shiftAnchor(_range == _Range.day
                            ? 1
                            : _range == _Range.week
                                ? 7
                                : 30),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              '${inView.length} records in view • ${widget.records.length} total',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
              children: [
                StatCard(
                  title: 'Steps',
                  icon: Icons.directions_walk,
                  accent: AppColors.teal,
                  value: steps.isEmpty ? '--' : fmtInt(stepsTotal),
                  subtitle: steps.isEmpty
                      ? 'no data in view'
                      : 'avg ${fmtInt(stepsTotal / span)} / day',
                ),
                StatCard(
                  title: 'Distance',
                  icon: Icons.map,
                  accent: AppColors.ringBlue,
                  value: dist.isEmpty
                      ? '--'
                      : distM >= 1000
                          ? '${fmt1(distM / 1000)} km'
                          : '${fmtInt(distM)} m',
                  subtitle: dist.isEmpty
                      ? 'no data in view'
                      : '${dist.length} readings',
                ),
                StatCard(
                  title: 'Calories',
                  icon: Icons.local_fire_department,
                  accent: AppColors.orange,
                  value: cals.isEmpty ? '--' : fmtInt(calTotal),
                  subtitle: cals.isEmpty
                      ? 'no data in view'
                      : 'avg ${fmtInt(calTotal / span)} / day',
                ),
                StatCard(
                  title: 'Sleep',
                  icon: Icons.bedtime,
                  accent: AppColors.periwinkle,
                  value: sleep.isEmpty ? '--' : '${fmt1(sleepH)} h',
                  subtitle: sleep.isEmpty
                      ? 'no data in view'
                      : 'avg ${fmt1(sleepH / span)} h / night',
                ),
                StatCard(
                  title: 'Heart rate (avg)',
                  icon: Icons.favorite,
                  accent: AppColors.orange,
                  value: hr.isEmpty
                      ? '--'
                      : fmtInt(_sum(hr) / hr.length),
                  subtitle: hr.isEmpty
                      ? 'no data in view'
                      : '${hr.length} readings',
                ),
                StatCard(
                  title: 'Weight (latest)',
                  icon: Icons.monitor_weight_outlined,
                  accent: AppColors.teal,
                  value: weight.isEmpty
                      ? '--'
                      : '${fmt1(weight.first.value)} kg',
                  subtitle: weight.isEmpty
                      ? 'no data in view'
                      : DateFormat('MMM d')
                          .format(weight.first.dateFrom.toLocal()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
