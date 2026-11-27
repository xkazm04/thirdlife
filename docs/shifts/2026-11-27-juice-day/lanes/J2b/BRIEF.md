# J2b: a second crazy ability for robot soccer and shield wall, through the fixed editor (evening of 27 Nov)

Tree `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane` (branch d27-second-b, from main f2d72951, which has
lane T's items 1-22; foreman built, class cache imported at 16:25). Model: Opus. You play the PERSON on the editor path.
Never edit foreman/, engine/ or contracts/. Add no selftests. Lane folder:
`C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane/docs/shifts/2026-11-27-juice-day/lanes/J2b/`.

## Why
The owner's bar: "demonstrate juicy/crazy ability to express we can compose any ide there". Lane J2nd gave karts,
biplane and half-court a second crazy ability today, all made by the editor (`d25-main/docs/shifts/2026-11-27-juice-day/
lanes/J2nd/PROOF-J2nd.md`: read it first, including its editor findings). Do the same for the two games whose first
ability came closest to the hand version today (lane JB-back, `.../lanes/JB-back/PROOF-JB-back.md`).

## The games (copy each job into your tree's `.tl/jobs/` first; never change the originals)
| Game | Start from (job) | Its first ability |
|---|---|---|
| Robot soccer | v0.1.9, `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/.tl/jobs/robot-soccer-3-v-20261125-1` | the sledgehammer |
| Shield wall | v0.1.13, `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/.tl/jobs/shield-wall-3-v-20261125-1-jb` | charge, brace, slam, shield throw |

## Steps per game
1. **Design (20 min at most).** A second crazy ability unlike the first, from a proven game. For example, robots: a
   rocket-jump stomp, a magnet that yanks the ball, or a Rocket League demolition boost. Shield wall: a Viking war horn
   that freezes rivals for a beat, a shield-surf down a slope, or a catapult volley. Write the juice sheet in
   `PROOF-J2b.md`: the key, the wind-up, exaggeration in numbers, impact, what the bots do with it and against it, the
   counterplay, and the reference game.
2. **One sentence** of up to 800 characters, naming the ability AND its juice AND what the rivals do with it. Save it in
   `SENTENCES.md`. Send it as a Create change on your copy, the way Create does it (real adapter, paid).
3. **Judge it as a person:**
   - a window clip of 30 s or less (at most 800 px wide, crf about 32);
   - 2-3 stills you looked at;
   - 3600 headless frames with 0 script errors;
   - the same hash twice;
   - the bots' uses per minute.
4. **One or two follow-up sentences** if parts are missing, as a person would. A `blocked-editor` line with evidence goes
   to the Director at the end of your turn.
5. **Disk is tight** (about 20 GB free; another project is filling it). Keep raw film under `.tl/` small and delete it
   once your clips are cut.

## Done when
PROOF-J2b.md covers both games, with their sentences, clips, measures and cost, plus a pack path and menu title for
each ("... (made in Create, juice day)"). Time box: about 4 hours; send what you have by 21:00.

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
- Keep `docs/shifts/2026-11-27-juice-day/lanes/J2b/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
