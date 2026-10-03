import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myhourspay/core/device_name.dart';

void main() {
  test('labels use device model without application prefix or hardware identifiers', () {
    expect(
      deviceLabel({
        'name': 'Galaxy Note20',
        'manufacturer': 'samsung',
        'model': 'SM-N981N',
      }, TargetPlatform.android),
      'Galaxy Note20 (Android)',
    );
    expect(
      deviceLabel({
        'manufacturer': 'samsung',
        'model': 'SM-N981N',
      }, TargetPlatform.android),
      'Samsung SM-N981N (Android)',
    );
    expect(
      deviceLabel({'modelName': 'iPhone 16 Pro'}, TargetPlatform.iOS),
      'iPhone 16 Pro (iOS)',
    );
    expect(
      deviceLabel(
        {'browserName': 'BrowserName.chrome'},
        TargetPlatform.android,
        web: true,
      ),
      'Chrome (Web)',
    );
    expect(
      deviceLabel({'name': 'x' * 110}, TargetPlatform.android).length,
      100,
    );
  });
  test('metadata failures safely fall back to platform label', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(
      await resolveDeviceName(
        readInfo: () async => throw StateError('Unavailable'),
      ),
      kIsWeb ? 'Web browser' : 'Android',
    );
    expect(
      await resolveDeviceName(readInfo: () async => {'name': 'Pixel 9'}),
      kIsWeb ? 'Web browser' : 'Pixel 9 (Android)',
    );
  });
}
