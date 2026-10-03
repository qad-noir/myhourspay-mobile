# Google validation diagnostics: build 7

The owner reported generic "Check the highlighted details" messages on Google sign-in and signup, and password-form validation when selecting Google. Provider 422 errors without an editable field now have specific credential/email/rejection guidance. Unknown fieldless 422 responses no longer claim fields were highlighted. Existing new-account name/terms guidance remains in place.

Google signup validates name and explicit terms only. Switching from a failed password Create account attempt clears stale email/password/confirmation validation, preserving entered drafts. Signup explains that Google supplies email and no password is needed. Password registration still validates the complete form. Promotional consent remains separate and defaults checked for password registration; social consent storage remains unsupported by the current backend.

Safe diagnostic lines contain only HTTP status and bounded protocol error codes. Original Google exchange codes are logged before conversion to UI guidance. No request/response body, provider token, bearer token, password, name, email or subject is logged by these additions.

Verification: 23 affected signup, Google and login regression tests passed; static analysis found no issues. A regression demonstrates a failed password registration followed by Google signup with only name/terms, clearing old field errors and invoking the provider callback once. These are fixture tests, not successful live Google authentication evidence.

Release APK built with config/production.json (53.8 MB). ADB installation succeeded on the connected phone; package inspection confirmed versionCode=7/versionName=0.1.0 and MainActivity launched. The actual Google rejection code remains to be captured from a live retry. Shared Flutter validation/error behavior applies to iOS too; iOS Google setup and device testing remain pending.
