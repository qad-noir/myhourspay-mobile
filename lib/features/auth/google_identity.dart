import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import 'google_browser_stub.dart'
    if (dart.library.js_interop) 'google_browser.dart';

abstract interface class GoogleIdentity {
  bool get configured;
  Future<GoogleCredential> acquireCredential(String nonce);
}

class GoogleCredential {
  const GoogleCredential(this.idToken, {this.name = ''});
  final String idToken, name;
}

class NativeGoogleIdentity implements GoogleIdentity {
  NativeGoogleIdentity({required this.serverClientId, this.iosClientId = ''});
  final String serverClientId, iosClientId;
  static const channel = MethodChannel('myhourspay/google_identity');
  @override
  bool get configured =>
      serverClientId.endsWith('.apps.googleusercontent.com') &&
      (kIsWeb || defaultTargetPlatform == TargetPlatform.android);
  @override
  Future<GoogleCredential> acquireCredential(String nonce) async {
    if (!configured) {
      throw const ApiFailure(
        'google_not_configured',
        'Google sign-in is not configured for this platform.',
      );
    }
    try {
      final result = kIsWeb
          ? await authenticateGoogleWeb(serverClientId, nonce)
          : await channel.invokeMapMethod<String, dynamic>('authenticate', {
              'serverClientId': serverClientId,
              'clientId': iosClientId,
              'nonce': nonce,
            });
      if (result?['error'] != null) {
        throw PlatformException(code: result!['error'] as String);
      }
      final token = result?['idToken'];
      if (token is! String || token.isEmpty) {
        throw const ApiFailure(
          'google_token_missing',
          'Google did not provide a sign-in credential. Please try again.',
        );
      }
      return GoogleCredential(
        token,
        name: (result?['name'] as String? ?? '').trim(),
      );
    } on PlatformException catch (error) {
      throw ApiFailure(
        error.code == 'google_canceled'
            ? 'google_canceled'
            : 'google_unavailable',
        error.code == 'google_canceled'
            ? 'Google sign-in was canceled. Please try again.'
            : 'Google sign-in could not complete. Please try again.',
      );
    }
  }
}
