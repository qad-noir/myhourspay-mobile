# Sign-up and device naming: Android build 4

The dedicated sign-up screen uses the real registration/session flow. Terms acceptance is required; promotional consent is separate, checked by default as requested, and can be deselected. Device labels use Android/iOS model metadata with a safe platform fallback. Existing server session names are not rewritten; a new login records the new label.

Verification on 3 October 2026:

- `flutter analyze --no-pub`: no issues.
- `flutter test`: 93 tests passed, including registration validation, promotional opt-out, duplicate-submission protection, restricted email-verification token replacement, responsive sign-up layouts, and Android/iOS device labels. These are fixture-based automated checks, not live provider authentication or production registration evidence.
- Release APK built with `APP_ENV=production` and `API_BASE_URL=https://mhp.glsltd.co.uk/api/v1/mobile`.
- ADB replacement installation succeeded on the connected Android phone. Package inspection confirmed `com.example.myhourspay`, versionName `0.1.0`, versionCode `4`; MainActivity launched successfully. User sign-in/sign-up interaction on this APK has not yet been verified.

iOS compatibility is considered in the shared layouts, device metadata path and plugin requirements. The project targets iOS 15; the device-info plugin requires iOS 12 or later. No iOS build or device verification was performed on Windows. Google/Apple native adapters and developer configuration remain pending; see SOCIAL-SIGN-IN-SETUP.md. Android release signing still uses the existing development key and is not store-ready.
