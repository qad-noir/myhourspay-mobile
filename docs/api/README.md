# Canonical contract pin

Version: **1.0.0**, implemented, copied byte-for-byte from Laravel at
`a973d70871330475ee4899ddf8df867215e7e364` (after e9653df).
`contract-lock.json` records the source and SHA-256. This replaces 0.1.0-draft.
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
