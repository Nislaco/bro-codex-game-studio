# Review All GDDs: Othello Design Set

# Summary

Senior-game-designer cross-document review of every current design artifact: `design/gdd.md`, `design/systems-index.md`, `design/systems/core-rules.md`, `design/systems/difficulty-mode.md`, `design/entities/entity-inventory.md`, and the two prior reviews. Scope: contradictions, missing systems, stale assumptions, and implementation blockers across the set (not a re-litigation of the approved contracts).

**Verdict: PROCEED WITH SPECS PENDING.** Cross-document consistency is strong — the rule, difficulty, entity, and review artifacts agree on ownership, dependencies, tiers, and the closed B1-B4 remediation. Two real cross-document defects and one spec-coverage gap block `implement`/`vertical-slice`: **four P0/P1 systems (S3, S5, S6, S8) still have no per-system GDD**, the White side is labeled "Computer" in local PvP, and several validation signals in `systems-index.md` are not yet asserted. All are design-doc work, not new code.

# Scope & Evidence

- `design/gdd.md` — purpose, pillars, differentiation, non-goals, core loop, systems, per-system links, entities, reviews, inputs/outputs/validation.
- `design/systems-index.md` — 14-system map, dependency order, tiers, validation needs, balance levers, risks, handoff.
- `design/systems/core-rules.md` — S2/S4 contract, AT-1..AT-14.
- `design/systems/difficulty-mode.md` — S7 contract, S7-AT-1..6.
- `design/entities/entity-inventory.md` — 41 entities, ownership, gaps, scope.
- `design/reviews/design-review.md`, `design/reviews/design-review-2.md` — prior reviews and B1-B4 closure.
- `docs/architecture/README.md`, `docs/architecture/product-boundary.md`, `docs/market-overview.md` — adjacent docs checked for stale assumptions.
- `.codex/studio.json` — audience "General players", genre "Unspecified", mode `prototype`.
- Verification: harness 30/0 exit 0; `validate` 1216 PASS / 0 FAIL; headless scene exit 0.

# Cross-Document Consistency Matrix

| System | Per-system GDD? | Harness coverage | Cross-doc status |
|--------|-----------------|------------------|------------------|
| S1 Board state | Partial (data model in `core-rules.md`) | AT-1 only; `_in_bounds` not asserted | Consistent; bounds validation unmet |
| S2 Legality & capture | Yes (`core-rules.md`) | AT-2..AT-9, AT-13, AT-14 | Consistent |
| S3 Turn & pass | **No** | AT-10 (double pass only; single skip not asserted) | **Spec missing** |
| S4 Scoring & end | Yes (`core-rules.md`) | AT-10..AT-12 | Consistent |
| S5 AI opponent | **No** | S7-AT-5 (one legal move); timing unmeasured | **Spec missing** |
| S6 Presentation/UI | **No** | Headless load only; click/restart unasserted | **Spec missing** |
| S7 Mode & difficulty | Yes (`difficulty-mode.md`) | S7-AT-1..6 | Consistent |
| S8 Feedback & game feel | **No** | None | **Spec missing** |
| S9 Verification harness | Self (harness) | 88 assertions | Consistent |
| S10 Engine bootstrap | Config only | Headless exit 0 | Consistent |
| S11-S13 Persistence/Audio/L10n | Deferred | N/A | Consistent (deferred with rationale) |
| S14 Accessibility | **No** | None | Deferred/unverified |

Ownership, dependency order, and priority tiers agree across `systems-index.md`, `entity-inventory.md`, and the reviews. No document disagrees about which system owns which rule.

# Contradictions

| ID | Contradiction | Evidence | Severity |
|----|---------------|----------|----------|
| RC1 | The White side is named "Computer" even in local player-vs-player mode | `othello.gd` `PLAYER_NAMES = {BLACK:"Black", WHITE:"Computer"}`; `difficulty-mode.md` R-S7-1 defines `PLAYER_VS_PLAYER` as two local players; `core-rules.md` feedback table and `turn_label` render the name | **Blocking (player-facing)** |
| RC2 | "Architecture not yet decided" vs. an architecture doc that exists | `systems-index.md` Assumptions: "Architecture and art direction are not yet decided" / "does not commit them"; `docs/architecture/README.md` exists but is a stub ("Capture game architecture decisions here") and `product-boundary.md` defines the product boundary | Non-blocking (wording) |
| RC3 | "Readable board" pillar vs. no legal-move affordance | `gdd.md` pillar 2 "score, turn, and match state visible at a glance"; `entity-inventory.md` records a missing "legal-move highlight" entity; `design-review-2.md` scores the pillar **Partial** | Non-blocking (pillar gap) |
| RC4 | Occupied-cell press is a silent no-op | `core-rules.md` R-S2-7 "no-op with no feedback requirement"; `_on_cell_pressed` returns before any feedback; `entity-inventory.md` E-P09 owns "invalid move" feedback | Non-blocking (UX gap) |

No contradiction exists among the rule, difficulty, and entity documents about capture, scoring, pass/end, depth mapping, or entity ownership.

# Missing Systems / Spec Coverage

Ranked by implementation risk:

1. **S3 Turn & pass — no spec.** P0, and end detection depends on it. `core-rules.md` references R-S4-2 pass behavior but the single-skip rule, the "exactly once" guarantee, and the in-tree timer/`await` flow are undefined and unasserted. Owner: systems-designer.
2. **S5 AI opponent — no spec.** P0. Depth is pinned by `difficulty-mode.md`, but move selection, evaluation weights, tie-breaking, and the Hard time budget are not specified. Owner: systems-designer (design) + ai-programmer.
3. **S6 Presentation/UI shell — no spec.** P0. Entities are cataloged but there are no UI rules (layout, focus order, click targets, the `[background, disc]` child contract). Owner: ui-ux-designer.
4. **S8 Feedback & game feel — no spec.** P1. The `core-rules.md` feedback table is partial; timing, pass notice, thinking, and transition behavior need a home. Owner: game-feel-designer.
5. **S14 Accessibility — no spec.** Unverified; acceptable to defer, but record the intent. Owner: accessibility-specialist.

`systems-index.md` also lists validation signals that no artifact currently satisfies: S1 out-of-bounds, S3 single-skip, S6 click-restart, S8 playtest checklist, S14 manual pass.

# Stale Assumptions

- **"No playtest exists"** — still true (`core-rules.md`, `entity-inventory.md`); keep, do not treat feedback timings as validated.
- **"No competitor analysis"** — still true (`market-overview.md` is a seed; `studio.json` `competitors: []`).
- **Genre undefined** — `studio.json` `genre: "Unspecified"` and the GDD has no Audience or Genre section. Acceptable for a prototype, but it is the same product-definition gap that drove B1; note it for the post-prototype gate.
- **"Architecture not decided"** — soften to "architecture is a stub, not authored"; see RC2.
- **Art direction undecided** — true; no `design/art/art-bible.md`.

# Implementation Blockers

| Blocker | Evidence | Owner |
|---------|----------|-------|
| S3/S5/S6/S8 specs missing | Matrix above | systems-designer / ui-ux-designer / game-feel-designer |
| White named "Computer" in PvP | RC1 | ui-programmer + gameplay-programmer |
| Hard-difficulty timing unmeasured | `difficulty-mode.md`, `systems-index.md` S5 | ai-programmer + performance-analyst |
| Terminal lock lives in the input handler | `core-rules.md` R-S4-5, review C5 | gameplay-programmer |
| `_get_best_move() -> Vector2i` can return `null` | review C8 | ai-programmer |
| `_refresh_board_visuals` depends on `get_child(1)` | review C9, entity-inventory | ui-programmer |
| Legal-move affordance absent | RC3 | ui-ux-designer |

# Verdict

**Consistency: PASS.** The design set is internally coherent; the B1-B4 remediation is closed and reflected everywhere; no ownership or dependency conflict was found.

**Coverage: CHANGES PROPOSED before implementation.** Author per-system GDDs for S3, S5, S6, and S8 (S14 optional/deferred), fix RC1, and reconcile the `systems-index.md` validation table with the harness. This is design-doc work; no new systems are introduced.

Because `review-all-gdds` is optional and non-gating, this verdict does not block `status` progression — but `implement`/`vertical-slice` for these systems should wait for their specs.

# Risks

- **Spec gap compounds (high):** implementing S3/S5/S6/S8 without specs repeats the C7 pattern — an unasserted behavior that only a later harness pass catches.
- **Player-facing naming (medium):** RC1 makes local PvP read incorrectly; small fix, visible defect.
- **Validation drift (medium):** the `systems-index.md` validation table promises checks the harness does not run (bounds, single skip, restart), which can be mistaken for coverage.
- **Assumption staleness (low):** RC2 wording could mislead a reader into thinking architecture is authored.
- **Product definition still open (medium):** genre/audience/differentiation remain deferred; fine for prototype, must be revisited at the gate.

# Changed Files / Proposed Files

Changed:
- `design/reviews/review-all-gdds.md` — this review (new).
- `design/gdd.md` — Reviews table links this review.
- `production/session-state/active.md` — session scope.

Proposed (not created in this read-only review):
- `design/systems/turn-pass.md` (S3), `design/systems/ai-opponent.md` (S5), `design/systems/ui-shell.md` (S6), `design/systems/feedback.md` (S8).

# Verification Evidence

- `godot --headless --path src -s res://scripts/verify_othello.gd` → 88 checks, 0 failures, exit 0.
- `godot --headless --path src --quit-after 90` → exit 0.
- `./codex-game-studio validate` → 1216 PASS / 0 FAIL.
- `./codex-game-studio status` → phase `pre-production`; `entity-inventory: complete`; `vertical-slice`/`test-setup`/`qa-plan` pending.

# Next Owner / Decision

- **Decision requested:** accept the consistency verdict and schedule the S3/S5/S6/S8 specs before implementation.
- **Next owner:** systems-designer authors `design/systems/turn-pass.md` first (S3 drives end detection), then S5/S6/S8 with their owners.
- **Immediate non-spec fix:** RC1 ("Computer" label in PvP) via ui-programmer + gameplay-programmer.
- **Follow-up:** reconcile the `systems-index.md` validation table with actual harness coverage.

# Remediation Note (2026-10-19)

- **RC1 — RESOLVED.** `src/scripts/othello.gd` now labels White `Computer` only in `PLAYER_VS_AI` via `_display_name`; local PvP shows `White`, and the mode selector refreshes the turn label immediately. Covered by three `RC1` assertions in `verify_othello.gd` (harness now 88 checks, 0 failures, exit 0). Contract recorded as R-S7-8 / S7-AT-7 in `design/systems/difficulty-mode.md`; `design/entities/entity-inventory.md` naming-conflict entry marked resolved.
- **S3 spec — CLOSED.** `design/systems/turn-pass.md` authored (R-S3-1..R-S3-10, S3-AT-1..7) and asserted by `_test_turn_flow` in `verify_othello.gd`; S3-AT-3 asserts the skip precondition and turn result because the on-screen skip notice is transient. Linked from the GDD and `design/systems-index.md` (S3 row, validation table, S9 coverage).
- **S5 spec — CLOSED.** `design/systems/ai-opponent.md` authored (R-S5-1..R-S5-11, S5-AT-1..7) and asserted by `_test_ai_contract`. Writing S5-AT-7 surfaced a real defect: **C8 fixed** — `_get_best_move() -> Vector2i` returned `null` on a blocked board (runtime "Nil" type error); it now returns the typed `NO_MOVE` sentinel and `_ai_move` checks it.
- **S6 spec — CLOSED.** `design/systems/ui-shell.md` authored (R-S6-1..R-S6-12, S6-AT-1..10) and asserted by `_test_ui_shell`. Writing S6-AT-7/8/10 surfaced and fixed **RC3** (missing legal-move affordance → added `_refresh_legal_hints`, `CELL_HINT_COLOR`) and **RC4** (silent occupied-cell click → unified invalid-click feedback). Both contradicted the approved "Readable board" pillar.
- **S8 spec — CLOSED.** `design/systems/feedback.md` authored (R-S8-1..R-S8-9, S8-AT-1..6) and asserted by `_test_feedback`. The three placeholder timings (0.5s invalid, 0.8s thinking, 1.0s pass) are now named constants with explicit acceptance tests; visual cadence remains an in-tree verification item (S8-VT-1..4).
- **RC2 — RESOLVED.** `design/systems-index.md` assumption wording now states architecture is a stub in `docs/architecture/README.md` rather than "not yet decided".
- **Validation table — RECONCILED (S3/S5/S6/S8/S9).** The `systems-index.md` validation rows for S3, S5, S6, S8, and S9 now match the harness (turn alternation, single/double skip, AI-turn input gating, AI determinism/board-restore/blocked-pass, cell structure/click/restart/highlighting, feedback preconditions/post-state).
- **All per-system spec gaps (S3/S5/S6/S8) are now closed.** The P0/P1 rule and feedback contracts are complete and asserted.
