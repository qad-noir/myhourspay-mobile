import 'package:flutter/foundation.dart';

import '../hours/models.dart';
import '../hours/repository.dart';

enum SessionPhase {
  signedOut,
  authenticating,
  twoFactorChallenge,
  verificationRequired,
  onboardingRequired,
  authenticated,
  expired,
  restricted,
}

class SessionModel extends ChangeNotifier {
  SessionModel(this.repository);
  final HoursRepository repository;
  SessionPhase phase = SessionPhase.signedOut;
  List<Workspace> workspaces = [];
  Workspace? workspace;
  List<HoursEntry> entries = [];
  DateTime week = weekStart(DateTime.now());
  bool busy = false;
  String? error;
  int _generation = 0;

  Future<void> enterDemo() async {
    phase = SessionPhase.authenticating;
    notifyListeners();
    try {
      workspaces = await repository.workspaces();
      phase = SessionPhase.authenticated;
    } catch (_) {
      phase = SessionPhase.signedOut;
      error = 'Could not load workspaces. Try again.';
    }
    notifyListeners();
  }

  Future<void> selectWorkspace(Workspace value) async {
    workspace = value;
    entries = [];
    await reload();
  }

  Future<void> reload() async {
    final selected = workspace;
    if (selected == null) return;
    final generation = ++_generation;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final result = await repository.week(selected.id, week);
      if (generation != _generation) return;
      entries = result;
    } catch (_) {
      if (generation != _generation) return;
      error = 'Could not load this week. Try again.';
    } finally {
      if (generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> add(HoursDraft draft) async {
    final selected = workspace;
    if (selected == null) return;
    await repository.add(selected.id, draft);
    if (workspace?.id == selected.id) await reload();
  }

  void switchWorkspace() {
    ++_generation;
    workspace = null;
    entries = [];
    error = null;
    busy = false;
    notifyListeners();
  }

  void logout() {
    ++_generation;
    repository.clear();
    entries = [];
    workspaces = [];
    workspace = null;
    phase = SessionPhase.signedOut;
    error = null;
    busy = false;
    notifyListeners();
  }
}
