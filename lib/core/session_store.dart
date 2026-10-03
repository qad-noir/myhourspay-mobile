import 'dart:convert';

class StoredSession {
  const StoredSession(this.token, this.expiresAt, {this.workspaceId});
  final String token;
  final DateTime expiresAt;
  final int? workspaceId;
  String encode() => jsonEncode({
    'access_token': token,
    'expires_at': expiresAt.toUtc().toIso8601String(),
    if (workspaceId != null) 'workspace_id': workspaceId,
  });
  factory StoredSession.decode(String value) {
    final json = jsonDecode(value) as Map<String, dynamic>;
    return StoredSession(
      json['access_token'] as String,
      DateTime.parse(json['expires_at'] as String),
      workspaceId: json['workspace_id'] is int && json['workspace_id'] > 0
          ? json['workspace_id'] as int
          : null,
    );
  }
}

abstract interface class SessionStore {
  Future<StoredSession?> read();
  Future<void> write(StoredSession value);
  Future<void> clear();
}
