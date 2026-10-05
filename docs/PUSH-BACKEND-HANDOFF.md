# Laravel implementation request: free native missing-hours push reminders

Implement this in the Laravel project. This is a proposed API extension, not an
already implemented contract. The Flutter client keeps `ENABLE_NATIVE_PUSH`
disabled until the backend and Firebase setup are deployed.

## Required mobile API

Add GET, PUT and DELETE `/api/v1/mobile/push/device` inside the existing native
mobile authentication/verified-user middleware. Restricted verification/challenge
tokens must not register devices. Bind registrations to the authenticated user AND
the current mobile Sanctum personal access token; never trust client user IDs.
Do not add `api_access` or `smart_reminders` feature middleware to these routes.

GET returns HTTP 200, `{"data":{"enabled":false}}` when no registration exists.
Existing registrations return the real boolean; never return the FCM token.

PUT accepts the following exact shape (token required only when enabling):

```json
{"enabled":true,"token":"FCM_REGISTRATION_TOKEN","platform":"android","device_name":"Samsung Galaxy"}
```

`platform` is `android` or `ios`. Disabled request omits `token`. Validate strict
boolean, token string max 4096 characters and device name max 255. Enabling means
free missing-entry push reminders for the user's active writable workspaces.
Do not enable promotional messages or email reminders through this setting.
Respond HTTP 200 `{"data":{"enabled":true}}` (or false for disabling).
Honor `Idempotency-Key` using the existing mobile write implementation. Same key
and same body replay the response; changed body returns the documented conflict.
DELETE unregisters the current mobile session only, returns HTTP 204, and is safe
to repeat. All errors follow the existing `code`, `message`, optional `errors` schema.

Use encrypted-at-rest FCM token storage and a unique hash index. Upsert/rebind a
rotated registration only from an authenticated session, removing its previous
user/session binding. Track disabled/revoked state and last registration time.
Token secrets must never enter request logging, error logs or API diagnostics.
Expire registrations with their Sanctum session. Mobile logout, revoke-device,
web mobile-device revocation and account deletion must invalidate delivery.

## Server delivery

Implement `mobile:send-missing-hours-reminders` and queue delivery jobs. Schedule
hourly with `withoutOverlapping`; use each workspace's timezone, weekday and 18:00
local cutoff. Only use valid memberships and active writable workspaces. Skip
users whose mobile session is revoked/expired or whose account is restricted.
Immediately before sending, recheck that this user has no entry for that workspace
and local work date. Any existing entry suppresses the reminder, including a zero
duration entry. Do not infer absence from mobile cache or use local timers.

The missing-entry PUSH path is available on every plan, including free accounts.
The existing `SendWorkspaceReminders` command currently checks `smart_reminders`
and delivers mail/database messages. Preserve other premium reminder types and
existing email preferences; remove the paid dependency only from this new native
missing-entry push path. Do not use a force bypass in the production scheduler.

Use Firebase HTTP v1 server credentials from protected server storage, never an
API key bundled in the APK. Queue credentials must be available to the worker.
Send an FCM notification payload plus string-valued routing data:

```json
{
  "message": {
    "token": "FCM_REGISTRATION_TOKEN",
    "notification": {"title":"Did you log today’s hours?","body":"No hours are recorded for today in Design Studio."},
    "data": {"type":"missing_entry","user_id":"12","workspace_id":"34","work_date":"2026-10-05"},
    "android": {"notification":{"icon":"ic_notification"}},
    "apns": {"payload":{"aps":{"sound":"default"}}}
  }
}
```

No MHP access tokens or website URLs in notification payloads. Notification taps
open the relevant week only after authentication and workspace membership checks.
The app checks the user ID to reject a previous account's delayed notification.

Use a durable unique delivery key for user/workspace/date/device/channel plus
transactional claiming/leases so concurrent schedulers cannot double-send. Keep
email and push delivery markers separate; a previous email cannot suppress push.
Record successful sends only after FCM acknowledges them. Retry transient failures
with bounded exponential backoff, honor throttling, and delete registrations on
UNREGISTERED. Do not delete valid registrations for invalid sender configuration.
Recheck membership, session validity and entry existence on retries too.

## Evidence and handoff

Add feature tests for free-user registration and dispatch; correct timezones/DST;
no reminder when an entry exists; weekends; membership/session revocation; token
rotation; ownership isolation; restricted bearer rejection; idempotency; concurrent
deduplication; successful vs failed delivery state; and retry rechecks. Use a fake
FCM transport for automated tests and separately document a real device result.

Update `docs/api/mobile.openapi.yaml` and `docs/api/mobile-integration.md` with the
implemented shapes, scheduling behavior, free availability and deployment steps.
Provide an implementation summary naming files, migrations, environment values,
scheduler/queue setup, tests and actual results. Package the production patch using
the existing timestamped ZIP, manifest/checksum convention. Do not claim deployment
or actual delivery from fake transport tests. Return the updated API documents to
the Flutter project before enabling its production flag.

References: [Firebase HTTP v1](https://firebase.google.com/docs/cloud-messaging/send/v1-api),
[Flutter receiving](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).
