# Android Google sign-in: build 5

Implemented the official google_sign_in 7.2.0 native adapter using the supplied Web OAuth client as serverClientId. Login and signup require both the backend provider flag and a configured native adapter. Exact contract JSON is exchanged through POST /auth/google; returned MHP status/access_token/challenge_token use the existing session flow. Provider tokens are never stored, logged, retried or treated as MHP bearer tokens. Busy state covers the native chooser and exchange. Existing-email linking conflicts remain explicit.

Verification on 3 October 2026:

- Public production GET /auth/providers returned data.google=true, data.apple=false.
- flutter analyze --no-pub: no issues.
- flutter test --no-pub: 100 tests passed. Added seven fixture-based checks for Google button wiring, authenticated/verification/MFA routing, duplicate prevention/cancellation, backend gating and separate iOS configuration gating. These do not prove live Google authentication.
- flutter build apk --release --dart-define-from-file=config/production.json completed successfully (53.8 MB).
- ADB replacement installation succeeded on the connected phone. Package version and launch are checked separately in the installation command output.

Remaining live checks/configuration: user must complete the real Google account chooser and backend exchange. The OAuth consent audience/test users and package/signing registration require verification in the owner's Google console; client IDs alone do not establish that they are correct. Existing MHP accounts require authenticated provider linking, whose mobile UI is pending. Promotional consent is not supported by the current social contract/controller; signup explains that its preference applies to password registration only. iOS needs its own client ID and reversed URL scheme, and later macOS/Xcode device testing. Flutter web needs registered origins and the SDK-rendered web button; native-only actions remain hidden on web. Apple is still unconfigured. Current Android package/development signing remain temporary before store release.
