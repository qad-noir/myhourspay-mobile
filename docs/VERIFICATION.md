# Verification record — 2026-09-29

- Flutter 3.47.2 / Dart 3.13.2 verified on Windows.
- `flutter analyze`: passed, no issues.
- `flutter test`: all 7 tests passed, including the demo add-hours widget journey.
- OpenAPI 3.1 draft: passed openapi-spec-validator 0.7.2.
- Pinned Flutter and Laravel draft copies: SHA-256 matched.
- Android `flutter build apk --debug`: attempted; failed because local NDK
  28.2.13676358 lacks source.properties. No APK is claimed. Repair/reinstall that
  NDK through Android SDK Manager and repeat the build; no SDK directory deleted.
- iOS: not built or device-tested; requires macOS/Xcode.
- No Android emulator/physical-device test or visual screenshot review performed.
- No live login, website round-trip, server authorization, MFA, provider,
  idempotency or store review tests performed. Those features are not implemented.
- No production requests that create/update records were made.

Tests exercise environment/origin validation, same-day shift rules, calendar
week boundaries, workspace/logout isolation, duplicate/locked demo writes, the
add-hours UI journey and a narrow-screen welcome. They are not backend security
proof. CI has format/analyze/test and schema validation jobs; CI itself has not
run remotely. There is no released contract baseline for a breaking-change check.
