# Account preferences and website actions

The account screen adds grouped Account, Preferences and Delete account sections.
Appearance applies throughout the Flutter app immediately. System tracks device
brightness; Light/Dark override it. The selection is saved separately from session
tokens, so logout does not remove it. It is a device preference, not a web-account
preference. No biometric app-lock feature from the inspiration image is implied.

Production configuration (`config/production.json`):

- `WEB_BASE_URL`: HTTPS website base, currently `https://mhp.glsltd.co.uk`.
- `WEB_DOMAIN`: displayed website name, currently `mhp.glsltd.co.uk`.
- `WEB_PROFILE_URL`: optional full profile destination override.
- `WEB_DELETE_ACCOUNT_URL`: optional full deletion destination override.

When an override is absent, its destination is the web base plus `/user/profile`.
The production config uses that default for both actions. Deletion is
reviewed and confirmed there; the app only opens the browser. No mobile delete
endpoint, destructive request or new phone/profile response field was invented.
Web pages use their own login session. Tokens are never appended to these links.
Missing/invalid HTTPS URLs disable the relevant action; launch failures show a toast.

JSON values are Flutter build-time defines: rebuild using
`flutter build apk --release --dart-define-from-file=config/production.json`
after editing them. Editing JSON cannot update an already installed APK.

The screenshots are actual Flutter renders using test account data. Checks cover
saved preference restore, restore/selection races, unsafe link rejection, default
and override destinations, immediate theme changes, System device-theme changes,
and account scrolling at normal and 2x text scale. Existing screen colours were
adapted for dark mode while retaining MHP typography and orange accents.

Android/iOS use shared Flutter themes and the existing secure-storage/url-launcher
plugins. No iOS device/build verification was performed on Windows. This change
does not update the native launch splash according to the saved Flutter preference.

Validation: `flutter analyze` reported no issues; `flutter test --reporter expanded`
passed 142 tests. After adding the selected dark-calendar contrast check, the final
focused appearance/monthly tests passed all 17 cases with production configuration
defines (mock HTTP transport, no production mutations). Light/dark account captures
were generated with `--dart-define=MHP_CAPTURE=true` and visually reviewed.
