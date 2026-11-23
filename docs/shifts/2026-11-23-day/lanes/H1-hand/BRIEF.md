# H1 hand: hockey behaviour teardown, the player's own body (movement, contact, stick and puck)

Shift 2026-11-23-day. Worktree `C:/Users/kazda/kiro/third-life/.claude/worktrees/n23-teardown` (branch `n23-teardown`,
at main c4b0b83). Route: Opus solo, research only. Started 09:30. Landable round 1 by 12:00, round 2 by 14:00.

## The owner's words (23 Nov, after reading the first teardown), verbatim
"Hockey - the points you identify plays minority role. You are focused on visual perspective where as the core of
gameplay design is in behavior, which is almost untouched by your analysis. Please do repeat it - it is about sensitivity
of movement (speed, accelaration, deaccelaration), tackles/croschecks and their reactivity, bot aggressivity and ability
to play hockey, openness to sandbox the game (bring weapons, special equipment and boosts), stick control with puck and
ability for puck to stick to players"

He will play hockey this evening. He judged thirdjam "a mediocre hockey game we delivered but at least it has set basic
gameplay mechanics, AI, bugless graphics and balanced speed", and ours "unplayable garbage".

## What the first teardown got wrong (read it first: `docs/research/hockey-teardown/TEARDOWN.md`, 2.3, 2.4, 2.9)
It compared **code and constants** and concluded that skating and contact were "ported faithfully, line for line", then
ranked scale, camera and presentation on top. A ported line is not a ported behaviour: ours runs on another body
(`TLBiped`: the intent scales thrust, not top speed), another physics engine (Jolt rigid bodies against thirdjam's own
integrator in `JamSim.cpp`), another base speed (8 against 11 m/s), another scale (2.2x figures), another puck (a rigid
body with a spring against a kinematic carry). Nobody measured what a hand gets back from a key press. That is this lane.

## Your three areas (lane H2 has the bots and the sandbox; do not do those)
For each area: measure **the same quantities with the same instrument in both games**, as curves and numbers, in metres,
in frames at 60 Hz, and in each game's own units (body widths, fractions of the rink). Then say what a hand feels and why.

1. **Movement sensitivity.** From rest, full stick: time and distance to 50 % and 90 % of top speed. From top speed:
   time and distance to stop on release, and on reversed input. A 90 and a 180 degree turn at top speed: time, radius,
   speed kept. Sprint: onset, gain, cost. The same for the puck carrier. Small inputs: what a 3-frame, 6-frame, 12-frame
   tap moves the body (the "sensitivity": can you place yourself?). Input-to-first-motion delay in frames. Speed over time
   plots for both games on the same axes.
2. **Tackles and cross-checks, and their reactivity.** Press to active frames, reach, arc, how long it stays live,
   recovery on a whiff, cooldown. The outcome table by closing speed and angle (bump, stagger, knockdown). What the
   victim does and for how many frames (stagger, down, get-up, when control returns). What the attacker pays. Hit-stop
   and anything else that takes the hand away. How it differs when the puck carrier is hit. Poke and lift the same way.
   "Reactivity" is: frames from the press to something happening, and frames until both bodies answer the hand again.
3. **Stick control with the puck, and the puck sticking to players.** How a loose puck becomes yours (ring, speed
   limits, frames from touch to control), measured as pick-up success against approach speed and angle. While carrying:
   the puck's distance from the blade over time through a hard turn, a stop, a sprint, a 180; when and why it comes off
   (count each cause per minute of carry). How the stick/aim moves the puck (deke, shield). How it behaves on a received
   pass. The owner's ruling R-0069 ("puck is not controlled by player if in his circle area") is the bar: test it on ours.

## How to measure
- **Ours:** headless tests in a COPY of the pack (`.tl/probe/hockey` is there from round 1; refresh it from
  `engine/packs/hockey`). Scripted inputs through the pack's own input path (what a key press does), one skater on empty
  ice for area 1 and 3, two for area 2. Log per frame: position, velocity, facing, state, puck position, owner.
  `G` is the Godot console exe (`node devx/bin/tl.mjs doctor` prints it).
- **thirdjam:** the clone is `.tl/thirdjam` (HEAD 8dc713c6), the runnable 15 Nov build `.tl/tj-run/Game` (how to start
  it: TEARDOWN.md section 1). Find the cheapest honest instrument, in this order: (a) its own headless sim / playtester
  or automation tests if the build runs them with scripted inputs and logs per frame; (b) the rendered game with
  `jam.ScriptHuman` or other `jam.*` console variables and its own telemetry; (c) only if neither can do a quantity, a
  small standalone integration of `JamSim.cpp`'s law for that quantity (say so, and check one point of it against film).
  Never edit `.tl/thirdjam` or `C:/t/t5`; work in copies.
- Check one figure per area **in a window as a person meets it** (ours: `tl play hockey`; a clip of a scripted tap is
  enough), so a headless number is not the only witness.
- Where a number of ours differs from thirdjam's, trace it to its cause in our code (file:line): the kernel body, the
  scale, a constant, a guard somebody added for a bot metric.

## Deliverable
`docs/research/hockey-teardown/BEHAVIOUR-HAND.md`, written for the owner (plain words, short sentences, no jargon he did
not use):
- **0. The verdict in ten lines**: the five biggest differences a hand feels, each with its two numbers.
- **1-3. One section per area**: a table thirdjam / ours (measured, with the instrument named), one plot or sheet
  (`media/beh_*.jpg`, under 300 KB each), "what the hand feels", "why ours does this" with file:line.
- **4. The behaviour sheet for our hockey**: the target numbers (in the player's units) that would make our body, hits
  and puck answer like thirdjam's at least. thirdjam is the floor, not the bar: where `docs/design/CASES.md` or a public
  source gives a proven arcade-hockey number (NHL '94, Hitz, Blades of Steel), put it beside. Mark each target
  "data change", "pack code" or "kernel".
- **5. What a design must measure before a build** (a proposal for `docs/design/METHOD.md`, at most 15 lines: the
  step-response sheet as a required artefact). Do not edit METHOD.md; the Director does.
- **6. What this could not see**, and the evidence index. Instruments (scripts under 200 lines each) go in
  `docs/research/hockey-teardown/probes/`.

## Acceptance
- Every row of every table has two measured numbers (or says plainly why one side could not be measured, and what was
  used instead).
- Area 1 has speed-over-time curves of both games on one plot, for start, stop and turn.
- Area 2 has a frame timeline (press, active, contact, victim free, attacker free) for both games.
- Area 3 has carry-loss causes per minute and pick-up success against speed for both games.
- Section 4 gives numbers a builder could apply without asking.
- Nothing under `engine/`, `foreman/`, `contracts/` or `devx/` changes. `node devx/bin/tl.mjs check --tier fast` passes.

## Scope
Write: `docs/research/hockey-teardown/BEHAVIOUR-HAND.md`, `docs/research/hockey-teardown/media/beh_*`,
`docs/research/hockey-teardown/probes/hand_*`, `docs/shifts/2026-11-23-day/lanes/H1-hand/`. Everything else under `.tl/`.
Absolute paths only; never `cd` in a backgrounded line. When a round is landable, say so in STANDUP.md, send no further
edits until told "landed", and return the report as your final message (the Director will message you for round 2).
Round 1 = areas 1 and 3 with section 0 drafted; round 2 = area 2, sections 4-6.


---

# Lane rules (pasted verbatim into every lane brief)

## Standups: you report, the Director reads
- Keep `docs/shifts/2026-11-23-day/lanes/H1-hand/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
  when the lane lands).
- Append one line at each milestone and at least every 60 minutes of work:
  `HH:MM | state: working|blocked|done|cut | did: <one line> | next: <one line> | gates: <last PASS/FAIL line or ->`
- `blocked` names the question in the same line. Then keep working on whatever the block does not touch.
- When you finish, write `REPORT.txt` beside it (the harness refuses agent writes to files named REPORT.md), return the
  full report as your final message too, and set the last standup line to `done`.

## Honesty
- Evidence or it is not done: a gate line, a test count, a still, a video, a repro before and after.
- A stopped run is never a pass. NOT RUN is not PASS. Fewer tests completed than on main is a stopped run.
- Unmeasured is not zero. Never fake a frame, a figure or a hash.
- A behaviour change that moves a test expectation is named, with why. Never loosen a test to make it pass.
- What the player sees or feels is judged as a person meets it (a window, the exported game), not only headless.

## Laws (CLAUDE.md)
- Work only in your worktree. No git that writes (read-only `git diff`/`git status` are fine). The Director lands.
- Never kill a process you did not start. Prefer `--headless`. Build the class cache once: `"$G" --headless --path engine --import`.
- Time is physics frames; determinism (same pack + seed + frames = same state_hash); unknown keys are errors; packs use only
  the TL* API and never declare class_name; kit, rigs, style reference nothing outside themselves.
- Contracts (`contracts/*`) are Director-only: put the question in your report.
- New selftest cases go in your own `engine/tools/selftest.d/NNN-<name>.sh` files, numbered inside the block range your brief
  assigns (two lanes once collided on 360).
- Raw captures (frame folders, long or uncompressed clips, mkv/avi) stay under `.tl/` in your worktree. The lane folder
  gets only sheets, notes, JPG stills and mp4 clips of 30 s or less.
- A kernel API addition updates `engine/kernel/API.md`; the Director regenerates docs on main (`tl arch --index`).
- Gates before `done`: `node devx/bin/tl.mjs check --tier fast`; when kernel, kits, rigs, style or seeds changed, also
  `node devx/bin/tl.mjs check --tier full` (perf alone if it says NOT RUN).

## REPORT.md
- Outcome against each acceptance criterion: met / not met, with its evidence.
- Gates with PASS/FAIL lines and counts.
- Changed files; behaviour changes; anything the owner should look at, and how.
- Questions for the Director; the next three things this lane would do.
