# Local web login diagnosis

The supplied trace shows HTTP 401 while fetching workspaces after login, followed
by access to a disposed password controller. Login, MFA and verification now guard
controller access after their asynchronous action completes and may replace the
route. The regression test disposes the login screen while workspace loading is
pending, then completes that request with 401.

A fresh designated local test login against `http://127.0.0.1:8000/api/v1/mobile`
returned login 200/authenticated, `/me` 200 and `/workspaces` 200. The temporary
diagnostic session was revoked (204). This was an HTTP probe, not a successful
Chrome login.

## Root cause found from the follow-up trace

The follow-up showed `/me` 200 with a bearer, then `/workspaces` 401 with no bearer.
The backend issued a roughly 30-day session. `_scheduleExpiry` previously passed
that full delay into Dart's browser Timer, implemented via JavaScript `setTimeout`.
The delay exceeds its signed 32-bit millisecond limit (about 24.8 days), causing
immediate expiry and token clearing.

Scheduling now uses at most one-day intervals, rechecks the absolute expiry at each
wake, and ignores callbacks for a disposed/replaced session. Genuine expiry still
clears tokens. This also applies to restored sessions, MFA and verification tokens.
No server token lifetime or auth protocol was changed.

An isolated Chromium page reproduced the 30-day timer firing within 150ms while a
one-day timer remained pending. It used no credentials or API requests. Fourteen
focused Flutter tests passed, including keeping the bearer through a delayed `/me`
with a 30-day token and clearing a genuinely expired restored token. The automated
Chrome Flutter harness stalled before running its test and was stopped; no live
Chrome login success is claimed from that harness.

Restart the app with:

```powershell
flutter run --debug -d chrome --dart-define=APP_ENV=development --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1/mobile --dart-define=MHP_API_DIAGNOSTICS=true
```

Sign in once and report only `MHP API` lines. The optional debug hook records method,
route (numeric identifiers replaced), HTTP status and bearer attached/none. It
never prints header values, credentials, payloads or response bodies. Production
release startup does not supply the hook. Real authenticated 401 still clears the
session; no refresh endpoint, fallback login or certificate bypass was introduced.

Validation: the disposal regression and existing journey tests passed (3 tests).
The local web debug build compiled successfully. Native Flutter controller guards
also apply on Android/iOS; no device or iOS build was claimed.
