# Verification — native integration, 2026-09-30

## Real local integration (not mocks)

Backend source: a973d70871330475ee4899ddf8df867215e7e364.
API: http://127.0.0.1:8000/api/v1/mobile; configured local MySQL.
Used the user-designated account from the ignored test-login/test-login.txt.
No credentials, cookies or account details are included in commits or this report.
Production deployment was not checked and production received no test writes.

Initially the native API could authenticate/read but saving returned server_error:
mobile_mutations was missing. Applied exactly the three additive mobile migrations
from 2026_09_29 to the local database. No backend controllers were changed.

Ran tool/verify_local.dart through the same ApiClient/AuthRepository/HoursRepository
used by the Flutter app. Verified:

1. Password login returned authenticated/access_token; /me and two workspaces read.
2. /auth/providers returned google=false and apple=false.
3. Created one labelled entry on a previously unused date in a writable workspace.
4. Replayed the identical POST with the same UUID; got the same entry ID.
5. PATCHed the entry using its version and a new UUID, changing end time to 17:30.
6. An update with the old version returned 409 entry_changed.
7. GET read-back returned the updated version and 480 net minutes; the week's
   server total increased by 480 minutes.
8. Revoked the integration token with DELETE /auth/session.

Then signed into the local website in a headless Edge browser. Its dashboard row
linked to that exact record and showed the saved work date, 09:00–17:30, 30-minute
unpaid break and 8-hour total. The website edit form had the same record ID,
times, break and updated verification note. No website form was submitted.
The single test record remains available for inspection. Detailed record IDs,
private browser screenshots and assertions are retained only in ignored .local/.

This verifies repository-to-Laravel-to-website integration. It does NOT claim a
physical Android/iOS device has completed the journey or secure storage was
validated on a device.

## Website issue found during verification

The dashboard edit link is /hours?month=YYYY-MM&edit=ID. In
resources/views/hours/calendar.blade.php, initialDate defaults to today's date
rather than initialEntry.work_date. The opened edit form therefore showed today's
date while the dashboard and API correctly retained the saved date. Do not submit
that web form without checking its date. No website date change was made here.
Suggested backend regression: open a past-date entry via the dashboard edit link,
assert the date field remains that entry's work_date, and prefer the selected
entry's date when constructing the open-hours event. This is separate from the
Flutter editor, which initializes edits from the returned entry date.

## Automated and visual checks

- Flutter client/widget suite: all 18 tests passed, including the final phone-layout capture run.
- Backend native API suite: 30 passed, 691 assertions (php artisan test --compact
  --filter=Mobile), using the configured in-memory SQLite test database.
- Canonical OpenAPI: validates with openapi-spec-validator 0.7.2.
- Contract source SHA-256 and version checked by tool/check_contract.py.
- Native widget journey uses explicitly synthetic HTTP fixtures to test UI state;
  these tests are separate from the real integration above.
- Captured and inspected native login/weekly layouts at 390×844 using test data;
  separate 320px / 200% text test checks overflow. Real brand PNG assets are bundled.
- MHP orange buttons use dark ink text to retain accessible contrast. The main
  Add hours action stays reachable below the scrollable week ledger.

Formatting and static analysis completed successfully. Generated readable OpenAPI HTML using Redocly CLI 2.56.0.

## Platform/build results and remaining configuration

Android debug build attempted with explicit emulator development configuration.
It failed before app compilation: NDK 28.2.13676358 lacks source.properties.
flutter doctor also reports missing Android cmdline-tools and unknown licence
status. No APK or emulator/physical-device run is claimed. Repair Android SDK/NDK
through Android Studio and rerun the documented build; no SDK folders were deleted.

Windows desktop build tooling lacks required C++/CMake/SDK components. iOS was not
built because macOS/Xcode are required. Keychain/Keystore persistence and secure
logout must still be tested on signed native builds.

Provider platform IDs/SDK integration and Apple Android HTTPS callback/handoff
remain unconfigured. Staging, owner-approved app identities, release signing,
iOS schemes and store-release lifecycle work remain as described in SETUP.md and
the backend integration guide. MFA/verification server paths have automated
coverage; this designated live account did not require an MFA/email challenge.
Timesheet/project screens are conditional and have not been exercised against
a live manager account in this verification.
