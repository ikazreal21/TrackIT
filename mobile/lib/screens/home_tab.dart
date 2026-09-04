import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/health_data.dart';
import '../theme.dart';
import '../utils/labels.dart';
import '../utils/scores.dart';
import '../widgets/rings.dart';
import '../widgets/score_card.dart';

/// Home tab: date header, balance rings, Sleep + Strain score cards.
class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.records,
    required this.supported,
    required this.supportMsg,
    required this.authorized,
    required this.syncing,
    required this.onGrant,
    required this.onSync,
    required this.onOpenSleep,
    required this.onOpenStrain,
  });

  final List<HealthRecord> records;
  final bool supported;
  final String supportMsg;
  final bool authorized;
  final bool syncing;
  final VoidCallback onGrant;
  final VoidCallback onSync;
  final void Function(DateTime evening) onOpenSleep;
  final void Function(DateTime day) onOpenStrain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final nights = sleepNights(records);
    final days = dayTotals(records);

    // Last night = most recent evening on/before today.
    SleepNight? lastNight;
    for (final n in nights) {
      if (!n.evening.isAfter(today)) lastNight = n;
    }
    final priorNights = nights
        .where((n) =>
            n.evening.isBefore(lastNight?.evening ?? today) &&
            n.evening.isAfter(
                (lastNight?.evening ?? today).subtract(const Duration(days: 8))))
        .toList();
    final lastHours = lastNight?.hours;
    final priorAvgHours = priorNights.isEmpty
        ? null
        : priorNights.map((n) => n.hours).reduce((a, b) => a + b) /
            priorNights.length;

    final todayT = days[today] ?? DayTotals();
    final priorDays = [
      for (var i = 1; i <= 7; i++) days[today.subtract(Duration(days: i))]
    ].whereType<DayTotals>().toList();

    final sleep = lastHours == null ? null : sleepScore(lastHours);
    final sleepDelta = deltaPct(
      lastHours,
      priorAvgHours,
    );
    final strain = strainScore(todayT);
    final priorStrain = priorDays.isEmpty
        ? null
        : priorDays
                .map(strainScore)
                .whereType<double>()
                .fold<double>(0, (a, b) => a + b) /
            priorDays.map(strainScore).whereType<double>().length;
    final strainDelta = deltaPct(
      strain,
      priorStrain?.isNaN == true ? null : priorStrain,
    );
    final recovery = recoveryScore(sleep, strain);

    final lastEvening = lastNight?.evening ??
        today.subtract(const Duration(days: 1));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Header row: avatar + pill ... sync action.
          Row(
            children: [
              const CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.cardElevated,
                child: Icon(Icons.monitor_heart,
                    size: 19, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.cardElevated,
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: AppColors.border, width: 1),
                ),
                child: Text('Local',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    )),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Fetch + upload',
                onPressed: syncing ? null : onSync,
                icon: syncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            DateFormat("'Today,' d MMMM").format(now),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (!supported && supportMsg.isNotEmpty)
            _noteCard(theme,
                'Health Connect not available: $supportMsg', null),
          if (supported && !authorized)
            _noteCard(
              theme,
              'Grant Health Connect access once — it stays on, no need to grant again.',
              ('Grant access', onGrant),
            ),
          _BalanceCard(
            sleep: sleep,
            strain: strain,
            recovery: recovery,
            stepsToday: todayT.steps,
            activeCalToday: todayT.activeCal,
            avgHrToday: todayT.avgHr,
          ),
          const SizedBox(height: 12),
          ScoreCard(
            title: 'Sleep',
            score: sleep,
            color: AppColors.teal,
            status: sleep == null ? 'No data' : bandFor(sleep),
            insight: sleepInsight(sleep),
            deltaPct: sleepDelta,
            onTap: () => onOpenSleep(lastEvening),
          ),
          const SizedBox(height: 12),
          ScoreCard(
            title: 'Strain',
            score: strain,
            color: AppColors.orange,
            status: strain == null ? 'No data' : bandFor(strain),
            insight: strainInsight(strain),
            deltaPct: strainDelta,
            onTap: () => onOpenStrain(today),
          ),
        ],
      ),
    );
  }

  Widget _noteCard(ThemeData theme, String text,
      (String, VoidCallback)? action) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
            if (action != null) ...[
              const SizedBox(width: 8),
              FilledButton(
                  onPressed: action.$2, child: Text(action.$1)),
            ],
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.sleep,
    required this.strain,
    required this.recovery,
    required this.stepsToday,
    required this.activeCalToday,
    required this.avgHrToday,
  });

  final double? sleep;
  final double? strain;
  final double? recovery;
  final double stepsToday;
  final double activeCalToday;
  final double? avgHrToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Rings(values: [
              (sleep == null ? null : sleep! / 100, AppColors.teal),
              (strain == null ? null : strain! / 100, AppColors.orange),
              (
                recovery == null ? null : recovery! / 100,
                AppColors.ringBlue
              ),
            ]),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recovery == null
                        ? 'No data yet'
                        : bandFor(recovery!),
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Today at a glance',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  _miniStat(theme, 'Steps', fmtInt(stepsToday),
                      AppColors.teal),
                  _miniStat(theme, 'Active kcal', fmtInt(activeCalToday),
                      AppColors.orange),
                  _miniStat(theme, 'Avg HR',
                      avgHrToday == null ? '--' : fmtInt(avgHrToday!),
                      AppColors.ringBlue),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(
      ThemeData theme, String label, String value, Color dot) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.bodySmall),
          const Spacer(),
          Text(value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}
