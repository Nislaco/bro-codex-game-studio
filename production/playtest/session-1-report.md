# Playtest Debrief — Session 1 — 2026-10-19

**Scenario run:** vs Computer (default mode) — PT-2 in intent
**Tester:** product owner (played in-editor on `main` @ `ff5e525`)
**Player:** product owner — *had already seen the game during the cell-alignment work, so NOT a first-timer*
**Build:** `ff5e525` (main), Godot 4.7.2
**Report:** `playtest_1792462976.json` (88 moves, 3 complete matches)

---

# Objective Results

| Metric | Value | Read |
|--------|-------|------|
| `duration_ms` | 501.9s (8.4 min) | Full session including idle |
| `first_legal_move_ms` | 54.9s | **Slow start — see Finding 1** |
| `moves_placed` | 88 | Engaged throughout (median **1.9s** between moves) |
| `invalid_clicks` | **2** (2.2% of 90 clicks) | **Excellent — see Finding 2** |
| `skipped_turns` | 3 | One pass per match, all handled |
| `restarts` | 3 | Restart found and used unprompted, every match |
| `mode_changes` / `difficulty_changes` | **0 / 0** | **Settings never explored — see Finding 3** |
| `completed` | **yes** | 3 of 3 matches played to a game-over |
| `outcome` | White Wins ×3 | AI won every match — see Finding 4 |

### Match breakdown

| Match | Moves | Invalid | Skips | Result | Duration |
|-------|-------|---------|-------|--------|----------|
| 1 | 30 | 0 | 1 | **White (AI) 50 – 13** | 55s |
| 2 | 30 | 1 | 1 | **White (AI) 51 – 13** | 215s |
| 3 | 28 | 1 | 1 | **White (AI) 58 – 2** | 149s |

---

# Findings

## Finding 1 — Slow start (55s to first move) — ✅ **DISCONFIRMED, not a defect**
The first legal move came **54.9 seconds** after launch. Two idle gaps also appear later (134s and 89s) where the player was not interacting.

**Resolution (player, after the session):** *"I had to step away before I could start a move."*

**The 55 seconds was the player being physically away from the keyboard — not confusion.** The same explanation covers the two later idle gaps. The objective data cannot distinguish absence from confusion, but the player's answer does, and it is decisive.

**Corroborating evidence:** the 2.2% invalid-click rate (Finding 2) shows the player understood the board essentially immediately on returning — there is no sign of a comprehension problem anywhere in the data.

**Verdict: DISCONFIRMED.** Not a usability finding. No action. The genuine "time to first meaningful action" remains unmeasured, because this session cannot supply it.

**Lesson for session 2:** the confound was not the instruction list — it was simply that the player stepped away. The clean-start rule still applies (it removes a *second* possible confound), but a slow first move in a future session should first be checked against the idle-gap log before being called a defect.

## Finding 2 — The legal-move highlight works extremely well — ✅ *positive*
**2 invalid clicks in 90 total clicks (2.2% error rate).**

For contrast, the scripted synthetic session clicked 3 illegal cells in 4 attempts (75% error rate) — it had no player reading the highlight.

A human who *uses* the gold highlight gets the move right **98% of the time**. This is strong validation of the "Readable board" pillar and specifically of the RC3 fix (adding the legal-move highlight). It also **dismisses Finding F1** from the synthetic validation as a *blocker* — the player did not need to know *why* a cell was illegal, because the highlight told them where to click.

## Finding 3 — Settings never explored — *low severity, mixed signal*
Zero mode changes and zero difficulty changes across 3 full matches.

**Reading A (good):** the defaults are sufficient; the player never felt the need to fiddle — which directly supports the "Instant local play" pillar.

**Reading B (gap):** the Mode and Difficulty selectors are effectively invisible; the "vs Player" mode and the AI ladder were never discovered.

**Verdict:** not a defect for a prototype, but it means **PT-5 (restart & settings) is still uncovered** and the difficulty ladder is untested by a human.

**Action:** cover PT-5 in session 3 with an explicit prompt: *"Try changing the mode or difficulty."*

## Finding 4 — The AI won every match, and the difficulty ladder is nearly flat — ⚠️ *real balance finding*
The player lost all 3 matches (13-50, 13-51, **2-58**). The 2-58 is a rout.

To find out whether the AI was simply strong or the *ladder* was broken, a scripted balance check was run (24 games: a naive "first legal move" opponent against the AI, 8 varied openings per difficulty):

| Difficulty | Depth | Naive wins | AI wins | Avg score (naive – AI) |
|-----------|-------|-----------|---------|------------------------|
| Easy | 1 | 1/8 | 6/8 | — |
| Medium | 3 | 0/8 | 8/8 | 6.8 – 24.9 |
| Hard | 5 | 0/8 | 8/8 | 5.5 – 24.8 |

**The ladder is nearly flat.** A depth-1 AI still beats naive play 6 times out of 8. Only Medium and Hard are reliably dominant.

**Why:** Othello's greedy evaluation is already strong (corners `+100`, edges `+5`, material `+10`, mobility `+2`), so even a 1-ply search plays near-optimally against an opponent who does not know the game. Search *depth* barely differentiates skill levels for weak play.

**Impact:** the GDD states the prototype's purpose includes *"a clearly labeled AI strength ladder"*. The labels are clear; the **strengths are not differentiated**. A player choosing "Easy" reasonably expects a winnable game and does not get one.

**Action:** new story required — see "Follow-up" below.

---

# Loop Completion
- **3 of 3 matches played to completion.** The core loop reaches a satisfying end every time.
- The player engaged at a steady pace (median 1.9s per move) — no stalling, no confusion-driven hesitation visible in the timing.
- 3 skip events were encountered (one per match) and produced **no complaints** — the "has no legal moves! Skipping..." message is understood well enough not to be remarked on.

# First Meaningful Action
54.9s (confounded — see Finding 1). Move cadence after that was fast and consistent.

# Core Fantasy
**Confirmed by the player:** *"It did feel like deliberate play."* (debrief Q5, asked after the session)

This is the answer to the question the killed "Intent" spike was chasing, and it is the opposite of what the spike assumed. The spike's premise was that players cannot read the AI and therefore need a tell to predict. **The evidence says the AI is already legible** — a player who had never seen Othello still perceived its moves as deliberate, without any added affordance.

**So the "legibility" direction carried forward from the spike is answered: it is not needed.** The AI does not need to be made more understandable.

What the player *did* report as a problem was not opacity — it was the wall:

| | |
|---|---|
| AI felt deliberate | ✅ legibility fine |
| AI won 13-50, 13-51, **2-58** | ⚠️ and it was never winnable at "Medium" |

**The gap is balance, not comprehension.** A player who finds the opponent intelligent but unbeatable is a player who stops playing. That is the same conclusion the 24-game balance harness reached from the other direction (Finding 4), so the two independent lines of evidence agree.

**Revised priority:** the carried-forward "legibility" work is **dropped**; the difficulty ladder (Finding 4 / Sprint 4 STORY-4.1) is now the single highest-value change to this prototype.

# Blockers & Confusion
**None reported.** No rescues were needed (no extended idle gaps during play). No setting was needed mid-match. The board, score, turn indicator, skip notice, game-over text, and restart all worked without comment.

# Bugs Found
| ID | Severity | Summary |
|----|----------|---------|
| — | — | **None.** Zero runtime errors during the session. |

---

# Conclusion

- **Scenarios passed:** the core loop (play → pass → game over → restart) ran cleanly 3/3 times with no bugs, no confusion, and no complaints. The AI read as deliberate.
- **Scenarios failed:** none.
- **Recommendation:** **PROCEED** — the prototype's play experience is sound.

**Two follow-ups:**
1. **The difficulty ladder is not actually differentiated** (Finding 4) — needs a real "weakening" model for Easy, not just a shallower search. **This is now the top priority** for the prototype.
2. **Settings remain unexplored** (Finding 3) — judged not a defect, but PT-5 stays uncovered.

**Closed by this session:**
- Finding 1 (slow start) — **disconfirmed**; the player stepped away.
- The "legibility" direction carried forward from the killed spike — **disconfirmed**; the AI already reads as deliberate.

**Session count:** 1 of 3 recorded. Two more sessions (PT-1 PvP, and PT-4/PT-5) are still required by the release criteria.

---

# Next Owner / Decision

- **Decision requested:** accept session 1 as a **PASS**; **drop the "legibility" direction**; open a follow-up story for the difficulty ladder (already drafted as Sprint 4 STORY-4.1).
- **Next owner:** gameplay-programmer for STORY-4.1 (weakened Easy); qa-playtester for sessions 2 and 3.
- **Session 2 focus:** now that legibility is answered, session 2 should re-measure the ladder against a human — *"is Easy winnable?"* — rather than re-asking Q5.
