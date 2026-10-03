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
  int? selectedWorkspaceId;
  List<DeviceSession>? deviceSessions;
  String? toast;
  HoursPage? page;
  HoursPage? _overviewPage;
  DateTime? _overviewLoadedWeek;
  ApiFailure? overviewFailure;
  bool loadingOverview = false;
  int _overviewGeneration = 0;
  StoredSession? _storedSession;
  Future<void> _workspaceWrite = Future.value();
  int _pendingWorkspaceWrites = 0;
  DateTime get overviewWeek => weekStart(workspaceToday(workspace!.timezone));
  HoursPage? get overviewData => _overviewLoadedWeek == overviewWeek
      ? _overviewPage
      : week == overviewWeek
      ? page
      : null;
  bool get overviewLoading =>
      loadingOverview ||
      (week == overviewWeek && loadingWeek && overviewData == null);
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
    } on TypeError {
      failure = const ApiFailure(
        'invalid_response',
        'The API response is not compatible with this app. Check the backend deployment.',
      );
      return false;
    } catch (error, stack) {
      // Exception messages can contain credentials or response bodies. Log only
      // the type and our own stack frames to diagnose unexpected device failures.
      debugPrint('MHP action failure: ${error.runtimeType}');
      for (final frame in stack.toString().split('\n')) {
        if (frame.contains('package:myhourspay/')) debugPrint(frame);
      }
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
      _storedSession = saved;
      selectedWorkspaceId = saved.workspaceId;
      auth.api.token = saved.token;
      _scheduleExpiry(saved.expiresAt);
      account = await auth.me();
      await _routeAccount();
      if (phase == SessionPhase.authenticated && saved.workspaceId != null) {
        final remembered = workspaces
            .where((w) => w.id == saved.workspaceId)
            .firstOrNull;
        if (remembered != null) {
          await selectWorkspace(remembered, persist: false);
        } else {
          selectedWorkspaceId = null;
        }
      }
    });
    unawaited(loadProviders());
  }

  Future<bool> login(String email, String password, String device) =>
      perform(() async {
        phase = SessionPhase.signedOut;
        await _accept(await auth.login(email, password, device));
      });
  Future<bool> register(Json input) =>
      perform(() async => _accept(await auth.register(input)));
  Future<bool> googleSignIn(
    Future<String> Function() acquireToken,
    Future<String> Function() deviceLabel, {
    String? name,
    bool terms = false,
  }) => perform(() async {
    if (providers['google'] != true) {
      throw const ApiFailure(
        'provider_unavailable',
        'Google sign-in is currently unavailable.',
      );
    }
    final device = await deviceLabel();
    final credential = await acquireToken();
    try {
      await _accept(
        await auth.google(credential, device, name: name, terms: terms),
      );
    } on ApiFailure catch (error) {
      if (error.code == 'account_link_required') {
        throw const ApiFailure(
          'account_link_required',
          'This email already has an MHP account. Sign in with your password. Google linking requires the existing account to be authenticated.',
          status: 409,
        );
      }
      if (error.fields.containsKey('terms') ||
          error.fields.containsKey('name')) {
        throw const ApiFailure(
          'google_signup_required',
          'To create a new account with Google, choose Create account, enter your name and accept the terms.',
          status: 422,
        );
      }
      rethrow;
    }
  });
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
      _storedSession = saved;
    } catch (_) {
      auth.api.token = saved.token;
      try {
        await auth.logout();
      } catch (_) {}
      auth.api.token = null;
      try {
        await _clear(SessionPhase.signedOut);
      } catch (_) {
        // Local bearer state has already been cleared; never use an unpersisted token.
      }
      throw const ApiFailure(
        'storage_error',
        'Cannot save your session in secure device storage. Restart the app and try again. If it persists, contact support with your device model and Android/iOS version.',
      );
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
    final created = await hours.createWorkspace(input);
    workspaces = [...workspaces.where((w) => w.id != created.id), created];
    notice = 'Workspace created successfully.';
    // Creation is already confirmed. A failed subsequent read must not invite
    // another POST or hide the new workspace from the user.
    try {
      account = await auth.me();
      await _routeAccount();
    } on ApiFailure catch (e) {
      if (phase != SessionPhase.expired) {
        failure = e;
        notice = 'Workspace created. Could not refresh the workspace list. Please try refreshing.';
      }
    } on FormatException {
      notice =
          'Workspace created. Could not read the refreshed workspace list.';
    } on TypeError {
      notice =
          'Workspace created. Could not read the refreshed workspace list.';
    }
  });
  Future<void> selectWorkspace(Workspace value, {bool persist = true}) async {
    ++_generation;
    _resetOverview();
    workspace = value;
    selectedWorkspaceId = value.id;
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
    final selectedGeneration = _generation;
    if (persist && _storedSession != null) {
      final saved = _storedSession!;
      _pendingWorkspaceWrites++;
      final write = _workspaceWrite
          .then((_) async {
            if (auth.api.token != saved.token ||
                selectedWorkspaceId != value.id) {
              return;
            }
            final updated = StoredSession(
              saved.token,
              saved.expiresAt,
              workspaceId: value.id,
            );
            await store.write(updated);
            if (auth.api.token == saved.token) _storedSession = updated;
          })
          .whenComplete(() => _pendingWorkspaceWrites--);
      _workspaceWrite = write.catchError((Object _) {});
      try {
        await write;
      } catch (_) {
        if (selectedGeneration == _generation) {
          toast = 'Workspace opened, but could not remember it for next time. Please try switching again.';
        }
      }
    }
    if (selectedGeneration == _generation) await reload();
  }

  void _resetOverview() {
    ++_overviewGeneration;
    _overviewPage = null;
    _overviewLoadedWeek = null;
    overviewFailure = null;
    loadingOverview = false;
  }

  Future<void> ensureOverview() async {
    if (workspace != null && overviewData == null && !loadingOverview) {
      await reloadOverview();
    }
  }

  Future<void> reloadOverview() async {
    final selected = workspace;
    if (selected == null) return;
    final start = overviewWeek;
    final generation = ++_overviewGeneration;
    loadingOverview = true;
    overviewFailure = null;
    _notify();
    try {
      final result = await hours.week(selected.id, start);
      if (generation == _overviewGeneration) {
        _overviewPage = result;
        _overviewLoadedWeek = start;
      }
    } on ApiFailure catch (e) {
      if (generation == _overviewGeneration) overviewFailure = e;
    } catch (_) {
      if (generation == _overviewGeneration) {
        overviewFailure = const ApiFailure(
          'invalid_response',
          'Could not read the server’s hours response.',
        );
      }
    } finally {
      if (generation == _overviewGeneration) {
        loadingOverview = false;
        _notify();
      }
    }
  }

  Future<void> reload() async {
    final selected = workspace;
    if (selected == null) return;
    final generation = ++_generation;
    final start = week;
    loadingWeek = true;
    failure = null;
    _notify();
    try {
      final result = await hours.week(selected.id, start);
      if (generation == _generation) {
        page = result;
        if (start == overviewWeek) {
          ++_overviewGeneration;
          loadingOverview = false;
          _overviewPage = result;
          _overviewLoadedWeek = start;
          overviewFailure = null;
        }
      }
    } on ApiFailure catch (e) {
      if (generation == _generation) {
        failure = e;
        if (start == overviewWeek) overviewFailure = e;
      }
    } catch (_) {
      if (generation == _generation) {
        failure = const ApiFailure(
          'invalid_response',
          'Could not read the server’s hours response.',
        );
        if (start == overviewWeek) overviewFailure = failure;
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

  Future<void> selectWeek(DateTime date) async {
    week = weekStart(date);
    page = null;
    await reload();
  }

  void switchWorkspace() {
    ++_generation;
    _resetOverview();
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
        notice = null;
        toast = revoked ? 'Signed out.' : 'Signed out on this device. Server revocation could not be confirmed; revoke this device from another session when connected.';
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
    _resetOverview();
    _storedSession = null;
    sessionRevision++;
    _expiry?.cancel();
    auth.api.token = null;
    account = null;
    _challenge = null;
    _challengeExpiry = null;
    workspaces = [];
    selectedWorkspaceId = null;
    deviceSessions = null;
    workspace = null;
    page = null;
    loadingWeek = false;
    phase = next;
    if (_pendingWorkspaceWrites > 0) {
      await _workspaceWrite;
    }
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
      _resetOverview();
      workspace = null;
      page = null;
      workspaces = [];
      phase = SessionPhase.verificationRequired;
    } else {
      ++_generation;
      _resetOverview();
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
