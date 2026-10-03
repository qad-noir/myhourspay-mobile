# Native API setup

## Environment and networking

Required public build-time values:
- APP_ENV: development, staging or production.
- API_BASE_URL: explicit origin plus /api/v1/mobile, without credentials/query.

Development rejects the known production host. Staging and production require
HTTPS. Release builds reject HTTP even in the development environment. The client
never disables certificate verification and never follows API redirects.

Android emulator: http://10.0.2.2:8000/api/v1/mobile.
Host-side repository verification: http://127.0.0.1:8000/api/v1/mobile.
Physical devices need a reachable LAN service or an HTTPS tunnel; device localhost
is not the development computer. Use an HTTPS tunnel on iOS unless an explicitly
scoped debug-only local networking exception is configured by the iOS developer.
The committed iOS release plist has no ATS exception. Android HTTP permission is
in the debug manifest only; release must use HTTPS.

Production target after confirmed backend deployment:
https://mhp.glsltd.co.uk/api/v1/mobile. Deployment has not been assumed or tested.
Staging still needs an isolated database, HTTPS service and provider registrations.

## Native credentials and signing

Android debug uses .dev applicationIdSuffix to isolate it from a later release.
The base com.example.myhourspay identity is still a scaffold placeholder; the owner
must supply final package/bundle identities and release signing. The generated
release build still has scaffold debug signing and MUST NOT be uploaded as a release.
Do not guess a reverse-domain identity from the website host. Full staging flavour
and matching iOS schemes/provider configs are still a release configuration task.

Android needs working cmdline-tools, accepted SDK licences and the Flutter-selected
NDK. Secure-storage data is excluded from Android auto-backup. No biometric permission
is requested. Tokens live in platform-backed storage, not preferences.

iOS requires macOS, Xcode, Apple team/signing and device provisioning. Runner has
keychain entitlements; validate secure write/read/delete on a real signed device.
The token uses unlocked-this-device keychain access. Do not claim Windows builds
iOS. Neither iOS nor native keychain/keystore behaviour has been device-tested here.

## Google / Apple

GET /auth/providers is called without an MHP token. A false/unavailable provider
never becomes a sign-in action. Android Google is wired when
GOOGLE_SERVER_CLIENT_ID is supplied and the backend reports true. Build with
config/production.json for the registered production APK. iOS Google still needs
its own client ID and URL scheme; Apple integration remains pending. See
docs/SOCIAL-SIGN-IN-SETUP.md.

Needed for Google: registered Android package, debug/release signing fingerprints,
iOS bundle/client configuration, correct web/server client ID and Laravel
MOBILE_GOOGLE_AUDIENCES. Needed for Apple: app/bundle and Services IDs, grouping,
team/key configuration on Laravel, MOBILE_APPLE_AUDIENCES, sender relay setup and
nonce-based native authorization. IDs/secrets are not inferred from the website.

Apple on Android also needs its registered HTTPS callback and verified secure
return-to-app handoff. The backend exchange endpoint is not that callback.
Never put MHP bearer tokens into URLs. See the integration guide for freshness,
nonce, replay, MFA, private relay and account-linking rules.

## Account flows and remaining release work

Verification stores the restricted access_token and replaces it only after a
successful /auth/email/verify response. MFA challenge_token is memory-only and
never a bearer credential. Expiry requires sign-in; there is no token refresh.

Offline logout clears local credentials/data but cannot confirm server revocation;
the UI explains this and suggests revoking from another session. Private records
are memory-only, and environment/account/workspace changes isolate them. Readonly
workspaces hide writes, but Laravel remains the permission authority.

Forgot-password starts the actual generic backend email flow. The reset link opens
the existing website; native reset deep links are not configured. Registration
requires terms acceptance and separate opt-in marketing consent. Terms/privacy open in the system browser using verified /terms and /policy routes. The legal copy
must be reviewed for launch. Trial-choice restrictions show an account-action
screen; no purchase or upgrade links are rendered.

Profile editing, account deletion/provider revocation, provider unlinking, push
registration/delivery and native trial-choice resolution are not supported by this
API contract. Complete them and current store privacy/deletion/login requirements
before release. They do not prevent the first hours workflow from being verified.

References used for dependency setup:
- https://pub.dev/packages/http
- https://pub.dev/packages/flutter_secure_storage
- https://pub.dev/packages/uuid
- https://pub.dev/packages/timezone
