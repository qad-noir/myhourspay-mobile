# Monthly Overview review

Overview now defaults to Month; Week remains available. A single scrollable page
contains the calendar, selected entry, weekly breakdown and monthly breaks. The
existing workspace picker, avatar/account route, entry editor, persistent Add hours
and capability-dependent navigation are retained.

The initial month and today use the workspace timezone. Calendar date arithmetic
uses local year/month/day values. Selecting an empty day supplies the Add hours
date; View entry uses the actual server entry, version and existing conflict flow.
Read-only workspaces explain their restriction and disable saves.

## Accounting and requests

No dashboard endpoint or new package was added. The existing paginated hours range
repository is used twice: exact month for logged hours, calendar entries, average
and breaks; complete intersecting Monday–Sunday weeks for overtime and weekly
breakdown. Summary totals are authoritative and repeated page summaries are not
added. Weekly bars share a common scale and preserve positive overtime.

The in-memory cache is scoped to user/workspace/month, discarded on logout, and
protected against late workspace/month responses. Pull-to-refresh and successful
entry writes refresh both ranges. Failed portions remain explicitly unavailable;
cached values show a stale notice and last-update time on refresh failures. Existing
401 session recovery remains in the shared API client.

## Reproducible visual evidence

The PNGs are actual Flutter widget renders with bundled Manrope/DM Sans, brand
assets and safe-area insets (44dp top, 34dp bottom). They use illustrative test-only
September records, never inserted into a live account. `top`, `calendar` and `lower`
are scroll positions of one screen, at 360, 390 and 430dp. The lower content is
intentionally reached by scrolling. Additional 390x600 and 844x390 cases at normal
and 2x text scale verify scrolling and absence of layout exceptions.

Reference figures verified: 184h month hours, 22 worked dates, 8h 22m daily average,
8h full-week overtime, 22 breaks, 0 paid-break hours and 11 unpaid-break hours.
The expanded range contains 208h and is deliberately not used as month hours.

Commands:

```powershell
flutter analyze
flutter test --reporter expanded
flutter test test/monthly_overview_widget_test.dart test/google_sign_in_test.dart --dart-define=MHP_CAPTURE=true --reporter expanded
```

Analysis passed with no issues. The full suite passed 136 tests before the added
secure-session restore test; focused final results are recorded in the completion
message (28 focused tests passed, including session restore). Coverage includes month-edge overtime, leap February, four/six-row grids,
paid/unpaid breaks, empty/non-40h targets, pagination, workspace/month response
races, stale partial results, both-range refresh after mutation, date taps, month
picker, period/navigation retention and responsive layouts.

No live monthly save or production device verification is claimed from these
fixtures. iOS uses shared native Flutter layouts; no macOS/Xcode build or physical
iOS verification was performed. Existing provider and signing setup still applies.
