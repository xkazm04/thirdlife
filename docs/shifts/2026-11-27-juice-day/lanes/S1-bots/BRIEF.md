# S1-bots, a spike: should a new move tell the bots to use it and answer it by default? (day of 27 Nov)

Trees: arm A `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-court` (branch d27-sp-bots), arm B
`C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-sp-bots-b` (branch d27-sp-bots-b). Both from main 8be26d61, foreman
built, class cache imported. Model: Opus. Selftest block range: 810-811. Lane folder (in the A tree):
`C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-court/docs/shifts/2026-11-27-juice-day/lanes/S1-bots/`.

**The owner's question (last night's verdict, ask 1):** "Bots and new moves: should the Planner tell the bots to use, and
react to, every new move by default? Karts, basketball and shield wall needed a second sentence."

## The arms
- **A, on by default:** when a person's change adds a move (an ability, an attack, a jump, a trick) and the sentence says
  nothing about the bots, the Planner adds to the plan: the bots use it at sensible moments, and they answer it (dodge,
  block, brace, punish). It reaches every package that drives a bot (in 3 v 3 games the crew package's mind, not only
  core). The person can turn it off in words ("only I can do it"). The what-changed card says it did this. Build it in
  foreman (the Planner prompt and code), as a person's change would meet it.
- **B, as now:** main's editor unchanged. The person types the move; when the bots do not use it, the person types the
  second sentence a person would ("the rivals use the X too, and dodge it when they see it coming"). Measure B after the
  first sentence AND after the second.
- Lane T fixes routing today (a sentence that names the rivals reaches every bot package) on main. Arm A may need its own
  minimal routing to work; keep it inside the A tree and say where it overlaps T.

## The test (same for both arms)
- Copies of three jobs, one copy per arm:
  - karts `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-kart/.tl/jobs/bumper-kart-football-3-20261125-1` (v0.1.7);
  - half-court `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-court/.tl/jobs/half-court-3-v-20261125-1` (v0.1.6);
  - shield wall `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/.tl/jobs/shield-wall-3-v-20261125-1` (v0.1.7).
- One NEW crazy move per game, written down before you start, the sentence word for word the same on both arms, with no
  word about bots or rivals (for example a rocket boost dash for karts, an alley-oop off the backboard for half-court, a
  thrown shield that comes back for shield wall; you choose, and it must be juicy).
- Measures per arm and game:
  - the bots' uses per live minute of the new move, and whether they spam it;
  - the bots' answers to it (dodges, blocks) per minute;
  - the person's feel, in a clip;
  - wall time, tokens and the number of sentences the person typed to reach "bots use it";
  - what else moved (balance notes, tests).
- Try A's off switch once ("only I can do it") and show the bots then do not use it.

## Done when
SPIKE.md has both arms on all three games with clips, and "arm-ready S1-bots A" was sent for the code. Time box: about
8 hours of work; send what you have by 18:00, and continue only if the Director says so.

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
- Keep `docs/shifts/2026-11-27-juice-day/lanes/S1-bots/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
