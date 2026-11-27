# T2-editor: a second editor lane for the rest of today's findings (evening of 27 Nov)

Tree `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-court` (branch d27-tofu2, from main 48a7e24b; this includes lane
T's items 1-22 and the Home session's M6; foreman built, class cache imported at 19:45). Model: Opus. Selftest block range:
805-809. New foreman tests: `foreman/src/test/d27b_*.test.ts`. Lane folder:
`C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-court/docs/shifts/2026-11-27-juice-day/lanes/T2-editor/`.

Lane T (tree d25-hard-a) works on items 25, 29, 33+40, 34, 35 and 37-39 at the same time. You take the others. Keep out
of the files lane T is editing now (`foreman/src/verifier.ts`, `handcheck.ts`, `boundlift.ts`) unless an item needs them;
if one does, say so in STANDUP.md. `foreman/src/foreman.ts` is at its 2005-line size limit: put new code in new modules.

Read first: lane T's report `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-hard-a/docs/shifts/2026-11-27-juice-day/lanes/T-editor/REPORT.txt`
(rounds 1-4: how the fixes are built and tested), and `contracts/JOB.md`'s section "Added 2026-11-27 (juice day, lane
T-editor)". Then the evidence named for each item below. Copy any job you use into your tree's `.tl/jobs/`; never change
another lane's job in place.

## Your items
- **23.** Biplane: the land check wants a new move counted in a bot test the package's own checks run, but core's only
  such test is the frozen tofu bot, so every edit was undone, and the done screen said the harpoon was "NOT made" while it
  does hook her. A package with no unfrozen bot test of its own needs a way to count a new move: a new test file of its
  own is allowed. Evidence: J2nd, `d25-main/docs/shifts/2026-11-27-juice-day/lanes/J2nd/PROOF-J2nd.md`, finding 1; job
  `d25-kart/.tl/jobs/j2nd/biplane-duel-two-biplanes-20261125-1`.
- **24.** Karts: core named a one-line fix in items.gd three times as NOT DONE, it never reached items, and v0.1.8
  promoted with the shells never switched on (same hash as v0.1.7). Check that lane T's items 17/18 (on main) cover it,
  and add the case as a test. Evidence: J2nd finding 2; job `d25-kart/.tl/jobs/j2nd/bumper-kart-football-3-20261125-1`.
- **26.** Karts: core asked the person "wider goals or a shorter match so the test fits?". A longer match gets more frames
  (lane T's (b)); never ask the person a question about the Foreman's own test.
- **27.** Court: a builder's process remark was shown on the card as "part of your change was NOT made".
- **28.** Court: "unasked rule: none added" is listed as an unasked rule.
- **31.** A biplane change with two play-changing RULE: lines was judged "view or screen only" (events 994, 1000), so a
  tofu figure (skill_spread 0.04) went unjudged and was never mentioned. A RULE: line makes the change a play change.
- **32.** "Make it fairer" is tuned blind. Neither package may run the newcomer hand check over 20 seeds (J2nd events 1673,
  1786), and each guess costs about 35 min of final checks. Give the package that tunes a fairness ask the per-seed
  results, or a way to run the check itself.

## Acceptance (per item)
- A unit test that fails before and passes after, on a real event from the evidence job when there is one.
- For 31 and 32, one real paid job on a copy, showing the change as a person meets it.
- foreman `npm test` with counts against main; the fast tier; `create.` when engine/ui/create changed.
- "landable T2-editor <items>" in STANDUP.md and as your final message, by about 01:00. The Director lands it on main
  and merges it with lane T's work.

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
- Keep `docs/shifts/2026-11-27-juice-day/lanes/T2-editor/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
