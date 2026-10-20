# Othello System GDD: Feedback & Game Feel (S8)

# Purpose

Define the player-facing feedback messages, timing, visual/audio feel, and acceptance tests for **S8 Feedback & Game Feel** — every transient message, pause, and visual cue the prototype presents. S8 is P1: it does not block a playable loop, but without explicit timings and clear text the prototype feels broken. Authoring it closes the S8 spec gap and promotes the currently scattered placeholder timings into named, testable values.

# Summary

Othello's feedback is delivered through a single centered `status_label` and cell-background highlights. The messages are:
- "Your turn!" — the human's turn prompt.
- "Computer is thinking..." — shown while the AI "thinks" (paused).
- "<Name> has no legal moves! Skipping..." — shown when a side is passed.
- "Invalid Move!" — shown when the human clicks an occupied or illegal cell.
- "Game Over: <Winner/Draw>! (N-N)" — shown when the match ends.

Each transient message is displayed for a placeholder duration (0.5s / 0.8s / 1.0s) implemented via `await get_tree().create_timer(...).timeout` gated by `is_inside_tree()`. Because the timers are skipped out-of-tree, the messages are not observable after the handler returns in the harness — they must be verified visually or with an in-tree test.

**Scope:** S8 only. S3 owns the pass logic and triggers the skip notice; S4 owns the game-over text; S5 triggers the "thinking" state; S6 owns the legal-move highlight and invalid-click feedback; S14 owns accessibility of the messages. This document formalizes the shipped feedback in `src/scripts/othello.gd`.

# Source Evidence

- `design/systems-index.md` — S8 entry, P1, depends on S6.
- `design/gdd.md` — pillar "Readable board" (approved B1) and "Instant local play".
- `design/systems/turn-pass.md` — R-S3-9 (feedback timing placeholders).
- `design/systems/ui-shell.md` — R-S6-7 (invalid-move feedback), R-S6-8 (legal-move highlight).
- `src/scripts/othello.gd` — `status_label`, `CELL_HINT_COLOR`, `_on_cell_pressed` (0.5s), `_advance_turn` (1.0s pass, 0.8s thinking), `_end_game`, `_update_ui_state`, `_refresh_legal_hints`.
- `src/scripts/verify_othello.gd` — S8 assertions (transient-text preconditions and postconditions; S8-AT-1..6).
- Godot `4.7.2.stable.official.ed1daf0bf`, `--headless --path src`.

# Data Model

| Field / Constant | Source | Value | Role |
|------------------|--------|-------|------|
| INVALID_MOVE_DELAY | `othello.gd` | `0.5` | Seconds "Invalid Move!" is shown |
| THINKING_DELAY | `othello.gd` | `0.8` | Seconds "Computer is thinking..." is shown |
| PASS_DELAY | `othello.gd` | `1.0` | Seconds the skip notice is shown |
| status_label | `othello.gd` | `Label` | Single message line |
| CELL_COLOR / CELL_HINT_COLOR | `othello.gd` | `Color(0.1,0.4,0.1)` / `Color(0.18,0.52,0.18)` | Base vs. legal-move cell background |
| Messages | `_on_cell_pressed` / `_advance_turn` / `_end_game` / `_update_ui_state` | See Feedback table | Transient + persistent text |

**Invariants**

- Only one message is visible at a time in `status_label`.
- A transient message is always followed by `_update_ui_state()` (or game over) which overwrites it.
- The human turn always shows "Your turn!" unless an invalid-move flash is active.
- The AI turn always shows "Computer is thinking..." unless a skip notice is active.
- Game-over text persists until restart.

# System Rules — S8 Feedback & Game Feel

- **R-S8-1 Single message channel:** all turn/state/invalid/skip/end text flows through `status_label` (no toasts, no popups).
- **R-S8-2 Human turn prompt:** when `not game_over` and the active side is the human, `status_label` reads "Your turn!".
- **R-S8-3 AI thinking notice:** when `game_mode == PLAYER_VS_AI` and `current_player == WHITE`, `status_label` reads "Computer is thinking..." for `THINKING_DELAY` (`0.8s`).
- **R-S8-4 Skip notice:** when a side has no legal move, `status_label` reads "<Name> has no legal moves! Skipping..." for `PASS_DELAY` (`1.0s`), where Name uses R-S7-8 (color names in PvP, "Computer" for White in vs-AI).
- **R-S8-5 Invalid-move flash:** a click on an occupied or illegal empty cell shows "Invalid Move!" for `INVALID_MOVE_DELAY` (`0.5s`), then restores the correct turn prompt.
- **R-S8-6 Game-over text:** when `game_over` is true, `status_label` reads "Game Over: <Winner/Draw>! (<black>-<white>)" and is not replaced.
- **R-S8-7 Highlights track the human:** legal-move cell highlights (`CELL_HINT_COLOR`) are shown only during the human's turn; cleared during AI turn and when `game_over` (R-S6-8).
- **R-S8-8 In-tree gating:** all pauses execute only if `is_inside_tree()`; out-of-tree runs (harness, headless boot) skip the delay without changing the turn outcome.
- **R-S8-9 Transience is not observable after return:** because `_update_ui_state()` overwrites the message immediately after the timer, the harness cannot assert the on-screen text after the handler returns; it asserts preconditions and final state instead.

# Feedback

| State | Message / Visual | Duration | Source |
|-------|------------------|----------|--------|
| Human turn, idle | "Your turn!" | persistent | `_update_ui_state` |
| AI turn | "Computer is thinking..." | `0.8s` | `_advance_turn` |
| Side skipped | "<Name> has no legal moves! Skipping..." | `1.0s` | `_advance_turn` |
| Invalid click | "Invalid Move!" | `0.5s` | `_on_cell_pressed` |
| Game over | "Game Over: <Winner/Draw>! (N-N)" | persistent | `_end_game` |
| Human turn, legal move available | cell backgrounds = `CELL_HINT_COLOR` | persistent | `_refresh_legal_hints` |

# Balance Levers

Values in `src/scripts/othello.gd`:

- **INVALID_MOVE_DELAY** = `0.5` seconds.
- **THINKING_DELAY** = `0.8` seconds.
- **PASS_DELAY** = `1.0` seconds.
- **CELL_HINT_COLOR** = `Color(0.95, 0.78, 0.25)` (gold; 3.78:1 vs base `CELL_COLOR = Color(0.16, 0.44, 0.16)`, WCAG AA non-text contrast and colorblind-distinct).

These are **not approved values**. Any change needs a playtest note and an updated validation case.

# Edge Cases

1. **AI blocked:** if White has no legal move in `PLAYER_VS_AI`, the skip notice names "Computer" (R-S7-8) and the turn returns to Black.
2. **Skip then AI:** after a human skip, if the AI's turn comes and it has moves, the "thinking" notice appears; if it also has none, a double skip ends the match without a second notice (R-S3-4).
3. **Invalid click during AI turn or game over:** ignored by R-S6-11; no message.
4. **Rapid clicks:** the handler returns immediately on invalid input; a second click before the timer fires restarts the 0.5s flash (current behavior, unasserted).
5. **No audio/VFX:** the prototype has no disc-place sound, flip animation, or win/lose fanfare (S12 deferred).
6. **No reduced-motion option:** the timers always fire (S14).

# Acceptance Tests

Method: **HARNESS** = asserted in `src/scripts/verify_othello.gd` against Godot 4.7.2; the run exits non-zero on failure. Because all feedback is transient and out-of-tree timers are skipped, the harness asserts *preconditions* and *post-state* rather than the on-screen text itself. Visual/in-tree verification is required for the actual message cadence.

| ID | Given | When | Then | Method |
|----|-------|------|------|--------|
| S8-AT-1 | New game, PvP | `_update_ui_state` | `status_label` = "Your turn!" | HARNESS |
| S8-AT-2 | PvP, human skips (constructed board) | `_advance_turn` | after: turn returned to human; `game_over` false | HARNESS |
| S8-AT-3 | vs-AI, human moves, AI's turn | `_advance_turn` | after: AI move executed; turn returned to human | HARNESS |
| S8-AT-4 | New game, PvP | click occupied cell | board unchanged; turn unchanged | HARNESS |
| S8-AT-5 | New game, PvP | click illegal empty cell | board unchanged; turn unchanged | HARNESS |
| S8-AT-6 | Game over | `_end_game` | `status_label` starts with "Game Over:" and contains the final score | HARNESS |

**Visual / In-Tree Only (not in harness):**
- S8-VT-1: "Invalid Move!" is visible for ~0.5s after an invalid click.
- S8-VT-2: "Computer is thinking..." is visible for ~0.8s on the AI turn.
- S8-VT-3: "<Name> has no legal moves! Skipping..." is visible for ~1.0s on a pass.
- S8-VT-4: Highlights appear on human turn and clear on AI turn / game over.

# Open Questions / Unverified Assumptions

- **Unverified:** the actual in-tree cadence of all three transient messages (no playtest recorded).
- **Unverified:** whether 0.5s / 0.8s / 1.0s feel right — too short to read, or too long and sluggish?
- **Unverified:** colorblind legibility of `CELL_HINT_COLOR` vs `CELL_COLOR` (S14).
- **Unverified:** "Your turn!" vs "Computer is thinking..." clarity for first-time players.
- **Assumption:** a single `status_label` is sufficient; no parallel channels needed.
- **Assumption:** no audio/VFX is acceptable for the prototype (S12 deferred).

# Risks

- **Cadence unverified (medium):** the three placeholder timings have never been playtested; they may feel too fast, too slow, or inconsistent.
- **Transient text untested in harness (low):** by design the harness cannot assert the on-screen message after the handler returns; a regression in message text would not be caught without a visual check.
- **AI-turn UX (low/medium):** "Computer is thinking..." shows even when the AI returns instantly (depth 1), which can look like a stutter.
- **Accessibility (medium):** no screen-reader support, no contrast guarantee, no reduced-motion path (S14).
- **No feedback variety (low):** repeated messages and no disc-place/flip animation make the game feel flat.

# Changed Files

- `design/systems/feedback.md` — this system GDD (new).
- `design/gdd.md` — per-system table links this document.
- `design/systems-index.md` — S8 row, validation, S9 coverage updated.
- `src/scripts/verify_othello.gd` — S8-AT-1..6 assertions added (`_test_feedback`).

# Verification Evidence

- `godot --headless --path src -s res://scripts/verify_othello.gd` → 88 checks, 0 failures, exit 0 (includes S8-AT-1..6).
- `godot --headless --path src --quit-after 90` → exit 0, no script errors.
- `./codex-game-studio validate` → 1216 PASS / 0 FAIL.

# Next Owner / Decision

- **Decision requested:** approve R-S8-1..R-S8-9 and the three delay constants as the feedback contract (subject to playtest adjustment).
- **Next design owner:** qa-playtester for an in-tree visual feedback pass (S8-VT-1..4).
- **Verification owner:** qa-playtester measures Hard-difficulty search time and validates timing feel.
- **Follow-up:** S14 owns accessibility adjustments; S12 owns audio/VFX when scheduled.