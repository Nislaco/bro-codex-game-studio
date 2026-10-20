# Playtest Debrief — Session 2 — 2026-10-20

**Scenario run:** vs Computer on **Easy** (PT-2 intent), after a deliberate switch from Medium
**Tester:** product owner
**Build:** `a70fb75` (main) — includes the reworked Easy AI (no-mobility evaluation)
**Report:** `session-2-report.json` (90 moves, 3 complete matches)

---

# Objective Results

| Metric | Value | Read |
|--------|-------|------|
| `duration_ms` | 39,335s (10.9h) | Includes an overnight step-away before play began |
| `first_legal_move_ms` | 39,138s | **Overnight idle, not a usability signal** |
| `difficulty_changes` | **1 → Easy** | **The player's first action was to switch to Easy** — see Finding 6 |
| `moves_placed` | 90 | 3 full matches, engaged (median 1.8s/move) |
| `invalid_clicks` | 4 (4.4%) | Still low; the highlight keeps working |
| `skipped_turns` | 3 | One per match, no complaint |
| `restarts` | 2 | Restart used between matches |
| `completed` | yes | 3/3 matches played to a game over |
| `outcome` | White (AI) won all 3 | But the margins are very different — see Finding 5 |

### Match breakdown (all on Easy)

| Match | Moves | Invalid | Skips | Result | Duration |
|-------|-------|---------|-------|--------|----------|
| 1 | 30 | 0 | 1 | **AI 45 – 19** | 73s |
| 2 | 30 | 2 | 1 | **AI 44 – 20** | 70s |
| 3 | 30 | 2 | 1 | **AI 41 – 23** | 53s |

---

# Findings

## Finding 5 — The rebalanced Easy AI is a real game, not a rout — ✅ **the fix worked**
Comparing the two sessions directly (both by the same player, same seat):

| | Medium (session 1) | **Easy (session 2)** |
|---|---|---|
| Player avg discs | 9.3 | **20.7** (+121%) |
| AI avg discs | 53.0 | **43.3** |
| Margin | 43.7 | **22.7 (48% smaller)** |
| Worst result | 2 – 58 | 19 – 45 |

The player went from being **decimated** (2 discs in the worst match) to holding **19–23 discs** — roughly a third of the board in every match. The Easy AI still wins, but the games are competitive rather than punitive, which is what a first-timer needs in order to keep playing.

**Cross-check against the scripted measurement:** the corner-aware beginner bot wins Easy 12/12 at an average 33–31, while the human wins 0/3 at 20.7–43.3. That gap is expected — a human explores, takes risks, and does not optimise material greedily the way a bot can. The bot's 12/12 is a *ceiling* on how winnable Easy is, not a promise that a human will win it.

## Finding 6 — The player voluntarily sought out Easy — ✅ *and it revises F3*
The **very first action** of the session (after the overnight idle) was `difficulty_change → Easy`.

This is meaningful behavioural data:
1. **The difficulty control is discoverable.** Session 1's F3 said "settings never explored (0 changes across 3 matches)" and treated that as a possible discoverability gap. Session 2 shows the player *did* find and use it — and used it exactly when the difficulty became the obstacle. So F3's "not discoverable" reading was wrong; the correct reading is **"discoverable when it matters."**
2. **It independently confirms the session-1 finding.** The player concluded, without prompting, that Medium was the wrong tier — the same conclusion the balance harness reached numerically and the GDD's "clearly labeled AI strength ladder" claim requires.

**F3 is therefore revised from "gap" to "not a gap"** — with the caveat that the player only looked because they had just been crushed on Medium. The default difficulty is still worth a second look (see Follow-up).

## Finding 7 — The Easy AI still looks deliberate — ✅
The player's report: *"It is working well."* No complaint about the AI feeling broken or random. This is the expected consequence of the design choice: the weakening is in the **evaluation** (no mobility term), not in a random toggle, so the AI still takes corners, still flips discs, and still looks like it is trying — it just misjudges mobility.

---

# Loop Completion
- **3/3 matches played to a game over**, at a steady pace (median 1.8s/move), with restarts used between matches.
- Skip events (1 per match) produced no complaint.
- The "Instant local play" pillar holds: launch → playing within seconds, restart one click, no friction reported.

# Core Fantasy
The player reports the project "is working well". The objective data supports that: engagement was consistent, the loop completed cleanly every time, and the outcome of the session-1 problem (a punishing AI) is measurably improved.

# Blockers & Confusion
**None.** 4 invalid clicks in 90 (4.4%) — a slightly higher rate than session 1's 2.2%, but still low, and no complaint accompanied them. No setting was needed mid-match. No bug was reported.

# Bugs Found
| ID | Severity | Summary |
|----|----------|---------|
| — | — | **None.** Zero runtime errors during the session. |

---

# Conclusion

- **Scenarios passed:** the core loop ran cleanly 3/3 times; the rebalanced Easy AI is engaging and no longer punishing.
- **Recommendation:** **PROCEED.** The Easy tier is fixed (F5), the settings are demonstrably discoverable when needed (F6), and the AI still looks deliberate (F7).
- **Open question (not a defect):** the player still lost 3/3 on Easy, at 19–23 discs. Whether Easy should be winnable *by a human first-timer* is a design choice, not a bug. The scripted bot wins 12/12, so headroom exists if the target is "a beginner should win about half the time."

**Session count:** 2 of 3 recorded. One more session (PT-1 local PvP and/or PT-5 settings with an explicit prompt) is still required by the release criteria.

---

# Next Owner / Decision

- **Decision requested:** accept session 2 as a **PASS**; revise F3 (settings are discoverable when they matter); keep the open question about Easy's human win-rate.
- **Open question to answer:** *"Did Easy feel winnable to you?"* If it still felt unwinnable, the next lever is the corner/edge weights (not depth) — see `production/stories-sprint4.md` STORY-4.1.
- **Next owner:** qa-playtester for the final session (PT-1 PvP / PT-5 settings).
- **Follow-up:** consider whether **Medium should remain the default** for a first-time player, given the player voluntarily dropped to Easy.
