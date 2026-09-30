import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_store.dart';

class SecureSessionStore implements SessionStore {
  SecureSessionStore(String apiBase)
    : key = 'mhp.session.${Uri.encodeComponent(apiBase)}';
  final String key;
  final _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  @override
  Future<StoredSession?> read() async {
    final value = await _storage.read(key: key);
    if (value == null) return null;
    try {
      return StoredSession.decode(value);
    } catch (_) {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(StoredSession value) =>
      _storage.write(key: key, value: value.encode());
  @override
  Future<void> clear() => _storage.delete(key: key);
}
