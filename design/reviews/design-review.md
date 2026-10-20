# Design Review: Othello Prototype Design Artifacts

# Summary

This review covers the current design set for the Othello prototype: `design/gdd.md`, `design/systems-index.md`, and `design/systems/core-rules.md`, checked against the project concept, implemented source, and the verification surface. The **rule contract for move legality, capture, and scoring is approved** — it matches the shipped engine behavior and is testable. The **artifact set as a whole requires changes before implementation handoff**: the GDD has no explicit pillars/non-goals, the difficulty control has a known mapping defect with no design contract, the existing verification harness contradicts the frozen rules, and `project.godot` has two competing main-scene declarations.

**Scope of this review:** design artifacts and their implementability. It does not review art, audio, localization, or live-ops, and it makes no playtest claims.

# Evidence Reviewed

- `design/gdd.md` — concept, core loop, systems, per-system links, inputs/outputs, validation.
- `design/systems-index.md` — 14-system map, dependency order, priority tiers, validation needs, risks.
- `design/systems/core-rules.md` — R-S2-*, R-S4-*, data model, feedback, AT-1..AT-14.
- `.codex/studio.json` — engine Godot 4.7.2, mode `prototype`, audience "General players".
- `docs/market-overview.md` — seed audience note only; no competitor research.
- `src/scripts/othello.gd`, `src/scripts/verify_othello.gd`, `src/project.godot` — implementation and verification evidence.
- Real Godot 4.7.2 headless run confirming opening legal moves and point legality (see `core-rules.md`).

# Pillar Fit

**No explicit pillars exist.** `design/gdd.md` has no Pillars, Player Fantasy, Non-Goals, or Audience section (headings: Purpose, Core Loop, Systems, Per-System GDDs, Inputs, Outputs, Validation). Pillar fit is therefore assessed against the pillars the artifacts imply.

| Implied pillar | Evidence | Fit |
|----------------|----------|-----|
| Rules-faithful classic Othello | R-S2-1..R-S2-8; engine-confirmed opening move sets; standard 8x8 start | **Strong** — rules are exact and match the shipped engine |
| Readable board state | Score, turn, and status labels; game-over result string; disc textures | **Partial** — state is visible, but legal-move affordance is absent and invalid feedback is transient |
| Low-friction local play | Restart, mode select, difficulty select, AI opponent | **Partial** — flow exists, but the difficulty control is mislabeled (see C3) |
| Distinct player hook | Concept text only; audience "General players"; no competitor analysis | **Absent** — the prototype is undifferentiated classic Othello |

**Assessment:** the design is faithful to the *mechanics* of its implied promise and is internally coherent for a prototype. It does not yet articulate *why a player chooses this over existing Othello implementations*. That is a product/pillars gap (B1), not a rule defect.

# Scope Risk

| Factor | Assessment | Notes |
|--------|------------|-------|
| System count vs. milestone | **Low** | 8 P0 systems, all with existing implementation; no new P0 system is proposed |
| Deferred systems | **Low** | S11 persistence, S12 audio, S13 localization are cleanly deferred with rationale |
| Verification debt | **High** | S9 harness asserts almost nothing and currently contradicts the rules (C1, C2) |
| AI performance | **Medium** | Hard difficulty is depth 5 minimax on a full board; no timing measurement exists |
| UI/UX polish | **Medium** | No UX review, accessibility review, or playtest; feedback is placeholder timing |
| Product/market | **High** | No differentiation, no competitor scan, audience is generic "General players" |
| Platform scope | **Low** | PC only, 800x600, Godot 4.7.2; no second platform commitment |

**Assessment:** production scope is appropriately small for a prototype. The real risk is not scope creep but **verification and product definition**. The systems index keeps the boundary visible, which is good; the next milestone should be gated on the remediation items below, not on adding systems.

# Contradictions

| ID | Contradiction | Evidence | Severity |
|----|---------------|----------|----------|
| C1 | Harness exercises an **illegal move** as a normal step, contradicting frozen rule AT-5 | `core-rules.md` AT-5 says Black `(3,2)` is illegal (engine-confirmed); `verify_othello.gd:27` and `:41` call `_execute_move(3,2,1)` directly | **Blocking** |
| C2 | Harness reports `SUCCESS` while emitting script errors | `verify_othello.gd:60` mocks cells as bare `Button`s; `othello.gd` `_refresh_board_visuals` reads `btn.get_child(1)` as the disc node, producing "Index p_index = 1 is out of bounds" and a null-texture error | **Blocking** |
| C3 | Difficulty labels do not match the enum they set | `othello.gd:66-70` adds `Medium`, `Easy`, `Hard` then assigns the selected index to `Difficulty` (`EASY=0`, `MEDIUM=1`, `HARD=2`); Medium and Easy are swapped and the initial label does not match the default enum | **Blocking** |
| C4 | Two competing main-scene declarations | `src/project.godot:14` `run/main_scene="uid://..."` and `:16` non-standard `config/main_scene="res://scenes/main.tscn"` | **Blocking (technical)** |
| C5 | Terminal lock is enforced at the input handler, not the rule executor | `core-rules.md` R-S4-5 says no move after game over; `_on_cell_pressed` checks `game_over`, but `_execute_move` itself does not | Non-blocking (spec boundary) |
| C6 | S3 pass/turn is P0 but has no per-system spec | `systems-index.md` S3 is P0; `core-rules.md` references pass behavior (R-S4-2) without defining the no-legal-move rule formally | Non-blocking (gap) |

No contradiction was found between `systems-index.md` and `core-rules.md` on system ownership, dependency order, or priority tiers.

# Review Verdict

**Rule contract (R-S2-*, R-S4-*, AT-1..AT-14): APPROVED.** The rules are coherent, engine-grounded, and implementable.

**Design artifact set: CHANGES REQUIRED before implementation handoff.**

Blocking items:

- **B1 — Add pillars and non-goals to the GDD.** At minimum: the intended player promise, 2-3 pillars, explicit non-goals (no online play, no monetization, no progression), and a one-line differentiation statement for the prototype. Owner: creative-director with producer; the senior-game-designer cannot invent product intent unilaterally.
- **B2 — Define the difficulty contract and fix C3.** State what Easy/Medium/Hard should mean (search depth or time budget), fix the label-to-enum mapping, and add the option-mapping acceptance test from `systems-index.md` S7.
- **B3 — Make the harness honest and rule-aligned.** Replace the illegal `(3,2)` step with a legal opening move, mock the `[background, disc]` child contract (or refactor `_refresh_board_visuals` to use named children), and fail the run on any script error. Convert AT-1..AT-14 into assertions.
- **B4 — Normalize `src/project.godot`.** Use exactly one `run/main_scene`, then confirm with a headless launch (C4).

Non-blocking items for a later pass: specify S3 pass/turn rules (C6), move the terminal lock into `_execute_move` or document the boundary (C5), measure hard-difficulty AI time, and scope accessibility/localization expectations for the prototype.

# Risks

- **Product risk (high):** without B1, a technically correct Othello clone has no reason to exist for players; validation may pass while the game is uninteresting.
- **Evidence risk (high):** until B3, the only automated game test can pass on a broken rule set, so later code changes are effectively unverified.
- **Tuning risk (medium):** S5 evaluation weights and depth are implementation values, not approved design values; difficulty meaning is undefined until B2.
- **Performance risk (medium):** depth-5 minimax on a dense board is unmeasured; no frame-time or move-time budget exists.
- **Coupling risk (low/medium):** `_refresh_board_visuals` depends on positional child order (`get_child(1)`); any UI refactor can silently break rendering.
- **Assumption risk (medium):** no playtest, no UX review, no accessibility review, and no competitor analysis exist; all player-experience statements in the design docs are unverified.

# Unverified Assumptions

- The prototype's intended differentiation and target player are unknown; "General players" is the only audience statement.
- Feedback timings (0.5s/0.8s/1.0s) are placeholders, not playtested values.
- Standard Reversi rules are assumed correct for the product; no variant was requested.
- AI difficulty expectations (how strong "Hard" should feel) are undefined.

# Changed Files

- `design/reviews/design-review.md` — this review (new).
- `design/gdd.md` — adds a Reviews link and verdict pointer (see companion edit).

# Verification Evidence

- `./codex-game-studio workflow render design-review` renders the owned workflow prompt.
- Godot 4.7.2 headless evidence for AT-2/AT-3/AT-4/AT-5/AT-6 is recorded in `design/systems/core-rules.md`.
- `godot --headless --path src --quit-after 90` → exit 0, no scene errors.
- `./codex-game-studio validate` and `./codex-game-studio docs-impact --base HEAD` to be re-run after the GDD link edit.

# Next Owner / Decision

- **Decision requested:** accept the rule contract as frozen and schedule the B1-B4 remediation pass before implementation.
- **B1 owner:** creative-director + producer (pillars, non-goals, differentiation).
- **B2/B3/B4 owner:** gameplay-programmer + godot-specialist, verified by qa-playtester.
- **Re-review:** senior-game-designer re-runs this review after B1-B4; the next design gate is `review-all-gdds` or `design-review` repeat, not `entity-inventory`.

# Remediation Status

Executed 2026-10-19 in response to this review.

| Item | Status | Evidence |
|------|--------|----------|
| B1 — pillars, differentiation, non-goals | **Closed (approved 2026-10-19)** | `design/gdd.md` Player Fantasy & Pillars, Differentiation, Non-Goals; project-owner sign-off recorded |
| B2 — difficulty contract + mapping fix | **Closed** | `design/systems/difficulty-mode.md`; `othello.gd` uses item IDs and default Medium; S7 assertions pass |
| B3 — honest, rule-aligned harness | **Closed** | `src/scripts/verify_othello.gd` runs 88 hard assertions, exit non-zero on failure, zero script errors |
| B4 — single main-scene declaration | **Closed** | `src/project.godot` has one `run/main_scene`; headless launch passes |

**New finding during B3 (C7):** writing AT-13 exposed that `_is_legal_move` did not reject occupied cells, and the opening board returned `[(0,0),(0,1)]` (including an occupied cell) as legal moves. Fixed with an empty-cell guard in `_is_legal_move`; AT-6 and AT-13 now guard it.

**Evidence:** `godot --headless --path src -s res://scripts/verify_othello.gd` → 88 checks, 0 failures, exit 0; `godot --headless --path src --quit-after 90` → exit 0; `./codex-game-studio validate` → 1216 PASS / 0 FAIL.

**Residual items:** Hard-difficulty time budget (S5/S7); restart/pass-timing assertions (S9); non-blocking C5/C6/C8/C9.
