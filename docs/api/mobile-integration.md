# MHP native API integration — version 2.0.0

This implementation replaces the earlier `0.1.0-draft` contract. The canonical
file is `docs/api/mobile.openapi.yaml`. It uses JSON syntax, which is valid YAML
1.2 and OpenAPI 3.1; Swagger Editor/UI and OpenAPI client tools can read it.
Regenerate it with `python scripts/build-mobile-contract.py`; CI can use
`python scripts/build-mobile-contract.py --check` to detect drift. Pin the file
and its Git commit in the Flutter repository. Do not keep using the old draft's
`state`/`token` fields: the implemented API uses `status`/`access_token`.

## Deployment and environment

Production target after deployment: `https://mhp.glsltd.co.uk/api/v1/mobile`.
These changes were implemented and tested locally, not deployed by this task.
Local backend: `http://127.0.0.1:8000/api/v1/mobile`; Android emulator:
`http://10.0.2.2:8000/api/v1/mobile`. A physical device needs a reachable LAN
address or HTTPS tunnel. Staging is not configured. Never silently fall back
to production. No automated write test should use production.

Native clients send `Accept: application/json` and `Authorization: Bearer TOKEN`.
JSON bodies use `Content-Type: application/json`. There is no browser session,
CSRF-cookie handshake, client secret embedded in Flutter, or JWT MHP session.
The existing external API stays separate and paid; mobile tokens cannot use it.

## Working first journey

1. POST `/auth/login` with email, password, device_name.
2. For `two_factor_required`, POST challenge_token and code/recovery_code to
   `/auth/two-factor`. Do not treat the challenge as a bearer token.
3. For `email_verification_required`, store the restricted token and show a
   verification screen. POST `/auth/email/verify`; replace the token with the
   new returned token. Resend is `/auth/email/resend`.
4. GET `/me`, then `/workspaces`. For a new account, POST `/workspaces` with the
   documented defaults and position. Existing users choose a returned workspace.
5. GET `/workspaces/{id}/hours?start=2026-09-28&end=2026-10-04`.
6. POST `/workspaces/{id}/hours` with a new UUID `Idempotency-Key` and the documented
   hours body. The created entry is the same database record used by the website.
7. PATCH an entry with all required input fields, its current `version`, and a
   new idempotency key. A stale version or locked week returns 409.

Workspace selection is local to the device. Resource paths carry the workspace
ID; do not switch the website's global current_workspace_id for each mobile read.
Workspace creation initializes the existing web onboarding state too.

## Authentication rules

Normal tokens default to 30 days (`MOBILE_TOKEN_DAYS`), verification tokens to
60 minutes, and MFA challenges to five minutes/five failed attempts. Tokens
have explicit per-token expiry even while global Sanctum expiry is unset. A
shorter existing global Sanctum expiry still takes precedence. No refresh endpoint
exists; reauthenticate on expiry. Store tokens in platform-backed secure storage.

MFA recovery codes are consumed once. Challenges are invalidated by changes to
password/MFA configuration. Password reset/change revokes existing Sanctum tokens,
including external integration tokens. Suspended and deleted accounts cannot
authenticate. A suspended account is also blocked on subsequent mobile requests.

GET `/auth/sessions` lists the user's mobile tokens. DELETE `/auth/session`
revokes the current token; DELETE `/auth/sessions/{id}` revokes another owned
mobile token. Offline logout can erase local credentials but cannot prove server
revocation. Biometric unlock is an optional local convenience, not replacement MFA.

Forgot-password sends the existing generic-response email flow. The email still
opens the web reset page; `/auth/reset-password` also accepts the emailed reset
token. Native reset/app links have not been configured.

## Google and Apple

GET `/auth/providers` returns availability. Empty audience configuration fails
closed with `provider_not_configured` (503). Flutter must hide unavailable actions
or show an honest disabled state, not simulate successful authentication.

Configure comma-separated OAuth client IDs in `MOBILE_GOOGLE_AUDIENCES` and Apple
bundle/service IDs in `MOBILE_APPLE_AUDIENCES`. These must be exact intended
audiences. Google SDK serverClientId should identify the configured backend/web
OAuth client. Android package/signing fingerprints and iOS bundle/client settings
must also be registered in the provider consoles; they cannot be derived from
the website URL. Use separate development/production registrations where possible.

POST `/auth/google` with a fresh nonce-bound provider ID token, challenge_id and device_name (see the v2 flow below). POST `/auth/apple` retains its existing nonce flow.
Tokens must have been issued within five minutes. Server validates RS256 signature
with provider keys, issuer, audience, subject and expiration; successful credentials
are single-use. Provider credentials never become MHP bearer tokens. Existing MHP
MFA still applies after social verification.

For Apple, first POST `/auth/nonce`, pass SHA-256 of the returned raw nonce as the
Apple authorization nonce, then send the raw nonce with id_token to MHP. Apple
native and Android browser flows must preserve that signed nonce. Android also
requires an Apple Services ID, registered HTTPS return URL and a secure app handoff;
that provider callback/verified-app-link configuration is not implemented by these
token-exchange endpoints. Do not put MHP tokens in callback URLs.

For a new social account, provide name and terms=true. MHP sends its own email
verification code, including to Apple relay addresses. Configure the sender domain
with Apple's private email relay. Capture Apple's initial name locally because
it may not be returned on later authorizations. A matching existing MHP email
returns `account_link_required`; it never silently merges identities.

To link: authenticate the existing MHP account, complete MFA/verification, then
POST `/auth/providers/{provider}/link` with id_token and current_password; Google also requires challenge_id and a signed raw nonce, while Apple requires its raw nonce request field. Social-only accounts can establish a password via recovery.
Stable provider subjects are stored separately; case-sensitive hashes avoid
collation-dependent identity matching and keep indexes within older MySQL limits.

Live provider sign-in on devices is not yet verified: actual client IDs and platform
configuration are still required. Automated tests use locally signed RSA credentials
and mocked provider key endpoints; they do not contact real user accounts.

## Hours and timesheets

Hours use local calendar `work_date` (YYYY-MM-DD) and wall-clock HH:MM times,
not UTC timestamps. Workspace response exposes the existing application hours
timezone. Weeks start Monday. This preserves web calculations: overnight shifts
are unsupported and wall-clock subtraction does not adjust for DST transitions.
Breaks must be shorter than the shift, even when paid. Unpaid breaks are deducted.
One active date per user/workspace is supported; the existing database uniqueness
also includes soft-deleted rows, so restore/delete-date reuse must follow web rules.
Duplicate-date validation returns HTTP 422 with `code: validation_failed` and
`errors.work_date: ["This date already has an entry. Try editing it instead."]`.

Hours, timesheet and project foreign keys are normalized through integer model
casts, including MySQL drivers that hydrate numeric IDs as decimal strings.
Nullable foreign keys remain null. Strict user/workspace authorization is retained;
an owned entry's 404 must be investigated rather than assumed to be a missing route.
There is no new editing route: continue PATCH with the current version and a UUID
Idempotency-Key. Refresh records after deployment before beginning a new edit.

Timesheet routes enforce `timesheet_approvals`; project use enforces
`clients_projects`. Core personal hours do not require paid `api_access`.
Readonly workspaces remain readable but reject mutations. Server permissions are
authoritative; never infer access from a hidden button or app-specific header.

Timesheet submit/review use the shared web workflow, activity records and existing
outbound webhooks. GET timesheets defaults to the user's own; `scope=review`
requires a reviewer role. Review version covers linked hours as well as status.
Approval locks the week. Entry writes check both original and destination weeks.
The existing workflow allows reviewers to review their own timesheet; no new
separation-of-duties rule is introduced here.

Hours listing is paginated, ordered by work date then ID; summary is for the whole
requested range. Partial weeks are labelled and empty weeks omitted. Use minutes
for UI calculations; returned formatted totals are HH:MM, not decimal hours.

## Retries, errors and cache

Hours create/update and timesheet submit/review require `Idempotency-Key` UUID.
Keep it for retries of the same operation/payload; generate a new one after an
edit. Successful response snapshots are retained in mobile_mutations; do not
reuse old keys for new operations. Replays return the original snapshot, which
may now be stale—refresh the list afterwards. Workspace creation is not idempotent:
refresh memberships before retrying an uncertain creation.

Error bodies contain `code`, `message`, and optionally Laravel `errors` by field.
401 means reauthenticate. 403 is an account/role/feature restriction, not automatic
logout. 409 requires conflict handling. 422 maps to field/credential errors.
429 may include Retry-After. Private responses use Cache-Control: private, no-store.
Use explicit per-account/workspace cache isolation and clear local data on logout.

Start online-first with optional clearly marked drafts. Do not silently queue
offline writes, mark unsent drafts as saved, or overwrite newer/approved records.
Redact passwords, bearer tokens, provider tokens, nonce and MFA/recovery values
from logs and telemetry.

## Remaining store-release work (not a blocker for the first live hours journey)

The web `/user/profile` page now has a separate Mobile devices section alongside
Jetstream Browser sessions. It lists only owned, unexpired `mobile:` Sanctum tokens,
including the global Sanctum lifetime when configured. Unused sessions say "Not used
yet"; expired sessions are omitted. Revocation requires the user's current password
and uses the CSRF-protected Livewire web update route, with cancelable confirmation.
No token secrets are rendered. Browser-session controls and native session routes
remain separate; this feature does not introduce token refresh.

- Native profile editing, account deletion including provider revocation, provider
  unlinking, and push-device registration/delivery are not in this contract.
- Apple Android callback/verified links and provider app registrations need setup.
- Password-reset email deep linking and mobile trial-choice resolution are not
  implemented. Trial-restricted accounts return a structured state; keep mobile
  purchasing/upgrade links out until the store-specific flow is reviewed.
- No in-app subscriptions or Stripe checkout are added. Existing entitlements apply.
- The generated design boards are proposed visuals, not a working Flutter build;
  Google/Apple and timesheet controls are conditional on provider/feature availability.
- App Store account-deletion, privacy and login requirements need completion before
  submission. This backend patch is not a claim that the full mobile app is release-ready.

## Continuation and deployment history

This work continues the task **Continue Hours Calculator migration**:
`codex://threads/01a076b4-ada1-7a12-a13c-e02dcbaf1598`.
Keep its production packaging convention: timestamped ZIP under production-patches,
Laravel-relative runtime paths, and separate deployment notes, manifest and checksum
under ignored deployment-notes. Do not include .env, user data, development caches,
unrelated work, or test files in the production upload.

## Google nonce-bound exchange � contract 2.0 (coordinated breaking change)

Older Google clients, including Build 8 without a per-attempt nonce adapter, must
upgrade. GET /auth/providers now includes data.google_challenge_required=true.
There is no token-only fallback. Password login and Apple's nonce flow are unchanged.

1. POST /auth/google/challenge with no body or bearer. Requires configured Google
   audiences; returns 503 provider_not_configured otherwise. Throttle: 10/minute/IP.
   Success: HTTP 201 with:
   {"challenge_id":"UUID","nonce":"64 lowercase hex characters","nonce_mode":"raw","expires_at":"UTC ISO8601"}
2. Nonce has 256 random bits, expires in five minutes, and is stored only as SHA-256
   server-side. Pass the returned RAW nonce to Google, unchanged. Google must return
   the exact raw string as the signed ID token's nonce claim. Do NOT hash it like Apple.
3. POST /auth/google:
   {"challenge_id":"UUID","id_token":"GOOGLE_ID_TOKEN","device_name":"Android phone"}
   Add name and terms=true when registering. Do not send the raw nonce separately.
   The server compares the signed claim's hash against the server-issued hash.
4. A successful exchange atomically marks the challenge consumed, inserts the
   existing unique token replay hash and creates/finds the identity or issues the
   existing MFA challenge/device token. Response stays AuthResponse (HTTP 200):
   authenticated, email_verification_required, or two_factor_required. MFA and email
   verification are still mandatory where applicable. Successful MFA initiation
   consumes the Google challenge even before MFA completion.
5. Every new login and explicit link starts a NEW Google challenge and NEW native
   credential request. Logout does not delete credential replay records.
   For POST /auth/providers/google/link send challenge_id, id_token and current_password,
   authenticated with the existing verified MHP bearer. Never silently merge email matches.

All signature/RS256/key/issuer/audience/exp checks and the five-minute iat freshness
limit remain unchanged. A nonce does not permit an old or replayed token.
Challenge consumption uses SELECT FOR UPDATE plus a conditional consumed_at update
inside the same transaction as token replay insertion and account work. If that
transaction fails, consumption rolls back. Clients should nevertheless restart
with a new challenge/native attempt after any failed or uncertain exchange.
No retry/idempotency exemption exists for provider credentials.
Expired challenge rows are pruned daily; after pruning they report invalid rather
than expired/used. The existing credential replay retention/expiry is unchanged.

Errors (existing JSON code/message/errors envelope):
- 422 validation_failed: missing/malformed challenge_id or other fields.
- 422 google_challenge_invalid: no matching Google challenge.
- 422 google_challenge_expired: unconsumed challenge has expired.
- 422 google_nonce_mismatch: signed nonce absent, wrong type/format, hashed or mismatched.
- 409 google_challenge_used: challenge already consumed.
- 409 credential_already_used: exchange token hash already recorded.
- 409 account_link_required: matching existing MHP email needs explicit linking.
- 409 account_link_conflict: identity/credential conflict during explicit linking.
- 422 invalid_provider_credential: cryptographic/issuer/audience/expiry/freshness failure.
- 403 account restrictions; 429 throttling; 503 provider_not_configured still apply.

Platform requirements:
google_sign_in 7.2.0's initialize-time nonce is insufficient for per-attempt
challenges, and repeatedly initializing the singleton is unsupported. Use a native
Android/iOS adapter (or verified plugin change) accepting nonce on EACH invocation.
Android Credential Manager's Google button request supports a nonce; iOS must pass
nonce using the installed Google Sign-In SDK's per-attempt API and prove the signed
claim in real-device tests. If unsupported, gate Google sign-in on that platform.
Flutter Web likewise needs its own per-attempt nonce-capable Google flow; do not
reuse native adapter assumptions. Never send Google client secrets in Flutter.
See flutter-google-nonce-handoff.md for exact implementation and release steps.
