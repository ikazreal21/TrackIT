import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/health_data.dart';
import '../theme.dart';
import '../utils/labels.dart';

/// Records tab: recent Health Connect records grouped by day.
///
/// Shows the latest 300 records; sorting + grouping is memoized so the
/// full store isn't re-scanned on every rebuild.
class RecordsTab extends StatefulWidget {
  const RecordsTab({
    super.key,
    required this.records,
    required this.onRefresh,
  });

  final List<HealthRecord> records;
  final Future<void> Function() onRefresh;

  @override
  State<RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<RecordsTab> {
  static const _limit = 300;

  List<HealthRecord>? _cachedRecords;
  Map<String, List<HealthRecord>>? _sections;
  int _total = 0;

  Map<String, List<HealthRecord>> _sectionsFor() {
    if (identical(widget.records, _cachedRecords) && _sections != null) {
      return _sections!;
    }
    final now = DateTime.now();
    final sorted = [...widget.records]
      ..sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
    _total = sorted.length;
    final sections = <String, List<HealthRecord>>{};
    for (final r in sorted.take(_limit)) {
      final local = r.dateFrom.toLocal();
      final key =
          _headerFor(DateTime(local.year, local.month, local.day), now);
      sections.putIfAbsent(key, () => []).add(r);
    }
    _cachedRecords = widget.records;
    _sections = sections;
    return sections;
  }

  String _headerFor(DateTime day, DateTime today) {
    final d = DateTime(day.year, day.month, day.day);
    final t = DateTime(today.year, today.month, today.day);
    final diff = t.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEE, MMM d').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = _sectionsFor();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: widget.onRefresh,
        color: AppColors.teal,
        child: sections.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(32),
                children: [
                  const SizedBox(height: 80),
                  const Icon(Icons.grid_view_rounded,
                      size: 56, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  Text('No records yet',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    'Pull down to fetch, or use Fetch on Home.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount:
                    sections.length + (_total > _limit ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i == sections.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Showing latest $_limit of $_total records',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    );
                  }
                  final header = sections.keys.elementAt(i);
                  final items = sections[header]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(4, 12, 4, 8),
                        child: Text(header,
                            style: theme.textTheme.titleMedium),
                      ),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var j = 0; j < items.length; j++) ...[
                              _row(theme, items[j]),
                              if (j != items.length - 1)
                                const Divider(
                                    height: 1,
                                    indent: 52,
                                    endIndent: 16,
                                    color: AppColors.border),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _row(ThemeData theme, HealthRecord r) {
    final (val, unit) = recordDisplay(r);
    final time =
        DateFormat('h:mm a').format(r.dateFrom.toLocal());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: typeColor(r.type),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(typeLabel(r.type),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    )),
                Text(time, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Text(val,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontFamily: 'monospace')),
          if (unit.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(unit, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
