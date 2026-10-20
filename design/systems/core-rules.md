# Othello System GDD: Move Legality, Capture, and Scoring

# Purpose

Define the player-facing rules, data contract, feedback, edge cases, and acceptance tests for the two rule-critical systems in the Othello prototype: **S2 Move Legality & Capture** and **S4 Scoring & End Conditions** (see `design/systems-index.md`). These rules are the contract every other system depends on, so they must be exact, inspectable, and testable before implementation work is scheduled.

# Summary

Othello is a two-player disc-flipping game on an 8x8 board. A move is legal only if it flips at least one opponent disc, and a single placement may flip discs along several directions at once. The match ends when neither player can move, and the player with more discs wins. The shipped implementation already exercises these rules in `src/scripts/othello.gd`; this document formalizes them and turns the implementation into explicit acceptance tests. Opening-move and legality values were confirmed by running the shipped code in Godot 4.7.2, and all acceptance cases (AT-1..AT-14) are now asserted by `src/scripts/verify_othello.gd`, which exits non-zero on failure.

**Scope:** S2 and S4 only. S1 (board state) is a dependency, S3 (turn/pass) is the trigger for end detection, and S5 (AI) consumes these rules but is out of scope here.

# Source Evidence

- `design/systems-index.md` — S2 and S4 entries, priority tier P0.
- `src/scripts/othello.gd` — `_is_legal_move`, `_check_direction`, `_execute_move`, `_flip_in_direction`, `_in_bounds`, `_advance_turn`, `_has_any_legal_moves`, `_update_ui_state`, `_end_game`.
- `src/scripts/verify_othello.gd` — assertion harness covering AT-1..AT-14 and the S7 difficulty contract (88 checks).
- Real-engine run (Godot `4.7.2.stable.official.ed1daf0bf`, `--headless --path src`): opening legal moves and point legality for the shipped code.
- Synthetic multi-direction capture and terminal-board cases, now asserted directly against the shipped functions.

# Data Model

| Field | Source | Type / values | Notes |
|-------|--------|---------------|-------|
| board | `othello.gd` | 8x8 array of `int` | `EMPTY=0`, `BLACK=1`, `WHITE=2` |
| BOARD_SIZE | `othello.gd` | `8` | Square board only |
| current_player | `othello.gd` | `BLACK` or `WHITE` | Owned by S3 |
| game_over | `othello.gd` | `bool` | Set by S4 end detection |
| cell mapping | `othello.gd` | `board[row][col]` | Row 0 top, col 0 left |

**Invariants**

- Every board value is `0`, `1`, or `2`.
- Board dimensions are exactly 8x8.
- A successful move increases the moving player's disc count by `1 + flips` and decreases the opponent's by `flips`.
- Own discs never flip as a result of a move.

# System Rules — S2 Move Legality & Capture

- **R-S2-1 Placement:** The active player may place only on an empty cell (`EMPTY`). Occupied cells are never legal.
- **R-S2-2 Flank requirement:** A placement is legal if and only if at least one of the eight directions from that cell contains a contiguous run of one or more opponent discs immediately adjacent, terminated by a disc of the active player within the board.
- **R-S2-3 Capture resolution:** On a legal placement, the disc is placed first; then, for each of the eight directions, if that direction has an opponent run terminated by the active player's disc, every disc in that run flips to the active color. Directions not terminated by the active player's disc flip nothing.
- **R-S2-4 Multi-direction capture:** All qualifying directions resolve in the same move; a single placement may flip in up to eight directions.
- **R-S2-5 Bound handling:** Positions outside `0..7` are ignored. A run that reaches the board edge without an active-player terminator does not flip (and does not make the move legal by itself).
- **R-S2-6 Illegal move:** Pressing an empty but non-capturing cell changes no board state, does not pass the turn, and shows invalid-move feedback.
- **R-S2-7 Occupied cell:** Pressing an occupied cell is a no-op with no feedback requirement.
- **R-S2-8 Implementation mapping:** `_is_legal_move` + `_check_direction` define R-S2-2/R-S2-5; `_execute_move` + `_flip_in_direction` define R-S2-3/R-S2-4.

# System Rules — S4 Scoring & End Conditions

- **R-S4-1 Score:** A player's score is the count of their discs on the board; it updates after every move.
- **R-S4-2 Pass:** If the player to move has no legal move, the turn passes to the opponent with a visible notice (S3 behavior; end detection depends on it).
- **R-S4-3 End condition:** The match ends when neither player has a legal move, even if empty cells remain.
- **R-S4-4 Outcome:** The player with more discs wins; equal counts are a draw.
- **R-S4-5 Terminal lock:** After the match ends, no further move changes the board.
- **R-S4-6 Implementation mapping:** `_has_any_legal_moves` + `_advance_turn` drive R-S4-2/R-S4-3; `_end_game` and `_update_ui_state` drive R-S4-1/R-S4-4.

# Feedback

| State | Player-facing signal | Source |
|-------|----------------------|--------|
| Normal turn | `status_label` shows whose turn it is | `_update_ui_state` |
| Invalid move | "Invalid Move!" for ~0.5s | `_on_cell_pressed` |
| Passed turn | "<Player> has no legal moves! Skipping..." for ~1.0s | `_advance_turn` |
| AI turn | "Computer is thinking..." for ~0.8s | `_advance_turn` / `_update_ui_state` |
| Game over | "Game Over: <Winner/Draw>! (<black>-<white>)" | `_end_game` |

# Balance Levers

S2 and S4 are **rule-exact**: they have no tunable values, and changing them changes the game, not its balance. The only inspectable presentation-adjacent constants near these systems are the feedback timings above (`0.5s` invalid, `1.0s` pass, `0.8s` AI). AI evaluation weights (disc `10`, corner `100`, edge `5`, mobility `2`) belong to S5 and are recorded in `design/systems-index.md`.

# Edge Cases

1. **Multi-direction capture:** one placement flips along several lines simultaneously (acceptance AT-9).
2. **No terminator:** an opponent run that reaches the edge without an own disc never flips and is not a legal move on its own.
3. **Single-disc flank:** an opponent run of length 1 is captured when terminated by an own disc.
4. **Adjacent own disc only:** a cell touching only own discs (no opponent run between) is illegal.
5. **Corner/edge entry:** corner placements are legal only when a run in a diagonal/orthogonal direction is terminated inside the board.
6. **Occupied cell press:** no state change.
7. **Illegal empty cell press:** no state change, turn does not pass, invalid feedback.
8. **Terminal board not full:** end detection must not require all 64 cells to be occupied (double pass ends the game).
9. **Single remaining legal move:** the only legal move must still be accepted.

# Acceptance Tests

Method: **HARNESS** = asserted in `src/scripts/verify_othello.gd` against Godot 4.7.2 and the run exits non-zero on failure. Opening-move and legality rows were additionally spot-checked in an interactive headless run.

| ID | Given | When | Then | Method |
|----|-------|------|------|--------|
| AT-1 | New game | read `board` | Black at `(3,3)`,`(4,4)`; White at `(3,4)`,`(4,3)`; all else `EMPTY`; counts 2-2 | HARNESS |
| AT-2 | New game, Black to move | `_get_all_legal_moves(BLACK)` | exactly `[(2,4),(3,5),(4,2),(5,3)]` | HARNESS |
| AT-3 | New game, White to move | `_get_all_legal_moves(WHITE)` | exactly `[(2,3),(3,2),(4,5),(5,4)]` | HARNESS |
| AT-4 | New game | `_is_legal_move(2,3,BLACK)` | `false` (edge of opening set) | HARNESS |
| AT-5 | New game | `_is_legal_move(3,2,BLACK)` | `false` | HARNESS |
| AT-6 | New game | `_is_legal_move(3,3,BLACK)` | `false` (occupied) | HARNESS |
| AT-7 | New game | Black plays `(2,4)` | flips exactly `(3,4)`; counts 4-1 | HARNESS |
| AT-8 | New game | Black plays `(4,2)` | flips exactly `(4,3)`; counts 4-1 | HARNESS |
| AT-9 | Black at `(0,0)`,`(0,2)`; White at `(1,1)`,`(1,2)`; Black to move | Black plays `(2,2)` | flips exactly `(1,1)` and `(1,2)`; counts 5-0 | HARNESS |
| AT-10 | Board all Black except empty `(7,7)` | `_advance_turn` | neither player has a legal move; `game_over = true`; result "Black Wins! (63-0)" | HARNESS |
| AT-11 | `game_over = true` | `_on_cell_pressed` on an empty cell | board unchanged | HARNESS |
| AT-12 | Any board | `_update_ui_state` | black/white labels equal actual disc counts | HARNESS |
| AT-13 | Black has exactly one legal move | place it | move accepted, board updated | HARNESS |
| AT-14 | Opponent run reaches edge with no own terminator | `_is_legal_move` for that cell/direction | `false` for that direction | HARNESS |

AT-1..AT-14 are now implemented as hard assertions in `src/scripts/verify_othello.gd` (88 checks total, exit non-zero on failure). Implementing them surfaced a real rule defect: `_is_legal_move` did not reject occupied cells, so `_get_all_legal_moves` (and the AI) could treat an occupied cell as legal. The function now enforces R-S2-1 with an explicit empty-cell guard.

# Open Questions / Unverified Assumptions

- **Unverified:** no playtest has been recorded, so the player-facing clarity of the pass/end feedback is assumed, not observed.
- **Unverified:** the win/draw copy and score formatting are assumed acceptable for the prototype; no UX review exists.
- **Assumption:** rules follow standard Othello/Reversi; no variant (e.g. different board size) is in scope.
- **Assumption:** feedback timings are placeholders, not tuned values.

# Risks

- **Difficulty mapping (S7): RESOLVED.** The `OptionButton` now binds labels to enum values by item ID with default Medium; see `design/systems/difficulty-mode.md`. Was: `Medium`/`Easy`/`Hard` assigned by index, swapping Medium and Easy.
- **Harness gap (mostly closed):** `verify_othello.gd` now asserts AT-1..AT-14 and exits non-zero on failure (S9). Restart behavior and pass-timing feedback remain unasserted.
- **Legality guard was missing:** `_is_legal_move` now rejects occupied cells (R-S2-1); this was found by AT-13 and fixed.
- **`_refresh_board_visuals` child contract:** it reads `btn.get_child(1)` as the disc, so any UI refactor must preserve the `[background, disc]` child order (UI contract for S6).
- **Typed-return mismatch (S5):** `_get_best_move() -> Vector2i` can return `null`; unrelated to S2/S4 but noted because AI consumes these rules.

# Changed Files

- `design/systems/core-rules.md` — this system GDD (new).
- `design/gdd.md` — added a per-system section linking this document.
- `src/scripts/_probe_legality.gd` — temporary grounding probe, created and removed (not shipped).

# Verification Evidence

- `godot --headless --path src -s res://scripts/verify_othello.gd` → 88 checks, 0 failures, exit 0 (covers AT-1..AT-14, S7-AT-1..7, and S3-AT-1..7).
- `godot --headless --path src --quit-after 90` → exit 0, no scene errors (engine `4.7.2.stable.official.ed1daf0bf`).
- `./codex-game-studio validate` → 1216 PASS / 0 FAIL; `./codex-game-studio docs-impact --base HEAD` → PASS.

# Next Owner / Decision

- **Decision recorded:** R-S2-* and R-S4-* are the frozen rule contract for the prototype; `design-review-2` accepts them.
- **Closed:** AT-1..AT-14 implemented as assertions (S9); S7 difficulty mapping fixed and asserted (B2/B3).
- **Next design owner:** senior-game-designer runs `review-all-gdds` once S3/S5/S6 specs exist.
- **Verification owner:** qa-playtester records the first playtest against the feedback table and adds restart/pass-timing assertions.
