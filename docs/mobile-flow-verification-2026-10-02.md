# Mobile flow verification — 2 October 2026

## Confirmed cause and changes

The designated production account returned hours entries whose workspace_id was a JSON string. Laravel's MySQL/PDO foreign-key serialization differed from local SQLite and from the OpenAPI integer schema. The previous strict Dart int cast failed after a successful POST and when reading populated weeks. That caused the unconfirmed-save message, refresh errors, and missing dashboard charts.

The app now normalizes positive decimal-string resource IDs at the response boundary for hours, projects, workspaces, account/device IDs and timesheets. Invalid, fractional, absent, or nonpositive IDs still fail validation; request payloads and idempotency/version rules are unchanged. The backend should eventually emit integer foreign keys consistently with its contract.

Workspace creation now keeps the confirmed new workspace, displays success feedback (including after first-workspace navigation), and distinguishes failed follow-up refreshes from failed writes. Weekly target input is hours (default 40; 37.5 becomes 2250 API minutes), with validation and the create action at the bottom of the page. Ambiguous workspace creation remains blocked from blind resubmission until the user reloads.

Password recovery validates the email, displays sending progress and completion, and restores retry controls after a timeout with an honest check-your-email message. The production reset endpoint acknowledged one designated-account request in 1127 ms. Email delivery and completing the password change were not verified; the password was not changed. The original stuck state was not reproduced against the now-working production endpoint.

Project and timesheet-detail parse failures now show recoverable errors. Successful hours saves followed by failed week refreshes state that the save succeeded while the refresh failed.

## Evidence

- Production read-only verification: three workspaces; populated weeks parsed correctly (two records totaling 900 minutes; one record totaling 420 minutes; one empty week). Probe session revoked; no production hours/workspaces changed.
- Local designated account: real login, workspace read, hours create, identical Idempotency-Key replay returning the same record, versioned update, stale-version rejection, and weekly read-back passed.
- Local saved entry 20, workspace 1, 2026-09-29, 09:00–17:30, 30-minute unpaid break, 480 minutes, was verified in the website dashboard by exact edit ID, date, shift, break and total. Website session logged out. Local test record retained.
- Full Flutter suite: 71 tests passed; static analysis clean. One additional first-workspace navigation regression then passed in the seven-test focused suite. Screen coverage includes 360/390/430 widths, large text, keyboard handling, ID-string save/read/refresh, invalid IDs, confirmed-create/failed-refresh, decimal hour conversion, reset progress/success/timeout, and onboarding confirmation.
- Production release APK built with APP_ENV=production and API_BASE_URL=https://mhp.glsltd.co.uk/api/v1/mobile. Connected-phone installation and user device verification are reported separately; automated tests are not a claim of native production save success.

Credentials are read from the ignored test-login/test-login.txt. The local verification runner selects the local section when both production and local credentials are present. Credentials, account emails, token values, and raw production response bodies were not printed or committed.
