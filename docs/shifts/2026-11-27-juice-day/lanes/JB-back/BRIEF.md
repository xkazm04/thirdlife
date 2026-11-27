# JB-back: send the hand juice back to Create as one sentence each (day of 27 Nov)

Tree `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield` (branch d27-back, from main 8be26d61; foreman built,
class cache imported). Model: Opus. You play the PERSON on the editor path. Never edit foreman/, engine/ or contracts/.
Selftest block range: 818-819. Lane folder: `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/docs/shifts/2026-11-27-juice-day/lanes/JB-back/`.
Night docs: `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-main/docs/shifts/2026-11-27-night/lanes/`.

## Why
Last night's clearest proof (J4b): basketball's hand-built juice, sent back to Create as ONE sentence of 656 characters,
came out about as juicy as the hand version (Create v0.1.6). Today: do the same for the three other games whose hand
layer beat the editor. The question is whether the editor reaches hand quality when a person names the juice.

## The three games
| Game | Newest editor version (job) | Hand version |
|---|---|---|
| Robot soccer (sledgehammer) | v0.1.6, `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-robot/.tl/jobs/robot-soccer-3-v-20261125-1` | `C:/Users/kazda/kiro/third-life/.tl/proof-games/robot_hammer_hand` |
| Shield wall (charge, brace, slam) | v0.1.7, `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-shield/.tl/jobs/shield-wall-3-v-20261125-1` (in your tree) | `.../proof-games/shield_charge_hand` |
| Arsenal hockey (meteor slapshot) | v0.1.23, `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-arsenal/.tl/jobs/three-against-three-hockey-20261125-1` | `.../proof-games/arsenal_meteor_hand` |

Copy each job into your tree's `.tl/jobs/` before the first change (other lanes copied them too; never change the
originals). Read J4b's sentence and how it was written (`J4-court/PROOF-J4-court.md`, the J4b section), and each game's
night PROOF doc, which lists what the hand layer added.

## Steps per game
1. Play the hand version and the editor version yourself (window clips) and write down every juice part the hand version
   has that the editor version lacks, in a person's words.
2. Write ONE sentence (up to 800 characters; Create takes 800 now) that names them, as J4b did. Save it in `SENTENCES.md`.
3. Send it as a Create change on your copy, the way Create does it (real adapter, paid). Record time, tokens, notes.
4. Judge the result against the hand version by eye: side-by-side clips, a checklist of the juice parts present, the
   bots' uses per minute, 3600 headless frames with 0 script errors, and the same hash twice.
5. If one part is missing, you may send ONE follow-up sentence, as a person would. Record both.

## Order and the editor fixes
Start with **robots**, which needs no editor fix. Lane T is landing two fixes on main today that shield wall and Arsenal
need: a sentence about the rivals reaches every bot package, and a play request handed off by a drawing package reaches
the cartridge. Write the shield and Arsenal sentences now. Before you SEND them, end a turn with "ff JB-back?", and the
Director fast-forwards your tree to main once T has landed. If T has not landed by 14:00, send them anyway and say so.

## Done when
PROOF-JB-back.md has all three games with sentences, clips, the checklists against the hand versions, and pack paths plus
menu titles ("... (made in Create from one juice sentence)"). Time box: about 7 hours; send what you have by 17:00.

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
- Keep `docs/shifts/2026-11-27-juice-day/lanes/JB-back/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
