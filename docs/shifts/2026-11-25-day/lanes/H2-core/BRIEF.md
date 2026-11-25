# H2: the core and the base (editor hardening; unblocks Arsenal hockey)

Tree `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-hard-b` (branch d25-hard-b). Opus. Selftest block range
865-869. Read first:
- `engine/cores/rink/SNAPSHOT.md` and `CARTRIDGE.md`;
- the pickups ask in `docs/shifts/2026-11-24-night/lanes/E1-base/REPORT.md`;
- how the rink DLLs were built: `engine/cores/rink/native/` and lane K1's notes in
  `docs/shifts/2026-11-24-night/lanes/K1-core/`.

The rink binaries you need are already copied into your tree. Work in this order:

1. **Pickups (and effect events) in the core's snapshot**, so a game made in the editor shows them.
   - Add a "Pickups" list ([{Id, Kind, Pos}]) from the effect system, and append it to SNAPSHOT.md (an addition only).
   - Rebuild the DLLs, debug and release, for both cores; run room.sh before the build.
   - Parity: every existing hokej bot hash stays unchanged, and the core's trace tests behave as before.
   - Then the base draws pickups (`rink_toys.gd`), and `bot_toys` checks them.
   - The template and hokej's shared files stay byte-equal (selftest 851).
   - Take stills of pickups on the ice and look at them.
2. **A finished game can move to the newest base** (My games).
   - The Foreman re-copies the base under a promoted game, keeping its cartridge, rules, skin and match, and verifies it.
   - Create's My games offers this in one control.
   - Prove it on a copy of `C:/Users/kazda/kiro/third-life/.tl/proof-games/pond_v014`: its top view should lose the
     roof trusses.
3. **If time remains:** two drawing faults from last night's stills.
   - Corner bumpers drawn across the rounded boards (E5c and E5e stills).
   - A frame of #7 climbing over a net (E5e strip).
   - Find the cause (base drawing or core cage contact) with a two-way probe, and fix it if it is the base.

Acceptance:
- hokej bot hashes unchanged; list them.
- `k.sh selftest`, the selftest `rink.` and `hokej.` blocks, and your new block pass.
- foreman npm test: 0 fail.
- `tl check --tier fast` passes, and `tl check --only world` passes 9/9 (the engine changed).
- Stills looked at.
- Then "landable H2" (you may land item 1 alone first), stop editing, and report.

---

# Day rules (25 Nov 2026), above the lane rules

- **The machine is shared and has a ceiling: RAM 70 %, CPU 70 %.** Before every heavy step (starting or resuming a
  Foreman job, any Godot run, a C++ build, a lab check, npm test, a selftest block), run
  `bash C:/Users/kazda/kiro/third-life/docs/shifts/2026-11-25-day/tools/room.sh --wait`. If it gives up after 45 min,
  write that in STANDUP.md and do light work. Never kill a process you did not start.
- Absolute paths only; never `cd` in a backgrounded command. Run Foreman job commands detached, one per line, and read
  their logs; a script that starts real (paid) work gets one dry start checked within 5 minutes.
- After you write "landable", stop editing until the Director says it landed.
- Rounds of 60-90 minutes; a STANDUP line at least every 60 minutes; a lane silent for 60 minutes is asked, at 120 stopped.
- Owner's standing rules: behaviour is the core of game design (movement, contact, bots, the object's physics); the
  owner's hand and eye are the bar; never call a thing fixed before it was seen as a person meets it.

## For game lanes (G*): you are the person
- Use the editor exactly as a person does: Create's command order through `foreman` with the flags of
  `engine/ui/flags/real.json` (real adapter: Sonnet via claude-cli, paid), your own jobs root under your tree's
  `.tl/jobs/`. Answer every card as a person would (keep, drop, a short note; "It's fine, go on" only when a person
  would). Iterate with the change box in words, at least four rounds, aiming at the target images of your game in
  `docs/shifts/2026-11-24-night/concepts/<slug>_concept.jpg` and `<slug>_screenshot.jpg`.
- Never edit foreman/, engine/ or contracts/. When the editor blocks you, write it in STANDUP.md as
  `blocked-editor: <what a person met> | evidence: <job event / still>` and keep going on what you can.
- Judge by play and eye: film each version (follow camera and a wide view), LOOK at your stills beside the target and
  hokej (`dist/PLAY-LATEST.cmd`'s hokej), and say per version what a person would feel, in plain words. Behaviour
  first: does it move, hit, react and play like a game worth replaying?
- At each version also record: time, tokens, path (fast/full), what changed, measured figures where the editor gives
  them, and the gap to the target in three lines.
- Promote good versions and add the best to the menu as Create does (Add to menu); the Director copies them out.

---

# Lane rules (pasted verbatim into every lane brief)

## Standups: you report, the Director reads
- Keep `docs/shifts/2026-11-25-day/lanes/H2-core/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
