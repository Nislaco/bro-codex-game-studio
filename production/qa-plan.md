# QA Plan — Othello Prototype

**Date:** 2026-10-19
**Owner:** qa-playtester
**Status:** Draft for review (Sprint 3, STORY-3.2)
**Engine:** Godot 4.7.2

---

# Purpose

Define how the Othello prototype is verified before and after each change: what is automated, what needs a human, on which platforms, and what "done" means. This plan extends the automated harness (90 assertions) and the GUT suite with the manual and playtest coverage that automation cannot provide.

---

# 1. Regression Checklist

## 1.1 Automated (runs on every change — no human required)

| Suite | Command | Coverage | Current |
|-------|---------|----------|---------|
| Standalone runner | `godot --headless --path src -s res://scripts/verify_othello.gd` | 90 assertions: rules (AT-1..14), mode/difficulty (S7-AT-1..7), turn/pass (S3-AT-1..7), AI (S5-AT-1..7), UI shell (S6-AT-1..10), feedback (S8-AT-1..6), accessibility (S14-AT-1..6), localization (S13-AT-1) | 90/90 pass, exit 0 |
| GUT suite | `godot --headless --path src -s res://addons/gut/gut_cmdln.gd` | Same 90 assertions via `othello_checks.gd`; JUnit XML → `user://gut_results.xml` | 90 asserts, 1 test, 0 orphans, exit 0 |
| Headless scene | `godot --headless --path src --quit-after 90` | Scene loads and idles with 0 script errors | exit 0 |
| Hard-difficulty budget | `godot --headless --path src -s res://scripts/bench_hard_difficulty.gd` | Depth-5 median ≤ 500ms over 50 runs on 10 boards | 403ms median |
| Studio validation | `./codex-game-studio validate` | Repo/template contract | 1216 PASS / 0 FAIL |
| Docs impact | `./codex-game-studio docs-impact --base HEAD` | Functional changes have doc evidence | PASS |
| Maintainer toolchain | `npm test` | CLI/template test suite | 187 pass / 0 fail |
| Live runtime | MCP `play_scene` → `get_editor_errors` | The running game produces **0** runtime errors on first play and on restart | 0 errors |

> **Invariant:** the standalone runner and the GUT suite execute the *same* assertion set (`src/scripts/othello_checks.gd`), so they cannot drift. Any new assertion is added once and runs in both.

## 1.2 Manual Smoke (5 minutes, per release candidate)

| # | Step | Expected | Related |
|---|------|----------|---------|
| SM-1 | Launch the game; observe the settings bar | Mode, Difficulty, Language, Volume visible and legible | S6-AT-4 |
| SM-2 | Select "vs Player"; play two legal moves | Discs appear exactly centered; score and turn update; legal cells highlighted in gold | S6-AT-6, S6-AT-10 |
| SM-3 | Click an occupied cell and an illegal empty cell | "Invalid Move!" appears (~0.5s); board unchanged | S8-VT-1 |
| SM-4 | Switch to "vs Computer"; make a move | "Computer is thinking..." appears; the computer replies; highlights clear during its turn | S8-VT-2, S8-VT-4 |
| SM-5 | Click Restart | Fresh board, 4 discs, "Turn: Black", scores reset | S9-AT-1/2 |

---

# 2. Device / Platform Matrix

| Platform | Status | Priority | Notes |
|----------|--------|----------|-------|
| Linux x86_64 (headless) | ✅ Covered by CI | P0 | Every automated suite runs here |
| Linux desktop (windowed) | ✅ Manual | P0 | Primary dev target; window 800×600, board 480×480 |
| Windows x86_64 | ⬜ Untested | P1 | Not yet built or run; export path untested |
| macOS | ⬜ Untested | P1 | Same as Windows |
| Web (HTML5) | ⬜ Untested | P2 | Godot web export; check `user://` → IndexedDB for save data |
| Mobile / touch | ⬜ Out of scope | P2 | Prototype is desktop-only (pillars say "local play", no touch contract) |

**Known constraint:** the board is a fixed 480×480 block with no responsive layout. On windows shorter than ~600px the board may clip (logged as a post-gate gap, not a gate blocker).

---

# 3. Playtest Scenarios

Each scenario has a goal, a script, and pass criteria. Record a debrief in `production/playtest/`.

| ID | Scenario | Script | Pass criteria |
|----|----------|--------|---------------|
| PT-1 | **First-time player, PvP** | Launch → play vs another human to completion, no instructions | Player understands legal-move highlighting without asking; understands whose turn it is; can find Restart |
| PT-2 | **First-time player, vs Computer (Easy)** | Launch → play vs AI on Easy to completion | AI feels beatable but not trivial; player notices the "thinking" pause; understands the score |
| PT-3 | **Difficulty ladder** | Play the same opening vs AI at Easy → Medium → Hard | Perceived AI strength increases monotonically; Hard is not so slow it feels broken |
| PT-4 | **Pass and end-of-game** | Play until a pass and a game-over occur | The skip notice is understood ("White has no legal moves! Skipping..."); the final score and winner are clear |
| PT-5 | **Restart and settings** | Change mode/difficulty mid-match → Restart → play again | Settings persist across restart; the board resets cleanly; no stale state |

**Per-session capture:** session date, build/commit, scenario IDs run, player count, completion (yes/no), time to first legal move, confusion points, verbatim quotes, bugs found (with severity).

---

# 4. Bug Triage

| Severity | Definition | Owner | Response SLA | Gate impact |
|----------|------------|-------|--------------|-------------|
| **P0 — Blocker** | Crash, softlock, unplayable, data loss, or a rule violation that changes the winner | gameplay-programmer | 24 hours | Blocks the release gate |
| **P1 — Major** | Core loop degraded but playable (no feedback, wrong highlight, mislabeled state, unusable in one mode) | owner of the affected system | 3 days | Blocks the release gate |
| **P2 — Minor** | Cosmetic, wording, or polish issue with no effect on play | ui-programmer / game-feel-designer | Current sprint | Does not block |
| **P3 — Trivial** | Typo, minor visual nit | any | Backlog | Does not block |

**Triage flow:** log → classify → assign owner (by system: S1–S10) → add a harness assertion before the fix (so it cannot regress) → fix → verify the full automated surface.

**Rule:** every P0/P1 fix ships with a regression assertion in `othello_checks.gd`. A fix without an assertion is not accepted.

---

# 5. Release Criteria (Definition of Done)

A build is releasable when **all** of the following hold:

- [ ] Standalone runner: 90+ checks, 0 failures, exit 0
- [ ] GUT suite: 0 failures, 0 orphans, exit 0
- [ ] Headless scene: exit 0, 0 script errors
- [ ] Live running game: 0 runtime errors (first play **and** restart)
- [ ] Hard-difficulty median ≤ 500ms on the reference machine
- [ ] `./codex-game-studio validate`: 1216 PASS / 0 FAIL / 0 WARN
- [ ] `./codex-game-studio docs-impact --base HEAD`: PASS
- [ ] `npm test`: 187 pass / 0 fail
- [ ] ≥ 3 recorded playtest sessions covering PT-1..PT-5
- [ ] 0 open P0 defects; 0 open P1 defects
- [ ] Accessibility baseline re-verified (contrast + keyboard) if the UI palette or layout changed
- [ ] Save/load round-trip verified if the save schema changed

---

# 6. Known Gaps (not covered by this plan yet)

| Gap | Why | Plan |
|-----|-----|------|
| Screen-reader announcements | Godot has no built-in narration for board state | Add `AccessibilityNode` descriptions per cell; S14 follow-up |
| Focus-visible ring on cells | Cells are plain `Control`s with no focus style | Add a focus indicator draw; S14 follow-up |
| Responsive/resize layout | Board is a fixed 480×480 block | Add anchors/scroll container; S14 follow-up |
| Platform export builds | No export presets configured | Add Windows/macOS/web presets once a target is chosen |
| Automated visual regression | Only assertion-level coverage | MCP `godot_screenshot` exists; add baseline-image diffing |
| Save/load automated test | Schema exists but auto-save is not wired | Add a round-trip assertion when Epic 4 completes |
| Audio verification | Headless has no audio device; placeholder WAVs only | Manual playtest + CI skips audio assertions |

---

# 7. Evidence Locations

| Artifact | Path |
|----------|------|
| Automated assertions | `src/scripts/othello_checks.gd` (shared) |
| Standalone runner | `src/scripts/verify_othello.gd` |
| GUT suite | `src/tests/test_othello.gd` |
| GUT config | `src/.gutconfig.json` |
| CI workflow | `.github/workflows/ci.yml` |
| Difficulty benchmark | `src/scripts/bench_hard_difficulty.gd` |
| S8 visual pass | `production/playtest/s8-visual-pass-2026-10-19.md` |
| A11y baseline | `production/playtest/a11y-baseline-2026-10-19.md` |
| Prototype gate | `production/session-state/prototype-gate-check.md` |
| Session state | `production/session-state/active.md` |

---

# Next Owner / Decision

- **Decision requested:** approve this QA plan as the release contract for the prototype.
- **Next owner:** qa-playtester runs the 5 smoke steps against the current build and schedules 3 playtest sessions (PT-1..PT-5).
- **Follow-up:** producer schedules the real-player playtest before the content-complete gate (m4).
