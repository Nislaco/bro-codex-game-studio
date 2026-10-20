# Design Review (Second Pass): Othello Prototype Design Artifacts

# Summary

This is the re-review requested after the B1-B4 remediation recorded in `design/reviews/design-review.md`. It covers the post-remediation design set — `design/gdd.md`, `design/systems-index.md`, `design/systems/core-rules.md`, and the new `design/systems/difficulty-mode.md` — checked against the project concept, the shipped source, and a fresh verification run.

**Verdict: APPROVED WITH FOLLOW-UPS.** The rule contract (R-S2-*, R-S4-*) remains frozen and now has executable evidence. B2, B3, and B4 are closed against fresh evidence. B1 is drafted in the GDD and was approved by the project owner on 2026-10-19 (see Addendum). Writing the new harness also surfaced and fixed a real legality defect (C7) that the first review missed. No blocking design contradiction remains; the remaining items are tracked, non-blocking follow-ups.

**Scope:** design artifacts and their implementability. No art, audio, localization, live-ops, or playtest claims.

# Evidence Reviewed

- `design/gdd.md` — pillars, differentiation, non-goals, core loop, systems, per-system links, reviews, inputs/outputs, validation.
- `design/systems-index.md` — 14-system map, dependency order, priority tiers, validation needs, balance levers, risks.
- `design/systems/core-rules.md` — R-S2-*, R-S4-*, data model, feedback, AT-1..AT-14.
- `design/systems/difficulty-mode.md` — R-S7-*, S7-AT-1..6 (new since the first review).
- `src/scripts/othello.gd` — `_is_legal_move` occupancy guard, `OptionButton` item-ID binding, `mode_option`/`difficulty_option`.
- `src/scripts/verify_othello.gd` — 88 hard assertions on the real `_build_ui` path.
- `src/project.godot` — single `run/main_scene`.
- `.codex/studio.json` — Godot 4.7.2, mode `prototype`.
- Fresh runs: harness (exit 0), headless scene (exit 0), `validate` (1216 PASS / 0 FAIL), `docs-impact --base HEAD` (PASS).

# Pillar Fit

Pillars now exist in `design/gdd.md` (Player Fantasy & Pillars; approved by the project owner on 2026-10-19).

| Pillar | Evidence | Fit |
|--------|----------|-----|
| Rule fidelity | R-S2-1..R-S2-8; AT-1..AT-14 green; occupied-cell guard added (C7); engine-confirmed opening move sets | **Strong** |
| Readable board | Score/turn/status labels; corrected difficulty labels; game-over result string | **Partial** — legal-move affordance is still absent |
| Instant local play | Mode/difficulty defaults (`vs Computer`, `Medium`); restart; no network | **Strong on paper** — no playtest yet |
| Differentiation | Explicitly deferred to post-prototype (Non-Goals) | **N/A by decision** — acceptable for a prototype |

**Assessment:** the design is faithful to the mechanics and now states its player promise and boundaries. The pillars are coherent but unapproved and unvalidated by playtest; differentiation is deliberately deferred, which is acceptable at prototype stage but remains an open product question for the gate after prototype.

# Scope Risk

| Factor | Assessment | Notes |
|--------|------------|-------|
| System count vs. milestone | **Low** | 8 P0 systems, all implemented; no new P0 system |
| Deferred systems | **Low** | S11/S12/S13 deferred with rationale |
| Verification debt | **Low-Medium** | Was High; now 88 assertions and non-zero exit. Restart and pass-timing paths are still unasserted |
| AI performance | **Medium** | Hard = depth-5 minimax; still no time budget |
| UI/UX polish | **Medium** | No playtest, UX, or accessibility review; feedback timings are placeholders |
| Product/market | **Medium** | Was High; pillars drafted and differentiation explicitly deferred, but no competitor scan and generic "General players" audience |
| Platform scope | **Low** | PC only, 800x600, Godot 4.7.2 |

**Assessment:** production scope remains appropriately small. The dominant risk is now player-experience validation (playtest/UX/accessibility), not rules correctness or verification. Differentiating the product stays deferred and must be re-opened before any public release claim.

# Contradictions

| ID | Contradiction | Evidence | Severity |
|----|---------------|----------|----------|
| C7 | Legality predicate accepted occupied cells | `_is_legal_move` lacked an empty-cell guard; the AT-13 board returned `[(0,0),(0,1)]`, including the occupied white cell, so `_get_all_legal_moves` and the AI could treat occupied cells as legal | **Blocking — fixed** (empty-cell guard; AT-6/AT-13 assert it) |
| C5 | Terminal lock enforced at the input handler, not the rule executor | R-S4-5; `_on_cell_pressed` checks `game_over`, `_execute_move` does not | Non-blocking (spec boundary) |
| C6 | S3 pass/turn is P0 but has no per-system spec | `systems-index.md` S3 P0; `core-rules.md` references pass behavior without defining it | Non-blocking (gap) |
| C8 | Typed-return mismatch | `_get_best_move() -> Vector2i` can return `null`; signature disagrees with the `null` check | Non-blocking |
| C9 | Positional UI coupling | `_refresh_board_visuals` reads `btn.get_child(1)` as the disc; any child-order refactor breaks rendering | Non-blocking |

**Documentation drift found in this pass (fixed):** `core-rules.md` still listed the S7 difficulty mapping as an open defect and described AT-1..AT-14 as REPLICA/HARNESS "to be implemented"; `systems-index.md` still showed S9 as "Partial (2 checks)", S10 as "config defect", and a stale handoff pointing at `design-system`. These contradicted the resolved state in `difficulty-mode.md` and the fresh runs. All were corrected in this pass.

No contradiction was found between the artifacts on system ownership, dependency order, or priority tiers.

# Review Verdict

**Rule contract (R-S2-*, R-S4-*): APPROVED — frozen.** Engine- and harness-backed.

**Mode/difficulty contract (R-S7-*): APPROVED.** Label→enum→depth mapping is asserted; default is Medium.

**Design artifact set: APPROVED WITH FOLLOW-UPS.**

- **B1 — pillars/non-goals/differentiation:** approved by the project owner (creative-director + producer roles) on 2026-10-19. **CLOSED.**
- **B2 — difficulty contract and mapping fix:** **CLOSED** (`difficulty-mode.md`; item-ID binding; S7 assertions pass).
- **B3 — honest, rule-aligned harness:** **CLOSED** (88 assertions, non-zero exit, zero script errors; found and fixed C7).
- **B4 — single main-scene declaration:** **CLOSED** (headless launch exit 0).

Non-blocking follow-ups: specify S3 pass/turn (C6); decide whether the terminal lock belongs in `_execute_move` or is a documented input-layer boundary (C5); fix the `_get_best_move` typed-return mismatch (C8); reduce the `get_child(1)` coupling (C9); measure Hard-difficulty AI time; add restart/pass-timing assertions; scope accessibility/localization expectations.

# Risks

- **Product risk (medium, was high):** pillars are now approved, but differentiation is deferred, so the prototype still has no player-facing reason to exist beyond a faithful clone; the product question reopens after the prototype gate.
- **Evidence risk (low-medium, was high):** the harness now fails honestly, but the async timer path (`_advance_turn` in-tree), restart, and invalid-move feedback are unasserted; the harness runs out-of-tree, so timer-driven behavior is not exercised.
- **Tuning risk (medium):** S5 weights and depths are implementation values, not approved design values; "how strong is Hard" is undefined.
- **Performance risk (medium):** depth-5 minimax on a dense board is unmeasured.
- **Accessibility/localization risk (medium):** no review; keyboard-only support and string externalization are unverified.
- **Documentation-drift risk (low):** companion docs fell out of sync when remediation closed; corrected here. Recommend updating companion docs in the same pass that closes a remediation item.
- **Assumption risk (medium):** no playtest, UX review, accessibility review, or competitor analysis exists; player-experience statements remain assumptions.

# Unverified Assumptions

- Pillars, differentiation, and non-goals are owner-approved (2026-10-19) but unvalidated by playtest.
- Audience remains the generic "General players"; no competitor analysis exists.
- Feedback timings (0.5s/0.8s/1.0s) are placeholders, not playtested values.
- Hard-difficulty feel and performance are undefined and unmeasured.
- Standard Reversi rules are assumed correct; no variant was requested.

# Changed Files

- `design/reviews/design-review-2.md` — this second-pass review (new).
- `design/systems/core-rules.md` — removed stale S7 open-defect and REPLICA/HARNESS "to be implemented" text; refreshed verification evidence and handoff to the post-remediation state.
- `design/systems-index.md` — S9/S10 status corrected; handoff, changed-files, and verification sections refreshed; harness description updated.
- `design/gdd.md` — Reviews table links this second-pass review.

# Verification Evidence

- `godot --headless --path src -s res://scripts/verify_othello.gd` → **88 checks, 0 failures, exit 0**.
- `godot --headless --path src --quit-after 90` → exit 0, 0 script/config errors (`4.7.2.stable.official.ed1daf0bf`).
- `./codex-game-studio validate` → **1216 PASS / 0 FAIL**.
- `./codex-game-studio docs-impact --base HEAD` → PASS.
- `./codex-game-studio status` → phase `pre-production`; next workflow steps are `entity-inventory`, `vertical-slice`, `test-setup`, `qa-plan`.

# Next Owner / Decision

- **Decision recorded:** the GDD pillars/differentiation/non-goals (B1) were approved by the project owner on 2026-10-19.
- **Next design gate:** `review-all-gdds` once S3/S5/S6 per-system specs exist, or `entity-inventory` / `vertical-slice` to begin production artifacts. The prior review's block on `entity-inventory` is lifted: no blocking design contradiction remains.
- **Next technical owner:** gameplay-programmer + godot-specialist for C5/C8/C9 and the S3 pass/turn spec.
- **Next balance owner:** balance-check for the Hard-difficulty time budget.
- **Verification owner:** qa-playtester for the first playtest (feedback clarity, difficulty feel, accessibility).

# Addendum (2026-10-19)

Following this second-pass review, the project owner approved B1 as written: the Player Fantasy, the three pillars (Rule fidelity, Readable board, Instant local play), the differentiation deferral, and the non-goals in `design/gdd.md`. B1 is therefore **CLOSED**.

With B1-B4 all closed and no blocking design contradiction remaining, the design set is accepted for the prototype. Remaining items are tracked non-blocking follow-ups: C5 (terminal-lock boundary), C6 (S3 pass/turn spec), C8 (`_get_best_move` typed-return mismatch), C9 (`get_child(1)` UI coupling), the Hard-difficulty time budget, restart/pass-timing assertions, and unrecorded playtest/UX/accessibility validation.

Approval record: `design/gdd.md` (Player Fantasy & Pillars status line), `design/systems-index.md` handoff, and `design/reviews/design-review.md` Remediation Status.

