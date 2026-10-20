# Othello System GDD: Turn, Pass & Turn Ownership (S3)

# Purpose

Define the player-facing rules, state contract, feedback, edge cases, and acceptance tests for **S3 Turn & Pass Handling** — how the active player is chosen, how a player with no legal move is skipped, and how a double skip ends the match. S3 is P0 and is the trigger for S4 end detection, so it must be exact and testable. Authoring it closes the S3 spec gap raised by `design/reviews/review-all-gdds.md`.

# Summary

Othello alternates turns between Black and White. A player who cannot move is skipped once (a "pass"); if both players cannot move, the game ends. This document formalizes the shipped behavior in `src/scripts/othello.gd` (`_advance_turn`, `_has_any_legal_moves`, `_on_cell_pressed`) and converts it into explicit acceptance tests. When the turn reaches the AI (White) in `PLAYER_VS_AI`, the AI resolves exactly one move and the turn advances automatically.

**Scope:** S3 only. S2 supplies the legality predicate S3 consumes; S4 owns the end/winner decision S3 triggers; S5 owns AI move selection; S6 renders the turn/status labels; S7 owns mode/difficulty and display names (R-S7-8); S8 owns final feedback timing.

# Source Evidence

- `design/systems-index.md` — S3 entry, P0, dependency order (depends on S2).
- `design/systems/core-rules.md` — R-S4-2/R-S4-3 (pass and end conditions S3 triggers).
- `design/systems/difficulty-mode.md` — R-S7-6/R-S7-8 (AI side; mode-aware display names).
- `src/scripts/othello.gd` — `current_player`, `_advance_turn`, `_has_any_legal_moves`, `_on_cell_pressed`, `_ai_move`, `_display_name`.
- `src/scripts/verify_othello.gd` — S3 assertions (`_test_turn_flow`).
- Godot `4.7.2.stable.official.ed1daf0bf`, `--headless --path src`.

# Data Model

| Field | Source | Type / values | Notes |
|-------|--------|---------------|-------|
| current_player | `othello.gd` | `BLACK` or `WHITE` | The side to move; starts `BLACK` |
| game_over | `othello.gd` | `bool` | Set by S4 `_end_game`; gates input and further turns |
| game_mode | `othello.gd` | `Mode` | Decides whether White is an AI (R-S7-6) |

**Invariants**

- `current_player` is always `BLACK` or `WHITE`.
- A pass never changes `board`; only `current_player` and feedback change.
- A single pass never ends the match; only a double pass (both sides blocked) does.
- Input is never accepted while `game_over` is true or `current_player == AI_PLAYER`.

# System Rules — S3 Turn, Pass & Turn Ownership

- **R-S3-1 First move:** at new game `current_player = BLACK`; Black always moves first.
- **R-S3-2 Alternation:** after a resolved legal move the turn passes to the opponent via `_advance_turn`.
- **R-S3-3 Skip:** if the side to move has no legal move, its turn is skipped once and the turn returns to the opponent, with a visible notice naming the skipped side. No disc is placed.
- **R-S3-4 Double skip ends the match:** if, after skipping one side, the other side also has no legal move, the match ends (`_end_game`), even if empty cells remain.
- **R-S3-5 Pass is state-neutral:** a pass changes only `current_player` and the status label; `board` and scores are untouched.
- **R-S3-6 AI turn:** in `PLAYER_VS_AI`, when the turn reaches `AI_PLAYER` (White), the AI resolves exactly one move and the turn advances; the human cannot act during the AI turn.
- **R-S3-7 Input gating:** `_on_cell_pressed` ignores input when `game_over` is true or `current_player == AI_PLAYER`.
- **R-S3-8 One pass at a time:** the skip check happens once per turn advance; a player who is skipped is not skipped again until the turn returns to them.
- **R-S3-9 Feedback timing:** the skip notice shows for ~`1.0s` and the AI "thinking" notice for ~`0.8s` (placeholders; S8 owns final values).
- **R-S3-10 Implementation mapping:** `_advance_turn` implements R-S3-2..R-S3-6; `_has_any_legal_moves` (S2) backs R-S3-3/R-S3-4; `_on_cell_pressed` implements R-S3-7.

# Feedback

| State | Player-facing signal | Source |
|-------|----------------------|--------|
| Normal turn | `turn_label` = "Turn: <name>"; `status_label` = "Your turn!" | `_update_ui_state` |
| Side skipped | `status_label` = "<name> has no legal moves! Skipping..." for ~1.0s | `_advance_turn` |
| AI turn | `status_label` = "Computer is thinking..." for ~0.8s | `_advance_turn` / `_update_ui_state` |
| Match ended | `status_label` = "Game Over: <Winner/Draw>! (<black>-<white>)" | `_end_game` |

Display names follow R-S7-8: White is "Computer" only in `PLAYER_VS_AI`.

**Transience:** the skip and "thinking" notices are set during `_advance_turn` and shown for the pause duration; `_update_ui_state()` then overwrites `status_label` with the next turn's message. Out-of-tree calls skip the pause, so the notice is overwritten immediately — it is observable on screen (in-tree) but not after `_advance_turn` returns. S3-AT-3 therefore asserts the skip *precondition* and the resulting turn, not the transient text.

# Balance Levers

S3 is **rule-exact**; it has no balance values. The only tunables adjacent to it are feedback timings (skip `1.0s`, AI thinking `0.8s`), which are placeholders owned by S8 and not approved values.

# Edge Cases

1. **Single skip returns the turn** to the player who just moved (they move again).
2. **Double skip ends the match** even with empty cells (do not require a full board).
3. **A pass must not consume a placement** or change any disc/score.
4. **Skipped-side naming** must be mode-aware (R-S7-8): never "Computer" in local PvP.
5. **AI with no legal move** is itself skipped; the turn returns to the human.
6. **Timer awaits only run in-tree:** `_advance_turn` awaits `create_timer` only when `is_inside_tree()`; out-of-tree runs (harness, headless boot) skip the pause without changing turn outcome.
7. **Input during AI turn or after game over** is ignored (R-S3-7).

# Acceptance Tests

Method: **HARNESS** = asserted in `src/scripts/verify_othello.gd` against Godot 4.7.2; the run exits non-zero on failure.

| ID | Given | When | Then | Method |
|----|-------|------|------|--------|
| S3-AT-1 | New game | read `current_player` | `BLACK` | HARNESS |
| S3-AT-2 | New game, PvP | Black plays a legal move, then `_advance_turn` | `current_player == WHITE` | HARNESS |
| S3-AT-3 | All Black, `(0,1)` White, `(0,0)` empty (White has no move, Black has one) | `_advance_turn` from Black | White is blocked and Black has a move (precondition); turn returns to Black; board unchanged | HARNESS |
| S3-AT-4 | Neither side has a legal move | `_advance_turn` | `game_over == true` (double skip ends match) | HARNESS (mirrors AT-10) |
| S3-AT-5 | Single-skip board | compare `board` before/after `_advance_turn` | identical (pass is state-neutral) | HARNESS |
| S3-AT-6 | `PLAYER_VS_AI`, `current_player == WHITE` | `_on_cell_pressed` on a legal Black cell | board unchanged; `current_player` stays White | HARNESS |
| S3-AT-7 | `PLAYER_VS_AI`, after Black's move | `_advance_turn` | AI resolves one White move; `current_player` returns to Black | HARNESS |

# Open Questions / Unverified Assumptions

- **Unverified:** the in-tree pause/feedback cadence (S3-AT uses the out-of-tree path, so `await` is skipped); no playtest has judged whether the skip notice is clear or long enough.
- **Unverified:** the skip-notice text itself (it is transient and overwritten before `_advance_turn` returns); confirming it needs an in-tree/visual check or a dedicated signal.
- **Unverified:** the AI-skip path (AI has no legal move) has no dedicated assertion.
- **Assumption:** standard Othello turn order; no variant.
- **Assumption:** feedback timings are placeholders.

# Risks

- **Async path unverified (medium):** the harness runs out-of-tree, so the timer-driven experience (`await` 1.0s/0.8s) is not exercised; a regression in timing or in-tree behavior would not be caught.
- **AI-skip untested (low/medium):** R-S3-6 assumes the AI handles a blocked turn; only the human-skip path is asserted.
- **Coupling (low):** S3 calls `_end_game` (S4) and `_ai_move` (S5); changes there can affect turn flow, so these boundaries must stay named.
- **Input gating boundary (low):** the terminal lock (game over) is enforced in the input handler (review C5), which S3 depends on.

# Changed Files

- `design/systems/turn-pass.md` — this system GDD (new).
- `design/gdd.md` — per-system table links this document.
- `design/systems-index.md` — S3 row and validation reference updated.
- `src/scripts/verify_othello.gd` — S3-AT-1..7 assertions added.

# Verification Evidence

- `godot --headless --path src -s res://scripts/verify_othello.gd` → 88 checks, 0 failures, exit 0 (includes S3-AT-1..7).
- `godot --headless --path src --quit-after 90` → exit 0.
- `./codex-game-studio validate` → 1216 PASS / 0 FAIL.

# Next Owner / Decision

- **Decision requested:** approve R-S3-1..R-S3-10 as the frozen turn/pass contract.
- **Next design owner:** senior-game-designer for the S5 AI spec next.
- **Verification owner:** qa-playtester adds an in-tree (timed) turn-flow check and an AI-skip case.
- **Follow-up:** S8 owns final feedback timings and clarity.
