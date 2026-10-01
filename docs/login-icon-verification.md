# Login and icon verification — 2026-10-01

Production checked at approximately 13:32–13:33 UTC:
- GET https://mhp.glsltd.co.uk/api/v1/mobile/auth/providers: HTTP 404, JSON code not_found.
- POST https://mhp.glsltd.co.uk/api/v1/mobile/auth/login with an empty JSON object (no credentials): HTTP 404, JSON code not_found. The implemented Laravel route should validate missing fields with HTTP 422.

These probes confirm a deployment/routing mismatch, not an incorrect password. Deploy the implemented native mobile routes and verify the web-server document root and Laravel route cache. No production credentials or hours writes were used.

The connected Android 13 Samsung SM_N981N became available over ADB. Filtered recent logs did not expose the reported exception; its precise cause remains unconfirmed. The former catch-all message could represent response parsing or device storage errors. The client now distinguishes those failures and still revokes an issued token when secure persistence fails. Public HTTP 401 login rejections no longer display a false session-expiry message.

Validation: 11 targeted login/session tests passed, including malformed login JSON, rejected login after expiry, secure-storage failure with token revocation, and authenticated workspace failures.

Launcher artwork is generated from assets/brand/brand-mark.png for Android, iOS, and web. Regenerate on Windows with tool/generate_icons.ps1. Rebuild and install the APK to update an existing phone installation; changing source icons cannot alter an already-built APK.
