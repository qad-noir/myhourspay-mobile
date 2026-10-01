import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myhourspay/features/auth/auth_screens.dart';

void main() {
  test('device name is safe on web and preserves native platform labels', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      final expected = kIsWeb
          ? 'MHP Web'
          : switch (platform) {
              TargetPlatform.android => 'MHP Android',
              TargetPlatform.iOS => 'MHP iPhone',
              _ => 'MHP ${platform.name}',
            };
      expect(deviceName, expected);
    }
  });
}
