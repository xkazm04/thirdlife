# K4 reference: what thirdjam's play is made of (tempo map, mechanic matrix, hand ladder)

Campaign night of 23-24 Nov 2026. Worktree `C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-ref` (branch `hk-ref`,
cut from the campaign branch `hokej` at aa609ce, which has the native rink core). Route: Opus solo. Rounds of 60-90 min.

## The owner's words (23 Nov)
"be aware, the pictures will not uncover core problem which is the gameplay itself in speed and balancing of skill
mechanisms to play the game". And of thirdjam: "a mediocre hockey game we delivered but at least it has set basic
gameplay mechanics, AI, bugless graphics and balanced speed".

## Goal
Directions 2, 3 and 4 of `docs/design/DIRECTIONS.md`. Our new game runs thirdjam's own simulation and bots (lane K1
compiled them unchanged; its traces equal the Unreal build's line for line). So the game's speed and balance are now
thirdjam's by construction. What nobody has is a **written, measured description of that play**: how fast it is as
ratios, which skill mechanics matter and what answers them, and how much skill shows. You produce it, from the running
game, as (a) the floor every later change is held to, (b) the list of where thirdjam itself is weak (it is "mediocre":
the surpass step starts there), and (c) a harness the gate can run so a change that moves the balance is seen.

## Instruments (all without Unreal; the machine has little RAM)
- `bash engine/tools/rink.sh` (read it): builds and runs thirdjam's own tournament commandlet natively, about 2 s a
  match: `-cartridge=hockey.regular -seeds=a-b -mode=playerbot|playerbot_ai|brain|idle -difficulty=rookie|pro|all_star
  -player=novice|regular|good -playersprint -trace=N -maxframes=`; a `thirdjam.playtest/1` JSON line per match; the
  per-frame TRACE. `engine/cores/rink/SNAPSHOT.md` lists every state field. The `RinkCore` class steps the same
  simulation from GDScript with any input you send for the human's skater.
- thirdjam's human-like hands are `native/thirdjam/.../JamPlaytester.cpp` (novice, regular, good). For ablation you
  need hands with one verb removed or only one verb allowed: build them as a **lab variant** in
  `engine/cores/rink/lab/` (a copy of the playtester with marked switches, or a wrapper that filters its input struct
  before the step; prefer the filter: it needs no change to thirdjam's file), compiled into a lab runner. The shipped
  core under `native/` stays byte for byte thirdjam's; you do not edit it.
- Use the HEAD source (the game the owner knows), not the 15 Nov tree.

## What to produce: `docs/research/hockey-teardown/PLAY.md`, for the owner (plain words, short sentences)
1. **The tempo map.** The game's speed as ratios in the player's units (frames, body widths of 0.80 m, rink lengths of
   90 m): zone and rink crossing times (cruise, sprint, carrier); a chaser's gain on a carrier and the time to close
   5 / 10 / 20 m; each hit's and the poke's wind-up and reach against those closing speeds (from how far away must you
   commit?); pass flight times over 5 / 15 / 30 m against a defender's time to step into the lane; shot flight from
   10 / 20 m against a blocker's reaction; stamina: seconds of sprint, seconds to refill; how long a carry, a
   possession, a shift between events lasts in real matches; decisions a minute a hand makes. One table, one page.
2. **The mechanic matrix.** For each verb the human has (skate, sprint, brake / stop, deke, spin, shield, pass, held
   pass, one-timer, tap shot, charged shot, poke, lift, body check, cross-check, brace, ability, signals to mates):
   its cost, its reward, its window, what beats it (from the source, with file:line), and then **measured by
   ablation**: the regular and the good hand at each level over at least 200 seeds, with the verb removed, against the
   full hand: goals for and against a minute, wins, possession share, shots, carries lost. And the reverse where it
   makes sense (a hand with only that verb beyond skating). Say plainly which verbs are dead (removing them costs
   nothing), which dominate (winning nearly alone), which have no answer, and which answers nobody uses.
3. **The skill ladder.** idle / novice / regular / good hands x rookie / pro / all-star, at least 200 seeds a cell: wins,
   goal difference, time to first goal, possession. Does skill show at every level? Does the level ladder mean harder
   by clumsiness or by absence? Where is it flat?
4. **What thirdjam is weak at**, ranked, as a player would meet it (from 1-3 and from watching traces of whole matches:
   stalls, piles, dead time, a verb that never comes up, a level that plays the same as another), each with its
   evidence. This is the list the "surpass" step starts from; do not fix anything.
5. **The harness**: one command (`bash engine/tools/rink.sh balance` or a `tl` command) that re-runs a small fixed
   subset (the ladder and the five most telling ablations, under 3 minutes) and prints the figures with the recorded
   baseline beside them, so a later change to a cartridge or the core shows what it moved. Baseline committed as JSON.

## Acceptance
- Every figure names its instrument, seeds and hand; every "what beats it" cites thirdjam's source line.
- The ablation table covers every verb the input struct has (or says why one could not be removed).
- The weak list has at least eight entries, each with a measured figure or a traced match and frame.
- The harness runs from a clean build by one command and reproduces its baseline exactly (determinism).
- Nothing under `engine/cores/rink/native/` changes. `node devx/bin/tl.mjs check --tier fast` passes.

## Scope
Write: `docs/research/hockey-teardown/PLAY.md` and `media/play_*`, `engine/cores/rink/lab/**`, the `balance`
sub-command in `engine/tools/rink.sh` (lane K1 also edits that file: add your block at its end, touch nothing else),
`docs/shifts/2026-11-24-night/lanes/K4-reference/`. Raw match output stays under `.tl/` (delete it when the tables exist;
disk is 68 GB free). Round 1 = the tempo map and the ladder; round 2 = the ablation matrix; round 3 = the weak list and
the harness.

---

# Campaign rules (the hockey port; pasted into every lane brief, above the lane rules)

Read `docs/design/DIRECTIONS.md` first: the owner's words, what went wrong three times, the ten directions, the stair.

1. **Port, do not reinterpret.** thirdjam is the reference and we own its source. Every number and every rule you write
   cites its thirdjam file:line. You do not tune, simplify, "improve" or re-derive anything. Where our engine cannot carry
   a thing as thirdjam has it, the engine gains the missing piece (say which); the game is not bent. Every deviation from
   thirdjam, however small, goes in a `DEVIATIONS` list in your report with its reason.
2. **Sources.** thirdjam's final submitted source (HEAD 8dc713c6, the game the owner knows):
   `C:/Users/kazda/kiro/third-life/.claude/worktrees/n23-teardown/.tl/thirdjam` (read-only; `Game/Source` is "S" below).
   The older 15 Nov source tree that the runnable editor build was made from: `C:/t/t5` (read-only). The runnable build
   (UE 5.9 editor binaries + content, 4.5 GB): `C:/Users/kazda/kiro/third-life/.claude/worktrees/n23-teardown/.tl/tj-run/Game`
   (read-only: run it in place with `-Multiprocess` and your own `-abslog=` and output folders, or copy it into your
   tree's `.tl/` if you must change it). UE 5.9 is at `C:/Program Files/Epic Games/UE_5.9`. How earlier lanes ran it:
   `docs/research/hockey-teardown/TEARDOWN.md` section 1 and `BEHAVIOUR-HAND.md` "How it was measured".
3. **Look, every round.** Before each standup line, put your own rendered frames beside the reference's frames of the
   same moment (same camera, same scene), LOOK at them yourself (read the image files), and write what your eye rejects.
   A defect you can see is not landable. Film is not the judge of play (the owner: "the pictures will not uncover core
   problem which is the gameplay itself in speed and balancing of skill mechanisms"); it is the judge of defects.
4. **Play is judged by play.** Where your lane touches how the game answers a hand, the proof is the same scripted hand
   through the same inputs in both games, compared frame by frame, never a number chosen by you.
5. **The machine is shared and tight** (about 15 GB of RAM free, other sessions run Godot). One Unreal process at a time
   per lane, closed as soon as it has done its job; never kill a process you did not start; Godot `--headless` unless you
   need a picture. Raw captures stay under your tree's `.tl/` and are deleted when their sheets exist.
6. **Module homes** (Director's ruling for this campaign; contracts follow at landing): the game core lives in
   `engine/cores/rink/` (a new engine module: a core may use the kernel API, kits, rigs and style; packs reach it through
   one kernel entry); the skater figure lives in `engine/rigs/skater/` with its imported mesh and clips beside it; the
   new game's pack is `engine/packs/hokej/` (thin: a cartridge and glue). The old `engine/packs/hockey` is not touched.
   If `tl arch`, the lint or the asset rules reject these homes, change the rule tables under `devx/` or
   `engine/kernel/runner/lint.gd` minimally, and list every such edit in your report (the Director words the contracts).
7. **Rounds.** Work in rounds of 60-90 minutes. At the end of each: standup line, your frames looked at, a short
   `ROUND-<n>.md` in your lane folder (what stands, what your eye rejects, deviations, next). When a round is worth
   landing, write "landable round n" in STANDUP.md, stop editing, and return your report as your final message; the
   Director lands it on the campaign branch `hokej` and sends you on.

---

# Lane rules (pasted verbatim into every lane brief)

## Standups: you report, the Director reads
- Keep `docs/shifts/2026-11-24-night/lanes/K4-reference/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
