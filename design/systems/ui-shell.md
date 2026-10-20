# Othello System GDD: UI Shell (S6)

# Purpose

Define the layout, widgets, interaction feedback, restart behavior, and acceptance tests for **S6 Presentation / UI Shell** — everything the player sees and clicks outside the rules engine. S6 is P0: without a readable board, clickable cells, score, and turn state, the prototype is not playable. Authoring it closes the S6 spec gap and records the resolutions of the two player-facing defects RC3 (missing legal-move affordance) and RC4 (silent occupied-cell click).

# Summary

The prototype is a single Godot `Control` scene whose entire UI is built in code by `_build_ui`. A full-rect vertical stack holds, top to bottom: a settings bar (Mode + Difficulty), a stats row (Black / White scores + turn), the 8x8 board grid, a status line, and a Restart button. Each board cell is a `Button` with a background `ColorRect` and a disc `TextureRect`. Clicking a legal empty cell places a disc; clicking anything else leaves the board unchanged and flashes "Invalid Move!". The cells the human may legally play are highlighted.

**Scope:** S6 only. S7 owns the mode/difficulty option semantics and display names, S3/S4 own turn/end rules, S5 owns the AI that drives the "thinking" state, S8 owns feedback timing, S14 owns accessibility. This document formalizes the shipped presentation in `src/scripts/othello.gd`.

# Source Evidence

- `design/systems-index.md` — S6 entry, P0, depends on S1/S4/S5.
- `design/gdd.md` — pillar "Readable board — score, turn, and match state are visible at a glance" (approved B1).
- `design/systems/turn-pass.md` — R-S3-7 (input gating); `design/systems/ai-opponent.md` — R-S5-11.
- `design/reviews/review-all-gdds.md` — RC3 (missing legal-move affordance), RC4 (silent occupied-cell click).
- `src/scripts/othello.gd` — `_build_ui`, `_create_textures`, `_make_disc_texture`, `_refresh_board_visuals`, `_refresh_legal_hints`, `_on_cell_pressed`, `_update_ui_state`, `_end_game`, `CELL_COLOR`, `CELL_HINT_COLOR`.
- `src/scripts/verify_othello.gd` — S6 assertions (`_test_ui_shell`).
- Godot `4.7.2.stable.official.ed1daf0bf`, `--headless --path src`.

# Data Model

| Field | Source | Type | Role |
|-------|--------|------|------|
| mode_option | `othello.gd` | `OptionButton` | Mode selector ("vs Computer" / "vs Player") |
| difficulty_option | `othello.gd` | `OptionButton` | Difficulty selector ("Easy" / "Medium" / "Hard") |
| black_score_label / white_score_label | `othello.gd` | `Label` | Disc counts |
| turn_label | `othello.gd` | `Label` | Active side (R-S7-8 names) |
| status_label | `othello.gd` | `Label` | Turn / invalid / skip / game-over messages |
| board_grid | `othello.gd` | `GridContainer` | 8x8 grid of cells |
| cells | `othello.gd` | `Array[Array[Button]]` | Per-cell buttons |
| cell child 0 | `_build_ui` | `ColorRect` | Background (base or hint color) |
| cell child 1 | `_build_ui` | `TextureRect` | Disc image |
| restart_button | `othello.gd` | `Button` | Calls `_new_game` |
| black/white_disc_tex | `_make_disc_texture` | `ImageTexture` | 50px circle textures |

**Invariants**

- The board grid always contains exactly 64 cells in 8 columns.
- Every cell has exactly two children: a background (index 0) and a disc (index 1).
- An empty cell renders no disc; a Black/White cell renders the matching texture.
- A click never changes the board unless it is a legal placement on the human's turn.
- Every cell is 60x60 at an exact pixel position; its disc is 48x48 centered at offset (6,6).
- Every cell is keyboard-focusable and wired for arrow-key navigation (R-S6-13).

# System Rules — S6 UI Shell

- **R-S6-1 Shell structure:** a full-rect `VBoxContainer` ("Layout") holds, in order: settings bar, stats row, board grid, status line, Restart button.
- **R-S6-2 Settings widgets:** `mode_option` lists "vs Computer" / "vs Player" and `difficulty_option` lists "Easy" / "Medium" / "Hard", each bound to enum item IDs (R-S7-1) and initialized to the current settings.
- **R-S6-3 Stats row:** `black_score_label`/`white_score_label`/`turn_label` render "Black: N", "White: N", and "Turn: <name>" (name via R-S7-8).
- **R-S6-4 Board grid:** a 480x480 `Control` ("BoardGrid") holding 64 cell `Control`s positioned at exact pixels (`c*60, r*60`); each cell owns a background `ColorRect` (child 0) and a disc `TextureRect` (child 1). Cells are plain `Control`s, not `Button`s, so no theme padding can offset the disc (fix for the cell-alignment defect).
- **R-S6-5 Disc rendering:** Black/White discs use generated 50px circle textures; empty cells render no disc.
- **R-S6-6 Click-to-place:** a click on a legal empty cell places a disc and hands the turn to S3 (`_on_cell_pressed`).
- **R-S6-7 Invalid-move feedback:** a click on an occupied cell **or** an illegal empty cell changes nothing and shows "Invalid Move!" for ~`0.5s` (RC4; R-S8-1).
- **R-S6-8 Legal-move affordance:** the shell highlights the cells the human to move may legally play (background `CELL_HINT_COLOR`) and clears the highlight during the AI turn and after game over (RC3).
- **R-S6-9 Restart:** the Restart button resets board, turn, game-over, and hints via `_new_game`, and preserves the selected mode and difficulty.
- **R-S6-10 Status line:** a single centered `status_label` carries turn, invalid-move, skip, thinking, and game-over messages (S3/S4/S8).
- **R-S6-11 Input gating:** the shell never places a disc during the AI turn or after game over (R-S3-7).
- **R-S6-12 Child-role coupling:** cell children are addressed by index (bg `0`, disc `1`); adding further cell art requires a named-reference refactor first (review C9). The C9 refactor replaced `get_child()` with named `cells[r][c].bg` / `.disc` / `.cell` dictionary entries.
- **R-S6-13 Keyboard access (S14):** every cell has `focus_mode = FOCUS_ALL` and `focus_neighbor_left/right/top/bottom` wired to sibling cells as `../Cell_r_c` (Godot resolves focus-neighbor paths relative to the focused node). Enter, KP-Enter, or Space on a focused cell places a disc; arrow keys move between cells. Edge cells have empty neighbor paths (no wrap-around).
- **R-S6-14 Input-event contract:** the `gui_input` signal is connected with `.bind(r, c)`, so Godot calls the handler as `(event, r, c)` — the signal argument comes **first**. `_on_cell_input(event, r, c)` must keep that order.

# Feedback

| State | Player-facing signal | Source |
|-------|----------------------|--------|
| Human turn | legal cells highlighted; `status_label` = "Your turn!" | `_refresh_legal_hints` / `_update_ui_state` |
| AI turn | no highlights; `status_label` = "Computer is thinking..." | `_update_ui_state` |
| Invalid click | "Invalid Move!" for ~`0.5s`; board unchanged | `_on_cell_pressed` |
| Move placed | disc added; flanked discs flip; scores/turn update | `_execute_move` / `_update_ui_state` |
| Match ended | `status_label` = "Game Over: <Winner/Draw>! (<black>-<white>)"; highlights cleared | `_end_game` |

Transient messages (invalid move ~`0.5s`, skip notice ~`1.0s`) are visible on screen but are overwritten by the next `_update_ui_state`, so they are not observable after the handler returns out-of-tree (same limitation as S3-AT-3).

# Balance Levers

Presentation values in `src/scripts/othello.gd`:

- **Cell size:** `CELL_SIZE = 60` (board ≈ 480px).
- **Disc texture:** `50px` circle (`_make_disc_texture`).
- **Cell colors:** base `CELL_COLOR = Color(0.16, 0.44, 0.16)`; legal-move hint `CELL_HINT_COLOR = Color(0.95, 0.78, 0.25)` (gold — chosen for WCAG 2.1 AA contrast and colorblind distinctness; see `production/playtest/a11y-baseline-2026-10-19.md`).
- **Feedback timings:** invalid `0.5s`, thinking `0.8s`, pass `1.0s` (shared with S8).

These are not approved values; changing them needs a playtest note and an updated validation case.

# Edge Cases

1. **Occupied click:** no board/turn change; "Invalid Move!" feedback (R-S6-7).
2. **Illegal empty click:** no board/turn change; same feedback.
3. **Legal click:** one disc placed, flanked lines flipped, turn advanced (R-S6-6).
4. **Click during AI turn or after game over:** ignored (R-S6-11).
5. **Restart mid-game:** resets state and hints but keeps mode/difficulty (R-S6-9).
6. **Hints follow the active player:** highlighted for the human, cleared while the AI thinks and when the match ends (R-S6-8).
7. **Transient feedback:** the "Invalid Move!" text is not observable after the handler returns out-of-tree.
8. **Fixed-size layout:** the board is a fixed 480px block; window-resize behavior is unverified.

# Acceptance Tests

Method: **HARNESS** = asserted in `src/scripts/verify_othello.gd` against Godot 4.7.2; the run exits non-zero on failure.

| ID | Given | When | Then | Method |
|----|-------|------|------|--------|
| S6-AT-1 | Built UI | inspect `cells` | 8x8 = 64 cells; each has a `ColorRect` (0) and `TextureRect` (1) | HARNESS |
| S6-AT-2 | Built UI | inspect `board_grid` | 64 cell children | HARNESS |
| S6-AT-3 | New game, PvP | `_update_ui_state` | labels read "Black: 2", "White: 2", "Turn: Black" | HARNESS |
| S6-AT-4 | Built UI | inspect option widgets | Mode labels `["vs Computer","vs Player"]`; difficulty `["Easy","Medium","Hard"]` | HARNESS |
| S6-AT-5 | New game | inspect disc textures | (3,3) black, (3,4) white, (0,0) none | HARNESS |
| S6-AT-6 | New game, PvP | click a legal cell (2,4) | disc placed (`board[2][4]==BLACK`); turn → White | HARNESS |
| S6-AT-7 | New game | click an occupied cell (3,3) | board and turn unchanged (RC4) | HARNESS |
| S6-AT-8 | New game | click an illegal empty cell (0,0) | board and turn unchanged | HARNESS |
| S6-AT-9 | Mid-game, game over | `_new_game` via Restart | 4 discs restored, turn Black, not game over; labels reset | HARNESS |
| S6-AT-10 | New game, PvP | inspect cell backgrounds | legal cell highlighted, illegal/occupied at base color; hints clear when game over | HARNESS |

### S14 Accessibility Assertions (same harness)

| ID | Given | When | Then | Method |
|----|-------|------|------|--------|
| S14-AT-1 | Palette | measure WCAG contrast | black disc vs cell base ≥3:1; white disc vs cell base ≥3:1 | HARNESS |
| S14-AT-2 | Palette | measure WCAG contrast | legal-move hint vs cell base ≥3:1 | HARNESS |
| S14-AT-3 | Built UI | inspect focus wiring | every cell `FOCUS_ALL`; `focus_neighbor_left/right` = `../Cell_r_c` | HARNESS |
| S14-AT-4 | New game, PvP | Enter on a focused cell | disc placed; turn advanced | HARNESS |
| S14-AT-5 | New game, PvP | mouse click on a legal cell | disc placed; turn advanced (bind-order regression guard) | HARNESS |
| S14-AT-6 | New game, PvP | Tab (non-activation key) | no disc placed | HARNESS |

# Open Questions / Unverified Assumptions

- **Unverified:** window resize / responsive layout — the board is a fixed-size block with no anchor strategy.
- **Verified:** keyboard grid navigation and focus order (S14-AT-3/4; live `simulate_key` check in `production/playtest/a11y-baseline-2026-10-19.md`).
- **Verified:** color contrast and colorblind legibility of the hint color (S14-AT-1/2; gold hint at 3.78:1 vs base, hue + lightness difference).
- **Unverified:** screen-reader announcements of legal moves and score changes (S14 post-gate).
- **Unverified:** "Invalid Move!" and skip-notice clarity and duration (S8, no playtest).
- **Assumption:** hardcoded English strings are acceptable for the prototype (S13 deferred).
- **Assumption:** the default Godot theme is acceptable until the S14/art pass.

# Risks

- **Child-index coupling (medium):** `_refresh_board_visuals` and `_refresh_legal_hints` read `get_child(0/1)` within a cell (C9); the cell/background/disc references themselves are now named (`cells[r][c].cell/.bg/.disc`), but adding a third child to a cell would still shift the disc's index.
- **Fixed-size layout (medium):** no responsive/anchored board; small or resized windows may clip the board.
- **Accessibility partially verified (low/medium):** contrast, colorblind, and keyboard navigation now pass; screen-reader support and focus-visible styling remain post-gate gaps.
- **Localization debt (low):** all strings are hardcoded English (S13).
- **Transient feedback unverified (low):** invalid-move/skip messages are not assertable out-of-tree.

# Changed Files

- `design/systems/ui-shell.md` — this system GDD (new).
- `design/gdd.md` — per-system table links this document.
- `design/systems-index.md` — S6 row, validation, S9 coverage updated; RC3/RC4 recorded as resolved.
- `src/scripts/othello.gd` — RC4 (unified invalid-click feedback) and RC3 (legal-move highlight: `CELL_COLOR`, `CELL_HINT_COLOR`, `_refresh_legal_hints`).
- `src/scripts/verify_othello.gd` — S6-AT-1..10 assertions added (`_test_ui_shell`).

# Verification Evidence

- `godot --headless --path src -s res://scripts/verify_othello.gd` → 88 checks, 0 failures, exit 0 (includes S6-AT-1..10).
- `godot --headless --path src --quit-after 90` → exit 0, no script errors.
- `./codex-game-studio validate` → 1216 PASS / 0 FAIL.

# Next Owner / Decision

- **Decision requested:** approve R-S6-1..R-S6-12 as the UI-shell contract, including the RC3 highlight and RC4 invalid-click feedback.
- **Next design owner:** game-feel-designer for the S8 feedback spec next.
- **Verification owner:** qa-playtester adds an in-tree visual check for the highlight and invalid-move feedback, and a resize/keyboard pass.
- **Follow-up:** refactor cell children to named references (C9) before adding further cell art; S14 owns theme/contrast/keyboard.
