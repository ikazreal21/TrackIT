import 'package:flutter/material.dart';

import '../theme.dart';
import 'score_gauge.dart';

/// Big score card: title, gauge with score + 7-day delta, status word,
/// insight line. Tapping opens the metric detail screen.
class ScoreCard extends StatelessWidget {
  const ScoreCard({
    super.key,
    required this.title,
    required this.score,
    required this.color,
    required this.status,
    required this.insight,
    this.deltaPct,
    this.onTap,
  });

  final String title;
  final double? score;
  final Color color;
  final String status;
  final String insight;
  final double? deltaPct;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      size: 18, color: AppColors.textMuted),
                ],
              ),
              const SizedBox(height: 8),
              ScoreGauge(
                value01: score == null ? null : score! / 100,
                color: color,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      score == null ? '--' : score!.round().toString(),
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontSize: 44,
                        color: score == null ? AppColors.textMuted : color,
                      ),
                    ),
                    if (deltaPct != null) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            deltaPct! >= 0
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          Text(
                            '${deltaPct!.abs().round()}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text('vs 7-day avg',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontSize: 11)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(status, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                insight,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
