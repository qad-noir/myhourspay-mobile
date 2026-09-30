# Backend integration status

The previous draft-gap handoff is superseded by the implemented mobile API 1.0.0.
Read api/mobile-integration.md and api/contract-lock.json. Core hours access does
not require paid external api_access. No backend controller changes were made by
this Flutter continuation.

Local setup initially lacked all three 2026_09_29 mobile migrations. They were
applied to the configured local MySQL service at 127.0.0.1. They create challenges,
mutation replay records and provider identity/nonce tables. Do not assume this
means production has been migrated or deployed.

The Flutter client uses exact status/access_token responses, restricted verification
tokens, challenge-based MFA, server totals, idempotency keys and version hashes.
Any remaining record-specific access failure must be resolved by backend policy,
not by bypassing entitlements in the client.

Remaining backend/store items are the explicit list in the integration guide:
profile editing, deletion/provider revocation, unlinking, push and native trial-choice
resolution. Provider IDs and the Apple Android HTTPS callback/handoff still need
owner configuration. No fake endpoint is used for these features.

See VERIFICATION.md for actual local API and website results and platform limits.
