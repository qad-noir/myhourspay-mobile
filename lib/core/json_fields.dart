/// MySQL/PDO can serialize foreign keys as decimal strings. Normalize only
/// positive integer IDs; never round numbers or substitute a missing ID.
int jsonId(Object? value) {
  if (value is int && value > 0) return value;
  if (value is String && RegExp(r'^[0-9]+$').hasMatch(value)) {
    final id = int.tryParse(value);
    if (id != null && id > 0) return id;
  }
  throw const FormatException('Invalid resource ID');
}

int? nullableJsonId(Object? value) => value == null ? null : jsonId(value);
