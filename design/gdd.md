# othello GDD

# Purpose

A classic Othello (Reversi) board game: 8x8 grid, two players alternate placing discs, flanking captures flip opponent discs, legal-move validation, score tracking, and game-over detection.

# Player Fantasy & Pillars

Player fantasy: the quiet satisfaction of watching the board flip in your favor after a well-placed disc.

Pillars (approved by the project owner acting as creative-director + producer on 2026-10-19):

1. **Rule fidelity** — standard Othello/Reversi only; every capture is explainable by the flanking rule; no house rules.
2. **Readable board** — score, turn, and match state are visible at a glance.
3. **Instant local play** — a match starts in seconds with no accounts, tutorial wall, or network dependency, and restart is always one click away.

**Approval (2026-10-19):** these pillars, the differentiation deferral, and the non-goals below are the frozen product-identity contract for the prototype.

# Differentiation

Prototype-level only. This build does not yet claim a player-facing product differentiator; its purpose is a lean, verified local Othello with a clearly labeled AI strength ladder, used to validate the studio production pipeline end to end. Product differentiation is explicitly deferred (see Non-Goals) until after the prototype gate.

**Status (2026-10-19):** the prototype gate has passed. The Epic 5 candidate hypothesis and its spike are recorded in [`design/differentiation-hypothesis.md`](differentiation-hypothesis.md) and [`production/spike-intent-report.md`](../production/spike-intent-report.md) — mechanic **"Intent"** (surface the AI's top candidate moves as a visual tell the player can predict). The spike was implemented and verified, and the decision is **KILL (as designed)**: the mechanic is too cheap to be a differentiator, and the prediction is a guess rather than a skill read. The underlying need — players must be able to read the AI — is carried forward as a *legibility* direction to be tested against the human playtest.

# Non-Goals

- Online multiplayer, matchmaking, or any networking.
- Accounts, telemetry, or live-ops.
- Progression, unlocks, meta-game, or monetization.
- Content authoring, levels, or modes beyond player-vs-computer and local player-vs-player.
- Localization beyond English and formal accessibility certification (basic keyboard operability only).

# Core Loop

A match runs on an 8x8 board. On each turn the active player places a disc on an empty cell that flanks at least one opposing disc; every flanked line flips to the active color. If the active player has no legal move, the turn passes. The match ends when neither player has a legal move and the higher disc count wins. The prototype supports player-vs-computer and local player-vs-player.

# Systems

The system inventory, dependency order, priority tiers, and validation needs are tracked in [`design/systems-index.md`](systems-index.md). P0 (playable prototype) covers board state, move legality and capture, turn/pass handling, scoring and end conditions, the AI opponent, the UI shell, verification, and engine bootstrap. P1 covers mode/difficulty settings, feedback and game feel, and accessibility. Persistence, audio, and localization are deferred until after the prototype gate.

# Per-System GDDs

| System | Document | Status |
|--------|----------|--------|
| S2 Move Legality & Capture, S4 Scoring & End Conditions | [`design/systems/core-rules.md`](systems/core-rules.md) | Rules R-S2-*, R-S4-*, AT-1..AT-14 implemented in `verify_othello.gd` |
| S7 Mode & Difficulty | [`design/systems/difficulty-mode.md`](systems/difficulty-mode.md) | Draft for review — rules R-S7-*, S7-AT-1..7 implemented in `verify_othello.gd` |
| S3 Turn & Pass Handling | [`design/systems/turn-pass.md`](systems/turn-pass.md) | Draft for review — rules R-S3-*, S3-AT-1..7 implemented in `verify_othello.gd` |
| S5 AI Opponent | [`design/systems/ai-opponent.md`](systems/ai-opponent.md) | Draft for review — rules R-S5-*, S5-AT-1..7 implemented in `verify_othello.gd` |
| S6 UI Shell | [`design/systems/ui-shell.md`](systems/ui-shell.md) | Draft for review — rules R-S6-1..R-S6-14, S6-AT-1..10 and S14-AT-1..6 implemented in `verify_othello.gd` |
| S8 Feedback & Game Feel | [`design/systems/feedback.md`](systems/feedback.md) | Draft for review — rules R-S8-*, S8-AT-1..6 implemented in `verify_othello.gd` |

The rule contract for capture and scoring is defined in `design/systems/core-rules.md`, the mode/difficulty contract in `design/systems/difficulty-mode.md`, the turn/pass contract in `design/systems/turn-pass.md`, the AI contract in `design/systems/ai-opponent.md`, the UI-shell contract (including the S14 accessibility contract) in `design/systems/ui-shell.md`, and the feedback contract in `design/systems/feedback.md`. All are asserted by `src/scripts/verify_othello.gd` against Godot 4.7.2.

# Entities

Gameplay objects, actors, configuration, presentation, engine, and verification entities are cataloged in [`design/entities/entity-inventory.md`](entities/entity-inventory.md), with owner roles, dependencies, lifecycle, and validation signals.

# Reviews

| Review | Verdict | Document |
|--------|---------|----------|
| Design review (systems + rules) | Rule contract approved; B1-B4 remediation executed (see Remediation Status) | [`design/reviews/design-review.md`](reviews/design-review.md) |
| Design review, second pass (post-remediation) | APPROVED WITH FOLLOW-UPS — B1-B4 closed (B1 owner approval recorded 2026-10-19), no blocking contradiction | [`design/reviews/design-review-2.md`](reviews/design-review-2.md) |
| Review all GDDs (cross-document) | Consistency PASS; per-system specs for S3/S5/S6/S8 proposed before implementation; RC1 PvP naming defect | [`design/reviews/review-all-gdds.md`](reviews/review-all-gdds.md) |

# Inputs

Design inputs: the concept above, engine reference under `docs/engine-reference/`, and playtest findings.

# Outputs

Design outputs: this GDD, system specs under `design/`, and task-ready acceptance criteria.

# Validation

Run `./codex-game-studio validate` from the game root.
