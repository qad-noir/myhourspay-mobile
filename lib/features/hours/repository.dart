import 'models.dart';

class AppFailure implements Exception {
  const AppFailure(this.code, this.message, {this.fields = const {}});
  final String code, message;
  final Map<String, String> fields;
}

abstract interface class HoursRepository {
  Future<List<Workspace>> workspaces();
  Future<List<HoursEntry>> week(int workspaceId, DateTime start);
  Future<void> add(int workspaceId, HoursDraft draft);
  void clear();
}

/// Contract-shaped, memory-only demonstration. Never contacts Laravel.
class DemoHoursRepository implements HoursRepository {
  final _entries = <int, List<HoursEntry>>{};
  final locked = <int>{};
  @override
  Future<List<Workspace>> workspaces() async => const [
    Workspace(1, 'My workspace'),
    Workspace(2, 'Studio team'),
  ];
  @override
  Future<List<HoursEntry>> week(int workspaceId, DateTime start) async =>
      List.unmodifiable(
        (_entries[workspaceId] ?? [])
            .where(
              (e) =>
                  !e.date.isBefore(start) &&
                  e.date.isBefore(
                    DateTime(start.year, start.month, start.day + 7),
                  ),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date)),
      );
  @override
  Future<void> add(int workspaceId, HoursDraft draft) async {
    if (locked.contains(workspaceId)) {
      throw const AppFailure(
        'timesheet_locked',
        'This timesheet is locked. Reload before making changes.',
      );
    }
    final errors = draft.validate();
    if (errors.isNotEmpty) {
      throw AppFailure(
        'validation_failed',
        'Check the highlighted fields.',
        fields: errors,
      );
    }
    final entries = _entries.putIfAbsent(workspaceId, () => []);
    if (entries.any((e) => dateKey(e.date) == dateKey(draft.date))) {
      throw const AppFailure(
        'validation_failed',
        'An entry already exists for this date.',
      );
    }
    entries.add(
      HoursEntry(
        date: draft.date,
        start: draft.start,
        end: draft.end,
        breakMinutes: draft.breakMinutes,
        paidBreak: draft.paidBreak,
        notes: draft.notes,
        netMinutes:
            HoursDraft.clock(draft.end)! -
            HoursDraft.clock(draft.start)! -
            (draft.paidBreak ? 0 : draft.breakMinutes),
      ),
    );
  }

  @override
  void clear() {
    _entries.clear();
    locked.clear();
  }
}
