# Active Session State

## Scope

- Reviewed and repaired the codex-game-studio CLI after integrating canonical `0ea0f50`.
- Hardening pass across runtime dispatch, orchestration locking, input parsing, validation, and test isolation.

## Documentation Impact

- Decision: no-update
- Reason: changes are developer-tooling behavior only (CLI `--version` value, `--runtime` value validation, orchestration lock TTL enforcement, guarded JSON/exec parsing, template prune list, and test-isolation fixes). No player-visible behavior, engine architecture, production commitment, or release communication changed, and no `README`/`docs` text references the corrected values (`npm test` is not documented; the `--runtime codex|bitrouter` values still behave as documented).
- Documents: none
