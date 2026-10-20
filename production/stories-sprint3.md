# Sprint 3 Stories — Epics 5, 6 + Sprint 1/2 Carryover (Week 5-6)

**Project:** othello (Godot 4.7.2) | **Sprint:** 3 (Week 5-6 of 6-week gate) | **Baseline:** Sprint 1-2 automated complete (88 checks, Hard gate PASS)

---

## Sprint Goal
Complete QA infrastructure (Test Runner, CI, QA Plan), execute manual playtest validation (S8 visual, A11y baseline), run Prototype Gate Review, and execute Differentiation Spike for Epic 5 go/no-go.

---

## Stories

### STORY-3.1: Godot Test Runner (GUT) Setup (Epic 6)
**Owner:** qa-playtester / godot-specialist  
**Epic:** 6 | **Sprint:** 3 | **Estimate:** 1 day  
**Dependencies:** None

**Description:** Install and configure GUT (Godot Unit Test) as the official test runner. Migrate/wrap the existing `verify_othello.gd` harness as GUT test classes. Configure headless CI execution with JUnit XML output.

**Acceptance Criteria:**
- [ ] GUT installed via AssetLib or submodule (`addons/gut/`).
- [ ] Existing 80 assertions run as GUT tests (`godot --headless -s res://addons/gut/gut_cmdln.gd`).
- [ ] `.github/workflows/ci.yml` runs GUT on push/PR, uploads JUnit XML.
- [ ] Test output includes: 80 tests pass, 0 failures, exit code 0 on success.
- [ ] `./codex-game-studio validate` still passes (1216 PASS).

**Files:**
- New: `addons/gut/`, `.github/workflows/ci.yml`
- Ref: `src/scripts/verify_othello.gd` (refactor to GUT `Test` class)

**Verification:**
```
godot --headless -s res://addons/gut/gut_cmdln.gd
→ 80 tests pass, JUnit XML produced
```

**Risks:**
- GUT expects `Node`-based tests; current harness extends `SceneTree`. Wrap or refactor.

---

### STORY-3.2: QA Plan Document (Epic 6)
**Owner:** qa-playtester / producer  
**Epic:** 6 | **Sprint:** 3 | **Estimate:** 0.5 day  
**Dependencies:** STORY-3.1 (test runner informs regression scope)

**Description:** Author `production/qa-plan.md` covering regression checklist, device matrix, playtest scenarios, bug triage SLA, release criteria.

**Acceptance Criteria:**
- [ ] Regression checklist: 80 harness assertions + 5 manual smoke tests.
- [ ] Device matrix: Linux (CI), Windows, macOS, Web export.
- [ ] 5 playtest scenarios: first-time PvP, vs AI each difficulty, pass/skip, game-over, restart.
- [ ] Bug triage: severity definitions (P0-P2), owner assignment, SLA (P0: 24h, P1: 3d, P2: sprint).
- [ ] Release criteria: all harness green, 3 recorded playtests, no P0/P1 bugs.

**Files:**
- New: `production/qa-plan.md`

**Verification:**
- Document review by producer; `docs-impact` passes.

---

### STORY-3.3: S8 Visual Feedback Pass (Sprint 1 Carryover)
**Owner:** qa-playtester  
**Epic:** 1 | **Sprint:** 3 | **Estimate:** 0.5 day  
**Dependencies:** None (template ready)

**Description:** Execute the in-editor visual verification items (S8-VT-1..4) using the template `production/playtest/s8-visual-pass-2026-10-19.md`. Record pass/fail and adjust delay constants if needed.

**Acceptance Criteria:**
- [ ] S8-VT-1: "Invalid Move!" visible ~0.5s after occupied/illegal click.
- [ ] S8-VT-2: "Computer is thinking..." visible ~0.8s on AI turn (all 3 difficulties).
- [ ] S8-VT-3: "<Name> has no legal moves! Skipping..." visible ~1.0s on pass.
- [ ] S8-VT-4: Legal-move highlights appear on human turn, clear on AI turn and game over.
- [ ] Evidence recorded in `production/playtest/s8-visual-pass-2026-10-19.md` with PASS/FAIL.
- [ ] If timing adjusted, `INVALID_MOVE_DELAY`, `THINKING_DELAY`, `PASS_DELAY` updated in `othello.gd` and harness re-run.

**Files:**
- Evidence: `production/playtest/s8-visual-pass-2026-10-19.md` (filled)
- Possible: `src/scripts/othello.gd` (delay constants)

**Verification:**
- Manual in-editor playtest (F6).
- `./codex-game-studio docs-impact --base HEAD` passes after any constant changes.

---

### STORY-3.4: Accessibility Baseline Pass (Sprint 1 Carryover)
**Owner:** accessibility-specialist  
**Epic:** 1 | **Sprint:** 3 | **Estimate:** 0.5 day  
**Dependencies:** None (template ready)

**Description:** Execute keyboard-only playthrough and contrast/colorblind audit using template `production/playtest/a11y-baseline-2026-10-19.md`.

**Acceptance Criteria:**
- [ ] Keyboard-only: Tab/Enter navigates mode→difficulty→board→restart; full match completable.
- [ ] Focus order logical (LTR/TTB on board).
- [ ] Contrast: Label text vs background ≥ 4.5:1; cell hint vs base ≥ 3:1.
- [ ] Colorblind: highlights distinguishable in protanopia/deuteranopia sim.
- [ ] Evidence recorded in `production/playtest/a11y-baseline-2026-10-19.md`.
- [ ] Gaps documented for post-gate remediation.

**Files:**
- Evidence: `production/playtest/a11y-baseline-2026-10-19.md` (filled)

**Verification:**
- Manual playtest + contrast tool (Godot theme preview or external).
- No code changes required unless contrast fails.

---

### STORY-3.5: Prototype Gate Review (Epic 1)
**Owner:** producer  
**Epic:** 1 | **Sprint:** 3 | **Estimate:** 0.5 day  
**Dependencies:** STORY-3.3, STORY-3.4 complete

**Description:** Run the prototype gate checklist: all Epic 1 acceptance criteria met, evidence recorded, no blocking defects. Decision: PROCEED to production / EXTEND / PIVOT.

**Acceptance Criteria:**
- [ ] Hard median ≤ 500ms (✅ 404ms).
- [ ] Cell refactor merged, harness green (✅ 80/0).
- [ ] S8-VT 1-4 recorded, constants adjusted if needed (STORY-3.3).
- [ ] Keyboard match complete, contrast documented, gaps listed (STORY-3.4).
- [ ] Restart assertion in harness (✅).
- [ ] Gate decision recorded in `production/session-state/active.md`.
- [ ] `production/epics.md` Epic 1 status → Done.

**Files:**
- `production/session-state/active.md` (gate decision entry)
- `production/epics.md` (Epic 1 status)

**Verification:**
```
./codex-game-studio validate
./codex-game-studio docs-impact --base HEAD
godot --headless --path src -s res://scripts/verify_othello.gd
```

---

### STORY-3.6: Differentiation Spike (Epic 5)
**Owner:** senior-game-designer / producer  
**Epic:** 5 | **Sprint:** 3 | **Estimate:** 2 days  
**Dependencies:** Prototype Gate Review (STORY-3.5) PROCEED decision

**Description:** Execute a 2-day throwaway spike exploring a product differentiation hypothesis. Document: fantasy, mechanic, audience, risk. Build a minimal playable prototype in a separate branch. Record go/no-go decision.

**Acceptance Criteria:**
- [ ] One-page hypothesis doc: fantasy, core mechanic, target audience, key risk.
- [ ] Throwaway spike branch (`spike/differentiation-<name>`) with playable demo (≤ 2 days work).
- [ ] Spike playtested internally (1 session, 15 min).
- [ ] Decision recorded: PROCEED to production with differentiation / KILL differentiation / PIVOT core loop.
- [ ] If PROCEED: spawn Epic 5 implementation stories; if KILL: archive spike; if PIVOT: new hypothesis.

**Files:**
- New: `design/differentiation-hypothesis.md`, `spike/differentiation-<name>/` (branch)
- Decision: `production/session-state/active.md` (Epic 5 status)

**Verification:**
- Spike demo runs and demonstrates the mechanic.
- Decision documented with rationale.

**Risks:**
- Scope creep: differentiation is explicitly a Non-Goal for prototype; spike must be throwaway.
- Must not disturb the verified P0/P1 loop (separate branch).

---

### STORY-3.7: Sprint 3 Review & Gate Decision
**Owner:** producer  
**Epic:** 6 | **Sprint:** 3 | **Estimate:** 0.5 day  
**Dependencies:** STORY-3.1–3.6 complete

**Description:** Verify all Sprint 3 acceptance criteria; update `active.md`, `epics.md`, `timeline.md`; final gate decision for m2 (Prototype Gate).

**Acceptance Criteria:**
- [ ] STORY-3.1: GUT installed, CI green, 80 tests via runner.
- [ ] STORY-3.2: `qa-plan.md` authored and reviewed.
- [ ] STORY-3.3: S8-VT 1-4 recorded, constants finalized.
- [ ] STORY-3.4: Keyboard match complete, contrast documented, gaps listed.
- [ ] STORY-3.5: Gate decision PROCEED (or recorded reason).
- [ ] STORY-3.6: Spike result + decision recorded.
- [ ] `production/epics.md` Epics 1, 5, 6 status updated.
- [ ] `production/timeline.md` m2 (Prototype Gate) status.
- [ ] Harness: 80+ checks pass.

**Files:**
- `production/session-state/active.md` (Sprint 3 summary, m2 gate)
- `production/epics.md` (Epic statuses)
- `production/timeline.md` (m2 complete)

**Verification:**
```
./codex-game-studio validate
./codex-game-studio docs-impact --base HEAD
godot --headless --path src -s res://scripts/verify_othello.gd
```

---

## Sprint 3 Summary

| Story | Owner | Est. | Depends On | Gate Evidence |
|-------|-------|------|------------|---------------|
| 3.1 GUT Test Runner | qa-playtester | 1d | — | CI green, JUnit XML |
| 3.2 QA Plan | qa-playtester | 0.5d | 3.1 | `qa-plan.md` |
| 3.3 S8 Visual Pass | qa-playtester | 0.5d | — | `s8-visual-pass.md` |
| 3.4 A11y Baseline | accessibility-specialist | 0.5d | — | `a11y-baseline.md` |
| 3.5 Prototype Gate Review | producer | 0.5d | 3.3, 3.4 | `active.md` decision |
| 3.6 Differentiation Spike | senior-designer | 2d | 3.5 PROCEED | `differentiation-hypothesis.md` + decision |
| 3.7 Sprint Review | producer | 0.5d | 3.1–3.6 | m2 gate |

**Total Estimate:** ~5.5 days (Week 5-6)

---

## Parallelization Plan

```
Week 5 (Days 1-3):
  ├── STORY-3.1 (GUT) ──► STORY-3.2 (QA Plan)
  ├── STORY-3.3 (S8 Visual) ◄── qa-playtester
  ├── STORY-3.4 (A11y) ◄───────── accessibility-specialist
  └── (parallel, independent)

Week 5-6 (Days 4-5):
  ├── STORY-3.5 (Gate Review) ◄── after 3.3, 3.4
  └── STORY-3.6 (Spike) ◄──────── after 3.5 PROCEED (senior-designer)

Week 6 (Day 6):
  └── STORY-3.7 (Sprint Review)
```

---

## Risks & Mitigations

| Risk | Story | Mitigation |
|------|-------|------------|
| GUT migration breaks harness | 3.1 | Keep `verify_othello.gd` as fallback; wrap incrementally |
| Contrast fails | 3.4 | Simple Theme override; defer full a11y to post-gate |
| Gate decision EXTEND | 3.5 | Document reasons; add 1-week buffer in timeline |
| Spike scope creep | 3.6 | Strict 2-day timebox; separate branch; no P0/P1 code touched |
| Manual playtest availability | 3.3, 3.4 | Schedule early Week 5; async evidence collection |

---

## Files to Create / Modify

| Story | New Files | Modified Files |
|-------|-----------|----------------|
| 3.1 | `addons/gut/`, `.github/workflows/ci.yml` | `src/scripts/verify_othello.gd` (wrap as GUT) |
| 3.2 | `production/qa-plan.md` | — |
| 3.3 | `production/playtest/s8-visual-pass-2026-10-19.md` (filled) | `src/scripts/othello.gd` (constants if adjusted) |
| 3.4 | `production/playtest/a11y-baseline-2026-10-19.md` (filled) | — |
| 3.5 | — | `production/session-state/active.md`, `production/epics.md` |
| 3.6 | `design/differentiation-hypothesis.md`, spike branch | `production/session-state/active.md` |
| 3.7 | — | `production/session-state/active.md`, `production/epics.md`, `production/timeline.md` |

---

## Verification Commands (Sprint 3 End)

```bash
# Full validation
./codex-game-studio refresh-context
./codex-game-studio validate                    # → 1216 PASS / 0 FAIL
./codex-game-studio docs-impact --base HEAD     # → PASS

# GUT test runner
godot --headless -s res://addons/gut/gut_cmdln.gd
# → 80 tests pass, JUnit XML

# Harness (legacy + new)
godot --headless --path src -s res://scripts/verify_othello.gd
# → 80+ checks, 0 failures

# Headless scene
godot --headless --path src --quit-after 90
# → exit 0

# Benchmark (Hard gate)
godot --headless --path src -s res://scripts/bench_hard_difficulty.gd
# → Hard median ≤ 500ms
```