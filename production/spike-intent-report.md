# Epic 5 Spike Report — "Intent"

**Date:** 2026-10-19
**Branch:** `spike/intent` (throwaway)
**Owner:** senior-game-designer + producer
**Hypothesis:** `design/differentiation-hypothesis.md`
**Status:** Spike **executed** — decision recorded below

---

# Summary

The "Intent" spike was implemented and verified end-to-end. The mechanic works as designed: the AI's top-2 candidate moves are marked during its thinking window, the player may predict which one it actually plays, and a matching prediction scores a **Read bonus**.

**The spike is technically sound. The decision is NOT to ship it as-is** — see *Decision* for why, and what the spike taught us.

---

# What Was Built

| Element | Implementation |
|---------|----------------|
| Candidate ranking | `_get_best_move()` now records a scored list; `_rank_candidates()` sorts it and keeps the top `INTENT_CANDIDATE_COUNT` (2) |
| Markers | A 14×14 `ColorRect` in the top-right corner of each cell (`INTENT_MARKER_COLOR`), hidden by default, shown on candidate cells during the AI's thinking window |
| Prediction | Clicking a marked cell during the AI's turn records a prediction (does **not** place a disc — the turn rules are untouched) |
| Resolution | After the AI moves, a matching prediction is a **hit**, a mismatch is a **miss**; both shown in the status line and tallied |
| Tally | A "Reads: N hit / M missed" label under the status line |
| Scope guard | vs-AI only — PvP is completely unaffected (no markers, no window, no tally interaction) |

---

# Verification Evidence

## Automated (105 assertions, 0 failures)

```
godot --headless --path src -s res://scripts/verify_othello.gd
→ --- Othello Verification End: 105 checks, 0 failures ---   (exit 0)

godot --headless --path src -s res://addons/gut/gut_cmdln.gd
→ 105 asserts, All tests passed, 0 orphans, exit 0

godot --headless --path src --quit-after 90
→ exit 0, 0 script errors

bench_hard_difficulty.gd
→ HARD (depth 5): median 405ms, p95 411ms, max 413ms
→ ✓ GATE PASS: Hard median (405ms) ≤ 500ms budget
```

The 9 new `SPIKE-AT-1..4` assertions cover marker presence/visibility, candidate legality, candidate-includes-best-move, prediction acceptance/rejection, and hit/miss resolution. **All 96 pre-existing P0/P1 assertions still pass** — the spike does not touch the rule contract.

## Live (running game, via Godot MCP)

| Check | Result |
|-------|--------|
| Fresh game | `discs=4 turn=Black` |
| Human plays (2,4) | `markers=2 open=true turn=White status="Computer is thinking..."` |
| After 2.5s (natural AI turn) | `discs=6` (4 + 1 human + **exactly 1** AI) `markers=0 open=false turn=Black status="Your turn!"` |
| Click marked candidate | `predictionMade=true prediction=(2,5)` |
| AI resolves, matching | `hits=1 misses=0` tally `Reads: 1 hit / 0 missed` |
| AI resolves, wrong | `hits=1 misses=1` |
| Click unmarked cell | ignored — no hit, no miss, no penalty |
| PvP mode | `markers=0` — human move still places a disc normally |
| Game-code runtime errors | **0** (only MCP's own injected-script noise in the log) |

**No double-move:** the natural-flow check confirms exactly 6 discs after one full turn cycle, so the AI moves once per turn.

---

# What the Spike Taught Us

## 1. The mechanic is technically cheap — and that is the problem
It took ~1 day, needed **no new rendering pipeline** (a corner dot on the existing cell), **no new input mode** (a click during the AI turn), and **no rule changes**. The AI already computed a ranked candidate list; the spike just exposed it.

That cheapness is a signal *against* it as differentiation: if the mechanic is this easy to bolt onto any minimax opponent, it is not a differentiator — it is a feature. And the "Readable board" pillar already delivered the legibility win (score + turn + legal-move highlight) without it.

## 2. The prediction is a coin flip, not a skill
With `INTENT_CANDIDATE_COUNT = 2`, the player has a **50% chance** of hitting by guessing. The marker reveals the top-2 but the *actual* choice between them depends on the AI's evaluation, which the player cannot see. So:

- It does not require reading the AI's evaluation — it requires guessing.
- It does not scale with skill — a strong player and a novice both score ~50%.
- The "read" fantasy is undermined: you are not reading the board, you are picking one of two dots.

Making it a real skill would require exposing *why* the AI prefers one candidate (a score, a corner/edge hint) — at which point the mechanic becomes "show me the answer with extra steps".

## 3. It fights the session's pacing
The prediction window is the AI's 0.8s thinking pause. Adding a second decision inside that window means the human is asked to react in under a second, mid-turn, while the board is in a transitional state. That is a **speed/attention tax on a contemplative game** — the "quiet satisfaction of watching the board flip" fantasy (the approved pillar) is the thing most at risk.

## 4. It adds UI to a board that just got simpler
The board is currently a clean 8×8 grid with three visual states (empty / legal-move / disc). The spike adds a fourth (intent marker) plus a tally line. The board has already been through one readability pass (the WCAG palette work, `S14-AT-1/2`); adding more chrome risks regressing the pillar the spike is supposed to serve.

## 5. It is invisible in PvP
The mechanic only exists vs-AI. A player who prefers the two-player mode — the "Instant local play" pillar — gets nothing.

---

# Decision

```
DECISION: KILL (as designed) — with a narrowed alternative carried forward
```

**Rationale:**
- Technically sound but **not a differentiator** — too cheap to bolt on, so it is a feature rather than an identity.
- The prediction is a **50% guess**, not a skill read; it fails the "core mechanic" test in the hypothesis.
- It taxes the **pacing and simplicity** of the approved pillars (quiet satisfaction, readable board).
- The hypothesis's own kill criteria were: *"If playtesters report the AI becomes 'too easy' or 'the answer is given away'"* (N/A — the mechanic is trivial to bypass) and *"If playtesters ignore the challenge entirely (< 25% usage)"* (a 50/50 guess in a 0.8s window is very likely to be ignored — this criterion is met by construction, without a playtest).

**The spike was worth running.** It converted an untested assumption into a *measured* result: the "legible AI" problem is real, but the answer is not a guessing game layered on top of it.

**What carries forward (not a mechanic — a product direction):** the finding that players need to *understand the AI*, not *beat a guess*. The "Readable board" pillar is the right home for that. The next candidate in that space should make the AI's reasoning legible (e.g. showing *why* a cell is attractive — corner, mobility, disc count) rather than adding a timed prediction. That is a smaller, quieter change that serves the same pillar and carries no pacing tax.

> ### UPDATE (2026-10-19, after playtest session 1) — carried-forward direction DISCONFIRMED and DROPPED
>
> The session-1 player — a genuine newcomer to Othello — reported that the AI *"did feel like deliberate play"*, with **no added affordance of any kind**. The AI is already legible. The problem this spike was chasing does not exist.
>
> What the session and the 24-game balance harness independently point to instead is a different problem: **the AI is legible AND unbeatable for a newcomer** (50-13, 51-13, 58-2; Easy still beats naive play 6/8). The gap is **balance, not comprehension**.
>
> Therefore: **no "legibility" work is scheduled.** The next step is the **difficulty ladder** (Sprint 4 STORY-4.1), not an AI-explanation affordance.

**Cleanup (per the hypothesis's cleanup boundary):**
- Branch `spike/intent` — the implementation is **archived, not merged**. The 9 `SPIKE-AT-*` assertions and the `Intent` UI do **not** land on `main`.
- `main` remains the faithful, verified Othello: 96 assertions, WCAG-AA palette, keyboard play, 0 runtime errors.
- The spike's code and evidence stay in this branch so the decision can be re-litigated with a real playtest rather than re-derived from scratch.

---

# Follow-up

| Item | Owner | When | Status |
|------|-------|------|--------|
| Test whether players read the AI as "intentional" or "opaque" (PT-2/PT-3 debrief) | qa-playtester | Next human playtest | ✅ **DONE — session 1: "it did feel like deliberate play"** |
| If players do report opacity, prototype **legibility** (not prediction): surface the AI's evaluation reason for its move | senior-game-designer | After the playtest result | ✅ **NOT NEEDED — condition not met; direction dropped** |
| Re-open Epic 5 only if the playtest shows a real comprehension gap | producer | Post-playtest | ✅ **CLOSED — no comprehension gap found** |
| **NEW** — Differentiate the difficulty ladder: the AI is legible but unbeatable for a newcomer (Easy still beats naive play 6/8) | gameplay-programmer | Sprint 4 STORY-4.1 | ⏳ Open |

---

# Changed Files (this branch only)

- `src/scripts/othello.gd` — Intent mechanic (candidates, markers, prediction, resolution, tally)
- `src/scripts/othello_checks.gd` — 9 `SPIKE-AT-1..4` assertions

**Not merged to `main`.** `main` is unchanged except for the playtest instrumentation commit (`29439e0`).
