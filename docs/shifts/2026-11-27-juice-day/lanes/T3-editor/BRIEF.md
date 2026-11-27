# T3-editor: the last editor findings of the juice day (night of 27-28 Nov)

Tree `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-hard-a` (branch d27-tofu, fast-forwarded to main f6592f87:
lane T's rounds 1-5 and the Home session's M6; foreman built, class cache imported at 21:40). Model: Opus. Selftest block
range: 800-804. New foreman tests: `foreman/src/test/d27t3_*.test.ts`. Lane folder:
`C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-hard-a/docs/shifts/2026-11-27-juice-day/lanes/T3-editor/`.

You take over from lane T, which hung twice today in one long tool call (about 4 h and 2 h). **Never block a tool call on
a monitor, a tail -f or a long job.** Run jobs and suites detached (`... > log 2>&1 &`) and poll their logs with short
commands. Write a STANDUP line at least every 45 minutes.

Lane T2 (tree d25-court) works on items 23, 24, 26-28, 31, 32, 41 and 42 at the same time. Keep out of the files it is
editing (its STANDUP.md says which). `foreman/src/foreman.ts` is at its 2005-line limit and the test files at 600: put new
code and tests in new modules.

Read first: lane T's report `.../d25-hard-a/docs/shifts/2026-11-27-juice-day/lanes/T-editor/REPORT.md` (rounds 1-5) and
`contracts/JOB.md`, section "Added 2026-11-27 (juice day, lane T-editor)". Copy any job you use into your own `.tl/jobs/`.

## Your items
- **34.** A wasted round: "my own bot teammates should use the magnet too" also went to the bots package after core had
  already built it (J2b, `d25-biplane/.tl/jobs/robot-soccer-3-v-20261125-1`; about 0.6 M tokens, 6 min).
- **35.** Longer matches are judged unevenly: after two packages' rounds the frozen pack test got "not judged", after the
  end-screen package's round the same test was "failed", then passed on a longer rerun. One rule for every package.
- **37.** On a rink-core game the Planner sent cartridge rules to the script package (harbour) twice: the MEGA stats, and
  the bots' check rate "in scripts/main.gd" (J2b, `d25-biplane/.tl/jobs/three-against-three-hockey-20261125-1`). On a core,
  play rules go to the cartridge's owner first.
- **38.** A Foreman pre-check paused a job to ask "should the bots be weaker still?", which the person never asked (same
  job, event 1283). A question comes only from the person's words.
- **39.** The suggested-key list missed the key that worked (an effect with trigger `check_landed`), and the quick
  cartridge pass said "no key says it". keyfind should search effects and triggers too.
- **43.** A drawing-only change was told "balance moved by your change: matches now run longer" (N-newcomer, robots
  v0.1.12, event 1828, `d27-newc/.tl/jobs/robot-soccer-3-v-20261125-1`). The game plays the same hash.
- **44.** A builder narrowed the person's ask (a call pressed while knocked down is dropped), and it shows only as a
  deviation note, not as "part of your change was NOT made" (N-newcomer, shield v0.1.18, event 1513).
- **45.** Two packages own one text: harbour draws its own HOME lines over the skin's `about` list (N-newcomer, Arsenal
  v0.1.32, event 1496), so the skin's text is dead. One owner per text the person reads.
- **Write-ups only, no code:** 30 (`foreman revert <job> --to <version>`: design and test plan) and 36 (the kit check counts
  places, not meshes; whether a beam, a ring and a catapult become kit parts is the owner's call).

## Acceptance (per item)
- A unit test that fails before and passes after, on the evidence job's real event when there is one.
- For 37 and 38, one real paid job on a copy, as a person meets it.
- foreman `npm test` (main: 508 tests, 501 pass, 0 fail, 7 skipped); the fast tier; `create.` if engine/ui/create changed.
- "landable T3-editor <items>" in STANDUP.md and as your final message: a first batch by about 00:30, the rest by 03:30.

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

---

# Lane rules (pasted verbatim into every lane brief)

## Standups: you report, the Director reads
- Keep `docs/shifts/2026-11-27-juice-day/lanes/T3-editor/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
