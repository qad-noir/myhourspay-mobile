import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

String get deviceName =>
    kIsWeb ? 'Web browser' : platformLabel(defaultTargetPlatform);
String platformLabel(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android => 'Android',
  TargetPlatform.iOS => 'iPhone / iPad (iOS)',
  TargetPlatform.macOS => 'macOS',
  TargetPlatform.windows => 'Windows',
  TargetPlatform.linux => 'Linux',
  TargetPlatform.fuchsia => 'Fuchsia',
};
String deviceLabel(
  Map<String, dynamic> data,
  TargetPlatform platform, {
  bool web = false,
}) {
  String clean(Object? value) => value is String
      ? value.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '').trim()
      : '';
  String result;
  if (web) {
    final browser = data['browserName']?.toString().split('.').last ?? '';
    result = browser.isEmpty || browser == 'unknown'
        ? 'Web browser'
        : '${browser[0].toUpperCase()}${browser.substring(1)} (Web)';
  } else if (platform == TargetPlatform.android) {
    var name = clean(data['name']);
    final model = clean(data['model']);
    final manufacturer = clean(data['manufacturer']);
    if (name.isEmpty || name.toLowerCase() == 'unknown' || name == model) {
      name = model;
      if (manufacturer.isNotEmpty &&
          !model.toLowerCase().startsWith(manufacturer.toLowerCase())) {
        name =
            '${manufacturer[0].toUpperCase()}${manufacturer.substring(1)} $model'
                .trim();
      }
    }
    result = name.isEmpty ? 'Android' : '$name (Android)';
  } else if (platform == TargetPlatform.iOS) {
    final model = clean(data['modelName']).isNotEmpty
        ? clean(data['modelName'])
        : clean(data['model']);
    result = model.isEmpty ? 'iPhone / iPad (iOS)' : '$model (iOS)';
  } else {
    result = platformLabel(platform);
  }
  return String.fromCharCodes(result.runes.take(100));
}

Future<String> resolveDeviceName({
  Future<Map<String, dynamic>> Function()? readInfo,
}) async {
  try {
    final data =
        await (readInfo?.call() ??
                DeviceInfoPlugin().deviceInfo.then((info) => info.data))
            .timeout(const Duration(seconds: 2));
    return deviceLabel(data, defaultTargetPlatform, web: kIsWeb);
  } catch (_) {
    return deviceName;
  }
}

String displayDeviceName(String saved) => switch (saved) {
  'MHP Android' => 'Android',
  'MHP iPhone' => 'iPhone (iOS)',
  'MHP Web' => 'Web browser',
  'MHP windows' => 'Windows',
  'MHP macOS' => 'macOS',
  'MHP linux' => 'Linux',
  _ => saved,
};
