class WebAccountLinks {
  const WebAccountLinks();
  static const base = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://mhp.glsltd.co.uk',
  );
  static const domain = String.fromEnvironment('WEB_DOMAIN');
  static String get profile =>
      resolve(const String.fromEnvironment('WEB_PROFILE_URL'), base);
  static String get deletion =>
      resolve(const String.fromEnvironment('WEB_DELETE_ACCOUNT_URL'), base);
  static String resolve(String override, String base) {
    if (override.isNotEmpty) return override;
    final uri = parse(base);
    if (uri == null) return '';
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    return uri
        .replace(path: '$path/user/profile', query: null, fragment: null)
        .toString();
  }

  static String displayDomain(Uri uri) =>
      domain.isNotEmpty && !domain.contains(RegExp(r'[\s/:]'))
      ? domain
      : uri.host;
  static Uri? parse(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri;
  }
}
