import 'package:flutter/material.dart';

import '../features/hours/models.dart';
import 'widgets.dart';

class OvertimeSummary extends StatelessWidget {
  const OvertimeSummary({
    super.key,
    required this.totals,
    this.showSelected = true,
    this.showComparisons = true,
    this.dailyScope = 'this week',
    this.weeklyScope = 'this week',
  });
  final OvertimeTotals totals;
  final bool showSelected;
  final bool showComparisons;
  final String dailyScope, weeklyScope;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showSelected) ...[
          Text(
            totals.label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            totals.selectedMinutes == null
                ? 'Unavailable'
                : durationLabel(totals.selectedMinutes!),
            style: totalStyle.copyWith(fontSize: 24),
          ),
          if (showComparisons) const Divider(),
        ],
        if (showComparisons) ...[
          _comparison(
            context,
            'Daily comparison · $dailyScope',
            totals.dailyMinutes,
            missing: 'Not configured',
          ),
          const SizedBox(height: 8),
          _comparison(
            context,
            'Weekly comparison · $weeklyScope',
            totals.weeklyMinutes,
          ),
          const SizedBox(height: 8),
          Text(
            'Comparisons are alternatives, not added together.',
            style: TextStyle(
              fontSize: 12,
              color: mhpColor(context, brandMuted),
            ),
          ),
        ],
      ],
    ),
  );
  Widget _comparison(
    BuildContext context,
    String label,
    int? value, {
    String missing = 'Unavailable',
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          value == null ? missing : durationLabel(value),
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    ],
  );
}
