# Sprint 4 Stories — Follow-up from Playtest Session 1 (Week 7-8)

**Project:** othello (Godot 4.7.2) | **Sprint:** 4 | **Baseline:** m2 gate PROCEED, 96 assertions, playtest session 1 PASS
**Triggered by:** `production/playtest/session-1-report.md` (Finding 4)

---

## Sprint Goal
Close the gap the first human playtest exposed — the AI is **legible but unbeatable** for a newcomer, so "Easy" is not easy — plus finish the remaining playtest sessions. The "legibility" direction is **dropped**: session 1 confirmed the AI already reads as deliberate.

---

## Stories

### STORY-4.1: Differentiate the Easy AI (Difficulty Ladder) — ⭐ **TOP PRIORITY**
**Owner:** gameplay-programmer
**Epic:** 1 (balance) | **Sprint:** 4 | **Estimate:** 1 day
**Dependencies:** None

**Problem:** the search depth does not separate skill levels for weak play. A depth-1 AI still beats a naive opponent 6/8 times, because Othello's greedy evaluation (corners `+100`, edges `+5`, material `+10`, mobility `+2`) is already strong. A player who picks "Easy" expects a winnable game and does not get one.

**Why this is the top priority:** playtest session 1 confirmed the AI *"did feel like deliberate play"* — so legibility is fine and needs no work. The player still lost 13-50, 13-51 and **2-58**. The gap is balance, not comprehension, and a player who finds the opponent intelligent but unbeatable is a player who stops playing.

**Approach — give Easy an actual weakening model** (choose one):
- (a) **Weakened evaluation:** depth 1 with a beginner evaluation (no corner weight, no mobility term, material only). Corners are the single most important concept in Othello; a beginner-weighted AI that ignores them will play recognizably human.
- (b) **Random with a bias:** pick a random legal move, with a small preference for corners/edges. Gives a genuinely beatable opponent.
- (c) **Deliberate blunder:** search depth 1, but pick the *second*-best move most of the time.

**Acceptance Criteria:**
- [ ] A naive opponent loses to Easy more often than it wins (target: naive wins ≥5/8 at Easy).
- [ ] Medium and Hard remain at naive wins 0/8 (they must not get weaker).
- [ ] The ladder is monotonic: naive-win rate Easy > Medium > Hard.
- [ ] A "notices the difference" check: the same naive opponent scores materially better against Easy than Medium.
- [ ] A deterministic-untouched check: Medium/Hard move selection is bit-identical to today (the 96 existing assertions must still pass unchanged).
- [ ] Measured with the balance harness (see STORY-4.2), 8+ openings per difficulty.

**Files:**
- `src/scripts/othello.gd` (`_evaluate_board` variant, `_get_best_move` difficulty branch)
- `design/systems/difficulty-mode.md` (new rule + acceptance test)

**Verification:**
```
# balance harness (new, STORY-4.2)
godot --headless --path src -s res://scripts/bench_difficulty_ladder.gd
→ prints naive win-rate per difficulty; asserts the ladder is monotonic

# regression
godot --headless --path src -s res://scripts/verify_othello.gd
→ 96+ checks, 0 failures (Medium/Hard behavior unchanged)
```

**Risks:**
- Making Easy *too* weak feels insulting to competent players. Mitigate: target "naive loses" but check it does not throw games against a *reasonable* opponent.
- Existing `S7-AT-*` assertions cover depth mapping, not move quality, so they should not need changing — verify.

**Owner note:** if (a) is chosen, the weakening must be visible in the *evaluation*, not a random toggle, so the AI still looks like it is trying.

---

### STORY-4.2: Difficulty Ladder Balance Harness
**Owner:** gameplay-programmer / qa-playtester
**Epic:** 6 | **Sprint:** 4 | **Estimate:** 0.5 day
**Dependencies:** STORY-4.1 (the harness validates it)

**Description:** a repeatable, headless measurement of the difficulty ladder, so the balance claim is evidence-based rather than a single anecdote. Plays a scripted naive opponent against the AI over N varied openings per difficulty and reports win rates.

**Acceptance Criteria:**
- [ ] `src/scripts/bench_difficulty_ladder.gd` runs headless, exits non-zero if the ladder is not monotonic.
- [ ] ≥ 8 varied openings per difficulty; reports naive-win rate and average score per difficulty.
- [ ] Runs in < 30s.
- [ ] Documented in `design/systems/difficulty-mode.md` as the balance evidence method.

**Files:**
- New: `src/scripts/bench_difficulty_ladder.gd`
- Ref: `design/systems/difficulty-mode.md`

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
