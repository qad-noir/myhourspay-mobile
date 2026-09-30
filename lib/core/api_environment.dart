/// Explicit build configuration. Missing configuration never selects production.
class ApiEnvironment {
  ApiEnvironment._(this.name, this.base);
  final String name;
  final Uri base;
  factory ApiEnvironment.parse(
    String name,
    String value, {
    bool release = false,
  }) {
    if (!['development', 'staging', 'production'].contains(name)) {
      throw const FormatException(
        'Set APP_ENV to development, staging or production.',
      );
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path.replaceAll(RegExp(r'/$'), '') != '/api/v1/mobile') {
      throw const FormatException(
        'Set API_BASE_URL to an origin followed by /api/v1/mobile.',
      );
    }
    if (uri.scheme != 'https' &&
        !(name == 'development' && !release && uri.scheme == 'http')) {
      throw const FormatException(
        'HTTPS is required except for debug development.',
      );
    }
    if (name != 'production' && uri.host == 'mhp.glsltd.co.uk') {
      throw const FormatException(
        'The production host cannot be used for development or staging.',
      );
    }
    return ApiEnvironment._(name, uri.replace(path: '/api/v1/mobile/'));
  }
  bool trusts(Uri target) =>
      target.scheme == base.scheme &&
      target.host == base.host &&
      target.port == base.port &&
      target.userInfo.isEmpty &&
      target.path.startsWith(base.path);
  Uri endpoint(String path, Map<String, String>? query) {
    if (!path.startsWith('/') ||
        path.contains('..') ||
        path.contains('://') ||
        path.contains('?') ||
        path.contains('#')) {
      throw const FormatException('Invalid API path.');
    }
    final uri = base.resolve(path.substring(1)).replace(queryParameters: query);
    if (!trusts(uri)) throw const FormatException('Untrusted API origin.');
    return uri;
  }
}
