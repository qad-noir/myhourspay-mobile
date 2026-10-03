import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/api_client.dart';

abstract interface class GoogleIdentity {
  bool get configured;
  Future<String> acquireIdToken();
}

/// Provider credentials stay in memory for one exchange; MHP owns the session.
class NativeGoogleIdentity implements GoogleIdentity {
  NativeGoogleIdentity({required this.serverClientId, this.iosClientId = ''});
  final String serverClientId, iosClientId;
  Future<void>? _initialization;
  @override
  bool get configured =>
      !kIsWeb &&
      serverClientId.endsWith('.apps.googleusercontent.com') &&
      (defaultTargetPlatform == TargetPlatform.android ||
          (defaultTargetPlatform == TargetPlatform.iOS &&
              iosClientId.endsWith('.apps.googleusercontent.com')));

  @override
  Future<String> acquireIdToken() async {
    if (!configured) {
      throw const ApiFailure(
        'google_not_configured',
        'Google sign-in is not configured for this platform.',
      );
    }
    final sdk = GoogleSignIn.instance;
    try {
      await (_initialization ??= sdk.initialize(
        serverClientId: serverClientId,
        clientId: defaultTargetPlatform == TargetPlatform.iOS
            ? iosClientId
            : null,
      ));
      // Every backend exchange requires a fresh, single-use provider credential.
      await sdk.signOut();
      final user = await sdk.authenticate();
      final token = user.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const ApiFailure(
          'google_token_missing',
          'Google did not provide a sign-in credential. Please try again.',
        );
      }
      return token;
    } on GoogleSignInException catch (error) {
      throw switch (error.code) {
        GoogleSignInExceptionCode.canceled => const ApiFailure(
          'google_canceled',
          'Google sign-in was canceled or could not complete. Please try again.',
        ),
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          const ApiFailure(
            'google_configuration',
            'Google sign-in configuration needs checking. Contact support.',
          ),
        _ => const ApiFailure(
          'google_unavailable',
          'Google sign-in could not complete. Please try again.',
        ),
      };
    } finally {
      // This clears SDK state, not the phone's Google account or its permissions.
      if (_initialization != null) {
        try {
          await sdk.signOut();
        } catch (_) {}
      }
    }
  }
}
