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

# Balance Levers

| Lever | Value | Owner | Notes |
|-------|-------|-------|-------|
| Easy depth | 1 | systems-designer | Weakest opponent; fast |
| Medium depth | 3 | systems-designer | Default |
| Hard depth | 5 | systems-designer | Strength and time unmeasured |
| Evaluation weights | disc 10, corner 100, edge 5, mobility 2 | systems-designer | Shared by all difficulties (see `systems-index.md` S5) |
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

# Risks

- **Unmeasured performance:** Hard (depth 5) has no timing budget; a dense board may pause noticeably.
- **Live-change semantics (R-S7-7):** changing difficulty mid-game is a prototype convenience that may surprise players; revisit with UX.
- **No difficulty feel validation:** "how strong should Hard be" is not playtested.

# Changed Files

- `design/systems/difficulty-mode.md` — this system GDD (new).
- `src/scripts/othello.gd` — `OptionButton` item IDs, default selection, `_is_legal_move` occupancy guard, mode-aware `_display_name`.
- `src/scripts/verify_othello.gd` — S7 assertions (including RC1 mode display-name checks).

# Verification Evidence

- `godot --headless --path src -s res://scripts/verify_othello.gd` → 88 checks, 0 failures, exit 0.
- `godot --headless --path src --quit-after 90` → exit 0.

# Next Owner / Decision

- **Decision needed:** approve depth mapping (1/3/5) and default Medium as the prototype difficulty contract.
- **Next owner:** game-feel-designer / balance-check for the Hard difficulty time budget; qa-playtester for difficulty feel.
