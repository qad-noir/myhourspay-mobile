# Configure Google and Apple mobile sign-in

## Android Google integration (build 9)

The native Google SDK adapter is now wired into both login and signup. Build using `flutter build apk --release --dart-define-from-file=config/production.json`. This public configuration file includes the production API and the supplied Web OAuth client ID. No client secret is included or needed in Flutter. Builds without `GOOGLE_SERVER_CLIENT_ID` hide Google.

Current Android OAuth client: `69237986520-u5q4fqgij9dr4ijm2bfdcq7t6buq60qd.apps.googleusercontent.com`. Register package `com.example.myhourspay` and signing SHA-1 `F6:D1:F8:E5:ED:CA:A7:75:EC:54:A7:61:8E:E9:27:99:7E:AC:ED:10`. The SDK takes the **Web** client as serverClientId; the Android client ID is provider-console registration, not the Dart serverClientId.

Web/backend audience: `69237986520-s7mltqvpk5aqt3l2pljgemcmr8vtnvb1.apps.googleusercontent.com`. Set that exact value in production `MOBILE_GOOGLE_AUDIENCES`. Register debug package `com.example.myhourspay.dev` separately if testing debug builds. Register final store package and release/Play signing separately before launch.

The adapter performs explicit native authentication and a fresh single-use ID-token exchange. It requests no Calendar/Contacts access, stores no provider token, and routes the MHP response through existing MFA/email-verification/secure-session handling. Cancellation and provider configuration failures release the busy state. Existing matching MHP emails require authenticated linking. Account now offers Link Google with current-password confirmation; identities are never silently merged.

The current SocialInput contract and Laravel social controller do not support marketing_consent. Signup shows this limitation: the checked promotional preference applies to password registration only. A backend contract/controller update is required before social registration can persist promotional consent.

Build 9 uses contract 2.0: obtain a new `/auth/google/challenge`, pass its raw nonce unchanged to Android Credential Manager, then exchange `challenge_id`, `id_token` and `device_name`. Every new attempt, including linking, requests a new challenge. No provider credentials/nonces are persisted or logged. Old build 8 is incompatible with the new Google protocol.

Flutter web now uses an isolated same-origin browser document per attempt, initializes Google Identity Services once in that document with the raw nonce, and displays Google's official button in a cancelable dialog. Register the exact Flutter origin in the Web OAuth client's Authorized JavaScript origins. Use a fixed development port, for example `flutter run -d chrome --web-port=8080 --dart-define-from-file=config/development.example.json`, and register `http://localhost:8080` if that is the actual origin. Configure Laravel CORS to allow that origin. Client code compiles for web; real browser Google login remains unverified.

iOS Google is deferred at the owner's explicit request until an iOS OAuth client exists. Its button remains gated. A future per-attempt adapter must use GoogleSignIn 9.2.0's nonce-bearing sign-in API (or a verified compatible version), configure the bundle/client/reversed-client URL scheme and be built/tested with macOS/Xcode. No iOS nonce adapter or successful iOS build is claimed.

## Laravel configuration

Edit the deployed Laravel `.env` (not the Flutter project `.env`):

```dotenv
MOBILE_GOOGLE_AUDIENCES=YOUR_GOOGLE_WEB_OAUTH_CLIENT_ID.apps.googleusercontent.com
MOBILE_APPLE_AUDIENCES=YOUR_IOS_BUNDLE_ID,YOUR_APPLE_SERVICES_ID
```

Use exact real audience IDs issued for the intended apps; the comma-separated list must match the `aud` claim in provider ID tokens. These are public identifiers, not client secrets. Do not put secrets in Flutter builds. The backend reads these variables in config/mobile.php. Google Calendar integration variables are unrelated.

From the Laravel project directory after updating `.env`:

```sh
php artisan config:clear
php artisan config:cache
```

Check `GET https://mhp.glsltd.co.uk/api/v1/mobile/auth/providers`. Its documented response has `data.google` and `data.apple` booleans. Enabling an audience makes the server verifier available; it does not finish provider-console or app setup.

## Google console and app

Create/configure a Google OAuth project and consent screen. Create a Web OAuth client for the mobile backend's server client ID, Android clients matching the actual app package and signing SHA-1, and an iOS client matching the bundle ID. Register both development and release identities when using both. Production APKs currently use the scaffold `com.example.myhourspay`; debug builds add `.dev`. Choose final store identities and release signing before registering final clients. Play App Signing uses the Play app-signing certificate for installed store builds.

The Flutter adapter must request a new server Google challenge, pass its raw nonce to the provider request, and send the resulting ID token with challenge_id and device_name. New-account requests use the Google-provided name and explicitly accepted terms. Promotional consent is supported only for email/password registration. The provider ID token must never be saved as an MHP bearer token. Handle authenticated, MFA challenge and email-verification responses through the same session flow.

Official setup: [Google Android sign-in](https://codelabs.developers.google.com/sign-in-with-google-android), [signing client authentication](https://developers.google.com/android/guides/client-auth).

## Apple console and app

Enable Sign in with Apple on the real Apple App ID and iOS target capability/provisioning profile. For Android or web, create an associated Services ID and register the real HTTPS domain and return URL. The Android callback and secure app handoff need implementation/configuration; this project does not currently provide an existing Apple callback URL to register. Never put MHP access tokens into callback URLs.

The Flutter adapter must first request `POST /auth/nonce`, hash its raw nonce with SHA-256 for Apple authorization, then exchange the fresh ID token and original raw nonce through `POST /auth/apple`. Preserve Apple's first-login name and explicit account consent. Matching email addresses must not automatically link accounts; use the documented password-confirmed link operation. Configure your sender domain for Apple's private email relay when supporting relay accounts.

Official setup: [Apple environment configuration](https://developer.apple.com/documentation/signinwithapple/configuring-your-environment-for-sign-in-with-apple), [Services ID and web return URLs](https://developer.apple.com/help/account/capabilities/configure-sign-in-with-apple-for-the-web).

## What makes buttons appear in this Flutter build

The app fetches `/auth/providers`. A button appears only when its backend flag is true **and a real platform adapter is configured**. Android and web Google adapters are configured in build 9 using the public Web client ID above; web also needs registered browser origins. iOS Google needs its client and URL scheme; Apple adapters and Android callback/handoff remain unconfigured.

The test-only sign-up preview enables both buttons with isolated callbacks for visual review. It does not perform or pretend to succeed at provider authentication, and is not reachable from release routing. See docs/api/mobile-integration.md for exchange, nonce, linking and remaining store-release requirements.
