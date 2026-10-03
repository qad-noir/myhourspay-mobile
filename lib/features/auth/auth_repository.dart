import '../../core/api_client.dart';
import '../../core/json_fields.dart';

class Account {
  Account.fromJson(Json json)
    : id = jsonId(json['id']),
      name = json['name'] as String,
      email = json['email'] as String,
      verified = json['email_verified'] as bool,
      mfaEnabled = json['two_factor_enabled'] as bool,
      onboardingRequired = json['onboarding_required'] as bool,
      trialChoiceRequired = json['trial_choice_required'] as bool;
  final int id;
  final String name, email;
  final bool verified, mfaEnabled, onboardingRequired, trialChoiceRequired;
}

class AuthResult {
  AuthResult.fromJson(Json json)
    : status = json['status'] as String,
      accessToken = json['access_token'] as String?,
      challengeToken = json['challenge_token'] as String?,
      expiresAt = DateTime.parse(json['expires_at'] as String),
      account = json['user'] == null
          ? null
          : Account.fromJson(json['user'] as Json) {
    if (status == 'two_factor_required'
        ? challengeToken == null
        : !['authenticated', 'email_verification_required'].contains(status) ||
              accessToken == null ||
              account == null ||
              json['token_type'] != 'Bearer') {
      throw const FormatException('Unknown authentication response');
    }
  }
  final String status;
  final String? accessToken, challengeToken;
  final DateTime expiresAt;
  final Account? account;
}

class DeviceSession {
  DeviceSession.fromJson(Json json)
    : id = jsonId(json['id']),
      name = json['device_name'] as String,
      current = json['current'] as bool,
      expiresAt = json['expires_at'] as String?,
      lastUsedAt = json['last_used_at'] as String?;
  final int id;
  final String name;
  final bool current;
  final String? expiresAt, lastUsedAt;
}

class GoogleChallenge {
  GoogleChallenge.fromJson(Json json)
    : id = json['challenge_id'] as String,
      nonce = json['nonce'] as String,
      expiresAt = DateTime.parse(json['expires_at'] as String) {
    if (json['nonce_mode'] != 'raw' ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(nonce) ||
        !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)) {
      throw const FormatException('Unsupported Google challenge');
    }
  }
  final String id, nonce;
  final DateTime expiresAt;
}

class AuthRepository {
  AuthRepository(this.api);
  final ApiClient api;
  Future<Map<String, bool>> providers() async {
    final json = await api.request(
      'GET',
      '/auth/providers',
      authenticated: false,
    );
    return (json['data'] as Json).map(
      (key, value) => MapEntry(key, value as bool),
    );
  }

  Future<AuthResult> login(
    String email,
    String password,
    String deviceName,
  ) async => AuthResult.fromJson(
    await api.request(
      'POST',
      '/auth/login',
      authenticated: false,
      body: {'email': email, 'password': password, 'device_name': deviceName},
    ),
  );
  Future<AuthResult> register(Json data) async => AuthResult.fromJson(
    await api.request(
      'POST',
      '/auth/register',
      authenticated: false,
      body: data,
    ),
  );
  Future<GoogleChallenge> googleChallenge() async => GoogleChallenge.fromJson(
    await api.request('POST', '/auth/google/challenge', authenticated: false),
  );
  Future<void> linkGoogle(
    String challengeId,
    String idToken,
    String password,
  ) async {
    await api.request(
      'POST',
      '/auth/providers/google/link',
      body: {
        'challenge_id': challengeId,
        'id_token': idToken,
        'current_password': password,
      },
    );
  }

  Future<AuthResult> google(
    String idToken,
    String deviceName, {
    required String challengeId,
    String? name,
    bool terms = false,
  }) async => AuthResult.fromJson(
    await api.request(
      'POST',
      '/auth/google',
      authenticated: false,
      body: {
        'challenge_id': challengeId,
        'id_token': idToken,
        'device_name': deviceName,
        'name': ?name,
        if (terms) 'terms': true,
      },
    ),
  );
  Future<AuthResult> mfa(
    String challenge,
    String value, {
    bool recovery = false,
  }) async => AuthResult.fromJson(
    await api.request(
      'POST',
      '/auth/two-factor',
      authenticated: false,
      body: {
        'challenge_token': challenge,
        recovery ? 'recovery_code' : 'code': value,
      },
    ),
  );
  Future<AuthResult> verify(String code) async => AuthResult.fromJson(
    await api.request('POST', '/auth/email/verify', body: {'code': code}),
  );
  Future<void> resend() async {
    await api.request('POST', '/auth/email/resend');
  }

  Future<void> forgot(String email) async {
    await api.request(
      'POST',
      '/auth/forgot-password',
      authenticated: false,
      body: {'email': email},
    );
  }

  Future<Account> me() async =>
      Account.fromJson((await api.request('GET', '/me'))['data'] as Json);
  Future<void> logout() async {
    await api.request('DELETE', '/auth/session');
  }

  Future<List<DeviceSession>> sessions() async =>
      ((await api.request('GET', '/auth/sessions'))['data'] as List)
          .map((e) => DeviceSession.fromJson(e as Json))
          .toList();
  Future<void> revoke(int id) async {
    await api.request('DELETE', '/auth/sessions/$id');
  }
}
