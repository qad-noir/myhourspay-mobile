# MyHoursPay Flutter companion

An incremental **demo milestone**, not a production-connected app. Explore demo →
choose workspace → view Monday–Sunday → add hours. Entries exist only in memory
and are cleared on logout/restart. They do not appear in the Laravel website.
Native password/social sign-in and the remaining lifecycle screens are not implemented.

## Run and verify

Installed SDK verified: Flutter 3.47.2 / Dart 3.13.2 on Windows.

```
flutter pub get
flutter run
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test
```

No API is contacted, including production. No passwords or tokens are collected.
See docs/BACKEND_HANDOFF.md for the blocking live integration work and acceptance
procedure, docs/SETUP.md for platform/provider setup, and docs/api/README.md for
contract provenance. Staging is not provisioned.

## Structure and decisions

- `lib/features/hours`: screens, typed entry/draft models and repository boundary.
- `lib/features/session`: ChangeNotifier state model. Flutter's built-in notifier
  makes this small slice understandable without an additional state dependency.
  A generation counter prevents old workspace responses replacing current data.
- Navigator handles the single add-hours route. Adopt a declarative router when
  deep links and real authentication gates exist, rather than adding one prematurely.
- `lib/core/api_environment.dart`: tested configuration/origin guard for the future
  client. It is not a live client and is not yet wired to network requests.
- No HTTP or storage package is installed because the current app has neither
  credentials nor networking. Select maintained HTTP and platform secure-storage
  packages and verify SDK compatibility when implementing the agreed auth contract.
  Never substitute shared preferences for bearer-token storage.

The SessionPhase enum reserves backend states, but only demo entry and logout are
implemented. It is not proof of MFA support. Demo totals model inspected clock
arithmetic solely for UI work; Laravel must supply authoritative production totals.
The draft model rejects invalid same-day shifts to give immediate form feedback;
backend validation still owns acceptance.

Visual direction follows source CSS: ink #171421, orange #ff6b35, muted #6e6878,
light surface #faf9fb, and darker orange #b3421c for readable controls. The weekly
ledger is the main visual structure. Platform fonts are used; licensed Manrope/DM
Sans assets from the website have not been bundled. Layout scrolls and constrains
wide-screen content; buttons have accessible labels and time inputs use 24-hour text.

## Achieved / pending

Implemented: temporary demo session, workspace choice/isolation, weekly ledger,
empty state, add-hours form, validation, success feedback, retry/reload, duplicate
and lock errors at repository boundary, configuration guard, unit/widget tests.

Pending: real sign-in/MFA and verification gates; registration/recovery; Google and
Apple; project selection; edit/version conflicts; submission and manager review;
account settings/linking/deletion; secure revocable sessions; API error handling;
read cache; platform flavours/signing; generated API docs and breaking-change CI.
No write idempotency, live authorization, provider or MFA tests are claimed.
The first live end-to-end milestone remains blocked on backend implementation.
