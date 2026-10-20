# Othello System GDD: AI Opponent (S5)

# Purpose

Define the player-facing behavior, search contract, tuning levers, edge cases, and acceptance tests for **S5 AI Opponent** — the computer player that selects White's move in `PLAYER_VS_AI`. S5 is P0 and must always return a legal move, respect the turn system, and stay deterministic enough to test. Authoring it closes the S5 spec gap raised by `design/reviews/review-all-gdds.md`.

# Summary

The AI is a deterministic minimax search with alpha-beta pruning over the standard Othello rule set. Its strength is controlled only by search depth (Easy `1`, Medium `3`, Hard `5`) and a small positional evaluation (material, corners, edges, mobility). It chooses exactly one move per turn, then hands the turn back to the human. It carries no randomness, so the same position always yields the same move.

**Scope:** S5 only. S2 supplies legality, S3 owns turn flow and the AI-turn handoff, S4 owns the end/winner decision, S7 owns mode/difficulty selection and the AI side, S6 renders status, S8 owns the thinking-delay feel. This document formalizes the shipped search in `src/scripts/othello.gd`.

# Source Evidence

- `design/systems-index.md` — S5 entry, P0, depends on S2/S4, must respect S3.
- `design/systems/core-rules.md` — R-S2-1 (placement legality), R-S4-2/R-S4-3 (pass/end).
- `design/systems/turn-pass.md` — R-S3-6 (AI turn), R-S3-7 (input gating).
- `design/systems/difficulty-mode.md` — R-S7-6 (AI side), depth mapping.
- `src/scripts/othello.gd` — `AI_PLAYER`, `NO_MOVE`, `_ai_move`, `_get_best_move`, `_minimax`, `_evaluate_board`, `_get_mobility`, `_match_difficulty`.
- `src/scripts/verify_othello.gd` — S5 assertions (`_test_ai_contract`).
- Godot `4.7.2.stable.official.ed1daf0bf`, `--headless --path src`.

# Data Model

| Field | Source | Type / values | Notes |
|-------|--------|---------------|-------|
| AI_PLAYER | `othello.gd` | `WHITE` (`2`) | The AI always plays White |
| game_difficulty | `othello.gd` | `Difficulty` | EASY/MEDIUM/HARD |
| search depth | `_match_difficulty` | `1` / `3` / `5` | Plies searched at the root |
| NO_MOVE | `othello.gd` | `Vector2i(-1, -1)` | Sentinel returned when the AI has no legal move |
| eval: disc | `_evaluate_board` | `10` | Per White disc, minus `10` per Black disc |
| eval: corner | `_evaluate_board` | `100` | Added for a corner disc (rows/cols 0 or 7) |
| eval: edge | `_evaluate_board` | `5` | Added for a non-corner edge disc |
| eval: mobility | `_evaluate_board` / `_get_mobility` | `2` | Per legal move available to each side |

**Invariants**

- The AI's chosen move is always in `_get_all_legal_moves(WHITE)`.
- `board` is identical before and after `_get_best_move` (search restores state).
- Given the same board and difficulty, the AI returns the same cell.
- The AI returns `NO_MOVE` exactly when White has no legal move.

# System Rules — S5 AI Opponent

- **R-S5-1 AI side & mode:** the AI is White (`AI_PLAYER = WHITE`) and takes a move only in `PLAYER_VS_AI` (cross-ref R-S7-6). It never moves for the human.
- **R-S5-2 Legal-move only:** the AI chooses exclusively from `_get_all_legal_moves(WHITE)`; it never plays an occupied or non-capturing cell (cross-ref R-S2-1).
- **R-S5-3 One placement per turn:** the AI makes exactly one placement, then the turn advances (cross-ref R-S3-6).
- **R-S5-4 Search:** minimax with alpha-beta pruning to `_match_difficulty(game_difficulty)` plies (Easy `1`, Medium `3`, Hard `5`).
- **R-S5-5 Evaluation (White's perspective):** material (`10` per disc, corner `+100`, edge `+5`) plus mobility (`2` per legal move), White positive, Black negative.
- **R-S5-6 Determinism:** for a fixed board and difficulty the AI returns the same cell; ties are broken by the first candidate found in row-major order. There is no randomness.
- **R-S5-7 Easy is 1-ply greedy:** at Easy the AI selects the legal move that maximizes the immediate `_evaluate_board()` (depth-1 search collapses to a single evaluation).
- **R-S5-8 Pass handling in search:** when a side has no legal move but the opponent does, the search passes the turn and continues at reduced depth; when neither side can move, the position is evaluated as terminal (cross-ref R-S4-2/R-S4-3).
- **R-S5-9 No-move sentinel:** if the AI has no legal move, `_get_best_move` returns `NO_MOVE` (`Vector2i(-1, -1)`) and `_ai_move` advances the turn without changing the board (cross-ref R-S3-3).
- **R-S5-10 Board restore:** the search operates on copies and leaves `board` exactly as it found it.
- **R-S5-11 Human-turn guarantee:** the AI holds no turn of its own; it acts only when the turn reaches White in `PLAYER_VS_AI` (cross-ref R-S3-6/R-S3-7).

# Feedback

| State | Player-facing signal | Source |
|-------|----------------------|--------|
| AI turn begins | `status_label` = "Computer is thinking..." for ~`0.8s` | `_advance_turn` (R-S3-9) |
| AI move placed | Board updates: one White disc added, flanked lines flip | `_execute_move` / `_refresh_board_visuals` |
| AI blocked | Turn passes; the skip notice names "Computer" (R-S7-8) | `_advance_turn` (R-S3-3) |

# Balance Levers

Values inspectable in `src/scripts/othello.gd`:

- **Search depth (primary strength lever):** Easy `1`, Medium `3`, Hard `5` (`_match_difficulty`).
- **Evaluation weights:** disc `10`, corner `100`, edge `5`, mobility `2` per legal move (`_evaluate_board`, `_get_mobility`).
- **No time budget:** Hard depth `5` runs uncapped; hardness is bounded only by the search cost.

These are tuning levers, not approved values. Easy is *not* weakened by a mistake model or randomness; it is simply shallow.

# Edge Cases

1. **Only one legal move:** the AI must take it.
2. **AI blocked:** no legal White move → `NO_MOVE` and a pass with no board change (R-S5-9).
3. **Board restoration:** after choosing, `board` must be byte-identical to before the search (R-S5-10).
4. **Ties:** resolved by row-major first-found, so the choice is stable (R-S5-6).
5. **Search pass recursion:** if both sides are blocked mid-search, the position is scored as terminal rather than recursing forever (R-S5-8).
6. **Hard-difficulty cost:** depth `5` with mobility recomputed at every leaf may be slow on weak hardware; unmeasured.
7. **No variety:** because the AI is deterministic, repeated positions look robotic.
8. **Heuristic blind spots:** the evaluation ignores parity, frontier discs, and late-game disc-differential weighting, so "strength" is only an approximation.

# Acceptance Tests

Method: **HARNESS** = asserted in `src/scripts/verify_othello.gd` against Godot 4.7.2; the run exits non-zero on failure.

| ID | Given | When | Then | Method |
|----|-------|------|------|--------|
| S5-AT-1 | Opening position, vs-AI | `_get_best_move()` | returns a legal White move | HARNESS |
| S5-AT-2 | One-move mid-game board | `_get_best_move()` at Easy/Medium/Hard | each returns a legal move | HARNESS |
| S5-AT-3 | One-move mid-game board, Easy | `_get_best_move()` vs. independent greedy argmax | identical cell (1-ply greedy) | HARNESS |
| S5-AT-4 | Same board, Medium | `_get_best_move()` twice | identical cell (deterministic) | HARNESS |
| S5-AT-5 | Legality set | compare chosen move to `_get_all_legal_moves(WHITE)` | chosen ∈ legal set | HARNESS |
| S5-AT-6 | Any searched board | `_get_best_move()` | `board` unchanged afterward | HARNESS |
| S5-AT-7 | AI has no legal move | `_get_best_move()` / `_ai_move()` | returns `NO_MOVE`; board unchanged; turn returns to Black | HARNESS |

# Open Questions / Unverified Assumptions

- **Unverified:** Hard-difficulty search time (no time budget or benchmark) — depth-5 cost is not measured.
- **Unverified:** playing strength of each difficulty versus a human; no playtest or Elo-style evidence exists.
- **Unverified:** deeper search (depth ≥ 3) quality — only the depth-1 greedy behavior is asserted against an independent computation.
- **Assumption:** minimax + material/corner/edge/mobility is "good enough" for a prototype; no opening book or endgame solver.
- **Assumption:** determinism is acceptable (no variety requirement for the prototype).

# Risks

- **Hard-difficulty performance (medium):** depth `5` has no time budget; a slow board could stall the UI. Needs a timing benchmark before the prototype gate.
- **Untested strength (medium):** evaluation weights are unvalidated against real play; Easy may feel too strong (it still plays legally optimal 1-ply) and Hard may feel slow rather than smart.
- **Determinism / no variety (low):** the AI repeats itself; a small tie-break variety option may be needed later.
- **Search cost (low):** mobility is recomputed at every leaf (`_get_mobility`), which is expensive; fine at depth 1/3, worst at depth 5.
- **Defect fixed (C8):** `_get_best_move() -> Vector2i` previously returned `null` on a blocked board, which raised `Trying to return a value of type "Nil" from a function whose return type is "Vector2i"`. Replaced with the typed `NO_MOVE` sentinel; the `== null` guard in `_ai_move` is gone. Asserted by S5-AT-7.

# Changed Files

- `design/systems/ai-opponent.md` — this system GDD (new).
- `design/gdd.md` — per-system table links this document.
- `design/systems-index.md` — S5 row, validation, S9 coverage, and typed-return risk updated.
- `src/scripts/othello.gd` — added `NO_MOVE` sentinel; `_get_best_move` and `_ai_move` now type-safe (C8 fix).
- `src/scripts/verify_othello.gd` — S5-AT-1..7 assertions added (`_test_ai_contract`).

# Verification Evidence

- `godot --headless --path src -s res://scripts/verify_othello.gd` → 88 checks, 0 failures, exit 0 (includes S5-AT-1..7).
- `godot --headless --path src --quit-after 90` → exit 0, no script errors.
- `./codex-game-studio validate` → 1216 PASS / 0 FAIL.

# Next Owner / Decision

- **Decision requested:** approve R-S5-1..R-S5-11 as the frozen AI contract.
- **Next design owner:** ui-ux-designer for the S6 UI-shell spec next.
- **Verification owner:** qa-playtester adds a Hard-difficulty timing budget and a golden depth-3 mid-game expectation.
- **Follow-up:** S8 owns the "thinking" delay presentation; S7 owns whether difficulty should add variety.
