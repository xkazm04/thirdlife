# H2 bots: hockey behaviour teardown, the bots and the sandbox

Shift 2026-11-23-day. Worktree `C:/Users/kazda/kiro/third-life/.claude/worktrees/d23-bots` (branch `d23-bots`, at main
c4b0b83). Route: Opus solo, research only. Started 09:30. Landable round 1 by 12:00, round 2 by 14:00.

## The owner's words (23 Nov, after reading the first teardown), verbatim
"Hockey - the points you identify plays minority role. You are focused on visual perspective where as the core of
gameplay design is in behavior, which is almost untouched by your analysis. Please do repeat it - it is about sensitivity
of movement (speed, accelaration, deaccelaration), tackles/croschecks and their reactivity, bot aggressivity and ability
to play hockey, openness to sandbox the game (bring weapons, special equipment and boosts), stick control with puck and
ability for puck to stick to players"

He will play hockey this evening. He judged thirdjam "a mediocre hockey game we delivered but at least it has set basic
gameplay mechanics, AI, bugless graphics and balanced speed", and ours "unplayable garbage".

## What the first teardown got wrong (read it first: `docs/research/hockey-teardown/TEARDOWN.md`, 2.7, 2.8)
It compared the AI's **code and constants** (cadence, reaction frames, role names) and did not measure what the bots DO
on the ice. Lane H1 measures the player's own body, hits and puck; you measure the ten bots and the game's openness.

## Your two areas
1. **Bot aggressivity and ability to play hockey**, in both games, per level, measured from the running game with the
   same definitions:
   - *Aggressivity:* frames from a carrier gaining the puck to the first opponent within stick reach; how many
     opponents are within 5 m / 10 m of the carrier over time; pokes, checks and cross-checks attempted and landed per
     minute; how deep they forecheck; what they do to the human in particular; how it changes by level (the owner's
     2026-11-13 direction for thirdjam: "difficulty = aggression").
   - *Ability to play hockey:* passes attempted / completed per minute and their length; possession chains (touches
     before a loss); shots per minute, from where, on net or not; zone entries (carried, dumped, lost); time the puck is
     loose; time in each third; team shape (spread of the five, how many chase the puck); what a bot does without the
     puck (support, cover, net front); goals per minute and how they are scored; idle or broken behaviour (standing,
     circling, piles, own-goals), counted.
   - *As the human's mates and opponents:* how often mates pass to the human, shoot themselves, win the puck back; what
     the human's first 60 seconds contain.
   Trace every large difference to its cause on our side (file:line under `engine/packs/hockey/scripts/ai/`, `data/`),
   and name every rule of ours that exists to move a bot metric (the README says which).
2. **Openness to sandbox the game: weapons, special equipment, boosts.** What thirdjam offers and how it is built
   (its cartridge / modes / abilities-on-F / crazy modes: `GAME.md`, `docs/VISION.md`, `docs/PLAY-ME.md`,
   `contracts/RULINGS.md`, `JamCartridge.h`, the mode list the owner asked for in R-0069), what the owner ruled about
   it, and how cheap a new toy is there (what one must touch to add one). The same for ours (`engine/packs/hockey`
   modes and data, what L4 ported as "crazy modes", `TL*` API hooks). Then: what a Third Life game needs so a player
   can bring a weapon, a piece of equipment or a boost into hockey: the seams (who owns speed, mass, reach, the puck's
   law; can an item change them at run time; does the AI understand a changed rule), a list of 8-12 concrete toys
   ranked by fun-per-cost, and which three you would build first. This is design, not a build.

## How to measure
- **Ours:** a headless probe in a COPY of the pack under `.tl/` (round 1's is at
  `C:/Users/kazda/kiro/third-life/.claude/worktrees/n23-teardown/.tl/probe`: copy its idea, not its folder; another lane
  is working there). 20 seeds a cell, all-AI and with the ladder hands (`TLHand` newcomer, regular) at rookie / pro /
  all-star. `G` is the Godot console exe (`node devx/bin/tl.mjs doctor` prints it).
- **thirdjam:** the clone is at `C:/Users/kazda/kiro/third-life/.claude/worktrees/n23-teardown/.tl/thirdjam` (read
  only), the runnable 15 Nov build at `.../n23-teardown/.tl/tj-run/Game` (how to start it: TEARDOWN.md section 1; run it
  with `-Multiprocess` and your OWN log and still folders under your tree's `.tl/`; lane H1 runs it too). It has its own
  telemetry and headless playtester (`docs/experiments/`, `BRAIN-*.md`, `docs/EVOLUTION.md`, `tools/`): use its event
  log where it has one; where it has none, count from its log lines or its stills. Its recorded experiment results
  (BRAIN tables) are evidence if you name the build they came from. Never edit the clone or `C:/t/t5`.
- Same definitions on both sides, written down once in the report. Where a quantity could not be measured on one side,
  say so plainly and say what stands in.
- Look at one thing per area **as a person meets it**: a 20 s clip or sheet of each game's bots with the puck.

## Deliverable
`docs/research/hockey-teardown/BEHAVIOUR-BOTS.md`, written for the owner (plain words, short sentences):
- **0. The verdict in ten lines.**
- **1. Aggressivity**, **2. Ability to play hockey**: tables thirdjam / ours by level (measured, instrument named), one
  sheet each (`media/bots_*.jpg`, under 300 KB each), "what the player meets", "why ours does this" with file:line.
- **3. The sandbox**: thirdjam's toys and seams, ours, the toy list, the first three.
- **4. The behaviour sheet for our bots**: target numbers and rules (in the player's units) that would make our bots
  press and play hockey at least as thirdjam's do; each marked "data change", "pack code" or "kernel"; the rules to
  delete (those that serve a bot metric).
- **5. What this could not see**, and the evidence index. Instruments (under 200 lines each) go in
  `docs/research/hockey-teardown/probes/`.

## Acceptance
- Every row has two measured numbers or says plainly why not.
- Aggressivity and ability are given per level for both games.
- The sandbox section names, for each game, the exact files one touches to add one new toy, and ranks 8-12 toys.
- Section 4 gives numbers and rules a builder could apply without asking.
- Nothing under `engine/`, `foreman/`, `contracts/` or `devx/` changes. `node devx/bin/tl.mjs check --tier fast` passes.

## Scope
Write: `docs/research/hockey-teardown/BEHAVIOUR-BOTS.md`, `docs/research/hockey-teardown/media/bots_*`,
`docs/research/hockey-teardown/probes/bots_*`, `docs/shifts/2026-11-23-day/lanes/H2-bots/`. Everything else under `.tl/`
of your own tree. Absolute paths only; never `cd` in a backgrounded line. When a round is landable, say so in
STANDUP.md, send no further edits until told "landed", and return the report as your final message (the Director will
message you for round 2). Round 1 = area 1 with section 0 drafted; round 2 = area 2 (sandbox), sections 4-5.


---

# Lane rules (pasted verbatim into every lane brief)

## Standups: you report, the Director reads
- Keep `docs/shifts/2026-11-23-day/lanes/H2-bots/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
