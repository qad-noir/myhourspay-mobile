# Canonical contract pin

Version: **2.0.0**, copied byte-for-byte from the Laravel handoff artifact
`production-patches/flutter-google-nonce-handoff-2026-10-03-14-11-37`.
`contract-lock.json` records the source artifact and SHA-256. Google now requires
per-attempt nonce-bound challenges; build 8 is incompatible with this Google flow.
The production server entry is a deployment target, not deployment evidence.

The file uses JSON syntax, valid YAML 1.2 / OpenAPI 3.1. Handwritten typed repositories
follow the defined payloads; no generated Dart client is checked in. Do not edit
the pinned specification independently. Regenerate in Laravel using
`python scripts/build-mobile-contract.py`, review the diff, then copy and update
the pin and response tests together.

Run `python tool/check_contract.py` to check the pin and essential client assumptions.
Run `python -m openapi_spec_validator docs/api/mobile.openapi.yaml` with validator
0.7.2 for full schema validation. CI performs both. Flutter tests parse the canonical
shape and exercise representative authentication, workspaces, hours and errors.

Readable operational documentation: mobile-integration.md. The source OpenAPI can
also be loaded into Swagger Editor or rendered with Redocly. Breaking changes must
be compared against the last released v1 artifact before backend deployment; no
mobile release baseline exists yet. CI does not claim full semantic compatibility.

Generated readable reference: [index.html](index.html), rendered from this contract
with Redocly CLI 2.56.0. Regenerate with:

```
npx --yes --package=@redocly/cli@2.56.0 redocly build-docs docs/api/mobile.openapi.yaml --output docs/api/index.html
```
