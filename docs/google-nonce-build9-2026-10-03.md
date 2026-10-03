# Google challenge integration — build 9, 3 October 2026

Build 9 uses https://mhp.glsltd.co.uk/api/v1/mobile from config/production.json. Public production providers returned google=true, apple=false, google_challenge_required=true. This confirms advertised deployment capability, not every backend branch.

The owner's connected Samsung Android 13 phone had build 9 installed successfully (ADB install Success, dumpsys versionCode=9). The owner tested Google sign-in, logout and two more sign-ins and reported: "All three attempts succeeded." This is real provider/device production evidence reported by the owner. It is separate from fixture tests. HTTP success/AuthResponse statuses were not captured from those attempts, and no tokens, nonces or personal claims were recorded. A new-account creation/email-verification cycle, live linking, live MFA and a non-production Google account run remain unverified.

Each attempt requests an anonymous POST /auth/google/challenge, passes raw nonce unchanged to Android Credential Manager GetSignInWithGoogleOption, and exchanges challenge_id/id_token/device_name. New signup takes Google's name and requires explicit terms. Provider credentials/challenges are transient. Busy state blocks duplicates; route disposal/session changes prevent stale callback exchange or session acceptance. Account offers explicit Link Google with current-password confirmation and an authenticated exchange. Challenge failures stay actionable inline; successes use disappearing toasts.

The canonical OpenAPI/integration guide was copied byte-for-byte from the supplied Laravel contract 2.0 artifact. Its source artifact and SHA-256 are recorded in docs/api/contract-lock.json. Backend replay, freshness, MFA and verification protections were not weakened.

Android adapter dependencies match the installed native Google plugin's versions: androidx.credentials 1.6.0, credentials-play-services-auth 1.6.0, googleid 1.2.0. Google singleton initialization is no longer used for authentication. The old plugin dependency remains installed but does not acquire credentials.

Web adapter compiles for Flutter web. Each attempt creates an isolated same-origin document, initializes Google Identity Services once with the raw nonce and displays Google's official button. Cancellation/late completion do not authorize stale exchanges. Two JavaScript fixture tests cover distinct raw nonces and profile/token handoff; they do not establish real web Google login. Register the exact browser origin on the existing Web OAuth client and allow it through Laravel CORS; use a fixed localhost port. Live web sign-in remains unverified.

iOS Google deferred at the owner's explicit request because no iOS OAuth client has been configured. No iOS Google adapter, Xcode build or device test is claimed. Future implementation must use a verified nonce-bearing SDK API, register the bundle/client/reversed-client URL scheme and be tested on macOS/iOS. Existing splash and layout changes retain iOS resources.

Also included from build 8: floating signup labels, Google profile without manual form inputs, expiring workspace/action success toasts, corrected account-link wording, branded native launch backgrounds and Flutter session-loading screen. Flutter loading layouts were rendered at 360/390/430px. Android 12+ uses the branded vector on the cream surface; native splash appearance and iOS storyboard still need device visual confirmation.

Validation: clean Flutter analyze; Google regression tests 16/16; contract tests 11/11; browser JavaScript fixture tests 2/2; SHA-256/protocol pin check passed. Full-suite and final build results are recorded below after completion.

Remaining release configuration: final Android package/signing (current release still uses debug signing), Play registration, exact web origins/CORS, iOS OAuth/Xcode setup, Apple platform integration. No Google client secret is embedded in Flutter.

Final verification: all 113 Flutter tests passed; Flutter analyze reported no issues. Final production web release build succeeded (94.2s) and final Android release build succeeded (101.3s, 53.6 MB). Readable API HTML regenerated with Redocly CLI 2.56.0. Source implementation commit: 07fc97c. The full create/verify/non-production acceptance journey and live browser/linking/MFA checks remain unverified as stated above.
