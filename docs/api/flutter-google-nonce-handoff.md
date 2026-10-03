# Flutter implementation prompt — Google challenge exchange, contract 2.0

Implement per-attempt nonce-bound Google sign-in and explicit Google linking in the
existing Flutter MHP project. Read the accompanying mobile.openapi.yaml (2.0.0) and
mobile-integration.md first. This is a coordinated breaking change; Build 8's old
token-only flow must not be presented as compatible.

## Exact protocol

- Backend base is the configured environment plus /api/v1/mobile. Use a separate
  non-production environment for live account tests; never silently use production.
- GET /auth/providers: data.google controls configuration availability and
  data.google_challenge_required=true advertises the required new flow.
- On EVERY explicit Google sign-in/link attempt, POST /auth/google/challenge with
  no body/bearer. Expect 201 {challenge_id, nonce, nonce_mode:"raw", expires_at}.
- Pass nonce UNCHANGED to Google's per-attempt native request. Do not SHA-256 it.
  The signed Google ID token must contain precisely that string in its nonce claim.
- POST /auth/google with {challenge_id,id_token,device_name}; add name and terms:true
  for new registration. The raw nonce is not an additional exchange request field.
- Preserve normal AuthResponse handling (authenticated, two_factor_required,
  email_verification_required). Read access_token, not token. Never bypass MFA or
  MHP email verification because Google says the email is verified.
- For explicit linking: obtain a NEW challenge/native credential, then POST
  /auth/providers/google/link with {challenge_id,id_token,current_password} and the
  current verified MHP Bearer token. account_link_required must direct the user
  through their existing account; never auto-merge on email.

## Native adapter requirement

google_sign_in 7.2.0 accepts nonce only at initialize, which is called once. Do not
reinitialize its singleton for each challenge, and do not assume signOut refreshes
the ID token. Implement a MethodChannel/native adapter or a supported plugin patch
that accepts nonce per sign-in invocation. Keep native authentication scoped to
that attempt, not a static shared nonce.

Android: use Credential Manager's explicit Google button request
GetSignInWithGoogleOption.Builder(serverClientId).setNonce(rawNonce).build(), with
the configured Web OAuth client ID. Inspect current dependency APIs and package /
signing registration first. Return the ID token only to the requesting Dart call.
iOS: use a Google Sign-In SDK version with a nonce-bearing per-attempt sign-in API;
verify its exact installed API and configure bundle/client/reversed-client URL
scheme. If the installed version lacks support, update it compatibly or keep Google
disabled on iOS until supported. Do not substitute Apple's hashed nonce convention.
Web: implement and test a separate nonce-capable Google browser flow if web sign-in
is supported; do not pretend a native MethodChannel works in the browser.

Keep initialization/configuration once per platform and credentials transient.
Keep Google nonce/state completely separate from Apple nonce/state and MHP MFA.
Never embed a Google client secret in Flutter. TLS verification stays enabled.

## Attempt lifecycle and errors

Disable duplicate taps while acquiring/exchanging a credential. Associate each
challenge with an immutable attempt ID. Ignore late native callbacks after cancel,
logout, account switch, route disposal, or a newer attempt. Do not keep challenges
or Google ID tokens in persistent storage or logs. Delete transient attempt state
when finished. A fresh MHP challenge must precede each new native request.

Keep the server's five-minute iat limit and single-use policy. Do not catch 409 and
resend the same token with another challenge. For google_challenge_used,
google_challenge_expired, google_challenge_invalid, google_nonce_mismatch or
credential_already_used, discard the attempt and offer a new sign-in action. Avoid
automatic retry loops. A lost success response needs a new challenge/native flow.
Treat invalid_provider_credential as a credential error, not an expired MHP session.
Maintain existing safe error distinctions for 403, 422, 429 and connectivity errors.

## Tests and acceptance

Unit/native adapter tests: nonce passed unchanged per call; two calls use distinct
challenges; SDK initialization occurs once; cancellation/late callbacks cannot
exchange stale attempts; second request after logout contains a new challenge;
all documented error branches remain actionable; no token/nonce/claims in logs.
Preserve linking, MFA, email verification and normal device-token storage tests.

Run analyze and relevant Dart/native tests. Build an explicitly numbered APK after
implementing the adapter. A backend deployment alone cannot fix Build 8.

With a designated non-production Google account/backend, verify:
create with Google -> MHP email verification -> logout -> Google login twice more.
Record build, UTC, HTTP status, AuthResponse status and safe server reason enums
only. Do not record token bodies, nonce, subject, email, name, bearer or full claims.
Confirm success on a real provider/device; mocked tokens do not establish this.
If no non-production backend/account is available, report this as unverified and
provide exact setup steps rather than claiming live completion.

Deliver adapter changes, tests, APK/build details, incremental commits, and actual
evidence. Coordinate release so unsupported builds hide Google or require upgrade;
do not add a backend legacy bypass. Password login remains available where configured.

Official native references:
- https://developers.google.com/identity/android-credential-manager/android/reference/com/google/android/libraries/identity/googleid/GetSignInWithGoogleOption.Builder
- https://developers.google.com/identity/sign-in/ios/release
