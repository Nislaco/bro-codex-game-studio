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

## Finding 1 — Slow start (55s to first move) — *low severity, confounded*
The first legal move came **54.9 seconds** after launch. Two idle gaps also appear later (134s and 89s) where the player was not interacting.

**Confound:** the player was reading the 7-item instruction list I had just sent them, and the later gaps are the same thing (reading chat). The objective data cannot separate "slow to understand the game" from "reading a message".

**Verdict:** not yet actionable. To measure it properly, a session must start with **no chat and no instruction list** — just *"Here's a board game. Play it however you'd like."*

**Action:** re-measure `first_legal_move_ms` in session 2 with a clean start.

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
**No complaints** — and the objective data supports it: the player stayed engaged for 3 full matches at ~2s/move and came away without friction. A quiet, frictionless Othello match.

However, the AI winning 50-13 and 58-2 means the *fantasy of out-thinking the machine* was not available in this session. That is the same gap the killed "Intent" spike was chasing — and the balance check shows the AI is strong enough that "just play better" is not a satisfying answer for a newcomer.

# Blockers & Confusion
**None reported.** No rescues were needed (no extended idle gaps during play). No setting was needed mid-match. The board, score, turn indicator, skip notice, game-over text, and restart all worked without comment.

# Bugs Found
| ID | Severity | Summary |
|----|----------|---------|
| — | — | **None.** Zero runtime errors during the session. |

---

# Conclusion

- **Scenarios passed:** the core loop (play → pass → game over → restart) ran cleanly 3/3 times with no bugs, no confusion, and no complaints.
- **Scenarios failed:** none.
- **Recommendation:** **PROCEED** — the prototype's play experience is sound.

**But two follow-ups are required:**
1. **The difficulty ladder is not actually differentiated** (Finding 4) — needs a real "weakening" model for Easy, not just a shallower search.
2. **Settings remain unexplored** (Finding 3) and the clean-start metric (Finding 1) are still unmeasured.

**Session count:** 1 of 3 recorded. Two more sessions (PT-1 PvP, and PT-4/PT-5) are still required by the release criteria — and session 1's confounded start-up metric means **session 2 must begin with no chat and no instruction list**.

---

# Next Owner / Decision

- **Decision requested:** accept session 1 as a **PASS** for the core loop; open a follow-up story for the difficulty ladder.
- **Next owner:** qa-playtester for sessions 2 and 3.
- **Follow-up:** gameplay-programmer for the Easy-difficulty weakening model (new story, `production/stories-sprint4.md`).
- **Carried forward:** the "legibility" direction from the killed spike is **still unresolved** — the player reported no complaints, but was not asked the AI-legibility question (debrief Q5). Session 2 must ask it explicitly.
