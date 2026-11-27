# T-editor: the editor's queue from the juice night (day of 27 Nov)

Tree `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-hard-a` (branch d27-tofu, from main 8be26d61; foreman built,
class cache imported at 07:57). Model: Opus. You are lane T again: last night you fixed the tofu gate (T1-T3, landed).
Today you fix what the juice lanes met. Selftest block range: 800-809. New foreman tests: `foreman/src/test/d27_*.test.ts`.
Lane folder (in your tree): `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-hard-a/docs/shifts/2026-11-27-juice-day/lanes/T-editor/`.

Read first: your own night report `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-main/docs/shifts/2026-11-27-night/lanes/T-tofu/REPORT.md`,
and the `blocked-editor` lines and evidence in the night lane folders `J19-shield/`, `J1-arsenal/`, `J4-court/` (PROOF
and STANDUP) under `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-main/docs/shifts/2026-11-27-night/lanes/`. The
jobs with that evidence are in `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/.tl/jobs/`,
`.../d25-arsenal/.tl/jobs/` and `.../d25-court/.tl/jobs/` (copy them, never change them in place).

## The queue, in this order (one landable round each, or two small ones together)
1. **A sentence about the rivals reaches every package that drives a bot.** J19: "the rivals charge and slam" went to core
   only, and in the 3 v 3 game 4 of 5 bots think in the crew package's `scripts/crew/mind.gd`, so they never charged
   (job events 596, 619).
2. **A play request that a drawing package hands off is carried to the cartridge's owner and made.** J1: the meteor change
   went to the drawing package; its builder wrote the exact cartridge edit and said it was outside its scope, and the job
   promoted v0.1.22 without it (events 1008, 1012, 1039-1042).
3. **The builder reads the cartridge's keys before saying "the cartridge has no key".** J1 event 1012: it said so for a
   wind-up and for being easier to knock over while winding up, though CARTRIDGE.md:109-110 and :394 have both.
4. **A new attack the person asked for lands at least once in the Foreman's bot run, or the change is not done.** J19:
   the charge's reach (1.15 m) was shorter than the gap between bodies (1.4 m), so it never landed (0 of 15), and the
   change still promoted. The Foreman should see that, say so, and send it back to the builder.
5. **Banners and impact words go mid-screen, not into the score line** (J4: the ON FIRE tag overlapped the clock; the
   v0.1.6 banner sat on a tall black slab). Fix it where builders get it (the template, the skin text, the prompt), not in
   one pack.
6. **Create shows every "balance moved" note of a change, not only the newest.**

## Do NOT decide the owner's open questions
Today's spikes test them, so leave them as they are on main:
- whether the Planner tells the bots about every new move by default (S1);
- whether a juice pass runs on new abilities (S2);
- the rink core's bots (S4).
Item 1 is about routing a sentence that DOES name the rivals; it must not add bot lines nobody asked for.

## Acceptance (per item)
- A unit test that fails before and passes after (`foreman/src/test/d27_*.test.ts`, or Create's own test dir).
- One real paid job on a COPY of the job that showed it, with the night's sentence: the event lines before and after,
  and the result as a person sees it played (a still or clip).
- foreman `npm test` with counts against main (main: 460 tests, 453 pass, 0 fail, 7 skipped); the fast tier; `create.`
  selftests when engine/ui/create changed.
- "landable T-editor <items>" in STANDUP.md and as your final message. The Director lands it on main, then you go on
  (SendMessage continues you).

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
- Keep `docs/shifts/2026-11-27-juice-day/lanes/T-editor/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
