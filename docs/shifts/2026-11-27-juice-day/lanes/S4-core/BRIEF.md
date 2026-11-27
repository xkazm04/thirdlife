# S4-core, a spike: is a C++ lane worth it, so the rink core's bots use abilities? (day of 27 Nov)

Trees: arm A `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-arsenal` (branch d27-sp-core), arm B
`C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-sp-core-b` (branch d27-sp-core-b). Both from main 8be26d61.
Model: Opus. Selftest block range: 814-815. Lane folder (in the A tree):
`C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-arsenal/docs/shifts/2026-11-27-juice-day/lanes/S4-core/`.

**The owner's question (ask 4):** "Rink core: bots that use abilities, and a dive block. Is it worth a C++ lane?"
Last night (J1) the Arsenal meteor slapshot worked for the hand, but "the rink core gives no ability to bots
(CARTRIDGE.md:475) and has no dive verb", so bots used it 0 times a minute. Read:
- `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-main/docs/shifts/2026-11-27-night/lanes/J1-arsenal/PROOF-J1-arsenal.md`
  and `REPORT.md`;
- `engine/cores/rink/CARTRIDGE.md`, `engine/cores/rink/native/PATCHES.md` and `engine/cores/rink/native/patches-thirdlife/`.

## The arms
- **A, C++:** a native core patch (in `engine/cores/rink/native/`, the patches-thirdlife way). The core's bots use the
  cartridge's abilities, deciding when from their own reads (a shooting lane, a crowd, a carrier), and a dive verb lets a
  bot throw itself to block a shot. Cartridge keys say how often and how well, so Create can write them.
  - In the first hour, check that the native build works on this machine (scons, the compiler, how `bin/` is built and
    loaded).
  - If it cannot build, say so at once in STANDUP.md and in a message. A then becomes a design with an estimate, and B
    gets the rest of the time.
- **B, no C++:** the pack drives the bots' ability use from GDScript, with what the core already exposes (the inputs it
  accepts for a bot skater, the events it reports), plus the best dive the pack can fake (a reaction the core allows).
  Say what B cannot do.

## The test (same for both arms)
- The Arsenal meteor: the hand pack `C:/Users/kazda/kiro/third-life/.tl/proof-games/arsenal_meteor_hand`, and Create's
  v0.1.23 (a copy of `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-arsenal/.tl/jobs/three-against-three-hockey-20261125-1`).
- Measures:
  - bot meteors per minute, by team;
  - bot dive blocks per minute, and how many meteors they stop;
  - the hand's wins at a regular and a sharp hand against each arm (`tl ladder`; quote the hand);
  - determinism: the same hash twice, and the core's own hash;
  - frame cost (p50 and p99);
  - the core lab's balance check;
  - the hockey house pack held: its hashes and tests unchanged unless the arm turns the feature on.
- Generality: can a Create sentence turn it on for another cartridge ability? Try one real change on a copy, either arm.
- Cost: build time, lines changed, and how a future core update would carry the arm.
- Each arm must be playable by the owner. For A, export an exe from the A tree if the main exe cannot load its core.

## Done when
SPIKE.md has both arms, clips of bots using the meteor and diving, and "arm-ready S4-core A/B" was sent. Time box: about
9 hours; send what you have by 19:00.

---

# Day rules (27-28 Nov 2026), above the lane rules

- **The owner's words (27 Nov ~08:00, away 24 h):** "keep the effort from last night, for decision questions try to create
  spikes and evaluate both, I will get into this tomorrow and evaluate together".
- **Last night's words, still the standard:** "give each game a unique juice ... demonstrate juicy/crazy ability to express
  we can compose any ide there".
- **Read first:**
  - the plan: `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-main/docs/shifts/2026-11-27-juice-day/PLAN.md`;
  - last night's verdict: `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-main/docs/shifts/2026-11-27-night/VERDICT.md`;
  - "What juice means" in `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-main/docs/shifts/2026-11-27-night/PLAN.md`
    (anticipation, exaggeration, impact, the game answering it; behaviour first);
  - the night lane docs your brief names (`docs/shifts/2026-11-27-night/lanes/<lane>/PROOF-*.md`, `REPORT.md`): they hold
    each job's commands and what the editor did.
- **The machine:** RAM at most 80 %, no CPU cap, disk floor 12 GB. Before every heavy step (a Foreman job start or change,
  any Godot run, a C++ build, a lab check, npm test, a selftest block) run
  `bash C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-main/docs/shifts/2026-11-27-night/tools/room.sh --wait`.
  Never kill a process you did not start.
- **Another session runs all day** (the Home sandbox, its own lanes). Never touch its files: `engine/kernel/world/**`,
  `engine/style/**`, `engine/kits/**`, `engine/boot/**`, `foreman/prompts/world_edit*`, `foreman/src/world_edit*`,
  `contracts/**`, `docs/research/sandbox/**`, `docs/shifts/2026-11-27-day/**`.
- **Paths:** absolute paths only; never `cd` in a backgrounded command. Run Foreman job commands detached, one per line,
  and read their logs. A script that starts real (paid) work gets one dry start, checked within 5 minutes.
- **Jobs:** never run a change on another lane's job folder. Copy the job you need into your own tree's `.tl/jobs/`
  (a plain recursive copy; last night's lane T proved changes on copies) and say which version you copied.
- **Rounds:** 45-90 minutes. A STANDUP line at least every 60 minutes. A lane silent for 60 minutes is asked; at 120 it is
  stopped.
- **Landable:** after you write "landable", stop editing until the Director says it landed. When you need the Director
  (a branch commit, a fast-forward, a ruling, a menu row), end your turn with the ask in your final message.
- **The bar is a person's hand and eye:** what the player sees or feels is shown in a window clip (mp4, 30 s or less) and
  JPG stills you LOOKED at, with plain words on how it feels. Headless numbers support it, they do not replace it. Film
  as the night lanes did (window captures through the exe's `TL_EXE_*` variables or the engine tools, ffmpeg to mp4,
  the repo's window lock).
- **Menu:** give the Director a pack path and the menu title you want for each version the owner should play.

## Spike rules (every S lane)
- **The owner decides.** Your job is to build BOTH arms well enough that the owner can feel the difference, and to measure
  them the same way. An arm built half-heartedly is a failed spike: give each arm a fair best effort.
- Same base (main 8be26d61), same job copies (copy once, then copy that copy per arm), same sentences word for word, same
  seeds, same measures, for both arms.
- Each arm ends with:
  - something the owner can play: a pack path and a menu title (or, for a code arm whose packs the main exe cannot run, a
    way to play it: an exe exported from the arm's tree, or a `tl play` command);
  - a window clip of 30 s or less and 2-3 stills you looked at;
  - headless: 3600 frames, 0 script errors, the same hash twice, and the arm's own measures;
  - its cost: wall time, tokens, lines changed, and what it risks for other games.
- Write `SPIKE.md` in your lane folder:
  1. the question, in the owner's words (from last night's verdict);
  2. the two arms, one paragraph each;
  3. the test (jobs, versions, sentences, seeds, measures);
  4. a results table, A against B;
  5. what each arm broke, or risks;
  6. how to play each arm (menu titles, keys);
  7. at the end, under "Lane's recommendation", your pick and why. Keep it separate from the evidence.
- **Code arms:** arm A's code lives in the A tree, arm B's in the B tree. Never mix them. When an arm's code is ready, send
  the Director "arm-ready <lane> <A|B>"; the Director commits it on that tree's branch. Nothing merges to main.

---

# Lane rules (pasted verbatim into every lane brief)

## Standups: you report, the Director reads
- Keep `docs/shifts/2026-11-27-juice-day/lanes/S4-core/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
