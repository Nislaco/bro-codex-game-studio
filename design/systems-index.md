# Othello Systems Index

# Purpose

Decompose the Othello prototype into implementable systems, record their dependency order and priority tiers, and define the validation each system needs before the project leaves concept/systems design.

# Summary

The prototype is a local, single-screen Othello (Reversi) game for one player against a computer opponent or two local players. Source review shows the core loop already exists in `src/scripts/othello.gd`: an 8x8 board, directional capture/flip resolution, turn passing, score tracking, end detection, and a minimax AI. This index treats the existing code as implementation evidence, not as proof of design quality. The systems are grouped into a P0 playable slice (board, capture, turns, scoring, AI, UI shell, engine bootstrap, verification), a P1 quality slice (settings correctness, feedback/game feel, accessibility), and deferred systems (persistence, audio, localization). The decision needed is approval of this map before starting `design-system` work on the capture and scoring rules.

# Source Evidence

- `.codex/studio.json` — project `othello`, engine `godot` 4.7.2, mode `prototype`, concept text.
- `design/gdd.md` — concept, core loop, inputs/outputs, validation sections (core loop still high level).
- `src/project.godot` — Godot config, main scene `res://scenes/main.tscn`, 800x600 viewport.
- `src/scenes/main.tscn` — single `Control` scene bound to `othello.gd`.
- `src/scripts/othello.gd` — board state, `_is_legal_move`, `_check_direction`, `_execute_move`, `_flip_in_direction`, `_advance_turn`, `_end_game`, `_update_ui_state`, `_get_best_move`, `_minimax`, `_evaluate_board`.
- `src/scripts/verify_othello.gd` — assertion harness for AT-1..AT-14 and the S7 mode/difficulty, S3 turn/pass, S5 AI, S6 UI-shell, and S8 feedback contracts (88 checks).
- `docs/market-overview.md` — seed audience note only; no competitor analysis yet.

Source-read observations are labeled as such below. No playtest session has been recorded for this game, so player-experience claims remain unverified.

# Systems Map

| ID | System | Responsibility | Current implementation evidence | Status |
|----|--------|----------------|---------------------------------|--------|
| S1 | Board & coordinate state | 8x8 grid, disc values, bounds, initial setup | `board`, `_new_game`, `_in_bounds`, `BOARD_SIZE` | Implemented |
| S2 | Move legality & capture | Directional flank detection, multi-direction flips, occupied/illegal rejection | `_is_legal_move`, `_check_direction`, `_execute_move`, `_flip_in_direction` | Implemented |
| S3 | Turn & pass handling | Alternate players, skip a player with no legal moves, detect double pass | `current_player`, `_advance_turn`, `_has_any_legal_moves`; contract in `design/systems/turn-pass.md` | Implemented, asserted |
| S4 | Scoring & end conditions | Disc counts, full-board/terminal detection, winner or draw | `_update_ui_state`, `_end_game` | Implemented |
| S5 | AI opponent | Move search, evaluation, difficulty depth | `_ai_move`, `_get_best_move`, `_minimax`, `_evaluate_board`, `_get_mobility`, `NO_MOVE`; contract in `design/systems/ai-opponent.md` | Implemented, asserted; tuning unvalidated |
| S6 | Presentation / UI shell | Board grid, discs, score, turn, status, restart | `_build_ui`, `_refresh_board_visuals`, `_make_disc_texture`, `_refresh_legal_hints`; contract in `design/systems/ui-shell.md` | Implemented, asserted |
| S7 | Mode & difficulty settings | Player-vs-AI / player-vs-player, easy/medium/hard depth | `Mode`, `Difficulty`, `mode_option`, `difficulty_option`; contract in `design/systems/difficulty-mode.md` | Implemented, mapping fixed and asserted |
| S8 | Feedback & game feel | Invalid-move message, thinking delay, pass notice, restart, legal-move highlight | `status_label`, timers in `_on_cell_pressed` / `_advance_turn`, `_refresh_legal_hints`; contract in `design/systems/feedback.md` | Implemented, asserted |
| S9 | Verification harness | Automated checks for turn flow, AI response, difficulty, UI shell, and feedback | `verify_othello.gd` | Implemented (88 assertions, exits non-zero on failure) |
| S10 | Engine bootstrap & scene | Project settings, main scene, script binding | `src/project.godot`, `src/scenes/main.tscn` | Implemented, config normalized |
| S11 | Persistence / save | Resume game or settings across sessions | None | Deferred |
| S12 | Audio | Disc placement, capture, win/lose cues | None | Deferred |
| S13 | Localization | Externalized player-facing strings | Hardcoded English strings | Deferred |
| S14 | Accessibility | Keyboard navigation, contrast, readable status, reduced motion | Default Godot focus behavior only | Partial / unverified |

# Dependency Order

1. **S10 Engine bootstrap** — everything runs inside the Godot project and main scene.
2. **S1 Board state** — no rule or UI system can operate without the grid.
3. **S2 Move legality & capture** — depends on S1; defines the core rule.
4. **S3 Turn & pass handling** — depends on S2 (a "no legal move" check is legality-driven).
5. **S4 Scoring & end conditions** — depends on S1 and S3 (terminal state follows pass/full-board logic).
6. **S5 AI opponent** — depends on S2 (legal moves) and S4/S1 (evaluation inputs); must respect S3 turn flow.
7. **S6 Presentation / UI shell** — depends on S1, S4, S5 (renders state and AI status).
8. **S7 Mode & difficulty** — depends on S3, S5, S6 (selects turn ownership and AI depth).
9. **S8 Feedback & game feel** — depends on S6 and rule outcomes from S2/S3.
10. **S9 Verification harness** — depends on S1-S5; validates rules and AI without the real UI.
11. **S14 Accessibility** — depends on S6; improves the existing shell.
12. **S11 Persistence, S12 Audio, S13 Localization** — depend on stable S1/S4/S6 contracts; intentionally after the P0 slice.

# Priority Tier

| Tier | Systems | Rationale |
|------|---------|-----------|
| **P0 — playable prototype** | S1, S2, S3, S4, S5, S6, S9, S10 | Without these the game is not a complete Othello loop against the computer. |
| **P1 — prototype quality** | S7, S8, S14 | Correct settings, understandable feedback, and baseline accessibility make the prototype testable. |
| **P2 — later / deferred** | S11, S12, S13 | Not needed to validate the core loop; add after the prototype gate. |

# Validation Need

| System | Validation method | Acceptance signal |
|--------|-------------------|-------------------|
| S1 | Unit checks in `verify_othello.gd` | Board is 8x8; initial four discs in correct colors/positions; out-of-bounds rejected. |
| S2 | Unit checks + table cases | Legal move flips all flanked lines; illegal/occupied cell changes nothing; multi-direction capture flips every line. |
| S3 | Unit checks | Turn alternates; a blocked player is skipped once; double pass ends the game; input is ignored during the AI turn. |
| S4 | Unit checks | Disc counts match the board; winner/draw text matches counts; no moves accepted after game over. |
| S5 | Deterministic board cases + timing check | AI always returns a legal move; depth maps to easy/medium/hard; the search is deterministic and restores the board; a blocked AI passes; hard search stays within a playable delay. |
| S6 | Headless scene run + manual playtest | Scene loads; cell count/grid, labels, disc rendering, click-to-place, occupied/illegal rejection, legal-move highlighting, and restart are asserted; visual look and resize are manual. |
| S7 | Option-mapping test | Selecting each mode/difficulty label activates the matching enum value. |
| S8 | Manual playtest checklist | Invalid move, pass, thinking, and game-over states are visible and understandable. | In-tree visual check of timing/legibility; harness asserts message preconditions and final state. |
| S9 | Harness run | Harness exits non-zero on failure and covers S1-S5, S7, S3 turn-flow, S6 UI-shell, S8 feedback, and S14 accessibility cases, not just one move. |
| S10 | `godot --headless` scene run | Project opens and the main scene runs without script/config errors. |
| S11-S13 | Not applicable yet | Deferred; define acceptance when scheduled. |
| S14 | Programmatic contrast audit + live keyboard check + manual pass | WCAG AA contrast measured and asserted (S14-AT-1/2); keyboard-only play verified with real key events; screen-reader support recorded as a post-gate gap. |

# Balance Levers

Values currently inspectable in `src/scripts/othello.gd`:

- **AI depth by difficulty:** easy `1`, medium `3`, hard `5` (`_match_difficulty`).
- **Evaluation weights:** disc `10`, corner `100`, edge `5`, mobility `2` per legal move (`_evaluate_board`, `_get_mobility`).
- **Feedback timing:** invalid move `0.5s`, AI "thinking" `0.8s`, pass notice `1.0s`.
- **Board presentation:** `CELL_SIZE = 60`, disc texture `50px`, base cell `Color(0.16, 0.44, 0.16)`, legal-move hint `Color(0.95, 0.78, 0.25)` (WCAG AA contrast, colorblind-distinct).

These are tuning levers, not approved values. Any change needs a playtest note and an updated validation case.

# Edge Cases

- A move that captures in several directions at once must flip every valid line.
- A player with no legal move must be skipped exactly once; if both players have none, the game ends.
- Clicking an occupied or non-capturing cell must leave the board unchanged and show feedback.
- The board may end before all 64 cells are filled (double pass), so end detection must not rely on a full board alone.
- The AI must still return a legal move when only one exists.
- Hard difficulty (`depth 5`) may be slow on weaker hardware; measure before shipping.

# Risks & Gaps

- **Difficulty mapping (S7): RESOLVED.** The option now binds labels to enum values through item IDs (`add_item(label, id)` + `get_item_id`), the default selection is Medium, and `verify_othello.gd` asserts label order, id-to-depth mapping, default, and live selection. Contract recorded in `design/systems/difficulty-mode.md`. Was: labels `Medium`/`Easy`/`Hard` assigned by index, swapping Medium and Easy.
- **Config risk (S10): RESOLVED.** `src/project.godot` now declares a single `run/main_scene="res://scenes/main.tscn"`; the non-standard `config/main_scene` was removed and a headless launch passes.
- **Typed-return risk (C8): RESOLVED.** `_get_best_move() -> Vector2i` now returns the typed `NO_MOVE` sentinel (`Vector2i(-1, -1)`) instead of `null`; the `== null` guard in `_ai_move` is gone and S5-AT-7 asserts the behavior. Contract recorded in `design/systems/ai-opponent.md`.
- **Verification (S9): IMPROVED.** `verify_othello.gd` now runs 88 hard assertions (AT-1..AT-14 plus S7-AT-1..7, S3-AT-1..7, S5-AT-1..7, S6-AT-1..10, S8-AT-1..6, and S14-AT-1..6) and exits non-zero on failure; it also caught and fixed a legality defect (`_is_legal_move` did not reject occupied cells). Remaining gaps: in-tree visual feedback cadence and layout/resize are not asserted.
- **UI gaps (S6): RESOLVED.** RC3 (missing legal-move affordance) and RC4 (silent occupied-cell click) are fixed and asserted — legal cells are highlighted (`_refresh_legal_hints`) and occupied/illegal clicks show "Invalid Move!". Contract recorded in `design/systems/ui-shell.md`; the child-index coupling (C9) remains a follow-up.
- **Accessibility (S14): RESOLVED (baseline).** WCAG AA contrast measured and asserted (S14-AT-1/2), keyboard-only play verified with real key events (S14-AT-3/4), and the palette was corrected (base `Color(0.16,0.44,0.16)`, hint `Color(0.95,0.78,0.25)`). Eight defects were found and fixed, including a **broken mouse-click path** caused by the `gui_input` bind-order contract. Screen-reader announcements and focus-visible styling remain post-gate gaps. Evidence: `production/playtest/a11y-baseline-2026-10-19.md`.
- **Localization (S13): PARTIAL.** Strings are externalized to `src/translations/strings.csv` with a runtime locale switch; the CSV was previously outside the Godot project root and never loaded (found and fixed by live runtime inspection).
- **No persistence:** a versioned save schema exists (`othello_save_v1.json`) but auto-save on quit is not wired.
- **Market evidence is a seed only:** audience/competitor claims are not yet researched.

# Assumptions

- Target experience is single-player vs a computer opponent plus local two-player; no online play.
- No monetization, progression, or meta-game is in scope for the prototype.
- "Playable" means a full game can be completed without developer intervention and with visible score/turn state.
- Architecture is recorded as a stub in `docs/architecture/README.md`; art direction is not yet decided.

# Handoff

- **Artifact owner:** systems-designer (this index); producer confirms priority tiers.
- **Design status:** S2/S4 rules (`core-rules.md`) and S7 mode/difficulty (`difficulty-mode.md`) are specified, asserted, and accepted by `design-review-2`.
- **Decision recorded:** GDD pillars/non-goals approved (B1, 2026-10-19); next gate is `entity-inventory` or `review-all-gdds`.
- **Next technical owner:** gameplay-programmer + godot-specialist for the S3 pass/turn spec, S5 Hard-difficulty timing, and the `_get_best_move` typed-return mismatch.
- **Verification owner:** qa-playtester extends `verify_othello.gd` with restart and pass-timing assertions against the validation table.
- **Ordering note:** do not schedule S11-S13 until the P0 slice and a recorded playtest exist.

# Changed Files

- `design/systems-index.md` — this systems map.
- `design/gdd.md` — Systems and Per-System GDDs sections linking this index.
- `design/systems/core-rules.md` — S2/S4 rule contract.
- `design/systems/difficulty-mode.md` — S7 mode/difficulty contract.
- `design/reviews/design-review.md`, `design/reviews/design-review-2.md` — design reviews.

# Verification Evidence

- `./codex-game-studio status` reports the Systems section complete and phase `pre-production`.
- `.codex/context-manifest.json` is fresh (`./codex-game-studio refresh-context`).
- `./codex-game-studio validate` → 1216 PASS / 0 FAIL.
