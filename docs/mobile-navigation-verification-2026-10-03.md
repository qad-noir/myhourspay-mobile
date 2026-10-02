# Mobile navigation fixes — 2026-10-03

## Implemented

- Overview recent entries sort by work date descending before taking the latest three.
- Workspace switching preselects the last active workspace; logout clears it.
- Account device sessions are cached in memory for the signed-in session. Revisiting the tab retains rows while refreshing; only the first uncached load shows skeletons. Revocation updates the cache, handles unexpected failures and releases loading state.
- Revoke and edit-conflict confirmations close the dialog navigator, fixing nonresponsive Cancel/confirm buttons inside the app's nested navigation.
- Hours tab uses the Apache-2.0 calendar_date_picker2 3.0.0 dialog. The API supplies month entry dates, orange dots identify entries, and selected dates load their Monday–Sunday week. Failed marker reads show an explicit retry notice. Markers are not generated from demo data.
- Chart days open their existing entry or a date-prefilled add form; day actions expose accessible labels.
- Duplicate-date validation suggests editing the existing entry. Save acknowledgement is "Hours saved." Logout uses a temporary SnackBar instead of a persistent notice on authentication screens.
- APK build number increased to 2.

## Validation

Final full Flutter suite with MHP_GOLDENS=true: all 78 tests passed, including the eight reviewed 390px golden comparisons. Static analysis: no issues. Updated overview captures at 360, 390 and 430px preserve the layout while showing newest dates first; the 390px capture was visually inspected.

Regression coverage includes nested revoke cancellation and confirmation, removal after DELETE, account cache during pending reload, newest-first rows, populated/empty chart taps, calendar API markers and selected week query range, workspace selection reset, duplicate-date copy and logout toast dismissal. Layout tests cover narrow devices and enlarged text. Fixture-based tests validate UI behavior only; the live evidence below is separate.

## Real production evidence

Used only the designated production account from ignored test-login/test-login.txt. Credentials and bearer tokens were never logged or committed.

- Password login succeeded and three workspaces loaded.
- Empty PATCH requests to two owned existing records returned HTTP 404 not_found. No hours values were sent or changed. Source inspection found the existing PATCH route and a strict foreign-key ownership guard in MobileWorkspaceController::saveHours. Earlier observed production foreign keys were decimal strings; this is the likely server-side rejection. No production backend patch has been applied here.
- Created temporary diagnostic sessions, revoked one through DELETE /auth/sessions/{id}; the revoked token's next /me request returned HTTP 401. The remaining diagnostic session was logged out. No user device session was revoked.
- A September month-range hours GET succeeded and parsed three entries, confirming the read used for calendar markers.

Production editing is still blocked pending the Laravel fix and deployment. Mobile sessions on the website also require a backend UI change: the current Jetstream section displays browser sessions only. The ready-to-use backend instructions are in LARAVEL-MOBILE-FIX-PROMPT.md. They include ownership isolation, conflict/idempotency checks and protected web revocation; they do not invent a new edit route.

Calendar source and licensing: https://pub.dev/packages/calendar_date_picker2 and https://github.com/theideasaler/calendar_date_picker2 (Apache-2.0).
