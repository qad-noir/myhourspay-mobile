# Google conflict guidance: build 6

The owner confirmed the generic record-conflict message appeared after selecting a Google account. Build 5 mapped every HTTP 409 to an hours-record conflict. Build 6 includes the specific account_link_required and credential_already_used messages committed in 3e20913, plus new-account consent/name guidance for google_signup_required. The user-requested promotional wording omits "yet".

Focused Google tests: eight passed. Static analysis: no issues. An additional regression case for new-account name/terms validation was added; its rerun could not compile because C: ran out of space. Production invalid-token probe now returned HTTP 422 with code invalid_provider_credential, replacing the previously observed HTTP 500 caused by the missing Firebase JWT class. No real Google tokens or user credentials were used in this probe.

The first build 6 attempt failed in copyFlutterAssetsRelease and mergeReleaseNativeLibs with "There is not enough space on the disk". After the owner freed space, all nine focused Google tests passed and the release build completed successfully (53.8 MB). ADB replacement installation succeeded on the connected Android phone. Package inspection confirmed versionCode=6/versionName=0.1.0, and MainActivity launched successfully. The build uses config/production.json. Real Google interaction on build 6 remains a user/device check.

The exact code for the owner's Google 409 has not been captured, so account linking is a likely cause, not a confirmed live result. A new APK distinguishes linking from credential replay. Successful Google login remains unverified. Existing-account linking requires password-confirmed authenticated POST /auth/providers/google/link; its mobile UI remains pending.
