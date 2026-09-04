import 'package:flutter/material.dart';

import '../models/health_data.dart';
import '../theme.dart';
import '../utils/labels.dart';
import '../utils/scores.dart';
import '../widgets/score_gauge.dart';

/// Strain detail: big gauge, hourly activity bars, metric rows.
class StrainDetailScreen extends StatelessWidget {
  const StrainDetailScreen({
    super.key,
    required this.records,
    required this.day,
  });

  final List<HealthRecord> records;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = dayTotals(records);
    final t = days[DateTime(day.year, day.month, day.day)] ?? DayTotals();

    final priors = [
      for (var i = 1; i <= 7; i++)
        days[DateTime(day.year, day.month, day.day)
            .subtract(Duration(days: i))]
    ].whereType<DayTotals>().toList();
    double? priorAvg(num Function(DayTotals) pick) {
      if (priors.isEmpty) return null;
      return priors.map(pick).reduce((a, b) => a + b) / priors.length;
    }

    final score = strainScore(t);
    final strainDelta = deltaPct(
      score,
      priorAvg((d) => strainScore(d) ?? 0),
    );

    final hourly = List<double>.filled(24, 0);
    for (final r in records) {
      if (r.type != 'STEPS') continue;
      final local = r.dateFrom.toLocal();
      if (local.year != day.year ||
          local.month != day.month ||
          local.day != day.day) {
        continue;
      }
      hourly[local.hour] += r.value.toDouble();
    }
    final maxH = hourly.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Strain'),
      ),
      body: (t.steps == 0 && t.activeCal == 0)
          ? _empty(theme)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                    child: Column(
                      children: [
                        ScoreGauge(
                          value01:
                              score == null ? null : score / 100,
                          color: AppColors.orange,
                          size: 210,
                          stroke: 14,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                score == null
                                    ? '--'
                                    : score.round().toString(),
                                style: theme.textTheme.headlineLarge
                                    ?.copyWith(
                                  fontSize: 52,
                                  color: AppColors.orange,
                                ),
                              ),
                              if (strainDelta != null &&
                                  !strainDelta.isNaN)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      strainDelta >= 0
                                          ? Icons.arrow_upward
                                          : Icons.arrow_downward,
                                      size: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                    Text(
                                        '${strainDelta.abs().round()}%',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color:
                                              AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        )),
                                  ],
                                ),
                              Text('vs 7-day avg',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(fontSize: 11)),
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
                          strainInsight(score),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(18, 18, 18, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Activity through the day',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 110,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (var h = 0; h < 24; h++)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 1.5),
                                    child: FractionallySizedBox(
                                      heightFactor: maxH == 0
                                          ? 0
                                          : (hourly[h] / maxH)
                                              .clamp(0.03, 1.0),
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: hourly[h] == 0
                                              ? AppColors.cardElevated
                                              : AppColors.orange,
                                          borderRadius:
                                              BorderRadius.circular(2.5),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            _AxisLabel('12 am'),
                            _AxisLabel('6 am'),
                            _AxisLabel('12 pm'),
                            _AxisLabel('6 pm'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(18, 8, 18, 14),
                    child: Column(
                      children: [
                        _metricRow(
                          theme,
                          'Steps',
                          fmtInt(t.steps),
                          t.steps,
                          priorAvg((d) => d.steps),
                        ),
                        _metricRow(
                          theme,
                          'Distance',
                          t.distanceM >= 1000
                              ? '${fmt1(t.distanceM / 1000)} km'
                              : '${fmtInt(t.distanceM)} m',
                          t.distanceM,
                          priorAvg((d) => d.distanceM),
                        ),
                        _metricRow(
                          theme,
                          'Active calories',
                          '${fmtInt(t.activeCal)} kcal',
                          t.activeCal,
                          priorAvg((d) => d.activeCal),
                          isLast: true,
                        ),
                        if (t.avgHr != null)
                          _hrRow(theme, t),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _metricRow(ThemeData theme, String label, String value,
      double current, double? baseline,
      {bool isLast = false}) {
    final frac = baseline == null || baseline == 0
        ? (current > 0 ? 1.0 : 0.0)
        : (current / (baseline * 1.5)).clamp(0.0, 1.0);
    return Padding(
      padding: EdgeInsets.only(top: 12, bottom: isLast ? 4 : 0),
      child: Column(
        children: [
          Row(
            children: [
              Text(label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  )),
              const Spacer(),
              Text(value, style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 13,
              backgroundColor: AppColors.cardElevated,
              valueColor:
                  const AlwaysStoppedAnimation(AppColors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hrRow(ThemeData theme, DayTotals t) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Row(
        children: [
          Text('Avg heart rate',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              )),
          const Spacer(),
          Text(
            '${fmtInt(t.avgHr!)} bpm  (${fmtInt(t.hrMin)}–${fmtInt(t.hrMax)})',
            style: theme.textTheme.bodySmall,
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
            const Icon(Icons.local_fire_department_outlined,
                size: 56, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('No activity recorded',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Fetch your stats from the Home tab to see your strain breakdown.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(fontSize: 11));
  }
}
