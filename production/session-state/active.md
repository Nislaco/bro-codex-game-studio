# Active Session State

## Scope

- Deduplicated shared helpers after canonical `0ea0f50` integration: `sectionHasContent` (one copy in `customization.ts`), `configFromStudio` (one copy in `projects.ts`), and the `prepareRun`/`prepareCustomRun` prompt-assembly path in `runner.ts` (shared context resolution, approval gate, review prompt, and run finalization helpers).
- Orchestration lock hardening: immediate lock release via `try/finally` around the scheduling loop and release-on-failure after post-acquisition bookkeeping; TTL expiry remains the crash backstop.
- New guarded-parse regression tests for path-annotated `studio.json` and `package.json` error messages.
- Hello-world pipeline verification found and fixed a pre-existing crash (canonical `0ea0f50`): `task orchestrate` planning threw a raw `ENOENT` for tasks whose context/write files do not exist yet; `safeArtifact` now resolves only the deepest existing ancestor via realpath and still rejects symlink escapes.

## Documentation Impact

- Decision: no-update
- Reason: the changes are behavior-preserving internal refactors (identical prompt/metadata/output strings verified by the exact-match prompt test suite), lock-lifecycle hardening with unchanged external semantics, new tests, and a robustness fix so planning tolerates not-yet-created task files (no documented behavior changed; no `README`/`docs` text references the realpath resolution of `--include-artifact`/task file paths).
- Documents: none
