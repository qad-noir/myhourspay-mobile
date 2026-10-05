# Local web login diagnosis

The supplied trace shows HTTP 401 while fetching workspaces after login, followed
by access to a disposed password controller. Login, MFA and verification now guard
controller access after their asynchronous action completes and may replace the
route. The regression test disposes the login screen while workspace loading is
pending, then completes that request with 401.

A fresh designated local test login against `http://127.0.0.1:8000/api/v1/mobile`
returned login 200/authenticated, `/me` 200 and `/workspaces` 200. The temporary
diagnostic session was revoked (204). This was an HTTP probe, not a successful
Chrome login; the browser-specific rejection remains to be diagnosed.

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
