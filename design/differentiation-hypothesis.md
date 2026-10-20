# Differentiation Hypothesis — Othello

**Date:** 2026-10-19
**Owner:** senior-game-designer + producer
**Epic:** 5 (post-gate)
**Status:** Spike **executed** — **DECISION: KILL (as designed)**; see `production/spike-intent-report.md`

---

# Context

The prototype gate passed (2026-10-19) with a verified, rule-faithful Othello: 90 automated assertions, 0 runtime errors, WCAG-AA contrast, keyboard play, and a depth-1/3/5 AI ladder.

Per the approved GDD, **differentiation is an explicit Non-Goal for the prototype** and is deferred until after the gate. The gate has now passed, so this document opens Epic 5.

The purpose of this hypothesis is **not** to redesign Othello. It is to identify the single smallest mechanic that would make this build *not* a generic Othello clone, then prove or kill that mechanic with a throwaway spike.

---

# Constraints (from the approved GDD pillars)

Any candidate must preserve the frozen product-identity contract:

1. **Rule fidelity** — standard Othello/Reversi only; every capture explainable by the flanking rule; no house rules.
2. **Readable board** — score, turn, and match state visible at a glance.
3. **Instant local play** — a match starts in seconds; no accounts, tutorial wall, or network; restart is one click.

Also: no online play, no accounts/telemetry, no progression/unlocks/meta/monetization, no content authoring beyond vs-AI and local PvP, no localization beyond English, and accessibility is limited to basic keyboard operability.

> **Important:** constraint 1 is the hardest. A differentiation that *changes the rules* is off the table — that would break "rule fidelity" and invalidate the approved pillars. The candidate must be an **adjacent layer on top of** standard Othello, not a variant of it.

---

# The Candidate Hypothesis

## Fantasy
*"I can see the board changing its mind."* — the same quiet satisfaction as the base game, but with a visible read on the AI's intent.

## Core Mechanic — **"Intent"**
The AI's *top candidate moves* are surfaced to the player as a subtle visual tell, and the player can *challenge* that read.

- On the AI's turn, the top 1–2 candidate cells carry a faint marker (a ring or dim dot) before the AI commits.
- The player may **challenge** the read (one action per turn): if the AI's chosen move is one of the marked candidates, the player scores a **Read bonus**; if not, the AI gains a small edge.
- The markers are advisory, not a guarantee — the AI still plays its best move, so the challenge is a *read*, not a prediction with a fixed answer.

## Why this could work
- It **layers** on top of standard Othello (rule fidelity intact).
- It makes the AI **legible** rather than opaque, which directly serves the "readable board" pillar.
- It creates a **single-player fantasy** (out-thinking the machine) that a plain clone does not have.
- It is **cheap**: the AI already computes a ranked candidate list during minimax; the mechanic is a rendering change plus a scoring flag.

## Target audience
Players who play Othello *against* the computer (not only against each other) — the audience that currently finds the AI opaque or "random".

---

# Risks (and the kill criteria)

| Risk | Kill criterion |
|------|-----------------|
| Markers leak the answer and make the game trivial | If playtesters report the AI becomes "too easy" or "the answer is given away", the candidate is **killed** or the marker is reduced to a weaker signal (e.g. only a direction hint) |
| The challenge action adds friction without meaning | If playtesters ignore the challenge entirely (< 25% usage), the mechanic is **killed** |
| It damages the PvP mode (a pillar-adjacent feature) | If PvP playtests report confusion, the mechanic is **restricted to vs-AI only** |
| It breaks rule fidelity | Any candidate that changes move legality or capture rules is **killed on sight** |
| It complicates the board visually | If the marker reduces board readability (a pillar), it is **killed** |

**Decision options at the end of the spike:** PROCEED (build it), KILL (drop it, keep the faithful clone), PIVOT (keep the theme, replace the mechanic with a different one).

---

# Spike Plan (2 days, throwaway)

| Day | Task | Output |
|-----|------|--------|
| 1 (morning) | Instrument `_get_best_move` to also return the ranked top-3 candidate list | Candidate list exposed alongside the move |
| 1 (afternoon) | Render a faint marker on the AI's top candidate(s); add a "Challenge" button to the status bar | Visible tell + action affordance |
| 2 (morning) | Wire the Read bonus (score/feedback) and the challenge-consumed flag | Mechanic is playable end-to-end |
| 2 (afternoon) | Internal playtest (1 tester, 15 min, vs AI Easy + Hard) + PvP regression check | Debrief notes |

**Spike constraints (hard):**
- Runs on a **throwaway branch** (`spike/intent`), never merged as-is.
- Touches **no** P0/P1 rule code — only additive rendering + a new score flag.
- The 90 automated assertions must still pass on the spike branch (or the spike is invalid).
- **Cleanup boundary:** the branch is deleted after the decision; only a written decision survives.

---

# Alternatives Considered (and why not)

| Alternative | Why rejected |
|-------------|--------------|
| Playable "beginner/advanced" board sizes (6x6, 10x10) | Breaks the single-board readability and adds a content axis; also risks "house rules" framing |
| Timed matches / chess-clock pressure | Breaks "instant local play" and "quiet satisfaction" fantasy; adds stress to a contemplative game |
| Ranked ladder / progression | Explicitly a Non-Goal (no progression, unlocks, or meta) |
| Hints on demand (show a legal move) | Too close to the existing legal-move highlight; the "Intent" idea is the more interesting version of the same theme |
| Online play | Explicitly a Non-Goal (no networking) |

---

# Decision Record (to be completed after the spike)

```
Date:               2026-10-19
Spike branch:       spike/intent
Build played:       105 assertions, 0 failures; live MCP verification
Playtester(s):      automated (no human session — this decision was made on
                    a technical + design review of the implemented spike, not
                    on player feedback)
Observation: did the player use the challenge?  N/A — 50/50 guess by construction
Observation: did the player read the markers?  N/A — markers show the top-2,
                    which is a 50% guess, not a legible reasoning trace
Observation: did the AI become trivial?     No — the AI's move is unchanged;
                    the markers only reveal candidates it already considered
PvP regression:     clean — the mechanic is vs-AI only; PvP verified unaffected
Automated assertions: still 105/105 (96 pre-existing P0/P1 + 9 spike)

DECISION: KILL (as designed) — with a narrowed alternative carried forward
Rationale: The mechanic is technically cheap (a corner dot + a click), which
           means it is a feature, not a differentiator. The prediction is a
           50/50 guess rather than a skill read, so it fails the "core
           mechanic" bar. It also taxes the pacing of a contemplative game
           (the "quiet satisfaction" pillar) and adds chrome to a board that
           just passed a readability pass. The underlying need is real —
           players must be able to read the AI — but the answer is
           legibility, not a timed guessing game.
Follow-up:   Test AI opacity in the PT-2/PT-3 human sessions. If confirmed,
             prototype surfacing the AI's *reason* (corner / mobility / disc
             count) rather than a guessable candidate list.
Cleanup:     Branch archived, not merged. 'main' remains the faithful clone.
             Full report: production/spike-intent-report.md
```

> **Note:** the human playtest (3 sessions, PT-1..PT-5) had not been run at the
> time of this decision. The decision therefore rests on a *design* argument
> (a 50/50 guess is not a skill mechanic; a corner dot is not an identity) and
> on the implemented spike's verified behaviour — **not** on player feedback.
> If the human sessions show players *do* want to engage with AI reasoning,
> this decision should be revisited with the alternative (legibility) rather
> than the prediction game.

---

# Next Owner / Decision

- **Decision requested:** approve the **"Intent"** hypothesis and the 2-day spike plan as the Epic 5 candidate.
- **Next owner:** senior-game-designer executes the spike on branch `spike/intent`; producer records the decision.
- **Fallback if the spike is not staffed:** keep the faithful clone and record Epic 5 as "KILLED — defer to post-content-complete". This is a legitimate outcome; differentiation is not a gate requirement.
