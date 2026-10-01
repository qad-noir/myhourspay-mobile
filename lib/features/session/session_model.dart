import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../../core/session_store.dart';
import '../auth/auth_repository.dart';
import '../hours/models.dart';
import '../hours/repository.dart';

enum SessionPhase {
  restoring,
  signedOut,
  twoFactorChallenge,
  verificationRequired,
  onboardingRequired,
  authenticated,
  expired,
  restricted,
}

class SessionModel extends ChangeNotifier {
  SessionModel(this.auth, this.hours, this.store) {
    // Both repositories must share bearer state and the expiry callback.
    assert(identical(auth.api, hours.api));
    auth.api.onSessionFailure = _sessionFailure;
  }
  final AuthRepository auth;
  final HoursRepository hours;
  final SessionStore store;
  SessionPhase phase = SessionPhase.restoring;
  Account? account;
  List<Workspace> workspaces = [];
  Workspace? workspace;
  HoursPage? page;
  DateTime week = weekStart(DateTime.now());
  Map<String, bool> providers = {};
  ApiFailure? failure;
  String? notice;
  bool busy = false, loadingWeek = false;
  String? _challenge;
  DateTime? _challengeExpiry;
  Timer? _expiry;
  int _generation = 0;
  int sessionRevision = 0;
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadProviders() async {
    try {
      providers = await auth.providers();
    } catch (_) {
      providers = {};
    }
    _notify();
  }

  Future<bool> perform(Future<void> Function() action) async {
    if (busy) return false;
    busy = true;
    failure = null;
    notice = null;
    _notify();
    try {
      await action();
      return true;
    } on ApiFailure catch (e) {
      if (phase != SessionPhase.expired) failure = e;
      return false;
    } on FormatException {
      failure = const ApiFailure(
        'invalid_response',
        'The API response is not compatible with this app.',
      );
      return false;
    } catch (_) {
      failure = const ApiFailure(
        'device_error',
        'Could not complete this action securely. Please try again.',
      );
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> restore() async {
    await perform(() async {
      final saved = await store.read();
      if (saved == null) {
        phase = SessionPhase.signedOut;
        return;
      }
      if (!saved.expiresAt.isAfter(DateTime.now())) {
        await _clear(SessionPhase.expired);
        return;
      }
      auth.api.token = saved.token;
      _scheduleExpiry(saved.expiresAt);
      account = await auth.me();
      await _routeAccount();
    });
    unawaited(loadProviders());
  }

  Future<bool> login(String email, String password, String device) =>
      perform(() async => _accept(await auth.login(email, password, device)));
  Future<bool> register(Json input) =>
      perform(() async => _accept(await auth.register(input)));
  Future<bool> completeMfa(String code, bool recovery) => perform(() async {
    if (_challenge == null || !_challengeExpiry!.isAfter(DateTime.now())) {
      await _clear(SessionPhase.expired);
      throw const ApiFailure(
        'challenge_expired',
        'The challenge expired. Sign in again.',
      );
    }
    await _accept(await auth.mfa(_challenge!, code, recovery: recovery));
  });
  Future<bool> verify(String code) =>
      perform(() async => _accept(await auth.verify(code)));
  Future<bool> resend() => perform(() async {
    await auth.resend();
    notice = 'Verification request processed. Check your email.';
  });
  Future<void> _accept(AuthResult result) async {
    if (result.status == 'two_factor_required') {
      _challenge = result.challengeToken;
      _challengeExpiry = result.expiresAt;
      phase = SessionPhase.twoFactorChallenge;
      return;
    }
    final saved = StoredSession(result.accessToken!, result.expiresAt);
    // Persist the replacement atomically as one value, then enable normal requests.
    try {
      await store.write(saved);
    } catch (_) {
      auth.api.token = saved.token;
      try {
        await auth.logout();
      } catch (_) {}
      auth.api.token = null;
      await _clear(SessionPhase.signedOut);
      rethrow;
    }
    auth.api.token = saved.token;
    _challenge = null;
    _challengeExpiry = null;
    _scheduleExpiry(saved.expiresAt);
    account = result.account;
    if (result.status == 'email_verification_required') {
      phase = SessionPhase.verificationRequired;
      return;
    }
    phase = SessionPhase.restoring;
    account = await auth.me();
    await _routeAccount();
  }

  Future<void> _routeAccount() async {
    if (!account!.verified) {
      phase = SessionPhase.verificationRequired;
      return;
    }
    if (account!.trialChoiceRequired) {
      phase = SessionPhase.restricted;
      return;
    }
    final generation = _generation;
    final result = await hours.workspaces();
    if (generation != _generation || auth.api.token == null) return;
    workspaces = result;
    phase = SessionPhase.authenticated;
    if (workspaces.isEmpty || account!.onboardingRequired) {
      phase = SessionPhase.onboardingRequired;
    }
  }

  Future<bool> refreshAccount() => perform(() async {
    account = await auth.me();
    await _routeAccount();
  });
  Future<bool> createWorkspace(Json input) => perform(() async {
    await hours.createWorkspace(input);
    account = await auth.me();
    await _routeAccount();
  });
  Future<void> selectWorkspace(Workspace value) async {
    ++_generation;
    workspace = value;
    page = null;
    failure = null;
    try {
      week = weekStart(workspaceToday(value.timezone));
    } on ArgumentError {
      workspace = null;
      failure = const ApiFailure(
        'unsupported_timezone',
        'This workspace uses an unsupported timezone.',
      );
      _notify();
      return;
    }
    await reload();
  }

  Future<void> reload() async {
    final selected = workspace;
    if (selected == null) return;
    final generation = ++_generation;
    loadingWeek = true;
    failure = null;
    _notify();
    try {
      final result = await hours.week(selected.id, week);
      if (generation == _generation) page = result;
    } on ApiFailure catch (e) {
      if (generation == _generation) failure = e;
    } catch (_) {
      if (generation == _generation) {
        failure = const ApiFailure(
          'invalid_response',
          'Could not read the server’s hours response.',
        );
      }
    } finally {
      if (generation == _generation) {
        loadingWeek = false;
        _notify();
      }
    }
  }

  Future<void> moveWeek(int days) async {
    week = DateTime(week.year, week.month, week.day + days);
    page = null;
    await reload();
  }

  void switchWorkspace() {
    ++_generation;
    workspace = null;
    page = null;
    loadingWeek = false;
    failure = null;
    _notify();
  }

  Future<void> logout() async {
    if (busy) return;
    busy = true;
    _notify();
    var revoked = false;
    try {
      if (auth.api.token != null) {
        await auth.logout();
        revoked = true;
      }
    } on ApiFailure catch (e) {
      revoked = e.status == 401;
    } finally {
      try {
        await _clear(SessionPhase.signedOut);
        notice = revoked ? 'Signed out.' : 'Signed out on this device. Server revocation could not be confirmed; revoke this device from another session when connected.';
      } catch (_) {
        failure = const ApiFailure(
          'storage_error',
          'Secure storage could not be cleared. Close the app and retry logout.',
        );
        phase = SessionPhase.restricted;
      }
      busy = false;
      _notify();
    }
  }

  Future<void> cancelChallenge() async {
    await _clear(SessionPhase.signedOut);
    _notify();
  }

  Future<void> _clear(SessionPhase next) async {
    ++_generation;
    sessionRevision++;
    _expiry?.cancel();
    auth.api.token = null;
    account = null;
    _challenge = null;
    _challengeExpiry = null;
    workspaces = [];
    workspace = null;
    page = null;
    loadingWeek = false;
    phase = next;
    await store.clear();
  }

  void _scheduleExpiry(DateTime time) {
    _expiry?.cancel();
    final duration = time.difference(DateTime.now());
    _expiry = Timer(
      duration.isNegative ? Duration.zero : duration,
      () => _sessionFailure(
        const ApiFailure(
          'session_expired',
          'Your session expired. Sign in again.',
          status: 401,
        ),
      ),
    );
  }

  void _sessionFailure(ApiFailure error) {
    failure = error;
    if (error.status == 401) {
      failure = null;
      notice = 'Your session has expired. Please sign in again.';
      unawaited(
        _clear(SessionPhase.expired).catchError((Object _) {
          failure = const ApiFailure(
            'storage_error',
            'Could not erase the expired session. Retry sign out.',
          );
        }),
      );
    } else if (error.code == 'email_verification_required') {
      ++_generation;
      workspace = null;
      page = null;
      workspaces = [];
      phase = SessionPhase.verificationRequired;
    } else {
      ++_generation;
      workspace = null;
      page = null;
      workspaces = [];
      phase = SessionPhase.restricted;
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _expiry?.cancel();
    auth.api.onSessionFailure = null;
    auth.api.close();
    super.dispose();
  }
}
