# Active Session State

## Scope

- Deduplicated shared helpers after canonical `0ea0f50` integration: `sectionHasContent` (one copy in `customization.ts`), `configFromStudio` (one copy in `projects.ts`), and the `prepareRun`/`prepareCustomRun` prompt-assembly path in `runner.ts` (shared context resolution, approval gate, review prompt, and run finalization helpers).
- Orchestration lock hardening: immediate lock release via `try/finally` around the scheduling loop and release-on-failure after post-acquisition bookkeeping; TTL expiry remains the crash backstop.
- New guarded-parse regression tests for path-annotated `studio.json` and `package.json` error messages.

## Documentation Impact

- Decision: no-update
- Reason: the changes are behavior-preserving internal refactors (identical prompt/metadata/output strings verified by the exact-match prompt test suite), lock-lifecycle hardening with unchanged external semantics, and new tests. No player-visible behavior, engine architecture, production commitment, or release communication changed, and no `README`/`docs` text references the refactored internals.
- Documents: none
