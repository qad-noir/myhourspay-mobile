import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AppearanceStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureAppearanceStore implements AppearanceStore {
  final _storage = const FlutterSecureStorage();
  @override
  Future<String?> read() => _storage.read(key: 'mhp.appearance');
  @override
  Future<void> write(String value) =>
      _storage.write(key: 'mhp.appearance', value: value);
}

class AppearanceController extends ChangeNotifier {
  AppearanceController(this.store);
  final AppearanceStore store;
  ThemeMode mode = ThemeMode.system;
  int _revision = 0;
  bool _disposed = false;
  Future<void> _writes = Future.value();
  Future<void> load() async {
    final revision = _revision;
    try {
      final value = await store.read();
      if (_disposed || revision != _revision) return;
      mode =
          ThemeMode.values.where((m) => m.name == value).firstOrNull ??
          ThemeMode.system;
      notifyListeners();
    } catch (_) {
      /* System remains available when storage cannot be read. */
    }
  }

  Future<bool> select(ThemeMode value) async {
    if (mode == value) return true;
    ++_revision;
    mode = value;
    notifyListeners();
    final write = _writes.then((_) => store.write(value.name));
    _writes = write.catchError((Object _) {});
    try {
      await write;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class AppearanceScope extends InheritedNotifier<AppearanceController> {
  const AppearanceScope({
    super.key,
    required AppearanceController controller,
    required super.child,
  }) : super(notifier: controller);
  static AppearanceController? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppearanceScope>()?.notifier;
}
