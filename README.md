# MHP native Flutter companion

The app now uses Laravel's implemented **mobile API 1.0.0**, not demo data.
The contract is pinned from backend commit
`a973d70871330475ee4899ddf8df867215e7e364` (after e9653df).

## Run against local Laravel

Start the configured local Laravel application and apply its three mobile
migrations. Then, for an Android emulator:

```sh
flutter pub get
flutter run --dart-define=APP_ENV=development --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1/mobile
```

Missing configuration opens a setup screen and makes no request. There is no
production fallback. `API_BASE_URL` includes `/api/v1/mobile`.
The production target is configured only explicitly after deployment verification;
this work does not establish that it has been deployed. Staging is not configured.

## Implemented

- Password sign-in, registration with separate optional marketing consent,
  MFA/TOTP or recovery-code challenge, email verification/resend and forgot-password.
- Secure device-token persistence and restore, expiry/401 reauthentication,
  restricted account states, logout, device listing and remote revocation.
- Workspace selection and creation; current week uses the workspace timezone.
- Server weekly totals, week navigation, add/update hours and conditional projects.
- UUID idempotency keys retained for identical manual retries; version-conflict
  handling preserves drafts and requires an explicit reload before another edit.
- Capability/role-gated timesheet submission, detail, approval, request changes and
  reopening. MFA status is read-only. No push delivery is promised.

The app fetches `/auth/providers` before considering provider availability. Native
provider integration is not configured, so no Google/Apple action is exposed.
No provider credentials, callback URL or client IDs have been invented.

## Why these pieces

ChangeNotifier keeps state explicit and testable without another state framework.
Navigator handles native pages, and an authentication/workspace gate discards
private routes when the session expires, is restricted, or changes accounts.

`http` provides a small injectable transport. Redirects are disabled, bearer
credentials stay within the configured origin/API path, requests time out, and
Retry-After blocks premature retries. There are no automatic write retries or
refresh endpoints. Errors use `code`, `message`, and field `errors` from Laravel.

`flutter_secure_storage` holds only the opaque token and expiry in one secure
record scoped to the API environment. Passwords, MFA codes and account records
are not persisted. `url_launcher` opens the verified website legal routes in the system browser. `uuid` creates mutation identifiers. `timezone` selects the
workspace's calendar week without converting work dates to UTC.

Repositories and models are handwritten against the pinned contract; there are no
generated Dart files. `lib/features` contains auth/session, hours, account and
timesheet code. `lib/core` owns HTTP, configuration and secure storage.

## Verification

```sh
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
python tool/check_contract.py
```

The opt-in `tool/verify_local.dart` uses the same real repositories as the app.
It creates one clearly labelled test entry on an unused date, replays the write,
updates it, checks stale-version rejection, reads it back and revokes its token:

```sh
dart run tool/verify_local.dart http://127.0.0.1:8000/api/v1/mobile test-login/test-login.txt
```

Use only a designated local test account. That script refuses non-local hosts.
Credentials and results are ignored by Git. It leaves the test record for website
verification; it never overwrites an existing date. Do not run it repeatedly
without reviewing the retained test entries.

See [verification evidence](docs/VERIFICATION.md), [device/environment setup](docs/SETUP.md),
and the pinned [backend integration guide](docs/api/mobile-integration.md).

## Visual rebuild

Eight production screens now follow the mobile concept boards using bundled fonts,
shared native components and a phone-width web shell. See
[rendered screenshots and verification](docs/visual-review/README.md).

Chrome local preview (Laravel must already be running):

```powershell
flutter run --debug -d chrome --dart-define=APP_ENV=development --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1/mobile
```
