# Othello System GDD: Mode & Difficulty (S7)

# Purpose

Define the player-facing contract for game mode (player-vs-computer, local player-vs-player) and AI difficulty (Easy, Medium, Hard), and pin the mapping between UI labels, option values, and AI search depth so the control can be tested instead of assumed. Closes design-review item **B2**.

# Summary

The prototype offers two modes and three difficulty levels. Difficulty changes only the AI search depth; the evaluation weights are shared. The label-to-value mapping is carried by the `OptionButton` item IDs (not the visual index), so reordering or renaming labels cannot silently change which difficulty is active. The default mode is player-vs-computer and the default difficulty is Medium.

# Source Evidence

- `design/systems-index.md` — S7 entry (P0-adjacent), S5 AI dependency.
- `src/scripts/othello.gd` — `Mode`, `Difficulty`, `_build_ui` (`mode_option`, `difficulty_option`), `_match_difficulty`, `_advance_turn` AI branch.
- `src/scripts/verify_othello.gd` — S7 checks (labels, ids, default, live selection, AI legal move).
- `design/reviews/design-review.md` — C3/B2 (defect and remediation).

# System Rules

- **R-S7-1 Mode values:** `PLAYER_VS_AI` (human plays Black, computer plays White) and `PLAYER_VS_PLAYER` (two local players). Default is `PLAYER_VS_AI`.
- **R-S7-2 Difficulty values:** `EASY`, `MEDIUM`, `HARD`. Default is `MEDIUM`.
- **R-S7-3 Depth mapping:** Easy = search depth `1`, Medium = `3`, Hard = `5` (`_match_difficulty`).
- **R-S7-4 Label binding:** each difficulty label is bound to its enum value through the option item ID (`add_item(label, id)` + `get_item_id`), never through the visual index.
- **R-S7-5 Label order:** labels read top-to-bottom as `Easy`, `Medium`, `Hard`.
- **R-S7-6 AI side:** the AI moves only in `PLAYER_VS_AI` and only for White; it never moves for the human.
- **R-S7-7 Live settings:** mode and difficulty are read when a turn is resolved, so a change takes effect immediately; the UI should recommend a restart after changing settings (prototype behavior, not a final UX decision).
- **R-S7-8 Display names:** the White side is labeled `Computer` only in `PLAYER_VS_AI`; in `PLAYER_VS_PLAYER` both sides use their color names (`Black`, `White`) in the turn label and the pass notice (`_display_name`).
- **R-S7-9 Difficulty is defined by evaluation, not depth alone:** search depth alone barely separates skill levels — a depth-1 AI with the standard evaluation already beats a corner-aware beginner 6/8 of the time, because the mobility term (`+2` per legal move) rewards keeping loose discs on the board, which is the classic beginner trap. **EASY therefore plays depth 1 with the standard evaluation MINUS the mobility term** (`_evaluate_board_no_mobility`): it still takes corners and edges, so it looks deliberate, but it does not understand mobility and a player who does can beat it. MEDIUM and HARD are unchanged.
- **R-S7-10 Measured ladder:** `bench_difficulty_ladder.gd` plays a corner-aware beginner against the AI over 12 varied openings per difficulty. Required result: the beginner's win rate is **monotonically non-increasing** with difficulty, and the beginner wins **at least 6/12 at EASY**. Measured: EASY 12/12 (avg 33–31, competitive), MEDIUM 0/12 (avg 26–38), HARD 0/12 (avg 21–43).

# Balance Levers

| Lever | Value | Owner | Notes |
|-------|-------|-------|-------|
| Easy depth | 1 | systems-designer | Shallow **and** no mobility term (R-S7-9) — the weakest opponent |
| Medium depth | 3 | systems-designer | Default |
| Hard depth | 5 | systems-designer | Time-budgeted to 400ms; median 403ms measured |
| Evaluation weights (Medium/Hard) | disc 10, corner 100, edge 5, mobility 2 | systems-designer | Shared by Medium and Hard (see `systems-index.md` S5) |
| Evaluation weights (Easy) | disc 10, corner 100, edge 5, **no mobility** | systems-designer | The weakening that makes Easy winnable (R-S7-9) |
| Computer think delay | 0.8s | game-feel-designer | Placeholder feedback pacing |

# Edge Cases

1. Changing difficulty mid-match applies to the next AI turn (R-S7-7); document that restart is recommended.
2. In `PLAYER_VS_PLAYER`, difficulty has no effect and the AI branch must not run.
3. A difficulty label rename must not change the selected difficulty (guarded by item IDs).
4. Default state must show `vs Computer` and `Medium` before any interaction.

# Acceptance Tests

Implemented in `src/scripts/verify_othello.gd`:

| ID | Given | When | Then |
|----|-------|------|------|
| S7-AT-1 | A built UI | read difficulty labels | `["Easy", "Medium", "Hard"]` |
| S7-AT-2 | A built UI | read each item id and map it | depths `[1, 3, 5]` |
| S7-AT-3 | New UI | read default selection | `Medium` |
| S7-AT-4 | A built UI | emit `item_selected` for Hard | `game_difficulty == HARD` |
| S7-AT-5 | Player-vs-AI, Easy | AI resolves a move | returned move is legal for White |
| S7-AT-6 | `_match_difficulty` | pass `EASY`/`MEDIUM`/`HARD` | `1`/`3`/`5` |
| S7-AT-7 | Built UI | `_display_name(WHITE)` in each mode | `Computer` in vs-AI, `White` in vs-Player; PvP turn label reads `Turn: White` |

### Balance acceptance (separate harness)

Implemented in `src/scripts/bench_difficulty_ladder.gd` (headless, exits non-zero if the ladder is not monotonic or Easy is not winnable):

| ID | Given | When | Then |
|----|-------|------|------|
| S7-BAL-1 | A corner-aware beginner vs the AI, 12 varied openings per difficulty | play all three difficulties | the beginner's win rate is monotonically non-increasing: EASY ≥ MEDIUM ≥ HARD |
| S7-BAL-2 | Same | measure EASY | the beginner wins at least 6/12 (Easy is winnable) |
| S7-BAL-3 | Same | measure MEDIUM and HARD | the beginner wins 0/12 (those tiers stay challenging) |
| S7-BAL-4 | Control: the same beginner vs a uniformly random AI | 12 openings | the beginner wins at least 8/12 — proves the opponent model and win detection are sound, so the numbers above mean something |

**Measured (2026-10-19):** EASY 12/12 (avg 33–31), MEDIUM 0/12 (avg 26–38), HARD 0/12 (avg 21–43). Control 9/12 PASS. Ladder monotonic PASS.

# Risks

- **Performance (resolved):** Hard (depth 5) is time-budgeted to 400ms; measured median 403ms.
- **Live-change semantics (R-S7-7):** changing difficulty mid-game is a prototype convenience that may surprise players; revisit with UX.
- **Easy strength is measured against a scripted opponent, not a human.** The 12/12 figure is against a corner-aware bot; a human plays worse in some positions and better in others. A human session (playtest session 2) is the real confirmation.
- **The no-mobility evaluation is a blunt instrument.** It makes Easy beatable, but it also makes Easy occasionally *better* than a random player in sharp positions. If a future playtest finds Easy still too strong, the next lever is the corner/edge weights, not depth.

# Changed Files

- `design/systems/difficulty-mode.md` — this system GDD (new).
- `src/scripts/othello.gd` — `OptionButton` item IDs, default selection, `_is_legal_move` occupancy guard, mode-aware `_display_name`, EASY no-mobility evaluation (`_get_best_move_easy`, `_evaluate_board_no_mobility`).
- `src/scripts/verify_othello.gd` — S7 assertions (including RC1 mode display-name checks) and the S5-AT-3 update for the new Easy contract.
- `src/scripts/bench_difficulty_ladder.gd` — the difficulty ladder balance harness (new).

# Verification Evidence

- `godot --headless --path src -s res://scripts/verify_othello.gd` → 97 checks, 0 failures, exit 0.
- `godot --headless --path src -s res://addons/gut/gut_cmdln.gd` → 97 asserts, all passed, exit 0.
- `godot --headless --path src --quit-after 90` → exit 0.
- `godot --headless --path src -s res://scripts/bench_hard_difficulty.gd` → HARD median 403ms ≤ 500ms.
- `godot --headless --path src -s res://scripts/bench_difficulty_ladder.gd` → ladder PASS (EASY 12/12, MEDIUM 0/12, HARD 0/12; monotonic; control 9/12).

# Next Owner / Decision

- **Decision needed:** approve the depth mapping (1/3/5) **and** the EASY evaluation change (no mobility term) as the prototype difficulty contract, per R-S7-9/R-S7-10.
- **Next owner:** qa-playtester for the human confirmation of the new Easy strength (playtest session 2 — "is Easy winnable?"); gameplay-programmer if the feel is off.
