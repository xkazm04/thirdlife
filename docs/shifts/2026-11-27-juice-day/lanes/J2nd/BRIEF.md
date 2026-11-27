# J2nd: a second crazy ability for karts, biplane and half-court, through the fixed editor (day of 27 Nov)

Tree `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-kart` (branch d27-second, from main ccf24701, which has lane T's
items 1-6; foreman built, class cache imported at 12:15). Model: Opus. You play the PERSON on the editor path. Never edit
foreman/, engine/ or contracts/. Selftest block range: none (add no selftests). Lane folder:
`C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-kart/docs/shifts/2026-11-27-juice-day/lanes/J2nd/`.

## Why
The owner's bar from last night: "demonstrate juicy/crazy ability to express we can compose any ide there". Last night
each game got its first crazy ability. Lane T has since fixed what the night's lanes met: the rivals' words reach every bot
package, a drawing package's hand-off reaches the cartridge, a new attack must land, impact words go mid-screen, and every
balance note is shown. Today shows the fixed editor composing a SECOND, different crazy idea per game, each in one
sentence when possible, and how close it gets to hand quality when the sentence names the juice (J4b's lesson).

## The three games (copy each job into your tree's `.tl/jobs/` first; never change the originals)
| Game | Newest version (job) | Its first ability (night) |
|---|---|---|
| Bumper-kart football | v0.1.7, `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-kart/.tl/jobs/bumper-kart-football-3-20261125-1` (in your tree: copy it) | jump, flip double jump, aerials, air bump |
| Biplane duel | v0.1.4, `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-biplane/.tl/jobs/biplane-duel-two-biplanes-20261125-1` | loop, barrel roll, smoke and shoot-downs |
| Half-court 3 v 3 | v0.1.6, `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-court/.tl/jobs/half-court-3-v-20261125-1` | sky jump, dunk, block, on fire |

Other lanes run spikes on copies of these same jobs today. That is fine: yours are your own copies.

## Steps per game
1. **Design (20 min at most).** Pick a second crazy ability unlike the first, from a proven game: for example a
   Mario-Kart-style item you pick up (a shell, a banana, a boost), a mid-air tag team swap, a biplane's tow cable or a
   wing-walker, half-court's alley-oop off the backboard, or a full-court "half-court heave" with a slow-motion arc.
   Write the juice sheet in `PROOF-J2nd.md` (the key, the wind-up, exaggeration in numbers, impact, what the bots do with
   it and against it, the counterplay, the reference game).
2. **One sentence,** up to 800 characters, naming the ability AND its juice AND what the rivals do with it (J4b's lesson:
   the editor builds exactly what the words say). Save it in `SENTENCES.md`. Send it as a Create change on your copy,
   the way Create does it (real adapter, paid).
3. **Judge it as a person:** a window clip of 30 s or less (at most 960 px wide, crf about 30), 2-3 stills you looked at,
   3600 headless frames with 0 script errors, the same hash twice, and the bots' uses per minute.
4. **One follow-up sentence** if a part is missing, as a person would. If the editor refuses, bends or fails, write a
   `blocked-editor` line with evidence and send it to the Director at the end of your turn. Build by hand only if the
   editor clearly cannot (in `.tl/juice/<slug>_hand/`).

## Done when
PROOF-J2nd.md has the three games with their sentences, clips, measures and cost, plus a pack path and menu title for
each ("... (made in Create, juice day)"). Time box: about 6 hours; send what you have by 18:30.

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
- Keep `docs/shifts/2026-11-27-juice-day/lanes/J2nd/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
