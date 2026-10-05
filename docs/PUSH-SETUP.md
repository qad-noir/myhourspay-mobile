# Native push setup and current status

The Flutter integration is prepared, not delivering production reminders yet.
Firebase has not been configured, and the current Laravel mobile contract has no
push registration/delivery routes. `ENABLE_NATIVE_PUSH` must stay false until
`PUSH-BACKEND-HANDOFF.md` is implemented, tested and deployed. No paid feature flag
is checked by the Flutter reminder preference.

## Android: use your existing Google project

1. Open [Firebase Console](https://console.firebase.google.com/). Add a project,
   select the existing Google Cloud project used for MHP Google sign-in, and finish
   setup. Google Analytics is optional for this feature.
2. Project settings → General → Add app → Android. The current release package is
   `com.example.myhourspay`; the debug package is `com.example.myhourspay.dev`.
   Register both if testing both variants. These must match the installed app;
   changing the package later also requires Google sign-in configuration changes.
3. Download each app's `google-services.json`. Put release at
   `android/app/src/release/google-services.json` and debug at
   `android/app/src/debug/google-services.json`. Both are ignored by Git. The
   conditional Google Services Gradle plugin generates the native Firebase resources.
4. From the corresponding JSON, copy the project/app values into your build JSON:

   | Build value | JSON value |
   |---|---|
   | FIREBASE_PROJECT_ID | project_info.project_id |
   | FIREBASE_MESSAGING_SENDER_ID | project_info.project_number (string) |
   | FIREBASE_ANDROID_APP_ID | matching client.client_info.mobilesdk_app_id |
   | FIREBASE_ANDROID_API_KEY | matching client.api_key[0].current_key |

   These are client configuration, **not** a Laravel service-account private key.
   Keep `ENABLE_NATIVE_PUSH` false while configuring the server.
5. Project settings → Cloud Messaging: confirm Firebase Cloud Messaging API (V1)
   is enabled. Project settings → Service accounts → Generate new private key.
   Install that file on Laravel outside the public directory and configure the
   server implementation to use it. Never add it to Flutter, Git or build JSON.
6. Paste [the Laravel handoff](PUSH-BACKEND-HANDOFF.md) in the Laravel project. Deploy
   its migrations, routes, worker and scheduler; return its updated OpenAPI and
   integration guide. Confirm the endpoint works using the designated test account.
7. Set `ENABLE_NATIVE_PUSH` true in the production JSON and build using
   `--dart-define-from-file=config/production.json`. Install on the test phone,
   sign in, open Account → Reminders → Missing hours, enable it and grant Android
   notification permission. The switch is on only after the server confirms saving.

Daily production eligibility is weekdays after 18:00 in each active writable
workspace's timezone, only when no hours entry exists. An opted-in device receives
reminders for its account's active writable workspaces, independently of plan.
This delivery rule must be implemented on the server, not an app background timer.

## iOS: prepared, still requires macOS/Xcode and Apple credentials

Register the matching iOS bundle in Firebase (currently `com.example.myhourspay`).
Add GoogleService-Info.plist to the Runner target in Xcode. Set build values
FIREBASE_IOS_APP_ID, FIREBASE_IOS_API_KEY and FIREBASE_IOS_BUNDLE_ID plus the shared
project/sender values. Enable Push Notifications and Background Modes → Remote
notifications on the Runner target, with provisioning that includes `aps-environment`.
Upload your APNs authentication key, key ID and Apple team ID to Firebase Cloud
Messaging. The remote-notification background mode is present in Info.plist;
signing/capability setup and real iOS verification remain outstanding on Windows.
FCM token registration waits for an APNs token; retry after the device is ready.

## Expected behavior and verification

Android 13 requires runtime permission; ask only when the user enables reminders.
Background/terminated notification messages use the OS notification UI. Foreground
Android messages show an app toast; iOS uses native foreground presentation.
Tapping a reminder opens the relevant Hours week after login and ownership checks.
Token rotation updates registration. Signing out unregisters and deletes the local
FCM token; the server must also reject expired/revoked mobile sessions even when
offline logout could not confirm deregistration.

Test foreground, background, terminated launch, denial, rotation, logout, revoked
session, different accounts, multiple workspaces, an existing entry and free plans.
Use a disposable workspace/account and document actual FCM and server delivery
evidence; a Firebase-console test alone does not prove missing-entry scheduling.
Web browser push needs separate service-worker/VAPID setup and is outside this
native production-app implementation. Web builds must continue to run normally.

Official guides: [Flutter client](https://firebase.google.com/docs/cloud-messaging/flutter/get-started),
[Android configuration](https://firebase.google.com/docs/android/google-services-plugin-and-file),
[HTTP v1 delivery](https://firebase.google.com/docs/cloud-messaging/send/v1-api).
