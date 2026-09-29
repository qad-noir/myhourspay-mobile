import 'package:flutter/foundation.dart';

/// Build-time values are public. No environment implies no network access.
class ApiEnvironment {
  ApiEnvironment._(this.name, this.origin);
  final String name;
  final Uri? origin;
  factory ApiEnvironment.parse(
    String name,
    String origin, {
    bool release = kReleaseMode,
  }) {
    if (name == 'demo' && origin.isEmpty) return ApiEnvironment._(name, null);
    if (!['development', 'staging', 'production'].contains(name)) {
      throw const FormatException('Select an explicit environment.');
    }
    final uri = Uri.tryParse(origin);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path != '' && uri.path != '/')) {
      throw const FormatException(
        'API_ORIGIN must be an origin without a path or credentials.',
      );
    }
    if (uri.scheme != 'https' &&
        !(name == 'development' && !release && uri.scheme == 'http')) {
      throw const FormatException(
        'HTTPS is required outside debug development.',
      );
    }
    return ApiEnvironment._(name, uri);
  }
  bool trusts(Uri target) =>
      origin != null &&
      target.scheme == origin!.scheme &&
      target.host == origin!.host &&
      target.port == origin!.port &&
      target.userInfo.isEmpty;
}
