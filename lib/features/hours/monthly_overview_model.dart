import '../../core/api_client.dart';
import 'models.dart';
import 'repository.dart';

DateTime monthStart(DateTime date) => DateTime(date.year, date.month);
DateTime monthEnd(DateTime date) => DateTime(date.year, date.month + 1, 0);
DateTime fullWeeksEnd(DateTime month) {
  final last = monthEnd(month);
  final monday = weekStart(last);
  return DateTime(monday.year, monday.month, monday.day + 6);
}

List<DateTime> monthCells(DateTime month) {
  final start = weekStart(monthStart(month));
  final end = fullWeeksEnd(month);
  final result = <DateTime>[];
  // Calendar arithmetic, rather than 24-hour durations, preserves local dates.
  for (
    var day = start;
    !day.isAfter(end);
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    result.add(day);
  }
  return result;
}

class MonthlyTotals {
  MonthlyTotals(HoursPage page, DateTime month)
    : totalMinutes = page.totalMinutes,
      entries = List.unmodifiable(
        page.entries.where(
          (e) =>
              !e.date.isBefore(monthStart(month)) &&
              !e.date.isAfter(monthEnd(month)),
        ),
      );
  final int totalMinutes;
  final List<HoursEntry> entries;
  int get workedDays => entries.map((e) => dateKey(e.date)).toSet().length;
  int get averageMinutes =>
      workedDays == 0 ? 0 : (totalMinutes / workedDays).round();
  int get breakCount => entries.where((e) => e.breakMinutes > 0).length;
  int get paidMinutes => entries
      .where((e) => e.paidBreak)
      .fold(0, (sum, e) => sum + e.breakMinutes);
  int get unpaidMinutes => entries
      .where((e) => !e.paidBreak)
      .fold(0, (sum, e) => sum + e.breakMinutes);
}

class MonthlySnapshot {
  HoursPage? calendar, fullWeeks;
  DateTime? calendarUpdated, weeksUpdated;
  ApiFailure? calendarFailure, weeksFailure;
}

/// In-memory range cache scoped to account and workspace, cleared at sign-out.
class MonthlyOverviewModel {
  MonthlyOverviewModel(this.repository, this.notify);
  final HoursRepository repository;
  final void Function() notify;
  final Map<String, MonthlySnapshot> _cache = {};
  int _generation = 0;
  int? _user;
  Workspace? _workspace;
  DateTime? _month;
  DateTime? selectedDate;
  bool loadingCalendar = false, loadingWeeks = false;
  ApiFailure? calendarFailure, weeksFailure;
  DateTime get month => _month!;
  String get _key => '$_user:${_workspace!.id}:${dateKey(month)}';
  MonthlySnapshot? get snapshot => _workspace == null ? null : _cache[_key];
  MonthlyTotals? get totals => snapshot?.calendar == null
      ? null
      : MonthlyTotals(snapshot!.calendar!, month);
  int? get overtimeMinutes => snapshot?.fullWeeks?.overtimeMinutes;
  bool get loading => loadingCalendar || loadingWeeks;
  bool get stale => calendarFailure != null || weeksFailure != null;
  HoursEntry? get selectedEntry => totals?.entries
      .where((entry) => dateKey(entry.date) == dateKey(selectedDate!))
      .firstOrNull;
  List<HoursWeek> get weeks {
    final data = snapshot?.fullWeeks;
    if (data == null) return [];
    final byStart = {for (final week in data.weeks) dateKey(week.start): week};
    final rows = <HoursWeek>[];
    for (
      var day = weekStart(month);
      !day.isAfter(fullWeeksEnd(month));
      day = DateTime(day.year, day.month, day.day + 7)
    ) {
      rows.add(
        byStart[dateKey(day)] ??
            HoursWeek(
              start: day,
              minutes: 0,
              targetMinutes: _workspace?.targetMinutes,
            ),
      );
    }
    return rows;
  }

  bool get _needsRefresh {
    final cached = snapshot;
    if (cached?.calendar == null ||
        cached?.fullWeeks == null ||
        stale ||
        cached?.calendarUpdated == null ||
        cached?.weeksUpdated == null) {
      return true;
    }
    return DateTime.now().difference(cached!.calendarUpdated!) >
            const Duration(minutes: 5) ||
        DateTime.now().difference(cached.weeksUpdated!) >
            const Duration(minutes: 5);
  }

  void bind(int user, Workspace workspace) {
    if (_user == user && _workspace?.id == workspace.id) {
      _workspace = workspace;
      return;
    }
    ++_generation;
    _user = user;
    _workspace = workspace;
    final today = workspaceToday(workspace.timezone);
    _month = monthStart(today);
    selectedDate = today;
    loadingCalendar = loadingWeeks = false;
    calendarFailure = snapshot?.calendarFailure;
    weeksFailure = snapshot?.weeksFailure;
  }

  Future<void> ensure(int user, Workspace workspace) async {
    bind(user, workspace);
    if (!loading && _needsRefresh) {
      await refresh();
    }
  }

  Future<void> selectMonth(DateTime value) async {
    final chosen = monthStart(value);
    if (chosen == _month) return;
    ++_generation;
    _month = chosen;
    final today = workspaceToday(_workspace!.timezone);
    selectedDate = monthStart(today) == chosen ? today : chosen;
    loadingCalendar = loadingWeeks = false;
    calendarFailure = snapshot?.calendarFailure;
    weeksFailure = snapshot?.weeksFailure;
    notify();
    if (_needsRefresh) {
      await refresh();
    }
  }

  void selectDay(DateTime date) {
    if (monthStart(date) != _month) return;
    selectedDate = date;
    notify();
  }

  Future<void> refresh() async {
    final workspace = _workspace;
    if (workspace == null || _user == null) return;
    final key = _key, range = month;
    final generation = ++_generation;
    final target = _cache.putIfAbsent(key, MonthlySnapshot.new);
    loadingCalendar = loadingWeeks = true;
    calendarFailure = weeksFailure = null;
    notify();
    bool current() =>
        generation == _generation && _workspace?.id == workspace.id;
    Future<void> load(bool calendar) async {
      try {
        final page = await repository.range(
          workspace.id,
          calendar ? monthStart(range) : weekStart(range),
          calendar ? monthEnd(range) : fullWeeksEnd(range),
        );
        if (!current()) return;
        if (calendar) {
          target.calendar = page;
          target.calendarUpdated = DateTime.now();
          target.calendarFailure = null;
        } else {
          target.fullWeeks = page;
          target.weeksUpdated = DateTime.now();
          target.weeksFailure = null;
        }
      } catch (error) {
        if (!current()) return;
        final failure = error is ApiFailure
            ? error
            : const ApiFailure(
                'invalid_response',
                'Could not read your monthly hours. Please refresh.',
              );
        if (calendar) {
          calendarFailure = failure;
          target.calendarFailure = failure;
        } else {
          weeksFailure = failure;
          target.weeksFailure = failure;
        }
      } finally {
        if (current()) {
          if (calendar) {
            loadingCalendar = false;
          } else {
            loadingWeeks = false;
          }
          notify();
        }
      }
    }

    await Future.wait([load(true), load(false)]);
  }

  /// Successful writes invalidate every cached range for this workspace.
  Future<void> afterMutation(int user, Workspace workspace) async {
    bind(user, workspace);
    final retained = _key;
    _cache.removeWhere(
      (key, _) => key != retained && key.startsWith('$user:${workspace.id}:'),
    );
    await refresh();
  }

  void suspend() {
    ++_generation;
    _workspace = null;
    loadingCalendar = loadingWeeks = false;
    calendarFailure = weeksFailure = null;
  }

  void clear() {
    suspend();
    _cache.clear();
    _user = null;
    _month = null;
    selectedDate = null;
  }
}
