# Flutter implementation prompt: Daily/Weekly workspace overtime

Paste the following into the existing Flutter project. Copy the supplied
`docs/api/mobile.openapi.yaml` and `docs/api/mobile-integration.md` there first.

---

Continue the existing MyHoursPay Flutter companion app. Read applicable AGENTS.md,
the supplied OpenAPI contract version 2.2.0 and mobile integration guide first.
Implement this additive overtime update using the existing design system and API
client. Preserve native Google nonce exchange, Apple sign-in, MFA, verification,
Sanctum bearer auth, push setup, entry editing and timesheet permissions.

Use the configured API base URL (production after backend deployment:
https://mhp.glsltd.co.uk/api/v1/mobile). Keep environment selection outside widgets.
Do not invent new endpoints, embed credentials or claim production deployment.

1. Extend typed workspace DTOs with nullable integer contracted_daily_minutes,
   overtime_basis (daily/weekly), settings_version and can_manage_settings.
   Extend hours summaries, weekly rows and timesheet DTOs exactly as documented.
   daily_overtime_minutes is nullable; weekly_overtime_minutes and selected
   overtime_minutes are integer minutes. Handle older server responses gracefully:
   default missing basis to weekly, missing daily contract to null; hide settings
   saving with a clear backend-update message when required capabilities/version
   are absent. Do not synthesize a settings_version or silently save locally.

2. Add an Overtime section in the workspace create/settings screen: a clear
   Daily/Weekly segmented choice, weekly contracted hours (existing value) and
   optional contracted daily hours. Daily selection requires 1–1440 whole minutes
   (up to 24h); offer hours/minutes input that produces an integer minute value,
   e.g. 7h30m =>450, 8h=>480. Keep weekly target visible in both modes because it
   remains the weekly progress/comparison target. For existing workspaces prefill
   server values and retain their Weekly default. Adding a contract alone must
   not switch basis. Explain: “Daily counts hours above your daily contract.
   Shorter days do not cancel longer days. This recalculates overtime for past
   records; recorded hours and earnings stay unchanged.” Allow clearing a contract
   only in Weekly mode. Use can_manage_settings for controls and honor server errors.

3. Save existing settings via PATCH /workspaces/{workspace}/settings with current
   settings_version and at least one changed supported setting:
   weekly_target_minutes, contracted_daily_minutes, overtime_basis. Send bearer
   auth, Accept/Content-Type application/json and a UUID Idempotency-Key. Keep
   exact body and key for retry after uncertain network failure; new intentional
   edits get a new UUID. Disable double submission. On 200 replace workspace data
   with response data and refetch summaries. On 409 workspace_settings_changed,
   reload and let the user review newer settings before resubmitting. Do not blindly
   overwrite. Render 422 errors by field; distinguish 403 restrictions from 401
   reauthentication. Existing POST /workspaces accepts optional daily/basis fields
   but remains non-idempotent: refresh memberships before retrying uncertain create.

4. Update Your week, monthly Overview, Timesheet, Review Timesheet and Add Hours
   previews to label the selected basis and use server overtime_minutes. Show
   Daily and Weekly comparison totals without adding them. Null daily comparison
   displays “Set daily contract”/“Not configured”; never “0h”. Weekly variance
   is signed progress against the weekly target, not overtime in Daily mode.
   Do not derive Daily from total hours minus weekly target. For date cells show
   daily_overtime_minutes with a subtle overtime marker, distinguishing this daily
   comparison from selected Weekly overtime. Avoid duplicating a weekly total in
   each day's summed overtime. API summary covers the whole range, not one page.

5. For month at a glance, request exact month dates for calendar cells, worked
   hours and daily overtime. Separately request the Monday before/on month start
   through Sunday after/on month end for the web-compatible weekly overtime.
   Monthly selected total = exact-month daily overtime in Daily mode, expanded
   weekly overtime in Weekly mode. Label “Daily overtime · this month” versus
   “Weekly overtime · full weeks touching this month”. Show comparisons with
   correct scope; adjacent-month cells stay visually muted and do not inflate
   monthly worked/daily totals. Use calendar dates in workspace timezone, preserving
   wall-clock start/end and paid/unpaid breaks; do not UTC-shift work_date.

6. Keep entry/review version strings opaque. Only settings_version changes for
   these preferences. Never update historical entry times, breaks, earnings,
   approval statuses or version hashes to perform this recalculation. Invalidate
   local caches by account/workspace after save, refresh overview/hours/sheets and
   handle a setting changed on the website when app resumes. Existing approved/
   locked entries remain locked. Do not imply earnings have been repriced.

7. Add meaningful DTO/API/widget tests and run flutter analyze/tests. Fixture:
   contract480, weeklytarget2400, days600/420/420/420/420 =>2280 worked,
   dailyOT120, weeklyOT0, variance−120. Switching selection changes main total
   120↔0 while data/earnings stay unchanged. Cover nullable contract, 450-minute
   contract, paid/unpaid breaks, month boundary, pagination summaries, stale-version
   handling, idempotency retry, role/read-only errors and approved sheet display.
   Make incremental commits. Show screenshots at Android phone size for workspace
   preferences and both overview modes. Report actual build/test evidence and
   remaining real-device verification. Backend readiness alone is not a mobile fix.

---

Backend production deployment and Flutter changes are separate. Test locally or
on staging with synthetic/designated test data first. Do not record auth tokens.
