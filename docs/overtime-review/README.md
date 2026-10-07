# Overtime implementation and report verification — 7 October 2026

Implements OpenAPI 2.2.0 and the revised report handoff supplied on 7 October.
The revised chart instruction supersedes the earlier chronological Weekly
allocation instruction. Production API base remains
`https://mhp.glsltd.co.uk/api/v1/mobile` in `config/production.json`; the accidental
space in the handoff's final URL is not copied into configuration.

Pinned OpenAPI SHA-256:
`812c431558debd241e72105dcf9bd1063d6ef4f511f5f55d0643a8d6aa951622`.
Source bundle: `flutter-report-overtime-handoff-2026-10-07-11-17-10`.
Canonical contract source commit: `b3df7702523a0fb4895465c3cf64cc93ab59d52f`.

## Behaviour

- Hours → Hours report supports selecting a date range. Its main overtime total
  comes from the server's entire-range `summary.overtime_minutes`; paginated
  summaries are not added. Comparisons have their requested-range scope labelled.
- Change overtime calculation fetches the latest workspace before opening
  preferences. Failed refresh does not open stale editable preferences. Owners
  and administrators can save; members and read-only workspaces cannot. Daily
  requires a positive whole-minute contract; adding a contract never silently
  changes Weekly selection. Settings saves retain exact keys/bodies for uncertain
  retries and require reload/review after a stale version.
- Settings replacement invalidates hours/overview/month caches and updates report
  and timesheet display. Resume refresh checks for website preference changes.
  Historical entry values and opaque entry/review versions are not rewritten.
- Dashboard bars always show per-date Daily overtime, independent of summary
  selection. Returned entry daily overtime is preferred; an older entry payload
  can use net minutes minus the configured daily contract. There is no default
  assumed daily contract and no chronological Weekly allocation. Orange regular
  and green Daily overtime segments have a legend, tooltips and semantic labels.
  Empty dates have no coloured bar; the largest shift controls chart scaling.
- A missing contract displays “Daily overtime not configured”, preserving null.
  Main summary cards still reflect the selected Daily/Weekly server calculation.
- Monthly Daily totals use exact-month dates; Weekly totals use separately fetched
  full Monday–Sunday weeks touching the month. Calendar remains Sunday-first,
  with muted, clickable adjacent dates. Calendar cells show only date and hours;
  overtime information cannot enlarge them. Dashboard comparison blocks and
  entry-list comparison detail have been removed.
- Partial weeks mean the requested range excludes some calendar dates in that
  Monday–Sunday week, not incomplete entries. Report help explains this and does
  not prorate the weekly target.

## Actual verification

The application Dart repositories were run against Laravel on localhost using a
new isolated SQLite test database. The existing MySQL services were stopped; no
existing account/database or production data was modified. Private QA credentials
and the SQLite database are ignored under `test-login/` and `.local/`.

Live API outcomes:

| Fixture | Net minutes | Daily overtime | Weekly overtime |
| --- | ---: | ---: | ---: |
| 10h Monday + four 7h days, 8h daily / 40h weekly | 2280 | 120 | 0 |
| 27 dates/times from the backend regression, Sep–Oct 2026 | 14955 | 1995 | 1845 |

The first fixture also verified paid/unpaid breaks, signed variance −120,
450-minute contract calculation, identical-key replay and HTTP 409
`workspace_settings_changed` for a stale settings version. The report fixture
verified a partial boundary week, selection switching and unchanged entry values
and versions. No auth/provider tokens were printed; the QA bearer was revoked
after the test. The test server was stopped afterwards.

Automated verification covers 60 distinct checks across `report_overtime_test`,
`overtime_test`, `hours_test`, `monthly_overview_model_test` and
`monthly_overview_widget_test`, including five screenshot capture checks.
The final calendar regression compares cell heights for equal hours with/without
daily overtime; its corrected test and all seven other report checks passed.
Other checks cover pagination, settings navigation/refetch, conflicts, null
contracts, permissions, approved DTO display, offline cache and accessible layouts.

To run these checks and generate fixture previews:

```powershell
flutter test --no-pub --concurrency=1 --dart-define=MHP_CAPTURE=true test/report_overtime_test.dart test/overtime_test.dart test/hours_test.dart test/monthly_overview_model_test.dart test/monthly_overview_widget_test.dart
flutter analyze --no-pub
```

The rendered previews use synthetic fixture data, not live screenshots:

- [Workspace preferences](settings-390.png)
- [Monthly overview](month-390.png)
- [Weekly overview and Daily chart](week-390.png)
- [Android report layout](report-android-390.png)
- [iOS-themed report layout](report-iOS-390.png)

## Remaining device checks

Flutter analyzer: **no issues found**. Production release APK build completed;
Android package metadata confirms `com.example.myhourspay`, `versionCode=17`,
`versionName=0.1.0`. The build command used
`flutter build apk --no-pub --release --dart-define-from-file=config/production.json`.
Artifact: `build/app/outputs/flutter-apk/app-release.apk` (55.2 MB).
SHA-256: `03288fd1856c91ff3beaf04e0e0c8f4b93e4af5a4d16a9a5dfe1cbd1827cc23f`.
Build 17 has **not** been installed or tested on a phone in this task.

The dashboard's weekly breakdown hides the “Partial week” label; the date-range
Hours report retains it and its explanation.

Build 16 was installed and launched on Android on 6 October. These later report,
chart and compact-calendar changes require build 17; do not infer installation
from APK compilation. Test both summary selections with the same records and
confirm chart segments remain unchanged, test report settings return and app
resume after a website settings change. Test Android TalkBack and offline retry.

iOS-themed widget rendering is not an iOS build or device verification. macOS,
Xcode and an iOS device are still needed for native testing, VoiceOver and existing
Google/Firebase/APNs configuration. No new plugin or platform permission is added
by this overtime implementation. No production preference or backend deployment
is asserted by these local tests.
