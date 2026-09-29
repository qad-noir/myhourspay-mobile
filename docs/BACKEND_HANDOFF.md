# Backend handoff — first live milestone blocked

The backend is readable but outside this workspace's writable roots. No backend
runtime or database was started, and no production writes were made. The requested
draft is saved at docs/api/mobile.openapi.yaml in Laravel. The Flutter
pinned copy matches it; reconcile the proposal before calling it an agreed contract.

## Verified source findings
Laravel ^13.17, Jetstream ^5.5, Sanctum ^4.0, Livewire ^3.6.4 and Cashier 16.6
appear in composer.json. routes/api.php has no native login or lifecycle routes.
The existing v1 group applies auth:sanctum, active, EnsureTrialChoice,
feature:api_access and throttle:premium-api. Official mobile must not use that
paid external API gate. Existing membership and token abilities must remain.

WorkspaceApiController uses raw model serialization. storeHours validates one
entry/day, rejects approved/locked weeks and calls HoursCalculator. Its membership
helper alone is not proof of writable-workspace or feature authorization. Project
validation scopes existence to the workspace but requires an explicit product
entitlement audit. Review updates need a shared policy/action and transaction audit.
Existing message-only errors cannot support reliable client state routing.

## Proposed contract work (none implemented)
Use a dedicated mobile API group only after agreement. Reuse web business actions;
keep Jetstream/Fortify routes intact. Design each JSON flow before implementation.

| Proposed method/path beneath /api/v1/mobile | Request/result |
| --- | --- |
| POST /auth/login | email/password/device_name; authenticated or restricted challenge |
| POST /auth/challenge | challenge plus TOTP or recovery code; consume once atomically |
| POST /auth/register | name/email/password/confirmation, terms version + acceptance, separate optional marketing consent |
| POST /auth/verify | restricted challenge + email code; bounded attempts and expiry |
| POST /auth/verification/resend | restricted challenge; throttle and invalidate old code |
| POST /auth/password/forgot | email; same response for existing/missing accounts |
| POST /auth/password/reset | reset credential + new password; apply revocation policy |
| POST /auth/provider/{provider}/exchange | verified provider credential + nonce/code context; preserve MHP MFA |
| GET /session | explicit account state, workspace roles, entitlements, expiry |
| DELETE /session | revoke current device token |
| GET /sessions; DELETE /sessions/{id} | list/revoke only own devices; reauthentication policy |
| GET/POST /onboarding | restricted account actions; validate required fields |
| GET/POST/DELETE /account/login-methods | authenticated linking/unlinking; prevent final-method removal |
| DELETE /account | recent reauthentication; deletion/retention and provider revocation policy |
| GET /workspaces; GET/POST/PATCH /workspaces/{id}/hours | shared authorized actions and Resources |
| POST /workspaces/{id}/timesheets/{id}/submit | idempotent submission, expected version |
| POST /workspaces/{id}/timesheets/{id}/review | role + membership + entitlement; expected version |

Decide exact request fields, nullable values and response Resources with backend
owners; this table is a concrete route proposal, not a frozen schema. Read paths
return data plus explicit pagination metadata. Errors should use
`{error: {code, message, fields, request_id}}`, with stable codes such as
session_expired, account_restricted, verification_required, feature_unavailable,
validation_failed, timesheet_locked and version_conflict. Never route by message.

401 clears credentials/data and requires sign-in. 403 preserves the session and
routes by code. 404 means unavailable. 409 preserves the local form and offers
reload. 422 attaches field errors. 429 respects Retry-After. Timeouts after a write
are uncertain: reload before manual retry until idempotency is implemented.
Disable credential-bearing redirects, scope bearer credentials to the configured
origin, use JSON headers, bounded read retries, no automatic write retries.

## Security and server tests required
- Password login must enforce existing MFA, email verification, active-account and
  onboarding rules. Store hashed, expiring, restricted single-use challenges with
  attempt limits; atomically consume TOTP/recovery challenges. No normal token early.
- Separate expiring Sanctum device tokens; choose/document lifetime. No assumed
  refresh route. Revoke current session on logout and all required sessions on
  password recovery/suspension/deletion. Offline logout clears local secure storage
  but cannot promise remote revocation; show that limitation and offer device management.
- Backend social verification must check signature, issuer, allowlisted audience,
  expiry and applicable nonce/state/code protections using maintained libraries.
  Unique (provider, subject), never silently merge email matches. Authenticated
  linking, private relay handling, initial-only Apple names, cancellation, revoked
  grants and last-method unlink prevention all need fixtures and tests.
- Every resource operation needs active account, membership, role, ownership,
  writable workspace and product-entitlement enforcement. Token abilities restrict
  further. First-party access must not require paid external API access.
- Transactionally check locks/version on writes. Idempotency key scoped to account,
  workspace and operation, request hash, persisted response and expiry; replay same
  request, 409 on changed payload, atomic concurrent requests. Agree retention.
- Test nonmembers, foreign IDs, downgraded plans, suspended accounts, stale versions,
  locked timesheets, consumed challenges, expired sessions, throttling and concurrent
  submission. Flutter mocks cannot prove server authorization.

## Acceptance procedure for real integration
Create a disposable local database and seeded test account, never production.
Run Laravel authorization/auth tests. Sign in on a device, choose workspace, add
hours, then open the same local Laravel website account/week and assert the entry
ID, work date, break and server total match. Record build, contract commit and test
results. This verification has NOT happened. Provision isolated HTTPS staging
before release, with separate secrets, database and provider callbacks.
