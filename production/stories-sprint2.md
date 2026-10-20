# Sprint 2 Stories — Epics 6, 3, 2, 4 (Week 3-4)

**Project:** othello (Godot 4.7.2) | **Sprint:** 2 (Week 3-4 of 6-week gate) | **Baseline:** Sprint 1 automated work complete (88 checks, Hard gate PASS)

---

## Sprint Goal
Establish QA infrastructure (CI, test-runner, qa-plan), externalize all strings for localization, add core audio, and design persistence schema — all while keeping the verified P0/P1 loop green.

---

## Stories

### STORY-2.1: Godot Test Runner Setup (Epic 6)
**Owner:** qa-playtester / godot-specialist  
**Epic:** 6 | **Sprint:** 2 | **Estimate:** 1 day  
**Dependencies:** None

**Description:** Configure Godot's built-in `GUT` or `GDUnit4` test runner for in-editor and headless CI runs. The current harness (`verify_othello.gd`) is a custom `SceneTree` script; migrate or wrap it as a proper test suite.

**Acceptance Criteria:**
- [ ] Test runner installed (GUT preferred — lightweight, Godot-native).
- [ ] Existing 80 assertions run via test runner (headless: `godot --headless -s res://addons/gut/gut_cmdln.gd`).
- [ ] CI config (`.github/workflows/ci.yml` or equivalent) runs tests on push/PR.
- [ ] Test output is JUnit XML for CI parsing.
- [ ] `./codex-game-studio validate` still passes (1216 PASS).

**Files:**
- New: `addons/gut/` (submodule or copied), `.github/workflows/ci.yml`
- Ref: `src/scripts/verify_othello.gd` (wrap as GUT test class)

**Verification:**
```
godot --headless -s res://addons/gut/gut_cmdln.gd
→ 80 tests pass, JUnit XML produced
```

**Risks:**
- GUT runs in-editor; harness uses `SceneTree` — may need refactor to `Node` test class.

---

### STORY-2.2: QA Plan Document (Epic 6)
**Owner:** qa-playtester / producer  
**Epic:** 6 | **Sprint:** 2 | **Estimate:** 0.5 day  
**Dependencies:** STORY-2.1 (test runner informs regression scope)

**Description:** Author `production/qa-plan.md` covering: regression checklist, device matrix, playtest scenarios, bug triage SLA, release criteria.

**Acceptance Criteria:**
- [ ] Regression checklist: 80 harness assertions + 5 manual smoke tests.
- [ ] Device matrix: Linux (CI), Windows, macOS, Web export (if targeted).
- [ ] 5 playtest scenarios: first-time PvP, vs AI each difficulty, pass/skip, game-over, restart.
- [ ] Bug triage: severity definitions, owner assignment, SLA (P0: 24h, P1: 3d, P2: sprint).
- [ ] Release criteria: all harness green, 3 recorded playtests, no P0/P1 bugs.

**Files:**
- New: `production/qa-plan.md`

**Verification:**
- Document review by producer; `docs-impact` passes.

---

### STORY-2.3: Externalize All Strings (Epic 3)
**Owner:** narrative-designer / ui-programmer  
**Epic:** 3 | **Sprint:** 2 | **Estimate:** 1 day  
**Dependencies:** None (can run in parallel)

**Description:** Move all 20+ hardcoded English strings in `othello.gd` to Godot `TranslationServer` (CSV or `.translation` resource). Add runtime locale switch to settings bar.

**Acceptance Criteria:**
- [ ] `strings.csv` (or `translation.tscn`) with all UI text: labels, buttons, status messages, game-over text.
- [ ] `_build_ui` reads from `tr("key")` instead of literals.
- [ ] New "Language" `OptionButton` in settings bar (English only for now; infra for more).
- [ ] Runtime locale switch updates all labels without restart.
- [ ] Harness 80/0 (labels still render correctly via `tr()`).

**Files:**
- New: `translations/strings.csv`, `translations/en.translation` (or `.csv` import)
- Modified: `src/scripts/othello.gd` (`_build_ui`, `_update_ui_state`, `_advance_turn`, `_end_game`, `_on_cell_pressed`)

**Verification:**
```
godot --headless --path src -s res://scripts/verify_othello.gd
→ 88 checks pass (labels render via tr())
# Manual: switch Language dropdown → all text updates
```

**Risks:**
- `tr()` in `_ready`/`_build_ui` before `TranslationServer` loaded — ensure load order.
- Format strings (e.g., `"Turn: %s" % name`) need `%s` preserved in translation.

---

### STORY-2.4: Audio Import & Core Sounds (Epic 2)
**Owner:** sound-designer / ui-programmer  
**Epic:** 2 | **Sprint:** 2 | **Estimate:** 1.5 days  
**Dependencies:** STORY-1.2 (C9 cell refactor — named `disc` ref for VFX sync)

**Description:** Define audio import settings, add 5 core sounds, wire to events, add master volume slider.

**Acceptance Criteria:**
- [ ] Import settings: `.wav` (44.1kHz, 16-bit), `.ogg` for music; default bus layout.
- [ ] 5 sounds: `disc_place.wav`, `disc_flip.wav`, `invalid_move.wav`, `game_over_win.wav`, `game_over_lose.wav` (draw = win sound).
- [ ] `_execute_move` plays `disc_place` + `disc_flip` (per flipped line or batched).
- [ ] `_on_cell_pressed` invalid branch plays `invalid_move`.
- [ ] `_end_game` plays win/lose/draw sound.
- [ ] Master volume slider (0.0–1.0) in settings bar; persists in-session via `AudioServer.set_bus_volume_db`.
- [ ] No audio latency > 50ms on headless run (spot-check).

**Files:**
- New: `assets/audio/*.wav`, `assets/audio/*.ogg`
- Modified: `src/scripts/othello.gd` (`_build_ui` add volume slider, `_execute_move`, `_on_cell_pressed`, `_end_game`, `_new_game` reset volume)

**Verification:**
- Manual in-editor playtest: hear all 5 sounds at correct moments.
- Headless run: no audio errors (Godot headless uses dummy audio driver).
- Volume slider changes audible level.

**Risks:**
- Headless has no real audio — sounds won't play in CI (expected).
- Sync: flip sound per line vs. one batched sound — start simple (one per move).

---

### STORY-2.5: Persistence Schema & Save/Load (Epic 4)
**Owner:** gameplay-programmer / systems-designer  
**Epic:** 4 | **Sprint:** 2 | **Estimate:** 1.5 days  
**Dependencies:** STORY-2.3 (save JSON should be locale-agnostic)

**Description:** Design versioned JSON save schema; implement `_save_game()` / `_load_game()`; wire to `_new_game` (auto-save on quit) and future "Save/Load" UI.

**Acceptance Criteria:**
- [ ] Schema v1: `{version: 1, board: int[][], current_player: int, game_over: bool, game_mode: int, game_difficulty: int, black_score: int, white_score: int}`
- [ ] `_save_game(path)` writes to `user://othello_save_v1.json`.
- [ ] `_load_game(path)` restores board, turn, mode, difficulty, scores, game_over, hints.
- [ ] `_new_game` calls `_save_game` on quit (via `_notification` or `SceneTree.quit` signal).
- [ ] Cold boot → auto-load if save exists → match resumable.
- [ ] Corrupted/missing save → falls back to `_new_game()` cleanly.
- [ ] Schema version field enables future migration.

**Files:**
- Modified: `src/scripts/othello.gd` (add `_save_game`, `_load_game`, `_notification(WM_QUIT_REQUEST)`, `_ready` auto-load)

**Verification:**
```
# Manual: play halfway → quit → relaunch → match restored
# Manual: corrupt save file → launch → fresh game
# Harness: 88 checks still pass
```

**Risks:**
- Save during AI turn: ensure `game_over`/`current_player` consistent.
- Legal-move hints must re-apply on load (`_refresh_legal_hints`).

---

### STORY-2.6: Sprint 2 Review & Gate Check
**Owner:** producer  
**Epic:** 6 | **Sprint:** 2 | **Estimate:** 0.5 day  
**Dependencies:** STORY-2.1–2.5 complete

**Description:** Verify all Sprint 2 acceptance criteria met; update `active.md`, `epics.md`; decision on Epic 1 gate extension.

**Acceptance Criteria:**
- [ ] STORY-2.1: CI green, test runner executes 80 tests.
- [ ] STORY-2.2: `qa-plan.md` authored and reviewed.
- [ ] STORY-2.3: Strings externalized, locale switch works.
- [ ] STORY-2.4: 5 sounds play, volume slider works.
- [ ] STORY-2.5: Save/load round-trip works.
- [ ] Harness: 80+ checks pass (new assertions for save/load, locale).
- [ ] Gate decision: PROCEED to Sprint 3 (Epic 5 differentiation spike) or EXTEND.

**Files:**
- `production/session-state/active.md` (Sprint 2 summary)
- `production/epics.md` (Epic 6, 3, 2, 4 status → Done/In Progress)

**Verification:**
```
./codex-game-studio validate
./codex-game-studio docs-impact --base HEAD
godot --headless --path src -s res://scripts/verify_othello.gd
```

---

## Sprint 2 Summary

| Story | Owner | Est. | Depends On | Gate Evidence |
|-------|-------|------|------------|---------------|
| 2.1 Test Runner Setup | qa-playtester | 1d | — | CI green, JUnit XML |
| 2.2 QA Plan | qa-playtester | 0.5d | 2.1 | `qa-plan.md` |
| 2.3 Externalize Strings | narrative/ui | 1d | — | `strings.csv`, locale switch |
| 2.4 Core Audio | sound/ui | 1.5d | 1.2 (C9) | 5 sounds + volume slider |
| 2.5 Save/Load Schema | gameplay/systems | 1.5d | 2.3 | Save/load round-trip |
| 2.6 Sprint Review | producer | 0.5d | 2.1–2.5 | Gate decision |

**Total Estimate:** ~6 days (parallelizable: 2.1/2.3/2.4/2.5 can run concurrently)

---

## Parallelization Plan

```
Week 3 (Days 1-3):
  ├── STORY-2.1 (Test Runner) ──► STORY-2.2 (QA Plan)
  ├── STORY-2.3 (Strings) ◄─────── independent
  ├── STORY-2.4 (Audio) ◄───────── needs C9 done (✅)
  └── STORY-2.5 (Save Schema) ◄── needs strings schema (2.3)

Week 4 (Days 4-5):
  ├── STORY-2.2 (QA Plan) after 2.1
  ├── STORY-2.4/2.5 completion
  └── STORY-2.6 (Review)
```

---

## Risks & Mitigations

| Risk | Story | Mitigation |
|------|-------|------------|
| GUT migration breaks harness | 2.1 | Keep `verify_othello.gd` as fallback; wrap incrementally |
| `tr()` in `_build_ui` before translations loaded | 2.3 | Preload translations in `_ready` before `_build_ui` |
| Audio not testable headless | 2.4 | Accept manual-only verification; CI skips audio |
| Save schema migration complexity | 2.5 | Version field from v1; write migration stub now |
| Sprint 1 playtests (1.3/1.4) not done | — | Note as carryover; don't block Sprint 2 |

---

## Files to Create / Modify

| Story | New Files | Modified Files |
|-------|-----------|----------------|
| 2.1 | `addons/gut/`, `.github/workflows/ci.yml` | `src/scripts/verify_othello.gd` (wrap) |
| 2.2 | `production/qa-plan.md` | — |
| 2.3 | `translations/strings.csv` | `src/scripts/othello.gd` (all UI text → `tr()`) |
| 2.4 | `assets/audio/*.wav`, `assets/audio/*.ogg` | `src/scripts/othello.gd` (audio calls, volume slider) |
| 2.5 | — | `src/scripts/othello.gd` (`_save_game`, `_load_game`, `_notification`) |
| 2.6 | — | `production/session-state/active.md`, `production/epics.md` |

---

## Verification Commands (Sprint 2 End)

```bash
# Full validation
./codex-game-studio refresh-context
./codex-game-studio validate                    # → 1216 PASS / 0 FAIL
./codex-game-studio docs-impact --base HEAD     # → PASS

# Test runner (GUT)
godot --headless -s res://addons/gut/gut_cmdln.gd
# → 80+ tests pass, JUnit XML

# Harness (legacy + new)
godot --headless --path src -s res://scripts/verify_othello.gd
# → 80+ checks, 0 failures

# Headless scene
godot --headless --path src --quit-after 90
# → exit 0
```