# S35-packs, two spikes on the packs: clean the old bends (ask 3), and shield's bot_call (ask 5) (day of 27 Nov)

Tree `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane` (branch d27-sp-packs, from main 8be26d61). Model: Opus.
You play the PERSON on the editor path. Every arm is made through Create change sentences on job copies, never by editing
a pack by hand. If the editor cannot make an arm, say so, and only then build that arm by hand, as last night. Never edit
foreman/, engine/ or contracts/. Selftest block range: 816-817. Lane folder:
`C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane/docs/shifts/2026-11-27-juice-day/lanes/S35-packs/`.
Night docs: `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-main/docs/shifts/2026-11-27-night/lanes/`.

## Spike 3: the old bends (ask 3)
**The owner's question:** "Old bends: biplane's edited test pilot and karts' reversal rule are still in those packs. Clean
them with one change each, or leave them?"
- Read the night's `J11-biplane/PROOF-J11-biplane.md` and `J5-karts/PROOF-J5-karts.md`. They say what the old balance
  gate made the builders add:
  - biplane: an edited test pilot (`tests/support/pilot.gd`) and the bend before the graze rule came out;
  - karts: the reversal rule added with the aerial hits.
- **3A clean:** ONE Create change sentence per game that removes the bend, as a person would say it.
  - Note: the measure freeze (lane T, last night) stops builders editing the tofu bot and the pilot it loads.
  - Find out what the freeze does when a person asks to restore the pilot, and record it. That is itself an answer for
    the owner.
- **3B leave:** the current versions (biplane v0.1.4, karts v0.1.7) as they are.
- Measure both arms:
  - what changes in play: the bots' behaviour, the reversal's effect on aerial goals, and wins at a regular hand with
    `tl ladder` (quote the hand);
  - clips of the moment the bend shows;
  - the time and tokens of the clean change.
- Jobs:
  - `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane/.tl/jobs/biplane-duel-two-biplanes-20261125-1`, in your
    tree: copy it first and work on the copy;
  - a copy of `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-kart/.tl/jobs/bumper-kart-football-3-20261125-1`.

## Spike 5: shield wall's bot_call (ask 5)
**The owner's question:** "Shield wall bot_call: accept it as a behaviour change, or have bots hold their big moves while a
call charges?" Last night (J19), one pack test failed (`bot_call`): the captain is floored before his call fills.
- Read the night's `J19-shield/PROOF-J19-shield.md`. Find which version fails the test (v0.1.7 from the editor, the hand
  pack `C:/Users/kazda/kiro/third-life/.tl/proof-games/shield_charge_hand`, or both) and show it failing.
- **5A accept:** a Create change sentence saying that a charge or a slam can now break the call, and that the test should
  expect that (a person accepting a behaviour change). Record whether the Foreman lets a person change what a test means.
- **5B hold:** a Create change sentence: the bots hold their charge and slam while their own captain's call charges (the
  rivals may still try to break it).
- Measure both arms: calls that fill per match, charges and slams per minute, the `bot_call` test, and the feel (a clip
  each).
- Job: a copy of `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/.tl/jobs/shield-wall-3-v-20261125-1`
  (v0.1.7) per arm.

## Done when
SPIKE.md covers both spikes, each in the layout below, and every arm is playable (a pack path and a menu title). Time box:
about 7 hours; send what you have by 16:00.

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
- Keep `docs/shifts/2026-11-27-juice-day/lanes/S35-packs/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
