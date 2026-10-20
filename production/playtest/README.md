# Playtest Kit — Othello Prototype

**Owner:** qa-playtester
**Plan:** `production/qa-plan.md` (scenarios PT-1..PT-5, triage P0–P3, release criteria)
**Last updated:** 2026-10-19

---

# 1. How to Run a Session

## 1.1 Enable logging (recommended)

Launch with the playtest flag so objective data is captured automatically:

```bash
cd /home/nicolas/project/bro-codex-game-studio
/opt/godot4/bin/godot --path src -- --playtest
```

A JSON report is written to:
```
~/.local/share/godot/app_userdata/othello/playtest_<unix_time>.json
```
It is written **on game over** and again **on quit** (the second write includes everything).

### What the report contains

| Field | Meaning | Which scenario it answers |
|-------|---------|---------------------------|
| `first_legal_move_ms` | Time from launch to the first legal move placed | "How long to get started?" |
| `moves_placed` | Legal moves placed | Did they engage with the loop? |
| `invalid_clicks` | Clicks on occupied/illegal cells | Did they understand legality without a highlight? |
| `skipped_turns` | Times a side was passed | Did they encounter and notice the skip notice? |
| `restarts` | Times Restart was used | Did they find and use restart? |
| `mode_changes` / `difficulty_changes` | Settings exploration | Did they discover the settings? |
| `completed` / `game_over` / `outcome` | Did the match finish; who won | Did the loop reach a satisfying end? |
| `events[]` | Ordered event trail with timestamps | Post-hoc reconstruction of the session |
| `duration_ms` | Total session length | Session pacing |

## 1.2 Session protocol

1. **Don't explain the game.** Say only: *"Here's a board game. Play it however you'd like."*
2. **Observe silently.** Note when they first touch the board, first hover over a cell, first click.
3. **Don't rescue.** If they seem lost, wait 15 seconds. Then ask: *"What are you trying to do?"*
4. **Think aloud.** After the match, run the debrief questions in §4.
5. **Record quotes verbatim** — especially confusion, delight, and expectation-violation.

## 1.3 Ground rules

- One human plays vs the computer unless the scenario says otherwise (PT-1 needs two people or a self-play proxy).
- Sessions are 5–15 minutes.
- Record the build commit: `git -C /home/nicolas/project/bro-codex-game-studio rev-parse --short HEAD`
- Minimum **3 sessions** across PT-1..PT-5 before the release-criteria checklist can be ticked.

---

# 2. Scenario Scripts

## PT-1 — First-time player, local PvP
**Goal:** A player who has never seen Othello can make legal moves and finish a match unaided.

**Setup:** Mode = "vs Player". Two players if available; otherwise the facilitator plays the second side.

**Script:**
1. Launch. Say only: *"This is a board game. Play it however you'd like."*
2. Observe: does the player notice the gold highlighted cells? Do they hover? Do they click a non-highlighted cell first?
3. Play to completion. Note who the player thinks is winning and how they know.
4. Find the Restart button. Note whether they do.

**Pass criteria:**
- Player makes legal moves without a hint (gold highlight is discoverable)
- Player can tell whose turn it is
- Player can find Restart
- Match reaches a game-over state

**Evidence to capture:** `first_legal_move_ms`, `invalid_clicks`, `moves_placed`, `completed`, quotes.

---

## PT-2 — First-time player, vs Computer (Easy)
**Goal:** The computer opponent feels like an opponent, not a random mover.

**Setup:** Mode = "vs Computer", Difficulty = Easy.

**Script:**
1. Launch with the same minimal prompt.
2. Observe the first move: hesitation? scanning? does the player use the highlight?
3. After the computer's first reply: *"What did the computer just do?"* — capture the answer verbatim.
4. Play 10+ moves. Note any moment the player was surprised.
5. Let it finish. Ask about the score display.

**Pass criteria:**
- Player understands it's playing against a computer
- Player can describe the computer's move (i.e. it looks intentional)
- "Computer is thinking..." is noticed and understood
- Score display is understood at game over

**Evidence:** `invalid_clicks` (does the highlight prevent mistakes?), `first_legal_move_ms`, quotes.

---

## PT-3 — Difficulty ladder
**Goal:** Easy → Medium → Hard is a perceptible ladder, and Hard is not broken.

**Setup:** Play the *same opening* against all three difficulties.

**Script:**
1. Play ~6 moves vs Easy. Ask: *"How hard is that?"*
2. Restart, same opening, Medium. Same question.
3. Restart, same opening, Hard. Same question.
4. Time the computer's response at each level.

**Pass criteria:**
- Perceived difficulty increases monotonically
- No difficulty is so slow it reads as broken (Hard ≤ ~1s wall-clock per move including the 0.8s "thinking" pause)
- No difficulty is so weak it feels random

**Evidence:** per-difficulty move times (from `events[]` timing), quotes.

---

## PT-4 — Pass and end-of-game
**Goal:** The skip notice and the final result are understood.

**Setup:** Play until a pass occurs (happens naturally in most games) and until game over.

**Script:**
1. When a skip notice appears: *"What's happening?"* — capture the answer.
2. At game over: *"What just happened? How do you know who won?"* — capture the answer.
3. Check whether the player reads the result as decisive or ambiguous.

**Pass criteria:**
- Player explains the skip ("that side can't move")
- Player explains the result (score → winner)
- Player does not think a draw is a bug

**Evidence:** `skipped_turns`, `outcome`, `completed`, quotes.

---

## PT-5 — Restart and settings
**Goal:** The settings are discoverable and restart is unambiguous.

**Setup:** Start a game, change settings mid-match.

**Script:**
1. Start vs Computer on Medium. Play a few moves.
2. Change Mode to "vs Player" mid-match. Observe: does anything visibly change? Does the player notice the turn label?
3. Change Difficulty. Observe.
4. Click Restart. Observe whether the board, score, and turn all visibly reset.
5. Ask: *"If you wanted to play a new game right now, what would you do?"*

**Pass criteria:**
- Player can find and use the settings
- Changing mode visibly updates the turn label ("Computer" ↔ "White")
- Restart visibly clears the board and resets score/turn
- Player can articulate how to start a new game

**Evidence:** `mode_changes`, `difficulty_changes`, `restarts`, quotes.

---

# 3. Observation Sheet (copy per session)

```
Session ID:            Date:              Tester:
Build commit:          Scenario(s):       Duration:
Players (name/role):   Mode / Difficulty:

--- Objective ---
first_legal_move_ms:   moves_placed:      invalid_clicks:
skipped_turns:         restarts:          mode/difficulty changes:
completed:             outcome:            duration_ms:

--- Timeline ---
[ ] t+0s    Session begins. Player sees the board.
[ ] t+__s   FIRST interaction with the board (describe)
[ ] t+__s   First legal move (highlight noticed? yes/no)
[ ] t+__s   First invalid click (what did they expect to happen?)
[ ] t+__s   First "Computer is thinking..." noticed
[ ] t+__s   First skip notice noticed
[ ] t+__s   Restart used
[ ] t+__s   Game over reached

--- Verbatim quotes ---
1.
2.
3.

--- Observed difficulties / confusions ---
-

--- Bugs found ---
| ID | Sev (P0-P3) | What happened | Repro steps |
|----|--------------|---------------|-------------|

--- Facilitator notes ---
-
```

---

# 4. Debrief Questions (after the match)

1. **What did you think this game was?** (open)
2. **What were you trying to do?** (open)
3. **How did you know it was your turn?** (open)
4. **How did you know which cells you could play?** (open)
5. **What did you think the computer was doing?** (open — PT-2/3)
6. **What was the best moment?** (open)
7. **What was the most confusing moment?** (open)
8. **What would you change first?** (open)
9. **Would you play this again? Why?** (open)

---

# 5. Debrief Report Template

```markdown
# Playtest Debrief — <scenario IDs> — <date>

**Sessions:** <n>  |  **Players:** <names/roles>  |  **Build:** <commit>

## Objective results
| Metric | Session 1 | Session 2 | Session 3 |
|--------|-----------|-----------|-----------|
| first_legal_move_ms | | | |
| moves_placed | | | |
| invalid_clicks | | | |
| skipped_turns | | | |
| restarts | | | |
| mode/difficulty changes | | | |
| completed | | | |
| outcome | | | |
| duration_ms | | | |

## Loop completion
- Did each player finish a match? yes/no — detail:
- Did the match end feel decisive? yes/no — detail:

## First meaningful action
- Time to first interaction:
- Did the player use the gold highlight before the first move? yes/no

## Core fantasy
- Did the "watching the board flip in your favor" moment land? yes/no — detail:
- Quotes:

## Blockers & confusion
- Top confusion point:
- Did any player need rescuing? (wait >15s) yes/no — detail:
- Settings discovered without prompting? yes/no

## Bugs
| ID | Severity | Summary | Repro |
|----|----------|---------|-------|

## Conclusion
- Scenarios passed:
- Scenarios failed:
- Recommendation: PROCEED / EXTEND / PIVOT
- Next owner:
```

---

# 6. Known Gaps to Watch For

These are logged risks — if a playtest confirms them, they become bug reports:

| Gap | What to watch for |
|-----|-------------------|
| No screen-reader announcements | A screen-reader user cannot learn the board state |
| No focus-visible ring | A keyboard user cannot see which cell is focused |
| Fixed 480×480 board | Player resizes the window and the board clips |
| No audio assets (placeholders) | Silent game — note whether that felt flat or fine |
| Hard difficulty has no time budget | 1.2s outliers on dense boards — note any perceived stall |
| Settings apply live mid-match | Player switches mode and the turn label changes — is that confusing? |

---

# Next Owner / Decision

- **Decision requested:** run 3 human sessions covering PT-1..PT-5 and file the debrief report.
- **Next owner:** qa-playtester (facilitator) with a second person for PT-1 PvP.
- **Dependency:** the Epic 5 differentiation spike (STORY-3.6) should be informed by the PT-2/PT-3 findings — in particular whether players read the AI as intentional or opaque, which is exactly the gap the "Intent" mechanic targets.
