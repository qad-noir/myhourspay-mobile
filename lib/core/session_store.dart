import 'dart:convert';

class StoredSession {
  const StoredSession(this.token, this.expiresAt);
  final String token;
  final DateTime expiresAt;
  String encode() => jsonEncode({
    'access_token': token,
    'expires_at': expiresAt.toUtc().toIso8601String(),
  });
  factory StoredSession.decode(String value) {
    final json = jsonDecode(value) as Map<String, dynamic>;
    return StoredSession(
      json['access_token'] as String,
      DateTime.parse(json['expires_at'] as String),
    );
  }
}

abstract interface class SessionStore {
  Future<StoredSession?> read();
  Future<void> write(StoredSession value);
  Future<void> clear();
}
