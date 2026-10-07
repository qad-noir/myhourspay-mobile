import 'package:flutter/material.dart';

import '../../shared/widgets.dart';

const overtimeExplanation =
    'Daily counts hours above your daily contract. Shorter days do not cancel longer days. This recalculates overtime for past records; recorded hours and earnings stay unchanged.';

int? dailyContractMinutes(String hours, String minutes) {
  final h = hours.trim().isEmpty ? 0 : int.tryParse(hours.trim());
  final m = minutes.trim().isEmpty ? 0 : int.tryParse(minutes.trim());
  if (h == null || m == null || h < 0 || m < 0 || m > 59) return null;
  final total = h * 60 + m;
  return total >= 1 && total <= 1440 ? total : null;
}

String? weeklyHoursError(String? text) {
  final h = double.tryParse(text?.trim() ?? '');
  if (h == null || !h.isFinite || h < 1 || h > 168) return 'Enter 1–168 hours.';
  if ((h * 60 - (h * 60).round()).abs() > .000001) {
    return 'Use whole minutes, for example 37.5 hours.';
  }
  return null;
}

class OvertimePreferences extends StatelessWidget {
  const OvertimePreferences({
    super.key,
    required this.weekly,
    required this.dailyHours,
    required this.dailyMinutes,
    required this.basis,
    required this.onBasis,
    this.enabled = true,
    this.fields = const {},
    this.onChanged,
  });
  final TextEditingController weekly, dailyHours, dailyMinutes;
  final String basis;
  final ValueChanged<String> onBasis;
  final bool enabled;
  final Map<String, List<String>> fields;
  final VoidCallback? onChanged;
  String? fieldError(String key) => fields[key]?.join(' ');
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionLabel('OVERTIME'),
      const SizedBox(height: 10),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'daily', label: Text('Daily')),
          ButtonSegment(value: 'weekly', label: Text('Weekly')),
        ],
        selected: {basis},
        onSelectionChanged: enabled ? (values) => onBasis(values.single) : null,
      ),
      if (fieldError('overtime_basis') != null)
        Text(
          fieldError('overtime_basis')!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      const SizedBox(height: 20),
      TextFormField(
        controller: weekly,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Weekly contracted hours'),
        validator: (v) =>
            fieldError('weekly_target_minutes') ?? weeklyHoursError(v),
        onChanged: (_) => onChanged?.call(),
      ),
      const SizedBox(height: 8),
      Text(
        'Used for weekly progress in both modes.',
        style: TextStyle(fontSize: 12, color: mhpColor(context, brandMuted)),
      ),
      const SizedBox(height: 20),
      Text(
        basis == 'daily'
            ? 'Contracted daily hours'
            : 'Contracted daily hours (optional)',
      ),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: dailyHours,
              enabled: enabled,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Hours'),
              onChanged: (_) => onChanged?.call(),
              validator: (_) {
                if (fieldError('contracted_daily_minutes') != null) {
                  return fieldError('contracted_daily_minutes');
                }
                final empty =
                    dailyHours.text.trim().isEmpty &&
                    (dailyMinutes.text.trim().isEmpty ||
                        dailyMinutes.text.trim() == '0');
                if (empty && basis == 'weekly') return null;
                return dailyContractMinutes(
                          dailyHours.text,
                          dailyMinutes.text,
                        ) ==
                        null
                    ? 'Enter 1 min–24 hours.'
                    : null;
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: dailyMinutes,
              enabled: enabled,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Minutes'),
              onChanged: (_) => onChanged?.call(),
              validator: (v) {
                final m = v!.trim().isEmpty ? 0 : int.tryParse(v.trim());
                return m == null || m < 0 || m > 59
                    ? 'Enter 0–59 minutes.'
                    : null;
              },
            ),
          ),
        ],
      ),
      if (basis == 'weekly')
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: enabled
                ? () {
                    dailyHours.clear();
                    dailyMinutes.clear();
                    onChanged?.call();
                  }
                : null,
            child: const Text('Clear daily contract'),
          ),
        ),
      const SizedBox(height: 14),
      const InfoPanel(overtimeExplanation),
    ],
  );
}
