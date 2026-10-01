# Visual rebuild verification

The PNGs in `390/`, `360/` and `430/` are actual Flutter widget renders with
bundled Manrope, DM Sans, Material icons and the MHP brand mark. They use isolated,
fictional test fixtures (Alex Morgan, Jamie Lewis, Design Studio), not live account
data. No concept board or screenshot is used as an application widget.

- [Baseline contact sheet](contact-sheet.png): 390 × 844 per screen.
- [Narrow phone](contact-sheet-360.png): 360 × 800 per screen.
- [Wide phone](contact-sheet-430.png): 430 × 932 per screen.

## Comparison and refinements

Both original boards were opened and inspected before editing. The first capture
was inspected, then recaptured after the visible differences below were corrected.
The final contact sheets were also inspected at all three sizes. This is a close
composition match, not a claim of pixel-perfect equivalence.

| Screen | Implemented composition and review |
| --- | --- |
| Sign in | Compact brand/header, thin bordered fields, restrained icons, provider divider/buttons in fixtures, bottom registration footer. Live unavailable providers stay hidden. |
| Your week | Workspace selector/avatar, paired title and total, thin progress line, seven daily bars, date-tile entry rows, bottom Add action and real navigation. |
| Add hours | Back/title, date and time pickers, break input, Paid/Unpaid selection, conditional projects, notes and peach total preview. Reduced spacing and reserved bottom Save space after capture review. |
| Weekly timesheet | Date/status, authoritative total, shared rows, submission note and corrected manager-review copy. Submit has reserved space above navigation. |
| Verify | MFA-specific shield/title, coherent accessible input behind six boxes, paste/backspace, separate recovery mode and bottom actions. Email verification remains a different flow. |
| Workspaces | Selected peach/orange cards, role/currency, quieter create action and explicit Continue. Loading/empty/failure states use the same layout. |
| Review | Employee initials/name/date/status, total, compact bordered day rows, note and side-by-side decisions. Narrow button padding was refined after capture. |
| Account | Identity row, read-only MFA badge, grouped real session rows, current/revoke actions, shared-account information and bottom Sign out. |

## Deliberate differences and limitations

- White button text on `#CF4515` has approximately 4.65:1 contrast. The original
  `#FF6B35` remains in the mark, chart and selection accents; copying the concept's
  bright orange with white small text would fail contrast.
- Real controls use 48px minimum action targets and scroll at large text or with
  the keyboard. No phone bezel, notch, fake status bar or presentation shadow is
  rendered. The app uses real SafeArea insets; these test surfaces have zero system
  insets and are not physical-device screenshots.
- The browser shell is limited to 430 logical pixels. Layout is reflowed, not scaled.
- Billing remains available in the hours editor's Billing options menu. The local
  total is labelled as a preview; saved totals continue to come from Laravel.
- Timesheets disappear from navigation when unavailable. Approve/reject requires
  reviewer permission and submitted status; request changes requires an explanation.
- Provider fixtures are test-only and do not authenticate. Live provider SDKs and
  developer IDs are still unconfigured. Google uses the official bundled mark.
  Apple's original black PNG mark is also bundled unchanged, recovered from the
  official design-resource disk image and validated against its PNG CRCs. No
  provider callback URL was invented.
- Native iOS/Android keyboard, autofill, screen-reader and secure-storage testing
  still requires devices and the platform toolchains described in ../SETUP.md.
  Flutter test coverage is not a substitute for device sign-off.

## Session and integration evidence

The repositories still share one ApiClient and scoped secure session store.
Authenticated 401 clears stale state, abandons private navigation and displays
"Your session has expired. Please sign in again." A workspace response cannot
advance an invalidated session. 403 and connectivity failures retain the session
for retry. Regression tests cover all three boundaries.

A fresh check against local Laravel at `http://127.0.0.1:8000/api/v1/mobile` used
the designated credential file: password login, bearer `/me`, two workspaces and a
weekly-hours read succeeded. Both provider flags were false. The temporary device
session was revoked. No hours were written and production was not contacted in
this rebuild. Earlier save-to-website evidence is in ../VERIFICATION.md.

## Reproduce

```powershell
flutter test
flutter test test/visual_screens_test.dart --dart-define=MHP_CAPTURE=true
./tool/capture_contact_sheet.ps1
./tool/capture_contact_sheet.ps1 -Width 360
./tool/capture_contact_sheet.ps1 -Width 430
flutter analyze
```

Fixtures live exclusively under `test/support/visual_fixtures.dart`; they cannot be
reached by normal application navigation and the MockClient never makes network
requests. Screenshots are explicitly preloaded with bundled fonts and image assets.
The layout checks include all eight screens at each requested size, long names,
200% text, keyboard insets, and the wide desktop shell. Interaction checks include
MFA paste/recovery, rejection-note validation, and the full login/workspace/save/
edit-conflict/logout journey. The saved-message overlay is dismissed before opening
an editor so it cannot obscure that screen's actions.

## Final checks

- Full Flutter suite: 61 tests passed, including eight reviewed baseline image
  comparisons, all three phone sizes, 200% text/long names, keyboard reachability,
  session boundaries and repository behavior.
- Static analysis: no issues. Contract checksum/client assumptions: passed.
- Chrome-specific device-name regression: compilation completed and headless
  Chrome launched, but its test suite did not return a result; stopped after the
  stalled run. Browser end-to-end authentication/secure persistence is not claimed.
- No native Android/iOS device build was performed in this visual pass.

To compare reviewed screenshots without changing them (same Windows Flutter 3.47.2
renderer used here):

```powershell
flutter test test/visual_screens_test.dart --dart-define=MHP_GOLDENS=true --name 'at 390px'
```

Do not combine capture and golden comparison when reviewing a change. Inspect new
renders first; normal CI runs layout and behavior tests without assuming identical
font rasterization across operating systems.
