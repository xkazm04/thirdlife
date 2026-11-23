# K8 balance: from thirdjam's play to a game where every skill matters

Campaign night of 23-24 Nov 2026. Worktree `C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-balance` (branch
`hk-balance`, cut from the campaign branch `hokej`). Route: Fable solo (this is game design). Rounds of 90 minutes.

## The owner's words
On thirdjam: "a mediocre hockey game we delivered but at least it has set basic gameplay mechanics, AI, bugless graphics
and balanced speed". On what matters: "the core of gameplay design is in behavior"; "the pictures will not uncover core
problem which is the gameplay itself in speed and balancing of skill mechanisms to play the game". On the goal: "think
about 10 directions how to philosophically approach AAA game design ... and start executing all directions done and you
think the game is perfect."

## Where we are
The new game runs thirdjam's own simulation and bots unchanged (`engine/cores/rink/native/thirdjam`, trace-identical to
the Unreal build). Lane K4 then measured thirdjam's play on that core over about 37,000 matches:
`docs/research/hockey-teardown/PLAY.md` (read all of it; it is your starting point). In short: you can score without
shooting (walk the puck over the line); passing gives the puck away (38 % complete at pro; removing the pass wins 9 more
points); the puck never settles (a carry lasts 0.8 s, the puck changes teams every 2.2 s); skill stops showing above the
regular hand at pro; rookie is won standing still 60 % of the time; half the keys do nothing measurable (brake, ability,
one-timer, tap shot, saucer, deke, spin, brace, poke); skating into a carrier takes his puck with no key; the human lies
on the ice 8-14 s a match; levels are harder by faster legs, not better play. That is the measured meaning of "mediocre".
Parity with thirdjam is the floor (stair steps 1-6 of `docs/design/DIRECTIONS.md`); this lane is step 7, **surpass**,
done the way the directions demand: from parity, one change at a time, each shown against parity.

## Goal
A second cartridge, `hockey.thirdlife`, beside the untouched `hockey.regular`: the same game made **worth mastering**.
Not a new game and not new toys: the same verbs, rink, camera and bots' brain, re-balanced (and where a rule is broken,
re-ruled) until the mechanic matrix says every kept skill matters, has an answer, and shows. Both cartridges stay
playable so the owner can feel the difference.

## Method (directions 1-5, applied to design)
1. **Design before numbers.** `docs/design/HOCKEY-BALANCE.md`: the fantasy in one sentence; 4-6 pillars (what the play
   must feel like, each tied to the owner's rulings in `docs/research/hockey-teardown/RULINGS.md`, to proven arcade
   hockey (`docs/design/CASES.md`: NHL '94, NHL Hitz, Blades of Steel; add sources where you need a number) and to
   PLAY.md's findings); then the **target matrix**: for every verb its intended cost, reward, window and answer, and the
   measurable targets (e.g. passes completed by the regular hand at pro; seconds a skilled carry survives pressure and
   an unskilled one; share of goals from shots; win spread idle / novice / regular / good at each level; seconds on the
   ice down; the cost in wins of removing each kept verb). A verb you cannot make matter is **cut** (direction 9:
   subtract), and the cut is a decision you write down. The Director's starting pillars, to challenge and sharpen:
   possession is earned and can be kept by skill; the pass is the fastest way up the ice and pays; goals come from
   shots and shots from space; contact is a choice with a cost on both sides; every key has its moment; skill shows at
   every level and a level is harder by better play, never by faster legs or by absence (the owner's standing ruling).
2. **Hands that are worth believing.** thirdjam's playtester hands were written for thirdjam's rules and do not re-plan:
   a dead key may be the hand's fault. Add a **planning hand** to the lab: a human-limited optimiser (reaction delay,
   aim error, presses a second, a short look-ahead by rolling the simulation forward from the current state over a
   small menu of intents, re-decided every few frames) at two or three skill settings. A verb's value is what a
   rational, human-limited hand does with it. Validate the planning hand against thirdjam's own hands on `hockey.regular`
   first (does it find the walk-in goal? does it stop passing?): if it rediscovers PLAY.md's findings by itself, it is
   worth believing. Keep thirdjam's hands as a second opinion in every table.
3. **One change at a time.** An experiment ledger (`engine/cores/rink/lab/experiments/LEDGER.md` + one JSON per
   experiment): the hypothesis (which target it moves and why), the change (prefer a cartridge or difficulty-profile
   number; then a rule in a patch), the full harness before and after (ladder, ablation of the verbs it touches, the
   planning hand), kept or rejected with the figures. No change is kept on a hunch, and none is kept that breaks a
   target it did not aim at. Interactions are re-measured: after every three kept changes the whole matrix runs again.
4. **Rules that must change are patches, never edits.** thirdjam's files under `native/thirdjam` stay byte for byte.
   A rule change lives as a marked patch in `engine/cores/rink/native/patches-thirdlife/` applied to a copy at build
   (a `thirdlife` sim variant the lab builds and runs; propose in your report how the shipped core selects the variant
   by cartridge: lane K1 owns `native/` and the build, do not restructure them).
5. **Speed stays thirdjam's** unless a pillar needs otherwise: the owner called its speed balanced. The tempo map's
   ratios are the frame every change is read in; say for each change which ratio it moves.
6. **What no instrument here can do:** tell whether it is fun. Every kept change gets one line for the owner: what he
   will feel differently in the first minute. His hand decides in the end; your job is that what he gets is coherent,
   deliberate and measured, and that the reasons are written.

## Rounds
1. The design document with the target matrix; the planning hand built and validated on `hockey.regular`; the ledger and
   harness set up; the first experiments on the two worst findings (the walk-in goal; the pass that loses the puck).
2. Possession and contact (a carry that skill can keep; pokes, checks and knockdowns with cost and answer; the
   no-key steal), then the dead verbs (make each matter or cut it).
3. The skill ladder and the levels (harder by play), the whole matrix re-run, the cartridge `hockey.thirdlife`, a page
   for the owner: what changed, why, what he will feel, what was cut, what is still weak.

## Acceptance (per round: say what is met)
- `HOCKEY-BALANCE.md` exists and every later change cites the target it serves; rulings it leans on or questions are quoted.
- The planning hand rediscovers at least three of PLAY.md's findings on `hockey.regular` unprompted, or the report says
  why it cannot be believed.
- Every kept change has its ledger entry with before / after tables by both kinds of hand; rejected ones too.
- The final matrix on `hockey.thirdlife`: no kept verb is dead by the planning hand; no verb wins alone; passes pay;
  walk-in goals are gone or deliberate; the hands spread at every level; each figure beside `hockey.regular`'s.
- `rink.sh balance` still reproduces the `hockey.regular` baseline exactly (parity untouched).
- `node devx/bin/tl.mjs check --tier fast` passes. No full tier (the Director runs it).

## Scope
Write: `docs/design/HOCKEY-BALANCE.md`, `engine/cores/rink/lab/**` (the planning hand, experiments, the thirdlife
variant's lab build), `engine/cores/rink/native/patches-thirdlife/**` (patch files only), the new cartridge file beside
the regular one, a `balance-thirdlife` block at the end of `engine/tools/rink.sh`,
`docs/shifts/2026-11-24-night/lanes/K8-balance/`. Not yours: `native/thirdjam*`, the shim, the glue, the pack, anything
drawn. Machine: the lab runs matches natively (about 2 s each); use at most 8 processes at once, keep raw output under
`.tl/` and delete it when its tables exist.

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
- Keep `docs/shifts/2026-11-24-night/lanes/K8-balance/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
