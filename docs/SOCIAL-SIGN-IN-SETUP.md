# Configure Google and Apple mobile sign-in

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

The Flutter adapter must initialize the Google SDK with the correct serverClientId (and appropriate iOS client/URL settings), obtain a fresh provider ID token, and send it to `POST /auth/google` with `device_name`. New-account requests also need explicit name/terms and the separate marketing choice. The provider ID token must never be saved as an MHP bearer token. Handle authenticated, MFA challenge and email-verification responses through the same session flow.

Official setup: [Google Android sign-in](https://codelabs.developers.google.com/sign-in-with-google-android), [signing client authentication](https://developers.google.com/android/guides/client-auth).

## Apple console and app

Enable Sign in with Apple on the real Apple App ID and iOS target capability/provisioning profile. For Android or web, create an associated Services ID and register the real HTTPS domain and return URL. The Android callback and secure app handoff need implementation/configuration; this project does not currently provide an existing Apple callback URL to register. Never put MHP access tokens into callback URLs.

The Flutter adapter must first request `POST /auth/nonce`, hash its raw nonce with SHA-256 for Apple authorization, then exchange the fresh ID token and original raw nonce through `POST /auth/apple`. Preserve Apple's first-login name and explicit account consent. Matching email addresses must not automatically link accounts; use the documented password-confirmed link operation. Configure your sender domain for Apple's private email relay when supporting relay accounts.

Official setup: [Apple environment configuration](https://developer.apple.com/documentation/signinwithapple/configuring-your-environment-for-sign-in-with-apple), [Services ID and web return URLs](https://developer.apple.com/help/account/capabilities/configure-sign-in-with-apple-for-the-web).

## What makes buttons appear in this Flutter build

The app fetches `/auth/providers`. A button appears only when its backend flag is true **and a real platform adapter is supplied**. This is intentional: the native SDKs, developer IDs and Apple Android callback/handoff are still unconfigured. There are no existing social-sign-in Dart flags that finish that setup. Provide the real client IDs, app identities, signing certificates and callback details before implementing/wiring those adapters. Do not enable buttons that cannot actually complete sign-in.

The test-only sign-up preview enables both buttons with isolated callbacks for visual review. It does not perform or pretend to succeed at provider authentication, and is not reachable from release routing. See docs/api/mobile-integration.md for exchange, nonce, linking and remaining store-release requirements.
