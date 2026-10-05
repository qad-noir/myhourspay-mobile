import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/device_name.dart';

/// Proposed API extension: docs/PUSH-BACKEND-HANDOFF.md. Enable only after
/// that extension and Firebase configuration are deployed together.
class PushController extends ChangeNotifier {
  PushController(this.api);
  final ApiClient api;
  static const enabledBuild = bool.fromEnvironment('ENABLE_NATIVE_PUSH');
  static const project = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const sender = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const androidApp = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const androidKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const iosApp = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const iosKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const iosBundle = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');
  bool get supported =>
      !kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform);
  bool get configured =>
      supported &&
      enabledBuild &&
      project.isNotEmpty &&
      sender.isNotEmpty &&
      (defaultTargetPlatform == TargetPlatform.android
          ? androidApp.isNotEmpty && androidKey.isNotEmpty
          : iosApp.isNotEmpty && iosKey.isNotEmpty && iosBundle.isNotEmpty);
  bool busy = false, enabled = false;
  String? error;
  String? _session;
  bool _disposed = false;
  bool _tokenChanged = false;
  Future<void>? _initializing;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  void Function(Map<String, dynamic>)? onOpen;
  void Function(String)? onForeground;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() =>
      _initializing ??= _initialize().catchError((Object error) {
        _initializing = null;
        throw error;
      });
  Future<void> _initialize() async {
    if (!configured || _disposed) return;
    final android = defaultTargetPlatform == TargetPlatform.android;
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: android ? androidKey : iosKey,
        appId: android ? androidApp : iosApp,
        messagingSenderId: sender,
        projectId: project,
        iosBundleId: android ? null : iosBundle,
      ),
    );
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
    if (_disposed) return;
    _subscriptions.add(
      FirebaseMessaging.instance.onTokenRefresh.listen((_) {
        _tokenChanged = true;
        if (_session != null && enabled) {
          unawaited(setEnabled(true, askPermission: false));
        }
      }),
    );
    _subscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => onOpen?.call(message.data),
      ),
    );
    _subscriptions.add(
      FirebaseMessaging.onMessage.listen((message) {
        if (_session != null &&
            defaultTargetPlatform == TargetPlatform.android) {
          onForeground?.call(
            message.notification?.body ?? 'You have an hours reminder.',
          );
        }
      }),
    );
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null && !_disposed) onOpen?.call(initial.data);
  }

  Future<void> sessionChanged(String? bearer) async {
    if (_disposed || _session == bearer) return;
    _session = bearer;
    enabled = false;
    error = null;
    _notify();
    if (bearer == null || !configured) return;
    try {
      await initialize();
      final result = await _request(bearer, 'GET');
      if (_session != bearer || _disposed) return;
      enabled = (result['data'] as Map?)?['enabled'] == true;
      if (enabled) await setEnabled(true, askPermission: false);
    } catch (_) {
      if (_session == bearer) {
        error = 'Could not load reminder settings. Please try again.';
      }
    }
    _notify();
  }

  Future<Json> _request(String bearer, String method, {Json? body}) async {
    final bound = ApiClient(
      api.environment,
      timeout: const Duration(seconds: 10),
    )..token = bearer;
    try {
      return await bound.request(
        method,
        '/push/device',
        body: body,
        idempotencyKey: method == 'PUT' ? const Uuid().v4() : null,
      );
    } finally {
      bound.close();
    }
  }

  Future<void> setEnabled(bool value, {bool askPermission = true}) async {
    final bearer = _session;
    if (_disposed || busy || bearer == null || !configured) return;
    _tokenChanged = false;
    busy = true;
    error = null;
    _notify();
    try {
      await initialize();
      final messaging = FirebaseMessaging.instance;
      final settings = value && askPermission
          ? await messaging.requestPermission(
              alert: true,
              badge: true,
              sound: true,
            )
          : await messaging.getNotificationSettings();
      if (value &&
          ![
            AuthorizationStatus.authorized,
            AuthorizationStatus.provisional,
          ].contains(settings.authorizationStatus)) {
        throw StateError('permission');
      }
      if (value &&
          defaultTargetPlatform == TargetPlatform.iOS &&
          await messaging.getAPNSToken() == null) {
        throw StateError('apns');
      }
      final token = value
          ? await messaging.getToken().timeout(const Duration(seconds: 20))
          : null;
      if (value && token == null) throw StateError('token');
      final name = await resolveDeviceName();
      if (_session != bearer || _disposed) return;
      await _request(
        bearer,
        'PUT',
        body: {
          'enabled': value,
          if (value) 'token': token,
          'platform': defaultTargetPlatform == TargetPlatform.android
              ? 'android'
              : 'ios',
          'device_name': name,
        },
      );
      if (_session == bearer) enabled = value;
    } on StateError catch (e) {
      if (_session == bearer) {
        error = e.message == 'permission'
            ? 'Allow notifications in your device settings to receive reminders.'
            : 'Notifications are not ready on this device. Please try again.';
      }
    } catch (_) {
      if (_session == bearer) {
        error = 'Could not save reminder settings. Please try again.';
      }
    } finally {
      busy = false;
      _notify();
      if (!_disposed && _tokenChanged && enabled && _session != null) {
        unawaited(setEnabled(true, askPermission: false));
      }
    }
  }

  Future<void> beforeLogout() async {
    final bearer = _session;
    _session = null;
    enabled = false;
    _notify();
    if (bearer == null || !configured) return;
    try {
      await _request(bearer, 'DELETE');
    } catch (_) {
      // Revoking the mobile bearer must also invalidate delivery server-side.
    }
    try {
      await FirebaseMessaging.instance.deleteToken().timeout(
        const Duration(seconds: 5),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}

class PushScope extends InheritedNotifier<PushController> {
  const PushScope({
    super.key,
    required PushController controller,
    required super.child,
  }) : super(notifier: controller);
  static PushController? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PushScope>()?.notifier;
}
