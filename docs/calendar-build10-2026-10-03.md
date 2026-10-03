# Calendar behavior — build 10, 3 October 2026

Hours calendar opens on today's date and current month in the workspace's timezone, independently of the displayed Hours week. Confirming the initial date without changing it returns no selection, so even a historical displayed week stays unchanged. Selecting a changed date within the displayed week preserves the page and skips reload/notifications. A changed date in another week loads that containing Monday–Sunday week. Month entry-date reads still run to populate calendar markers; these do not replace the displayed week.

Validation: 14 navigation/workspace regression tests passed, including opening today while viewing a historical week, unchanged OK preserving page identity and read count, selecting another day in the displayed week without notifications or reads, selecting another week, entry-date markers and Overview/Hours isolation. Flutter analyze: no issues. Production Android release build 10 succeeded (53.6 MB) using config/production.json and https://mhp.glsltd.co.uk/api/v1/mobile. Source commit 2aec097.

The initial test compilation hit a full disk. Only verified project build/app/intermediates was removed; source and release APK were preserved. Tests and build then succeeded. The change uses the existing cross-platform Flutter calendar; iOS compilation/device testing remains unavailable on Windows.

Installation confirmed: ADB install returned Success, package versionCode=10, and app launch completed. Live calendar interaction on the phone remains for the owner to verify.
