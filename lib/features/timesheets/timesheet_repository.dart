import '../../core/api_client.dart';
import '../hours/models.dart';
import '../hours/repository.dart';

class Timesheet {
  Timesheet.fromJson(Json json)
    : id = json['id'] as int,
      status = json['status'] as String,
      weekStart = json['week_start'] as String,
      version = json['version'] as String,
      totalMinutes = json['total_minutes'] as int,
      name = json['user_name'] as String?,
      reviewNote = json['review_note'] as String?,
      entries = (json['entries'] as List? ?? [])
          .map((e) => HoursEntry.fromJson(e as Json))
          .toList();
  final int id, totalMinutes;
  final String status, weekStart, version;
  final String? name, reviewNote;
  final List<HoursEntry> entries;
}

class TimesheetRepository {
  TimesheetRepository(this.api);
  final ApiClient api;
  Future<List<Timesheet>> list(int workspace, {bool review = false}) async {
    final result = <Timesheet>[];
    var page = 1, last = 1;
    do {
      final json = await api.request(
        'GET',
        '/workspaces/$workspace/timesheets',
        query: {'scope': review ? 'review' : 'mine', 'page': '$page'},
      );
      result.addAll(
        (json['data'] as List).map((e) => Timesheet.fromJson(e as Json)),
      );
      last = json['meta']['last_page'] as int;
      page++;
    } while (page <= last);
    return result;
  }

  Future<Timesheet> detail(int workspace, int id) async => Timesheet.fromJson(
    (await api.request('GET', '/workspaces/$workspace/timesheets/$id'))['data']
        as Json,
  );
  Future<void> submit(
    int workspace,
    DateTime start,
    String note,
    MutationKey mutation,
  ) async {
    final path = '/workspaces/$workspace/timesheets';
    final body = {'week_start': dateKey(start), 'submission_note': note};
    await api.request(
      'POST',
      path,
      body: body,
      idempotencyKey: mutation.forPayload([path, body]),
    );
  }

  Future<void> review(
    int workspace,
    Timesheet sheet,
    String decision,
    String note,
    MutationKey mutation,
  ) async {
    final path = '/workspaces/$workspace/timesheets/${sheet.id}/review';
    final body = {
      'decision': decision,
      'review_note': note,
      'version': sheet.version,
    };
    await api.request(
      'POST',
      path,
      body: body,
      idempotencyKey: mutation.forPayload([path, body]),
    );
  }
}
