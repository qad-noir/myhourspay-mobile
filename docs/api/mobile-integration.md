# MHP native API integration — version 2.2.0

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
not UTC timestamps. Workspace response exposes its optional IANA timezone, falling
back to the existing application hours timezone. Weeks start Monday. This preserves web calculations: overnight shifts
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

### Workspace overtime settings — added in 2.2.0

Existing workspaces default to `overtime_basis: weekly` and
`contracted_daily_minutes: null`. Adding a daily contract alone leaves the selected
basis weekly. An owner/administrator chooses Daily or Weekly per workspace.
These settings apply to all historical dates as a read-only calculation. No hours,
breaks, stored earnings/rates, approval status, entry versions or timesheet versions
are rewritten. Payroll exports reclassify regular/overtime minutes using the chosen
basis while retaining stored earnings. Compensation pricing is unchanged.

Daily overtime is `sum(max(0, net minutes per work_date - contracted_daily_minutes))`.
Short days cannot cancel long days; weekends use the same daily contract when hours
are recorded. Missing days contribute zero overtime. Weekly overtime is
`sum(max(0, net minutes per Monday–Sunday week - weekly_target_minutes))`.
Do not add the two figures together. `overtime_minutes` is the selected figure;
`daily_overtime_minutes` and `weekly_overtime_minutes` are comparisons. A null daily
contract or daily overtime means **not configured**, rather than zero. Weekly
`variance_minutes` remains signed weekly-target variance even in Daily mode.

Workspace responses add `contracted_daily_minutes` (nullable integer 1–1440),
`overtime_basis` (`daily|weekly`), `settings_version` (64-character SHA-256) and
`can_manage_settings`. Workspace creation accepts the two optional settings.
PATCH `/workspaces/{workspace}/settings` requires a verified mobile access token,
writable workspace and owner/administrator membership. Send at least one setting,
the last workspace `settings_version`, and a new UUID `Idempotency-Key`:

```http
PATCH /api/v1/mobile/workspaces/123/settings
Authorization: Bearer <device token>
Accept: application/json
Content-Type: application/json
Idempotency-Key: <new UUID>
```

```json
{
  "settings_version": "<64-character value from GET /workspaces>",
  "weekly_target_minutes": 2400,
  "contracted_daily_minutes": 480,
  "overtime_basis": "daily"
}
```

Success is HTTP 200 `{"data": Workspace}` with a new settings version. Omitted
settings retain their values. Effective Daily mode requires a positive daily
contract; clearing it requires switching to Weekly in the same request. Native
clients send integer minutes; the web decimal-hours input rounds to the nearest
minute. Invalid settings return 422 `validation_failed` with field errors. Stale
settings return 409 `workspace_settings_changed`; reload and ask the user to review
before saving. Same key/different body returns 409 `idempotency_conflict`.
Foreign workspace is 404, insufficient role is 403, read-only workspace returns
403 `workspace_read_only`. Retry an uncertain request using its exact body/key;
the replay snapshot may be stale, so refresh workspaces and summaries afterwards.

GET hours summary includes the new settings and both overtime figures for the
**entire requested range**, independent of pagination. Entry payloads add nullable
`daily_overtime_minutes`; timesheet payloads add basis, daily contract and both
comparison totals plus selected overtime. Existing edit/review versions remain
stable when only workspace overtime settings change. Never persist derived
overtime back into entries or include it in a client-generated version.

For a monthly overview, request exact calendar-month dates for total hours, daily
overtime and calendar cells. The web's existing Weekly monthly overtime includes
full Monday–Sunday weeks intersecting that month. Use a separate expanded-range
request for that weekly figure/comparison; use the exact-month daily figure in
Daily mode. Expanded weeks must not inflate daily monthly overtime. Label boundary
weeks and comparison scope. Calendar cells use their date's daily excess; weekly
overtime has no automatic per-day allocation. Server wall-clock/break rules remain
unchanged. Refresh local workspace caches, overview, hours and timesheets after a
settings save; Laravel invalidates its dashboard/admin caches.

Acceptance fixture: 8h daily contract, 40h weekly target, Monday 10h and Tuesday
through Friday 7h each => 38h worked, 2h daily overtime, 0h weekly overtime, signed
weekly variance −2h. Daily selection shows 2h; Weekly selection shows 0h. Test past
approved/locked records and verify no persisted entry/approval changes.

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
  unlinking are not in this contract. Free native missing-entry push is implemented
  in 2.1.0 but requires server Firebase/queue setup and coordinated Flutter rollout.
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

## Google nonce-bound exchange — contract 2.0 (coordinated breaking change)

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

## Free native missing-entry push — added in 2.1.0

GET, PUT and DELETE `/push/device` require a verified, active native `mobile:access`
Sanctum bearer. Verification-only tokens receive 403; MFA challenge credentials,
browser sessions, integration tokens and absent/expired bearers cannot register.
These routes have neither api_access nor smart_reminders middleware. Every plan,
including free, can opt in; writable-workspace and valid-membership rules still
apply. This setting never alters email reminders or marketing consent.

GET HTTP 200: `{"data":{"enabled":false}}` when absent or disabled; true when the
stored registration is enabled. No FCM token, token hash or registration ID is
returned. PUT HTTP 200 accepts exactly this documented client shape:

```json
{"enabled":true,"token":"FCM_REGISTRATION_TOKEN","platform":"android","device_name":"Samsung Galaxy"}
```

Use a strict JSON boolean; platform android/ios; token nonempty string max 4096,
required when enabling and prohibited when disabling; device_name max 255. Disable
with `{"enabled":false,"platform":"android","device_name":"Samsung Galaxy"}`,
omitting token, including null. Success envelope is `{"data":{"enabled":true}}`
or false. PUT requires UUID Idempotency-Key: identical key/body replays original
200 with Idempotency-Replayed=true; changed body/path/method returns 409
idempotency_conflict. Scope is authenticated mobile session, not workspace.
GET reports current state if a historic replay no longer reflects later settings.
DELETE requires no idempotency key, returns 204, is repeatable and unregisters only
the current session. Existing code/message/optional errors envelope and 401,403,
409,422,429,503 statuses apply. Client user/session IDs are never used for binding.

Registration tokens are encrypted with Laravel APP_KEY at rest and omitted from
model/API serialization. A unique SHA-256 token hash and a transactional rebinding
lock ensure one binding per FCM token; authenticated rotation/rebinding removes
previous user/session ownership. Idempotency records contain a keyed request digest
and safe response only. Losing APP_KEY prevents decrypting registrations; preserve
the current key and Laravel key-rotation policy. Never enable request-body capture
on this route in proxy/APM tooling; redact token and Authorization externally too.
Unexpected registration exceptions produce a safe enum-only log/503 response.

Mobile logout, native revoke-device and password-confirmed web Mobile devices
revocation clear the registration secret and disable delivery. Account soft deletion
also disables registrations; hard deletion cascades user-owned records. Foreign
keys sever registrations when Sanctum tokens are bulk-deleted. Every send checks
the token and user again; the minute retry command clears expired/orphaned secrets.
Disabled/revoked state and registered_at are retained; no session refresh is added.

`mobile:send-missing-hours-reminders` runs hourly withoutOverlapping. For each
enabled device it considers the user's active, writable workspaces and the local
IANA timezone (workspaces.timezone, fallback config hours.timezone), weekdays only,
at/after 18:00 before local midnight. Hourly scans can send later than exactly 18:00,
especially in half/quarter-hour zones. Invalid timezone values skip delivery.
There is no force option. Future/backfilled prior dates are not scanned. All existing
premium mail/database reminder types and notification preferences are unchanged.

Each queued job rechecks current membership, writable access, user/owner state,
verification, trial restriction, native token ownership/ability/explicit expiry and
global Sanctum expiry. ANY active entry for that user/workspace/local date suppresses
the send, including zero net duration; it does not use app caches or local timers.
Retries crossing local midnight are skipped. Soft-deleted entries follow existing
active-entry queries. The routing payload is all strings: type=missing_entry,
user_id,workspace_id,work_date; no MHP access token or website URL is included.
Notification title is "Did you log today’s hours?", body names the workspace,
Android icon is ic_notification and APNs sound is default. See the Flutter handoff
for authenticated membership-checked tap routing and previous-account rejection.

The separate mobile_push_deliveries outbox has a durable unique
user/workspace/date/device/channel key. Email markers never suppress push. Row-lock
claims use a UUID fencing lease (120s), and only the matching claimant can record
completion. Success is recorded only after an FCM HTTP v1 acknowledgement. Retryable
429/5xx and authorization-unavailable responses use at most five attempts with
60/120/240/480-second exponential floors and provider Retry-After (bounded to one
day; next-day eligibility still suppresses the old date). The minute
`mobile:retry-missing-hours-reminders` scheduler queues due retries only, without
creating reminders. Duplicate queue candidates cannot claim an active lease.

UNREGISTERED must appear in Firebase's typed FcmError details before deleting a
registration; generic 404, permission/sender/configuration errors never delete it.
Definitive failures remain failed without delivered_at. Network timeouts or expired
in-flight leases remain unknown, not success and not automatically replayed: FCM
provides no transactional exactly-once send with this database, so a crashed worker
or missing acknowledgement may represent an accepted message. Investigate unknown
records rather than force-send. This trades occasional missed uncertain reminders
for avoiding automatic duplicate notifications. APP/server/provider diagnostics
must never contain tokens, credential files, raw claims or provider response bodies.

### Server deployment and Firebase setup

Apply migration `2026_10_05_180000_create_mobile_push_tables.php` before running new
workers/routes. New tables: mobile_push_registration_locks, mobile_push_devices,
mobile_session_mutations, mobile_push_deliveries; workspace timezone is nullable.
Set these production environment values outside the upload bundle:

```dotenv
MOBILE_PUSH_ENABLED=false
MOBILE_PUSH_FIREBASE_PROJECT_ID=your-firebase-project-id
MOBILE_PUSH_FIREBASE_CREDENTIALS=/home/raaingqv/private/mhp-firebase-service-account.json
QUEUE_CONNECTION=database
```

The path is an EXAMPLE: create a protected file outside public/document root with
minimal owner/worker read permission (e.g. chmod 600 when they share the same user),
never upload it to Git or Flutter. Use a Firebase service account permitted to send
FCM messages in the selected project; enable the FCM HTTP v1 API. The transport
uses a fixed Google OAuth endpoint, signed RS256 service-account assertions and
short-lived OAuth tokens cached encrypted; no composer dependency change is needed
beyond the already-installed firebase/php-jwt from previous mobile patches.
The scheduler and queue worker must share this env/path, APP_KEY and database.
Configure Firebase Android/iOS apps, APNs key and client notification permission.

Keep the existing cron `* * * * *` invoking php84 artisan schedule:run from the
application root. Run a supervised process for
`php84 artisan queue:work --queue=mobile-push --tries=1 --timeout=45`.
Keep queue retry_after greater than 45s (database default 90s), process-manager
stopwaitsecs greater than the timeout, and use a durable queue rather than sync.
Restart workers after code/config changes. With credentials and native setup
ready, set MOBILE_PUSH_ENABLED=true, config:cache and queue:restart. Verify
schedule:list and the three push/device routes. Roll back by disabling server and
client flags and restarting workers; do not drop populated tables to roll back.

Automated fake transport tests validate backend behaviour, not Firebase/device
delivery. Real-device acceptance has NOT been executed. Record an authorized
non-production device test using flutter-native-push-handoff.md before enabling
ENABLE_NATIVE_PUSH in production. Send the updated OpenAPI/integration/handoff
documents to the Flutter project first.

Sources: [FCM HTTP v1](https://firebase.google.com/docs/cloud-messaging/send/v1-api),
[FCM error codes](https://firebase.google.com/docs/cloud-messaging/error-codes),
[Flutter receiving](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).
