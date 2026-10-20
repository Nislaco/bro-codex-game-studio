# Sprint 4 Stories — Follow-up from Playtest Session 1 (Week 7-8)

**Project:** othello (Godot 4.7.2) | **Sprint:** 4 | **Baseline:** m2 gate PROCEED, 96 assertions, playtest session 1 PASS
**Triggered by:** `production/playtest/session-1-report.md` (Finding 4)

---

## Sprint Goal
Close the gap the first human playtest exposed — the AI is **legible but unbeatable** for a newcomer, so "Easy" is not easy — plus finish the remaining playtest sessions. The "legibility" direction is **dropped**: session 1 confirmed the AI already reads as deliberate.

---

## Stories

### STORY-4.1: Differentiate the Easy AI (Difficulty Ladder) — ✅ **DONE 2026-10-19**
**Owner:** gameplay-programmer
**Epic:** 1 (balance) | **Sprint:** 4 | **Estimate:** 1 day
**Dependencies:** None

**Result:** implemented as **"EASY drops the mobility term"** (approach (a), with a better rationale than first proposed). The root cause turned out to be the evaluation, not the depth: the mobility term (`+2` per legal move) rewards keeping loose discs, which is the classic beginner trap, so a depth-1 AI with the *standard* evaluation already beat a corner-aware beginner 6/8. Removing mobility from EASY keeps corners and edges (so it still looks deliberate) but drops the term that causes the trap.

**Measured:** EASY 12/12 beginner wins (avg 33–31), MEDIUM 0/12 (26–38), HARD 0/12 (21–43). Ladder monotonic PASS.

**Rejected alternatives (measured, kept for the record):**
- material-only evaluation → beginner won 12/12 but the AI collapsed (49–15): too weak, and it stopped looking like it was trying.
- uniform random → beginner won 9/12: too brainless.
- "one-mistake player" (standard eval, second-best move) → 0/12 but 12 draws: too strong and dull.
- a tunable blunder rate → the sweep inverted, because a random legal move often flips many discs and is sometimes *better* than the greedy move. Abandoned in favour of the evaluation change, which is deterministic and explainable.

**Acceptance Criteria:**
- [x] A naive opponent loses to Easy more often than it wins — superseded by the corner-aware beginner (target ≥6/12).
- [x] Medium and Hard remain at 0/12 (they must not get weaker).
- [x] The ladder is monotonic: EASY ≥ MEDIUM ≥ HARD.
- [x] A "notices the difference" check: the same opponent scores 33–31 against Easy and 26–38 against Medium.
- [x] Medium/Hard move selection is unchanged (the change is on a separate Easy code path).
- [x] Measured with the balance harness, 12 varied openings per difficulty.
- [x] Deterministic-untouched check: 97 assertions pass; `S5-AT-4` (AI is deterministic) still passes.
- [x] Documented in `design/systems/difficulty-mode.md` (R-S7-9 / R-S7-10).

**Files:**
- `src/scripts/othello.gd` (`_get_best_move_easy`, `_evaluate_board_no_mobility`)
- `design/systems/difficulty-mode.md` (R-S7-9/R-S7-10, balance acceptance tests)
- `src/scripts/othello_checks.gd` (S5-AT-3 updated to the new contract)

**Risks:**
- Making Easy *too* weak feels insulting to competent players. → Measured 12/12 with close scores; the games are competitive, not walkovers. A human session (STORY-4.4) is the real confirmation.
- Existing `S7-AT-*` assertions cover depth mapping, not move quality → unchanged and still pass.

**Owner note:** the weakening is in the *evaluation*, not a random toggle, so the AI still looks like it is trying.

---

### STORY-4.2: Difficulty Ladder Balance Harness — ✅ **DONE 2026-10-19**
**Owner:** gameplay-programmer / qa-playtester
**Epic:** 6 | **Sprint:** 4 | **Estimate:** 0.5 day
**Dependencies:** STORY-4.1 (the harness validates it)

**Result:** `src/scripts/bench_difficulty_ladder.gd` — headless, exits non-zero if the ladder is not monotonic or Easy is not winnable. 12 varied openings per difficulty, two opponent profiles, plus a **control**.

**Acceptance Criteria:**
- [x] Exits non-zero if the ladder is not monotonic.
- [x] ≥ 8 varied openings per difficulty; reports win rate and average score per difficulty.
- [x] Runs in < 4 min.
- [x] Documented in `design/systems/difficulty-mode.md` (S7-BAL-1..4).

**Files:**
- New: `src/scripts/bench_difficulty_ladder.gd`
- Ref: `design/systems/difficulty-mode.md`

**Two harness bugs this story caught (worth keeping):**
1. **Stale board.** The AI's move was computed *before* the opponent's move, so the AI acted on an old position and could overwrite the opponent's disc. Fixed to: opponent moves, then the AI replies on the updated board.
2. **A broken oracle.** The first opponent model ("take a corner, else the first legal move row-major") only beat a *random* AI 1/12 times — its fallback was catastrophically bad, so the whole measurement was meaningless. The control section now proves the opponent model is sound (9/12 vs random) before any ladder number is believed. This is why the control exists.

---

### STORY-4.3: Settings Discoverability Pass
**Owner:** ui-ux-designer
**Epic:** 1 | **Sprint:** 4 | **Estimate:** 0.5 day
**Dependencies:** None

**Problem:** session 1 explored **zero** settings across 3 full matches. The "vs Player" mode and the AI ladder were never discovered.

**Acceptance Criteria:**
- [ ] Decide (with a human playtester) whether this is a problem: the player may simply not have needed the settings, which is fine for the "Instant local play" pillar.
- [ ] If judged a gap: apply a low-cost affordance (e.g. a one-line hint under the settings bar, or a clearer "Mode" label) — **no new chrome on the board**.
- [ ] If judged not a gap: record the reasoning in `design/systems/ui-shell.md` and close.
- [ ] Board readability must not regress — re-run the contrast assertions (`S14-AT-1/2`).

**Files:**
- Possible: `src/scripts/othello.gd` (settings bar), `translations/strings.csv`
- Ref: `design/systems/ui-shell.md`

**Risks:** adding hints to satisfy a metric can make the game feel cluttered. Default to **not changing anything** unless a tester says they were confused.

---

### STORY-4.4: Playtest Sessions 2 and 3
**Owner:** qa-playtester
**Epic:** 6 | **Sprint:** 4 | **Estimate:** 1 day (facilitation)
**Dependencies:** STORY-4.1 (so session 2 measures the *new* Easy ladder)

**Description:** complete the remaining two playtest sessions, following `production/playtest/SCHEDULE.md`.

**Session 2 focus (changed):** the AI-legibility question (Q5) is already answered by session 1 — *"it did feel like deliberate play."* Do **not** re-ask it. Session 2 should instead re-measure the ladder against a human: play **Easy** and ask *"is this winnable?"* That is the direct human counterpart to the 24-game balance harness.

**Acceptance Criteria:**
- [ ] **Session 2 — PT-2 (vs Computer, Easy) with a CLEAN start:** no chat, no instruction list. The player gets only *"Here's a board game. Play it however you'd like."*
- [ ] Session 2 plays **Easy** (the reworked ladder, STORY-4.1) and records whether the player perceives it as winnable — quote verbatim.
- [ ] **Session 3 — PT-1 (local PvP)** and/or **PT-5 (restart & settings)** with an explicit prompt to change a setting.
- [ ] All three sessions filed at `production/playtest/sessions/session-N.md`.
- [ ] `node collect-reports.mjs` output saved to `production/playtest/summary.md`.
- [ ] Consolidated debrief written; release-criteria item ticked in `production/qa-plan.md` §5.

**Files:**
- `production/playtest/sessions/session-2.md`, `session-3.md`
- New: `production/playtest/summary.md`, `production/playtest/playtest-debrief-2026-10-XX.md`

---

## Sprint 4 Summary

| Story | Owner | Est. | Depends On | Gate Evidence |
|-------|-------|------|------------|---------------|
| 4.1 Differentiate Easy AI | gameplay-programmer | 1d | — | Naive wins ≥5/8 at Easy; Medium/Hard unchanged |
| 4.2 Ladder Balance Harness | gameplay-programmer | 0.5d | 4.1 | `bench_difficulty_ladder.gd` exits non-zero if not monotonic |
| 4.3 Settings Discoverability | ui-ux-designer | 0.5d | — | Decision recorded; contrast assertions still pass |
| 4.4 Playtest Sessions 2 & 3 | qa-playtester | 1d | 4.1 | 3 sessions filed; release criteria ticked |

**Total:** ~3 days

---

## Risks

| Risk | Mitigation |
|------|------------|
| Weakening Easy breaks existing AI assertions | `S7-AT-*` covers depth mapping, not move choice — verify before/after; Medium/Hard must be bit-identical |
| A weaker Easy makes the AI look broken | Weaken the *evaluation* (beginner-shaped), not the search; the AI should still look like it is trying |
| The balance harness becomes a maintenance burden | Keep it small: one naive opponent, N openings, one table |
| Playtest sessions slip again | Session 2 is the critical one (clean start + Q5). Schedule it first, in a protected 20-minute window |

---

## Next Owner / Decision

- **Decision requested:** approve the sprint; confirm the weakening model for Easy — **(a) weakened evaluation** is the recommended option (it looks like the AI is trying, it teaches the game, and it is deterministic).
- **Next owner:** gameplay-programmer starts STORY-4.1; qa-playtester schedules session 2 for the same day so it can measure the new ladder.
