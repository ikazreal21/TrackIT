import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/health_data.dart';
import '../theme.dart';
import '../utils/labels.dart';
import '../utils/scores.dart';
import '../widgets/score_gauge.dart';

/// Sleep detail: big gauge, hypnogram timeline, stage breakdown rows.
class SleepDetailScreen extends StatelessWidget {
  const SleepDetailScreen({
    super.key,
    required this.records,
    required this.evening,
  });

  final List<HealthRecord> records;
  final DateTime evening;

  String _dur(double secs) {
    final h = secs ~/ 3600;
    final m = ((secs % 3600) / 60).round();
    if (h == 0) return '$m min';
    return '${h}h ${m.toString().padLeft(2, '0')} min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stages = nightStages(records, evening);
    final segs = nightSegments(records, evening);
    final total = stages.values.fold(0.0, (a, b) => a + b);
    final hours = total / 3600;
    final score = sleepScore(hours);

    final nights = sleepNights(records);
    final idx = nights.indexWhere((n) => n.evening == evening);
    final prior = [
      for (var i = idx - 7; i < idx; i++)
        if (i >= 0) nights[i].hours
    ];
    final priorAvg = prior.isEmpty
        ? null
        : prior.reduce((a, b) => a + b) / prior.length;

    const order = [
      'SLEEP_AWAKE',
      'SLEEP_LIGHT',
      'SLEEP_REM',
      'SLEEP_DEEP',
      'SLEEP_ASLEEP',
    ];
    final present = order.where(stages.containsKey).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Sleep'),
      ),
      body: total == 0
          ? _empty(theme)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _scoreBlock(theme, score,
                    deltaPct(hours, priorAvg)),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                    child: Column(
                      children: [
                        _Hypnogram(segs: segs),
                        const SizedBox(height: 8),
                        _axis(theme, segs),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                    child: Column(
                      children: [
                        for (var i = 0; i < present.length; i++)
                          _stageRow(
                            theme,
                            present[i],
                            stages[present[i]]!,
                            total,
                            isLast: i == present.length - 1,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _scoreBlock(ThemeData theme, double? score, double? delta) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        child: Column(
          children: [
            ScoreGauge(
              value01: score == null ? null : score / 100,
              color: AppColors.teal,
              size: 210,
              stroke: 14,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    score == null ? '--' : score.round().toString(),
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontSize: 52,
                      color: AppColors.teal,
                    ),
                  ),
                  if (delta != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          delta >= 0
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        Text('${delta.abs().round()}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  Text('vs 7-day avg',
                      style:
                          theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              score == null ? 'No data' : bandFor(score),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              sleepInsight(score),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _axis(ThemeData theme,
      List<({DateTime start, DateTime end, String stage})> segs) {
    final start = segs.map((s) => s.start).reduce((a, b) => a.isBefore(b) ? a : b);
    final end = segs.map((s) => s.end).reduce((a, b) => a.isAfter(b) ? a : b);
    final span = end.difference(start).inSeconds;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i <= 4; i++)
          Text(
            DateFormat('h a')
                .format(start.add(Duration(seconds: span * i ~/ 4)))
                .toLowerCase(),
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
      ],
    );
  }

  Widget _stageRow(ThemeData theme, String stage, double secs,
      double total, {required bool isLast}) {
    final pct = total == 0 ? 0 : secs / total * 100;
    final meta = typeMeta[stage];
    return Padding(
      padding: EdgeInsets.only(top: 12, bottom: isLast ? 4 : 0),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${meta?.label ?? stage}  ${pct.round()}%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(_dur(secs), style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : secs / total,
              minHeight: 13,
              backgroundColor: AppColors.cardElevated,
              valueColor:
                  AlwaysStoppedAnimation(meta?.color ?? AppColors.periwinkle),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bedtime_outlined,
                size: 56, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('No sleep recorded',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Fetch your stats from the Home tab to see your sleep breakdown.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Banded timeline: one row per stage, blocks positioned on a shared clock.
class _Hypnogram extends StatelessWidget {
  const _Hypnogram({required this.segs});
  final List<({DateTime start, DateTime end, String stage})> segs;

  static const _bands = [
    'SLEEP_AWAKE',
    'SLEEP_LIGHT',
    'SLEEP_REM',
    'SLEEP_DEEP',
    'SLEEP_ASLEEP',
  ];

  @override
  Widget build(BuildContext context) {
    if (segs.isEmpty) return const SizedBox(height: 120);
    final start =
        segs.map((s) => s.start).reduce((a, b) => a.isBefore(b) ? a : b);
    final end =
        segs.map((s) => s.end).reduce((a, b) => a.isAfter(b) ? a : b);

    int flexOf(Duration d) => d.inSeconds.clamp(1, 1 << 31);

    return Column(
      children: [
        for (final band in _bands)
          if (segs.any((s) => s.stage == band))
            Builder(builder: (ctx) {
              final mine = segs.where((s) => s.stage == band).toList();
              var cursor = start;
              final kids = <Widget>[];
              for (final s in mine) {
                final gap = s.start.difference(cursor);
                if (gap.inSeconds > 0) {
                  kids.add(Expanded(
                      flex: flexOf(gap), child: const SizedBox()));
                }
                kids.add(Expanded(
                  flex: flexOf(s.end.difference(s.start)),
                  child: Container(
                    height: 24,
                    decoration: BoxDecoration(
                      color:
                          typeMeta[band]?.color ?? AppColors.periwinkle,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ));
                cursor = s.end;
              }
              final tail = end.difference(cursor);
              if (tail.inSeconds > 0) {
                kids.add(
                    Expanded(flex: flexOf(tail), child: const SizedBox()));
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: SizedBox(
                  height: 24,
                  child: Row(children: kids),
                ),
              );
            }),
      ],
    );
  }
}
