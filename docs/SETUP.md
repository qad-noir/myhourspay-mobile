# Environments, devices and release setup

## Network configuration
Current executable is demo-only. The future client must explicitly read APP_ENV
(development/staging/production) and API_ORIGIN through dart-define and validate
with ApiEnvironment. Do not imply these flags enable networking in this build.
Missing settings must fail closed, never select production. Build-time values are
public. Keep secrets, Apple keys and provider client secrets on Laravel.

For local Laravel, Android emulator reaches the computer at 10.0.2.2, typically
http://10.0.2.2:8000 when that service is configured. Device localhost is the device.
Physical devices require a reachable LAN listener or HTTPS tunnel; verify firewall
and bind settings. Permit local HTTP only in Android debug manifest/network
security config or an iOS debug-only ATS exception. No release exceptions and no
certificate-validation bypass. Staging and production require HTTPS. Existing
production origin is https://mhp.glsltd.co.uk; no test writes are permitted there.

Create actual development, staging and production flavours after owner-approved
package/bundle IDs are supplied. Generated com.example identifiers are placeholders,
not release identities. Separate Android applicationId suffixes and iOS schemes,
bundle IDs, entitlements and provider client configs. Do not invent company IDs.
Staging requires an isolated backend/database, HTTPS origin, mail sandbox and
separate provider callbacks; none exists today.

## Android and iOS
Run flutter doctor -v and flutter devices. Android needs SDK/platform tools, JDK
and accepted licences; use flutter build apk --debug for compilation evidence.
Emulator/physical-device tests are separate from compilation. Release requires an
owner-controlled signing keystore and provider signing fingerprints.

Windows cannot build iOS. Use macOS with supported Xcode, CocoaPods as required,
an Apple team, registered bundle IDs, provisioning profiles and signing. Enable
Sign in with Apple and associated domains only for verified owned domains and
configured callbacks. Test simulator and real-device secure storage, return links,
logout, text scaling and background/resume before TestFlight. Do not check secrets
or signing materials into Git.

## Provider setup (blocked; no SDK integration yet)
Google: supply Android/iOS client IDs plus backend audience allowlist, Android
package and debug/release SHA signing fingerprints, iOS bundle ID and URL scheme
from provider configuration. Use maintained native/system-browser integration.
Pass identity credentials to Laravel over HTTPS; never use them as MHP tokens.

Apple: supply team ID, key ID and backend private key, iOS app ID/bundle capability,
Android browser service ID, associated app/service grouping and exact HTTPS return
URL. Backend must verify issuer/audience/signature/expiry and nonce/state/code
binding. Android requires a secure browser callback and verified return-to-app
link. Return only an expiring single-use exchange code, never an MHP token in a URL.
No callback URL or provider ID has been invented or configured.

Provider cancellation is a normal return to sign-in. Matching email is not account
linking authority. Preserve MFA and all MHP account restrictions for social login.
Private relay email and first-authorisation-only Apple profile data need tests.
Deletion must address provider grant revocation and account retention policy.

## Store and notification work
Free companion only. No purchase buttons, Stripe links or upgrade_url rendering.
Before submission, review current Apple/Google policies for the actual regions and
flows; this file is not a completed store-policy review. Confirm Apple equivalent
login requirements when adding Google. Implement in-app deletion with recent
authentication before release, privacy policy/data disclosures, accurate permissions,
review account and reviewer instructions. Avoid unneeded device permissions.

Push is deferred. It requires FCM/APNs configuration, backend device-token
registration/rotation, account/device ownership and logout cleanup. Keep sensitive
hours/account data out of lock-screen previews. Push transport is separate from
foreground REST and WebSockets.
