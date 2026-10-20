# Playtest Debrief — Synthetic Instrumentation Validation — 2026-10-19

**Type:** Automated simulation (not a human session)
**Purpose:** Validate that the playtest instrumentation captures objective session evidence end-to-end, before human sessions are run
**Build:** commit `6b18fb6` + playtest instrumentation
**Runner:** Godot MCP (`execute_game_script` driving the live game)

> **This is NOT a substitute for a human playtest.** It proves the *measurement* works. It does not measure comprehension, delight, or confusion — only a human session can do that. See `production/playtest/README.md` for the human protocol.

---

# Objective Results

Source: `production/playtest/sample-session-report.json`

| Metric | Value |
|--------|-------|
| `first_legal_move_ms` | 3281 (3.3s after launch) |
| `moves_placed` | 1 |
| `invalid_clicks` | 3 |
| `skipped_turns` | 0 |
| `restarts` | 1 |
| `mode_changes` | 1 (vs Computer → vs Player) |
| `difficulty_changes` | 1 (Medium → Hard) |
| `completed` | false (session ended before game over) |
| `duration_ms` | 47437 (includes idle time between scripted steps) |

---

# What the Session Did (and What It Proved)

| Action | Result | What it validates |
|--------|--------|-------------------|
| Click (0,0) — illegal empty cell | `invalid_click` logged | Illegal clicks are detected and counted, not silently dropped |
| Click (2,4) — legal for Black | `first_legal_move` + `move` | Time-to-first-legal-move is captured |
| Click (2,3) — **illegal for Black** | `invalid_click` logged | **The logger correctly distinguished a legal from an illegal cell** — the ground-truth legal moves for Black are (2,4), (3,5), (4,2), (5,3); (2,3) is not one |
| Click (2,4) again — now occupied | `invalid_click` logged | Occupied-cell rejection is captured (RC4 behavior confirmed) |
| Change Mode → vs Player | `mode_change` logged | Settings exploration is captured |
| Change Difficulty → Hard | `difficulty_change` logged | Settings exploration is captured |
| Click Restart | `restart` logged | Restart usage is captured; board/score/turn visibly reset (`Black: 2/White: 2`, `Turn: Black`) |

---

# Loop Completion

- The scripted session did **not** reach a game over (it was terminated early), so `completed: false` and `outcome: ""` — the logger correctly reports an incomplete match rather than a default.
- The `record_game_over` path is covered separately by harness assertion `PT-AT-3` (records completion, outcome, and winner).

---

# First Meaningful Action

- First interaction: 2704ms (first click).
- First legal move: 3281ms.
- A real first-time player would likely click a non-highlighted cell first — the simulation reproduced exactly that behavior (invalid click before the first legal move), which is the pattern the metric exists to measure.

---

# Core Fantasy

**Not measured.** A synthetic run cannot evaluate "watching the board flip in your favor". This requires a human session (PT-2/PT-3 debrief questions 4–7).

---

# Blockers & Confusion

**Not measured** for the same reason. However, the simulation did surface one **factual** finding worth carrying into the human session:

> **Finding F1:** A player who does not notice the gold legal-move highlight will click illegal cells and receive only "Invalid Move!" — the game gives no *explanatory* feedback about *why* the cell was invalid (e.g. "not adjacent to a disc" / "that square is taken"). The message says something happened, not what the rule is.

This is a candidate for the human session to confirm: does "Invalid Move!" alone satisfy a first-time player, or do they need the reason? If the latter, that is a cheap, high-value change to S8 feedback (differentiating "that square is occupied" from "no discs to flip there").

---

# Bugs Found

| ID | Severity | Summary |
|----|----------|---------|
| — | — | None. The session produced **0 runtime errors** attributable to the game (the only warnings in the editor log came from the MCP's own injected scripts, not from `othello.gd`). |

One code-quality warning surfaced and was fixed: `othello.gd` `_notification(what)` — unused parameter (renamed `_what`).

---

# Conclusion

- **Instrumentation:** PASS — all seven objective metrics captured, and the legal/illegal distinction is correct.
- **Human sessions:** STILL REQUIRED — 3 sessions covering PT-1..PT-5.
- **Recommendation:** PROCEED to the human playtest, using `production/playtest/README.md` as the facilitator script. Carry **Finding F1** into the PT-1/PT-2 sessions as a targeted question.

---

# Next Owner / Decision

- **Decision requested:** qa-playtester runs 3 human sessions (PT-1..PT-5) and files the debrief report.
- **Next owner:** qa-playtester (facilitator) + one additional player for PT-1 PvP.
- **Dependency:** the PT-2/PT-3 results (does the player read the AI as intentional or opaque?) feed directly into the Epic 5 "Intent" spike decision.
