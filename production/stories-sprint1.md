# Sprint 1 Stories — Epic 1: Prototype Gate Polish & Hardening

**Project:** othello (Godot 4.7.2) | **Sprint:** 1 (Week 1-2 of 6-week gate) | **Baseline:** Vertical slice PROCEED (88 checks)

---

## Sprint Goal
Deliver a hardened, measured prototype that passes the prototype gate: Hard difficulty ≤ 500ms, feedback cadence validated in-tree, cell coupling removed, baseline accessibility met.

---

## Stories

### STORY-1.1: Hard-Difficulty Timing Benchmark
**Owner:** ai-programmer  
**Epic:** 1 | **Sprint:** 1 | **Estimate:** 1 day  
**Dependencies:** None (starts from current vertical slice)

**Description:** Measure depth-5 minimax search time across representative mid-game positions on reference hardware (CI runner + local). Record min/median/max/p95. If median > 500ms, implement a time-budgeted search (iterative deepening with early exit) as a follow-up story.

**Acceptance Criteria:**
- [ ] Benchmark script runs 50 searches on 10 fixed mid-game boards (depth 5, EASY/MEDIUM/HARD all measured).
- [ ] Output: JSON with `depth`, `board_hash`, `time_ms`, `nodes_visited` per run.
- [ ] Summary printed: median/p95/max per difficulty.
- [ ] If depth-5 median > 500ms, story spawns STORY-1.1b (time-budgeted search).

**Files:**
- New: `scripts/bench_hard_difficulty.gd` (headless benchmark script)
- Ref: `src/scripts/othello.gd` (`_get_best_move`, `_minimax`, `_match_difficulty`)

**Verification:**
```
godot --headless --path src -s res://scripts/bench_hard_difficulty.gd
→ prints median/p95/max for each difficulty; exit 0
```

**Risks:**
- Search time variance high (move ordering, alpha-beta cutoffs).
- CI runner slower than local → use relative budget (e.g., "≤ 2× MEDIUM median").

---

### STORY-1.2: Cell Children Refactor (C9 Fix)
**Owner:** ui-programmer  
**Epic:** 1 | **Sprint:** 1 | **Estimate:** 1 day  
**Dependencies:** None

**Description:** Replace positional `get_child(0/1)` access in `_refresh_board_visuals` and `_refresh_legal_hints` with named references stored on the cell Button (or a per-cell dict). This unblocks Epic 2 (Audio/VFX hooks on cells).

**Acceptance Criteria:**
- [ ] Each cell Button has `bg: ColorRect` and `disc: TextureRect` as named members (via `set_meta` or a parallel `cell_data` array).
- [ ] `_refresh_board_visuals` and `_refresh_legal_hints` use named access, no `get_child(0/1)`.
- [ ] Harness S6-AT-1..10 still pass (88 checks total).
- [ ] No visual regression in headless scene.

**Files:**
- `src/scripts/othello.gd` (`_build_ui`, `_refresh_board_visuals`, `_refresh_legal_hints`, `cells` array structure)

**Verification:**
```
godot --headless --path src -s res://scripts/verify_othello.gd
→ 88 checks, 0 failures
godot --headless --path src --quit-after 90
→ exit 0
```

**Risks:**
- Must not change cell composition (bg + disc only) — if more children added later, named refs still work.
- Meta access is slightly slower than `get_child` but negligible for 64 cells.

---

### STORY-1.3: S8 Visual Feedback Pass (In-Tree)
**Owner:** qa-playtester  
**Epic:** 1 | **Sprint:** 1 | **Estimate:** 1 day  
**Dependencies:** None (can run in parallel with 1.1/1.2)

**Description:** Run the 4 visual verification items (S8-VT-1..4) in a real Godot editor session (not headless) and record pass/fail + subjective feel notes. Adjust the three delay constants if needed.

**Acceptance Criteria:**
- [ ] S8-VT-1: "Invalid Move!" visible for ~0.5s after clicking occupied/illegal cell.
- [ ] S8-VT-2: "Computer is thinking..." visible for ~0.8s on AI turn (all 3 difficulties).
- [ ] S8-VT-3: "<Name> has no legal moves! Skipping..." visible for ~1.0s on pass.
- [ ] S8-VT-4: Legal-move highlights appear on human turn, clear on AI turn and game over.
- [ ] If any timing feels off, update `INVALID_MOVE_DELAY`, `THINKING_DELAY`, `PASS_DELAY` in `othello.gd` and re-verify.

**Files:**
- `src/scripts/othello.gd` (delay constants)
- Evidence: `production/playtest/s8-visual-pass-2026-10-19.md` (notes + screenshots optional)

**Verification:**
- Manual in-editor playtest (not automatable).
- Record: `./codex-game-studio docs-impact --base HEAD` passes after any constant changes.

**Risks:**
- Subjective; "feels right" varies by player. Use "readable without waiting" as heuristic.

---

### STORY-1.4: Baseline Accessibility Pass (S14)
**Owner:** accessibility-specialist  
**Epic:** 1 | **Sprint:** 1 | **Estimate:** 1 day  
**Dependencies:** STORY-1.2 (cell refactor makes focus order testable)

**Description:** Verify keyboard-only playthrough of one complete match (vs AI, Easy). Check contrast ratios for cell backgrounds, text labels, and highlight color. Document gaps for post-gate remediation.

**Acceptance Criteria:**
- [ ] Keyboard-only: Tab/Enter navigates mode → difficulty → board cells → restart; full match completable.
- [ ] Focus order logical (left-to-right, top-to-bottom on board).
- [ ] Contrast: `CELL_COLOR` vs `CELL_HINT_COLOR` ≥ 3:1 (UI non-text); label text vs background ≥ 4.5:1.
- [ ] Colorblind check: highlights distinguishable in protanopia/deuteranopia simulator.
- [ ] Reduced motion: no animations to disable yet (N/A, but noted).

**Files:**
- `src/scripts/othello.gd` (`CELL_COLOR`, `CELL_HINT_COLOR`, UI labels)
- Evidence: `production/playtest/a11y-baseline-2026-10-19.md`

**Verification:**
- Manual playtest + contrast tool (e.g., Godot theme preview or external checker).
- No code changes required unless contrast fails (then adjust constants).

**Risks:**
- Default Godot theme may not meet 4.5:1 for Label text on dark green.
- If contrast fails, a simple Theme resource is the fix (post-gate scope).

---

### STORY-1.5: Restart Behavior Assertion (S9 Gap)
**Owner:** gameplay-programmer  
**Epic:** 1 | **Sprint:** 1 | **Estimate:** 0.5 day  
**Dependencies:** None

**Description:** Add a harness assertion for the restart path (already manually tested in S6-AT-9) to close the S9 residual gap. Assert board, turn, game-over, hints, and labels all reset.

**Acceptance Criteria:**
- [ ] New test `_test_restart_assertion` in `verify_othello.gd`.
- [ ] Asserts: board = 4 discs, current_player = BLACK, game_over = false, hints cleared, labels = "Black: 2", "White: 2", "Turn: Black".
- [ ] Harness still 72+ checks, 0 failures.

**Files:**
- `src/scripts/verify_othello.gd` (add `_test_restart_assertion`, call in `_init`)

**Verification:**
```
godot --headless --path src -s res://scripts/verify_othello.gd
→ 73 checks, 0 failures
```

**Risks:**
- Low; restart is already tested manually in S6-AT-9.

---

### STORY-1.6: Prototype Gate Checklist Review
**Owner:** producer  
**Epic:** 1 | **Sprint:** 1 | **Estimate:** 0.5 day  
**Dependencies:** STORY-1.1, 1.2, 1.3, 1.4, 1.5 complete

**Description:** Run the gate checklist: all Epic 1 acceptance criteria met, evidence recorded, no blocking defects. Decision: PROCEED to Epics 2/3/4 / EXTEND sprint / PIVOT.

**Acceptance Criteria:**
- [ ] STORY-1.1: Hard median ≤ 500ms (or time-budgeted search story created).
- [ ] STORY-1.2: Cell refactor merged, harness green.
- [ ] STORY-1.3: S8-VT 1-4 recorded, constants adjusted if needed.
- [ ] STORY-1.4: Keyboard match complete, contrast documented, gaps listed.
- [ ] STORY-1.5: Restart assertion in harness.
- [ ] Gate decision recorded in `production/session-state/active.md`.

**Files:**
- `production/session-state/active.md` (gate decision entry)
- `production/epics.md` (Epic 1 status → Done)

**Verification:**
```
./codex-game-studio validate
./codex-game-studio docs-impact --base HEAD
godot --headless --path src -s res://scripts/verify_othello.gd
```

---

## Sprint 1 Summary

| Story | Owner | Est. | Depends On | Gate Evidence |
|-------|-------|------|------------|---------------|
| 1.1 Hard Benchmark | ai-programmer | 1d | — | `bench_hard_difficulty.gd` JSON output |
| 1.2 Cell Refactor (C9) | ui-programmer | 1d | — | Harness 72/0 |
| 1.3 S8 Visual Pass | qa-playtester | 1d | — | `s8-visual-pass.md` |
| 1.4 A11y Baseline | accessibility-specialist | 1d | 1.2 | `a11y-baseline.md` |
| 1.5 Restart Assertion | gameplay-programmer | 0.5d | — | Harness 73/0 |
| 1.6 Gate Review | producer | 0.5d | 1.1–1.5 | `active.md` decision |

**Total Estimate:** ~5 days (1 week with parallelization)

---

## Risks & Mitigations

| Risk | Story | Mitigation |
|------|-------|------------|
| Hard median > 500ms | 1.1 | Spawn STORY-1.1b (iterative deepening + time budget) |
| Refactor breaks visuals | 1.2 | Run harness immediately after; manual spot-check |
| Contrast fails | 1.4 | Simple Theme override; defer full a11y to post-gate |
| S8 timings feel wrong | 1.3 | Adjust constants; re-run visual pass same day |

---

## Next Sprint (Sprint 2, Week 3-4)
- **Epic 6 (QA Infra):** `test-setup` workflow, CI harness, `qa-plan` authored.
- **Epic 3 (Localization):** Externalize strings, add CSV translation, runtime switch.
- **Epic 2 (Audio):** Define import settings, add 5 sounds, volume slider (needs 1.2 done).
- Begin **Epic 4 (Persistence)** schema design.

---

## Files to Create / Modify

| Story | New Files | Modified Files |
|-------|-----------|----------------|
| 1.1 | `scripts/bench_hard_difficulty.gd` | — |
| 1.2 | — | `src/scripts/othello.gd` |
| 1.3 | `production/playtest/s8-visual-pass-*.md` | `src/scripts/othello.gd` (constants) |
| 1.4 | `production/playtest/a11y-baseline-*.md` | — |
| 1.5 | — | `src/scripts/verify_othello.gd` |
| 1.6 | — | `production/session-state/active.md`, `production/epics.md` |

---

## Verification Commands (Sprint 1 End)

```bash
# Full validation
./codex-game-studio refresh-context
./codex-game-studio validate                    # → 1216 PASS / 0 FAIL
./codex-game-studio docs-impact --base HEAD     # → PASS

# Harness (now 73+ checks)
godot --headless --path src -s res://scripts/verify_othello.gd
# → 73 checks, 0 failures

# Benchmark
godot --headless --path src -s res://scripts/bench_hard_difficulty.gd
# → JSON with median/p95/max per difficulty

# Headless scene
godot --headless --path src --quit-after 90
# → exit 0
```