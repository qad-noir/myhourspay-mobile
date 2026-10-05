# Laravel implementation prompt

Expose authoritative Google linkage to the mobile app. The current mobile User
payload from `MobileAuthentication::user` has no linked-provider status, while
`social_accounts` stores the link. Flutter currently hides Link Google after a
confirmed Google authentication/link and retains that fact in secure session
storage. Password login after logout, or links created on another device, cannot
be detected from the existing contract.

Implement a boolean `google_linked` on the User response, derived from an existing
`social_accounts` row for the authenticated user and provider `google`. Return it
consistently from `/me` and every authentication, MFA and verification response
containing User. Do not expose provider subjects, tokens or identifiers. Update
`docs/api/mobile.openapi.yaml` and `docs/api/mobile-integration.md`; include true,
false, cross-account isolation and password-login-after-link regression tests.
Preserve the current Google nonce/challenge protocol. Include an implementation
summary, changed files, exact test commands/results and deployment instructions.

After that contract is implemented and deployed, Flutter must parse the documented
field, prefer the server status over the session hint, refresh `/me` after linking,
and test account switching and password login. This document proposes an API
addition; it does not claim it exists or has been deployed.
