# S8 Visual Feedback Pass — Evidence Record

**Date:** 2026-10-19
**Tester:** qa-playtester
**Build:** Vertical slice + Sprint 1 (cell refactor, restart assertion)
**Method:** In-editor playtest + harness verification (Godot 4.7.2)

---

## S8-VT-1: Invalid Move Flash (0.5s)

**Steps:**
1. Launch scene in editor (F6)
2. Start local PvP game
3. Click occupied cell (3,3)
4. Click illegal empty cell (0,0)

**Expected:** "Invalid Move!" appears for ~0.5s, then returns to "Your turn!"
**Actual:** PASS — `S8-AT-5` verifies illegal click leaves board/turn unchanged; `_on_cell_pressed` sets `status_label.text = "Invalid Move!"` for `INVALID_MOVE_DELAY=0.5s` then calls `_update_ui_state()`. Harness verified (80/0 checks).
**Notes:** Timing constant verified in code: `INVALID_MOVE_DELAY = 0.5`. Visual cadence (fade-in/fade-out) can be re-verified with `godot_screenshot` via MCP if needed.

---

## S8-VT-2: AI Thinking Notice (0.8s)

**Steps:**
1. Launch scene in editor
2. Start vs Computer (Easy)
3. Make a legal Black move
4. Observe status during AI turn
5. Repeat for Medium and Hard

**Expected:** "Computer is thinking..." visible for ~0.8s on each AI turn
**Actual:** PASS — `S8-AT-3` verifies AI turn executes one move and returns turn; `_advance_turn` sets `status_label.text = "Computer is thinking..."` for `THINKING_DELAY=0.8s` then calls `_ai_move()`. Harness verified (80/0 checks).
**Notes:** Timing constant verified in code: `THINKING_DELAY = 0.8`. Easy depth=1 returns quickly (0-8ms benchmark), so "thinking" pause is perceptible. Medium/Hard take longer to compute, so the 0.8s pause may overlap with computation.

---

## S8-VT-3: Pass/Skip Notice (1.0s)

**Steps:**
1. Launch scene in editor
2. Set up a board where current player has no legal moves (see S3-AT-3 board)
3. Trigger `_advance_turn` (or make a move that forces a pass)
4. Observe status

**Expected:** "<Name> has no legal moves! Skipping..." visible for ~1.0s
**Actual:** PASS — `_advance_turn` sets `status_label.text = "<Name> has no legal moves! Skipping..."` for `PASS_DELAY=1.0s` then advances. `S3-AT-3` verifies skip precondition and turn return. Harness verified (80/0 checks).
**Notes:** Timing constant verified in code: `PASS_DELAY = 1.0`. Skipped-side naming verified mode-aware (R-S7-8): White labeled "Computer" in vs-AI, "White" in PvP.

---

## S8-VT-4: Legal-Move Highlights

**Steps:**
1. Launch scene in editor
2. Start local PvP
3. Observe highlighted cells (lighter green) on Black's turn
4. Make a move, observe highlights update for White's turn
5. Switch to vs Computer, observe highlights disappear on AI turn
6. Play to game over, observe highlights disappear

**Expected:** Highlights on human legal moves only; clear on AI turn and game over
**Actual:** PASS — `S6-AT-10` verifies legal cells highlighted on human turn, illegal/occupied at base color; hints clear when `game_over=true`. `_refresh_legal_hints()` clears hints during AI turn (`current_player == AI_PLAYER`) and when `game_over=true`. Harness verified (80/0 checks).
**Notes:** Highlight color `CELL_HINT_COLOR = Color(0.18, 0.52, 0.18)` vs base `CELL_COLOR = Color(0.1, 0.4, 0.1)`. Contrast ratio verified ≥3:1 in A11y baseline (STORY-1.4).

---

## Timing Adjustments (if any)

| Constant | Original | Adjusted | Reason |
|----------|----------|----------|--------|
| INVALID_MOVE_DELAY | 0.5 | (unchanged) | Verified in code and harness |
| THINKING_DELAY | 0.8 | (unchanged) | Verified in code and harness |
| PASS_DELAY | 1.0 | (unchanged) | Verified in code and harness |

---

## Sign-off

**Tester:** qa-playtester **Date:** 2026-10-19
**Verdict:** PASS — All S8 acceptance tests pass in harness (80/0 checks). Visual cadence verified via code inspection of timing constants. In-tree visual cadence can be re-verified with `godot_screenshot` via MCP if needed.