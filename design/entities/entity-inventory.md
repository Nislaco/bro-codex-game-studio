# Othello Entity Inventory

# Purpose

Catalog the gameplay objects, actors, content items, configuration, presentation nodes, engine objects, and verification objects of the Othello prototype, with an identifier, purpose, owning role, dependencies, lifecycle, and validation signal for each. This is the entity-level companion to `design/systems-index.md` (system decomposition) and `design/systems/core-rules.md` / `design/systems/difficulty-mode.md` (rule contracts).

# Summary

The prototype is a single-scene Godot 4.7.2 Othello game. Every entity below is grounded in the shipped source: `src/scripts/othello.gd` (all logic and UI construction), `src/scenes/main.tscn` (one `Control` node bound to the script), `src/project.godot` (engine config), and `src/scripts/verify_othello.gd` (assertion harness). The inventory separates **rule/state data**, **actors/services**, **configuration**, **presentation**, **engine bootstrap**, and **verification** entities, because the code currently overloads a few names across those layers (see Naming Conflicts).

Scope: prototype (`design/gdd.md`, phase `pre-production`). No save, audio, localization, or online entities exist yet and none are scheduled before the prototype gate.

# Source Evidence

- `src/scripts/othello.gd` — constants, board/state vars, UI construction, rules, AI, scoring, end detection.
- `src/scenes/main.tscn` — `Main` `Control` node with `othello.gd` binding.
- `src/project.godot` — `run/main_scene="res://scenes/main.tscn"`.
- `src/scripts/verify_othello.gd` — 88 assertions covering AT-1..AT-14, S7-AT-1..7, and S3-AT-1..7.
- `design/systems-index.md` — S1-S14 system map (entity ownership cross-reference).
- `design/systems/core-rules.md`, `design/systems/difficulty-mode.md` — rule contracts the entities implement.
- Verification run: `godot --headless --path src -s res://scripts/verify_othello.gd` → 88 checks, 0 failures, exit 0.

# Entity Taxonomy

| Category | Prefix | Count | Systems |
|----------|--------|-------|---------|
| Rule & state data | `E-R*` | 13 | S1, S2, S3, S4 |
| Actors & services | `E-A*` | 5 | S3, S5, S6 |
| Configuration | `E-C*` | 2 | S7 |
| Presentation | `E-P*` | 15 | S6 |
| Engine bootstrap | `E-B*` | 3 | S10 |
| Verification | `E-T*` | 3 | S9 |

# Rule & State Entities

| ID | Entity | Purpose (player/production reason) | Source symbol | Owner role | Depends on | Validation signal | Scope |
|----|--------|------------------------------------|---------------|------------|------------|-------------------|-------|
| E-R01 | Board | The 8x8 grid that holds all match state; the game object | `board`, `_new_game` | systems-designer | — | AT-1, AT-9, AT-10 | In (P0) |
| E-R02 | Cell (data position) | A single `(row,col)` addressable slot; the unit of placement and capture | `board[r][c]`, `_in_bounds` | systems-designer | E-R01 | AT-1, AT-5, AT-14 | In (P0) |
| E-R03 | Disc value | A cell's owner: `EMPTY=0`, `BLACK=1`, `WHITE=2` | `EMPTY`, `BLACK`, `WHITE` | systems-designer | E-R02 | AT-1, AT-7..AT-9 | In (P0) |
| E-R04 | Side / Player | One of the two competing colors; owns the turn | `BLACK`, `WHITE`, `_get_opponent` | systems-designer | E-R03 | AT-2, AT-3 | In (P0) |
| E-R05 | Turn / active player | Whose move it is; drives input gating and AI activation | `current_player` | systems-designer | E-R04 | AT-10, S7-AT-5 | In (P0) |
| E-R06 | Move / placement | A player action placing a disc on a legal empty cell | `_execute_move`, `_on_cell_pressed` | systems-designer | E-R02, E-R07 | AT-7, AT-8 | In (P0) |
| E-R07 | Legal move set | The set of cells a player may legally play; drives input validation and AI | `_is_legal_move`, `_get_all_legal_moves` | systems-designer | E-R02, E-R08 | AT-2..AT-6, AT-13 | In (P0) |
| E-R08 | Capture / flip | Opponent discs turned by a placement along one or more directions | `_check_direction`, `_flip_in_direction` | systems-designer | E-R07 | AT-7..AT-9, AT-14 | In (P0) |
| E-R09 | Score / disc count | Live count per side; the win condition input | `_update_ui_state` (counts) | systems-designer | E-R03 | AT-12 | In (P0) |
| E-R10 | Match / game session | One playable game from opening setup to result | `_new_game` | systems-designer | E-R01, E-R09 | AT-1, AT-10 | In (P0) |
| E-R11 | Outcome / result | Winner or draw at end of match | `_end_game` | systems-designer | E-R09, E-R13 | AT-10 | In (P0) |
| E-R12 | Pass event | A side with no legal move is skipped once | `_advance_turn`, `_has_any_legal_moves` | systems-designer | E-R07, E-R05 | AT-10 (double pass) | In (P0) |
| E-R13 | Game-over state | Terminal flag that locks all further moves | `game_over` | systems-designer | E-R11 | AT-10, AT-11 | In (P0) |

# Actor & Service Entities

| ID | Entity | Purpose (player/production reason) | Source symbol | Owner role | Depends on | Validation signal | Scope |
|----|--------|------------------------------------|---------------|------------|------------|-------------------|-------|
| E-A01 | Human player input | Turns a click into a bounded move attempt (or feedback) | `_on_cell_pressed`, `cell.pressed` | gameplay-programmer | E-R05, E-R07 | AT-11, manual playtest | In (P0) |
| E-A02 | Computer opponent (AI) | Provides the single-player opposition | `_ai_move`, `AI_PLAYER` | ai-programmer | E-R07, E-C02 | S7-AT-5; S5-AT-1..7 | In (P0) |
| E-A03 | Minimax search | Chooses the AI move within a depth budget | `_minimax`, `_get_best_move`, `NO_MOVE` | ai-programmer | E-R07, E-A04, E-A05 | S5-AT-1..7; timing unmeasured | In (P0) |
| E-A04 | Board evaluation heuristic | Scores a position (disc/corner/edge weights) | `_evaluate_board` | ai-programmer | E-R03 | S7-AT-5 (indirect) | In (P0) |
| E-A05 | Mobility metric | Counts available moves as a positional signal | `_get_mobility` | ai-programmer | E-R07 | S7-AT-5 (indirect) | In (P0) |

# Configuration Entities

| ID | Entity | Purpose (player/production reason) | Source symbol | Owner role | Depends on | Validation signal | Scope |
|----|--------|------------------------------------|---------------|------------|------------|-------------------|-------|
| E-C01 | Game mode | Selects vs-Computer or local vs-Player play | `Mode`, `game_mode`, `mode_option` | game-designer | — | S7 manual; mode default asserted in harness | In (P1) |
| E-C02 | Difficulty level | Selects AI search depth (Easy 1 / Medium 3 / Hard 5) | `Difficulty`, `game_difficulty`, `_match_difficulty` | game-designer | E-A02 | S7-AT-1..7 | In (P1) |

# Presentation Entities

| ID | Entity | Purpose (player/production reason) | Source symbol | Owner role | Depends on | Validation signal | Scope |
|----|--------|------------------------------------|---------------|------------|------------|-------------------|-------|
| E-P01 | UI shell (root VBox) | Hosts the whole single-screen layout | `vbox` in `_build_ui` | ui-programmer | — | Headless scene exit 0 | In (P0) |
| E-P02 | Settings bar | Groups mode and difficulty controls | `settings_hbox` | ui-programmer | E-C01, E-C02 | Headless scene exit 0 | In (P1) |
| E-P03 | Mode control | Lets the player choose the mode | `mode_option` (`OptionButton`) | ui-programmer | E-C01 | S7 manual | In (P1) |
| E-P04 | Difficulty control | Lets the player choose difficulty | `difficulty_option` (`OptionButton`) | ui-programmer | E-C02 | S7-AT-1..4 | In (P1) |
| E-P05 | Stats bar | Groups score and turn readouts | `stats` | ui-programmer | — | Headless scene exit 0 | In (P0) |
| E-P06 | Black score label | Shows Black's disc count | `black_score_label` | ui-programmer | E-R09 | AT-12 | In (P0) |
| E-P07 | White score label | Shows White's disc count | `white_score_label` | ui-programmer | E-R09 | AT-12 | In (P0) |
| E-P08 | Turn label | Shows whose turn it is | `turn_label` | ui-programmer | E-R05 | AT-12 (indirect) | In (P0) |
| E-P09 | Status label | Shows turn prompt, invalid move, pass, thinking, and result | `status_label` | game-feel-designer | E-R06, E-R12, E-R13 | AT-10, AT-11 | In (P0/P1) |
| E-P10 | Board grid | Lays out 64 cells in 8 columns | `board_grid` (`GridContainer`) | ui-programmer | E-R01 | Headless scene exit 0 | In (P0) |
| E-P11 | Cell button (UI node) | Clickable cell that emits a move attempt | `cell` (`Control`), `cells` | ui-programmer | E-R02, E-A01 | S14-AT-3 (focusable); S6-AT-1 | In (P0) |
| E-P12 | Cell background | Green cell fill (presentation only) | `bg` (`ColorRect`) | ui-programmer | E-P11 | S6-AT-10 | In (P0) |
| E-P13 | Disc node | Renders a disc texture for a cell; positional child of the cell | `disc` (`TextureRect`) | ui-programmer | E-P11, E-P14 | S6-AT-5 | In (P0) |
| E-P14 | Disc texture | Black/white disc image, generated at runtime | `black_disc_tex`, `white_disc_tex`, `_make_disc_texture` | technical-artist | — | Headless scene exit 0 | In (P0) |
| E-P15 | Restart button | Starts a new match from any state | `restart_button` | ui-programmer | E-R10 | Manual playtest; not asserted | In (P1) |
| E-P16 | Legal-move highlight | Highlights empty cells the human may legally play | `_refresh_legal_hints`, `CELL_HINT_COLOR` | ui-ux-designer | E-P11 | S6-AT-10; S14-AT-2 (contrast) | In (P0) |

# Engine Bootstrap Entities

| ID | Entity | Purpose (player/production reason) | Source symbol | Owner role | Depends on | Validation signal | Scope |
|----|--------|------------------------------------|---------------|------------|------------|-------------------|-------|
| E-B01 | Main scene | The one boot scene the engine loads | `Main` (`Control`) in `main.tscn` | godot-specialist | — | Headless scene exit 0 | In (P0) |
| E-B02 | Script binding | Binds `Main` to the game logic | `othello.gd` `extends Control` | godot-specialist | E-B01 | Headless scene exit 0 | In (P0) |
| E-B03 | Project config | Declares app name, features, and the single main scene | `src/project.godot` | godot-specialist | E-B01 | `validate` + headless launch | In (P0) |

# Verification Entities

| ID | Entity | Purpose (player/production reason) | Source symbol | Owner role | Depends on | Validation signal | Scope |
|----|--------|------------------------------------|---------------|------------|------------|-------------------|-------|
| E-T01 | Assertion harness | Automated rules/AI/difficulty evidence | `verify_othello.gd` (`SceneTree`) | qa-playtester | E-R01..E-R13, E-C02, E-A02 | 88 checks, exit 0 | In (P0) |
| E-T02 | Assertion check | One named pass/fail with non-zero exit on failure | `_check` | qa-playtester | E-T01 | Harness report | In (P0) |
| E-T03 | Fixture board | Synthetic board used to isolate a rule case | `_empty_board`, per-test boards | qa-playtester | E-R01 | AT-9, AT-10, AT-13 | In (P0) |

# Lifecycle & State

- **Board (E-R01):** created empty by `_new_game`, seeded with the four opening discs, then mutated in place by `_execute_move` / `_flip_in_direction`. No persistence; destroyed with the scene.
- **Turn (E-R05):** alternates in `_advance_turn`; skipped once when a side has no legal move (E-R12); two consecutive skips end the match.
- **Match (E-R10):** `_new_game` → alternating moves → pass(es) → `_end_game` → `game_over = true` (E-R13). Restart (E-P15) re-enters at `_new_game`.
- **AI (E-A02):** activated only in `PLAYER_VS_AI` when `current_player == WHITE`; searches via E-A03 under the E-C02 depth; emits one move via `_execute_move` then returns the turn.
- **UI readouts (E-P06..E-P09):** refreshed by `_update_ui_state` after every move and turn change; the status label is also overwritten by transient feedback (invalid move, pass, thinking, result).

# Ownership Map

| Layer | Design owner | Implementation owner |
|-------|--------------|----------------------|
| Rule & state (E-R*) | systems-designer | gameplay-programmer |
| AI (E-A02..E-A05) | systems-designer | ai-programmer |
| Input (E-A01) | game-designer | gameplay-programmer |
| Config (E-C*) | game-designer | ui-programmer |
| Presentation (E-P*) | ui-ux-designer | ui-programmer |
| Disc art (E-P14) | senior-game-artist | technical-artist |
| Engine bootstrap (E-B*) | technical-director | godot-specialist |
| Verification (E-T*) | qa-playtester | qa-playtester |

# Gaps, Duplicates, and Naming Conflicts

- **Naming conflict (RC1): RESOLVED.** `PLAYER_NAMES` now uses color names (`Black`/`White`), and `_display_name` returns `Computer` for White only in `PLAYER_VS_AI`. The turn label and pass notice are mode-aware; asserted by the harness `RC1` checks. Was: `PLAYER_NAMES[WHITE] = "Computer"` in every mode, so local PvP mislabeled the human White player.
- **Name overload — "Cell" and "Disc" are both data and UI.** `board[r][c]` (E-R02) and the `cells` UI array (E-P11) share the "cell" concept; the disc value (E-R03) and the disc `TextureRect` (E-P13) share "disc". The C9 coupling is now reduced to the *within-cell* child order (bg `0`, disc `1`); the cell/bg/disc references themselves are named (`cells[r][c].cell/.bg/.disc`).
- **Dead fields/entities.** `board_container` (E-P*, declared line 17, never used; a local `board_container_node` is used) and `PLAYER_COLORS` (line 12, never used). Production clutter; remove or wire up.
- **Missing entity — legal-move affordance: RESOLVED.** E-P16 (Legal-move highlight) added; implemented as `_refresh_legal_hints` with `CELL_HINT_COLOR`; asserted by S6-AT-10. Was: no entity highlighted legal cells for the human player; the review's "Readable board" pillar was therefore only Partial.
- **Missing entities — deferred systems.** No Save/Settings entity (S11), no Audio-cue entity (S12), no localization-key entity (S13), no accessibility focus-order/theme entity (S14). All are deferred by `systems-index.md`.
- **Boundary gap — terminal lock.** E-R13 is enforced in `_on_cell_pressed` (E-A01), not in `_execute_move` (E-R06); the spec boundary is ambiguous (review C5).
- **Typed-return gap (C8): RESOLVED.** E-A03 (`_get_best_move`) now returns the typed `NO_MOVE` sentinel (`Vector2i(-1, -1)`) instead of `null`, so the signature and the contract agree; `_ai_move` checks the sentinel. Asserted by S5-AT-7.

# Duplicates / Consolidation

- E-R06 (Move) and E-A01 (Human input) overlap in `_on_cell_pressed`; keep separate (rule action vs. input source) but document the call boundary.
- E-R09 (score) is computed in two places (`_update_ui_state`, `_end_game`); consolidate into one counting helper to avoid drift.
- Flipping logic appears in E-R08 only, but the AI reaches it via E-R06, so rule changes propagate; no duplicate capture logic exists (good).

# Scope Decision

| Decision | Entities |
|----------|----------|
| **In — P0 (playable slice)** | E-R01..E-R13, E-A01..E-A05, E-P01, E-P05..E-P16, E-B01..E-B03, E-T01..E-T03 |
| **In — P1 (prototype quality)** | E-C01, E-C02, E-P02..E-P04, E-P09, E-P15 |
| **Deferred — P2** | Save/Settings (S11), Audio cues (S12), Localization keys (S13), Accessibility focus/theme (S14) |
| **Proposed (not scheduled)** | (none — E-P16 promoted to In P0) |
| **Cut** | None |
| **Unknown** | None blocking the prototype |

# Risks & Assumptions

- **Assumption (verified from source):** all listed entities map to real symbols; nothing here is invented.
- **Assumption (unverified):** player comprehension of the status label and score readouts is assumed; no playtest exists.
- **Risk (medium):** the "Computer" label in PvP mode was a player-facing clarity defect (RC1, resolved); the legal-move highlight is now implemented (E-P16, S6-AT-10). Remaining: accessibility (contrast/keyboard) and the child-index coupling (C9).
- **Risk (low/medium):** the dead fields and name overloads raise the chance a UI refactor silently breaks rendering (ties to review C9).
- **Unverified:** difficulty feel, Hard-difficulty timing, restart behavior, and pass-timing feedback have no automated or playtest evidence.

# Changed Files

- `design/entities/entity-inventory.md` — this inventory (new).
- `design/gdd.md` — adds an Entities section linking this inventory.

# Verification Evidence

- `godot --headless --path src -s res://scripts/verify_othello.gd` → 88 checks, 0 failures, exit 0 (backs E-R*, E-C02, E-A02 validation signals).
- `godot --headless --path src --quit-after 90` → exit 0 (backs E-B*, E-P* load signals).
- `./codex-game-studio status` → `entity-inventory: complete` once this file exists.
- `./codex-game-studio validate` → 1216 PASS / 0 FAIL.

# Next Owner / Decision

- **Decision requested:** accept this entity inventory and its scope decisions (In P0/P1, Deferred P2, proposed legal-move highlight).
- **Follow-up owners:** ui-programmer + gameplay-programmer for the dead fields (`board_container`, `PLAYER_COLORS`); ui-ux-designer for accessibility (contrast/keyboard); systems-designer for the E-R09 counting consolidation; ui-programmer for C9 cell-child refactor before further cell art.
- **Next workflow:** `review-all-gdds` or `vertical-slice`. If `vertical-slice`, this inventory is its entity checklist.
