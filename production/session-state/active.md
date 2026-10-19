# Active Session State

## Scope

- Deduplicated shared helpers after canonical `0ea0f50` integration: `sectionHasContent` (one copy in `customization.ts`), `configFromStudio` (one copy in `projects.ts`), and the `prepareRun`/`prepareCustomRun` prompt-assembly path in `runner.ts` (shared context resolution, approval gate, review prompt, and run finalization helpers).
- Orchestration lock hardening: immediate lock release via `try/finally` around the scheduling loop and release-on-failure after post-acquisition bookkeeping; TTL expiry remains the crash backstop.
- New guarded-parse regression tests for path-annotated `studio.json` and `package.json` error messages.
- Hello-world pipeline verification found and fixed a pre-existing crash (canonical `0ea0f50`): `task orchestrate` planning threw a raw `ENOENT` for tasks whose context/write files do not exist yet; `safeArtifact` now resolves only the deepest existing ancestor via realpath and still rejects symlink escapes.

## Documentation Impact

- Decision: no-update
- Reason: this batch changes runtime implementation only — bro headless argument compatibility (drop the unsupported `--model-reasoning-effort` flag, map the studio write policy to `--approve-all`/`--approve-reads`) and validation enforcement of the gdd template's already-declared required sections plus init-scaffold conformance. No README/`docs`/`docs/user-guide.md` text references bro argument shapes or the scaffolded GDD section list (`user-guide.md` only points at `templates show gdd`); the enforcement check is itself the discoverable contract via `./codex-game-studio validate`.
- Documents: none
