# N3 hockey-play: make hockey playable (puck, speed, AI decisions)

Read `docs/shifts/2026-11-22-night/COMMON.md` first. Then read `docs/research/HOCKEY-ARCADE.md` IN FULL: it is your spec,
and you implement §5. Also read `engine/packs/hockey/README.md`, which describes yesterday's thirdjam port.
- **Worktree:** `C:/Users/kazda/kiro/third-life/.claude/worktrees/n22-hockey`.
- **Route:** Opus director, Astra builds.
- **Land:** by 06:00.
- **Selftest:** 730-739.

## The owner, 21 Nov
"THe game is unplayable through inbalancing of puck stickiness, players speed, ability AI to decide what to do, when to
pass and shoot." Also: keep the body-check rate as it is now; the big puck uses a kernel radius setter (N1 builds
`TLBall.set_radius`).

## Work, in the order a player feels it (gate each step)
1. **The puck carry as a state with readable loss causes** (§5.1):
   - a spring anchor at the drawn blade, with dangle from speed and turn rate, and self-loss only on a sprint plus a hard
     turn;
   - pickup and bobble by relative speed;
   - pass reception with a soft magnet, and the one-timer window;
   - poke check with angle and timing, a cooldown and a whiff cost;
   - the anti ping-pong rule;
   - the vetoes.
   Scale the anchor and radii to our 4.4 m figure, as L4 scaled the carry distance.
2. **The speed table** (§5.2): keep the RATIOS (pass about 2x cruise, carrier x0.88, acceleration over top speed, goalie
   lateral speed below a cross-slot pass) and tune the absolute numbers to our rink with bots.
3. **The AI decision model** (§5.3, §5.4):
   - decisions at 4 Hz, staggered, interrupted on events, with a commitment bonus;
   - utility scores for SHOOT / PASS / CARRY / PROTECT / DUMP, with the named inputs and vetoes;
   - perception lag and noise by difficulty, and no state reads the player could not see;
   - roles F1/F2/F3 and D1/D2/D3 re-sorted by time-to-puck;
   - the support-spot grid;
   - the goalie on the puck-to-net line with a lateral cap;
   - teammates who call for the pass and never take the puck from the human.
4. **The five bot metrics** (§5.5), measured per hand and difficulty over at least 20 seeds, written to a table in the
   README:
   - possession length;
   - passes per possession and completion;
   - shots per minute and the slot/one-timer share;
   - turnovers by cause;
   - offensive-zone share and goals.
   Tune until each is inside its band.
5. **Big puck:** switch to `TLBall.set_radius` when N1 lands. The Director merges main into your tree and tells you.

## Acceptance
- The 5 metrics inside their bands, with the table showing before and after.
- packs green and world 8/8 = alone. Hockey hashes move: say why for each.
- Hockey invariants p50 ≤ 1.0 ms: quiet, or an A/B against main labelled busy.
- The ladder re-run, quoted with hands. The idle hand still wins nothing.
- **Clips judged by you in a window, 20 s or less:**
  - a passing play ending in a one-timer;
  - a poke that frees the puck;
  - the carrier losing it on a hard sprint turn;
  - a defensive rotation.
- **Not a lane claim:** the owner's hand decides "playable"; say plainly what you could not judge by hand.
