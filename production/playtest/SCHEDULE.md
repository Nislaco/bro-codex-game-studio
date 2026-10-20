# Playtest Session Schedule

**Owner:** qa-playtester
**Requirement:** 3 sessions (release criteria) — `production/qa-plan.md` §5
**Status:** ⏳ **AWAITING HUMAN TESTERS** — tooling complete and verified

---

## Before the first session

- [ ] Two or more people available (PT-1 needs a second player, or use the self-play proxy)
- [ ] A quiet ~20 minute window per session
- [ ] `production/playtest/sessions/session-1.md` (etc.) opened in an editor
- [ ] Verify the launcher: `cd production/playtest && ./run-session.sh --help` shows the protocol header

## Running a session

```bash
cd production/playtest
./run-session.sh PT-2          # starts the game with logging on
# ... run the scenario with the player ...
# (close the window when the match ends)
```

Then:

```bash
node collect-reports.mjs        # prints the objective summary + event trails
```

Paste the objective table into the session worksheet, fill in the observation sheet and debrief answers, and file it at `production/playtest/sessions/session-N.md`.

---

## Recommended schedule

| Session | Scenario | Who | Focus | Why this scenario |
|---------|----------|-----|-------|-------------------|
| **1** | **PT-2** — vs Computer (Easy) | New player | Does the AI read as an opponent? | Feeds the carried-forward "legibility" direction directly (debrief Q5). Also the most common first contact. |
| **2** | **PT-1** — local PvP | New player + partner | Is the board self-explanatory? | Tests whether the gold legal-move highlight is discoverable without the computer. Validates the "Readable board" pillar in its purest form. |
| **3** | **PT-4** + **PT-5** — pass/game-over, then restart & settings | Player from session 1 (or new) | Do the end states and settings land? | Covers the states a single session rarely reaches: a skip notice, the final result, and mid-match setting changes. |

**If only 2 sessions are possible:** run PT-2 and PT-1. Those two carry the most decision weight (AI legibility, board legibility).

---

## What to watch for (decision-relevant)

| Watch | Where | Feeds |
|-------|-------|-------|
| Did the player use the gold highlight before their first move? | Objective: `invalid_clicks` | Whether the "Readable board" pillar is landing |
| Can they explain the computer's move? | Debrief Q5 | **The "legibility" direction** — if players call the AI random/opaque, prototype surfacing *why* it likes a cell (NOT the killed prediction game) |
| Did they find Restart without help? | Objective: `restarts` + timeline | "Instant local play" pillar — restart is one click away |
| Did they understand the skip notice? | Debrief + `skipped_turns` | Whether S8 feedback needs a clearer message |
| **Finding F1:** is "Invalid Move!" enough? | Debrief Q4 | Whether invalid-move feedback should explain *why* (occupied vs. nothing to flip) |

---

## Session log

| # | Date | Tester | Player(s) | Scenario | Report file | Worksheet | Notes |
|---|------|--------|-----------|----------|-------------|-----------|-------|
| 1 | | | | PT-2 | | `sessions/session-1.md` | |
| 2 | | | | PT-1 | | `sessions/session-2.md` | |
| 3 | | | | PT-4/PT-5 | | `sessions/session-3.md` | |

---

## Once all 3 are done

1. Run `node collect-reports.mjs` → save the output to `production/playtest/summary.md`
2. Write the consolidated debrief to `production/playtest/playtest-debrief-2026-10-XX.md` using the template in `README.md` §5
3. Tick the release-criteria item in `production/qa-plan.md` §5
4. Update `production/session-state/active.md`
5. **Decide the "legibility" direction** using the PT-2 debrief Q5 answers:
   - Players describe the AI as intentional/opaque → prototype legibility
   - Players describe the AI as random → first investigate the AI's actual play quality (is Easy really beatable?)

---

## Notes

- The synthetic validation session (2026-10-19) confirmed the instrumentation works but is **not** a substitute for a human session — it cannot measure comprehension or delight. See `playtest-debrief-synthetic-2026-10-19.md`.
- Sessions can be run in any order; the scenario label is metadata only and does not change the build.
