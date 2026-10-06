import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import 'models.dart';

/// Retain this object for an identical manual retry, including after a timeout.
/// A changed payload is a new logical operation and receives a new UUID.
class MutationKey {
  String? _payload;
  String? _key;
  String forPayload(Object payload) {
    final encoded = jsonEncode(payload);
    if (_payload != encoded) {
      _payload = encoded;
      _key = const Uuid().v4();
    }
    return _key!;
  }
}

class HoursRepository {
  HoursRepository(this.api);
  final ApiClient api;
  Future<List<Workspace>> workspaces() async =>
      ((await api.request('GET', '/workspaces'))['data'] as List)
          .map((e) => Workspace.fromJson(e as Json))
          .toList();
  Future<Workspace> createWorkspace(Json input) async => Workspace.fromJson(
    (await api.request('POST', '/workspaces', body: input))['data'] as Json,
  );
  Future<Workspace> updateSettings(
    int workspace,
    Json body,
    MutationKey mutation,
  ) async {
    final path = '/workspaces/$workspace/settings';
    return Workspace.fromJson(
      (await api.request(
            'PATCH',
            path,
            body: body,
            idempotencyKey: mutation.forPayload([path, body]),
          ))['data']
          as Json,
    );
  }

  Future<HoursPage> week(int workspace, DateTime start) async {
    return range(
      workspace,
      start,
      DateTime(start.year, start.month, start.day + 6),
    );
  }

  Future<HoursPage> range(int workspace, DateTime start, DateTime end) async {
    final first = HoursPage.fromJson(
      await api.request(
        'GET',
        '/workspaces/$workspace/hours',
        query: {
          'start': dateKey(start),
          'end': dateKey(end),
          'per_page': '100',
        },
      ),
    );
    for (var page = 2; page <= first.lastPage; page++) {
      final next = HoursPage.fromJson(
        await api.request(
          'GET',
          '/workspaces/$workspace/hours',
          query: {
            'start': dateKey(start),
            'end': dateKey(end),
            'per_page': '100',
            'page': '$page',
          },
        ),
      );
      first.entries.addAll(next.entries);
    }
    return first;
  }

  Future<HoursEntry> save(
    int workspace,
    HoursDraft draft,
    MutationKey mutation, {
    HoursEntry? existing,
  }) async {
    final path =
        '/workspaces/$workspace/hours${existing == null ? '' : '/${existing.id}'}';
    final body = draft.toJson(version: existing?.version);
    return HoursEntry.fromJson(
      (await api.request(
            existing == null ? 'POST' : 'PATCH',
            path,
            body: body,
            idempotencyKey: mutation.forPayload([path, body]),
          ))['data']
          as Json,
    );
  }

  Future<List<Project>> projects(int workspace) async {
    final projects = <Project>[];
    var page = 1, last = 1;
    do {
      final json = await api.request(
        'GET',
        '/workspaces/$workspace/projects',
        query: {'page': '$page'},
      );
      projects.addAll(
        (json['data'] as List).map((e) => Project.fromJson(e as Json)),
      );
      last = json['meta']['last_page'] as int;
      page++;
    } while (page <= last);
    return projects;
  }
}
