# Contract provenance and readable endpoint reference

Status: **0.1.0-draft**, source inspected, not runtime verified or agreed.
Backend source commit: `f1f63b8e13079d649dc60d1e4f09e0132d1a4ede`.
Source: `C:/Users/HP-MC/Documents/laravel/myhourspay`.
Files: routes/api.php, WorkspaceApiController.php, HoursEntry.php,
HoursCalculator.php, composer.json. Inspected 2026-09-29.

The adjacent OpenAPI file is a pinned, incomplete integration draft. The Flutter
UI uses a handwritten **demo repository**, not a generated or live API client.
Do not infer that every proposed response is supported by Laravel.

| Existing route | Behaviour and restrictions |
| --- | --- |
| GET /api/user | Sanctum-authenticated raw user serialization |
| GET /api/v1/workspaces | Membership list |
| GET /api/v1/workspaces/{id}/hours | Own entries, inclusive start/end, descending date, paginator |
| POST /api/v1/workspaces/{id}/hours | hours:write, one date/user/workspace, locked-week check |
| GET /api/v1/workspaces/{id}/projects | Active projects; nested paginator under data |
| GET /api/v1/workspaces/{id}/invoices | Nested paginator, newest first |
| GET /api/v1/workspaces/{id}/reports/hours | Required start/end, server-calculated summary |
| POST /api/v1/workspaces/{id}/timesheets/{id}/review | approvals:write, reviewer role, workspace match |

All v1 routes additionally require active account, trial choice, paid
api_access and premium-api throttle. Projects/invoices/reports/review are
inventoried here but not yet fully schematized. Raw model serialization makes
response-field guarantees unsafe until explicit Resources and fixtures exist.

Proposed login is marked `proposed-not-implemented` inside OpenAPI. Further
proposed lifecycle routes and security requirements are in BACKEND_HANDOFF.md.
No namespace is agreed. Never use an app header or prefix as authentication.

Dates are calendar strings. The inspected calculator uses clock-minute
subtraction, rejects overnight work and starts weeks Monday. Confirm configured
backend timezone and DST policy before live display; do not convert a work date
through UTC. Store monetary values in integer minor units with explicit currency;
no client payroll calculation is implemented.

To validate: install the pinned Python requirements in CI and run
`python -m openapi_spec_validator docs/api/mobile.openapi.yaml`.
To render HTML once Node tooling is available:
`npx @redocly/cli build-docs docs/api/mobile.openapi.yaml --output docs/api/index.html`.
The table above is the committed readable reference; generated HTML has not been
produced in this environment. Pin the chosen Redocly version before release CI.

Before changing a released contract, compare against the released artifact using
oasdiff breaking in CI, allow additive fields, and introduce a version for
breaking changes. There is no released mobile baseline yet. Do not describe the
current schema-validation job as a compatibility check.
