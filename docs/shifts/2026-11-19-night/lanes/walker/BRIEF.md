# Lane walker: walker and terrain residue (night of 19 Nov)

Shift `2026-11-19-night`, lane `walker`. Worktree `.claude/worktrees/n19-walker` (branch `n19-walker`). Time box 00:00-06:30.
Route: **Opus directing Astra**. You are the Opus director: you read, decide and write the round briefs; GPT 6.2 Astra
builds through `codex exec` (the command is in `.claude/skills/shift/SKILL.md` § 3: always `< /dev/null`, resume by the
session id, never `--last`, tell it "read-only git is fine; do not commit"). You verify every claim yourself, re-run the
gates and re-grade. You may make small surgical fixes yourself.

## The owner's words (18 Nov)
"Character look, movement (jumps, slides, smoothness of texture and run)" and "Texture bugs: sliding down the hill, walking
towards the hill do struggle with camera look through the texture and blinking of dead space, breaking the immersion".

## Goal, in this order
1. What the bug fixer deferred: the rows of `docs/reports/bugfix-37/REPORT.md` marked `deferred` that touch the walker,
   camera or terrain. Fix the safe ones; give a reason for the rest.
2. L2: the camera near tree canopies. The chase camera never sits inside a crown or just under one (the hunt's D5 family).
3. L1: ink outline coverage: where the toon outline is missing or crawls, on the walker and on the terrain.
4. If time remains: the A/D sidestep-or-turn question belongs to the OWNER. Prepare both behind a flag with a clip each;
   change no default.

## Acceptance
- For each item: a repro, or a before/after measurement (`engine/tools/look.sh boil` for crawl; frames inside a crown
  counted for the camera); a permanent check in your own `engine/tools/selftest.d/NNN-*.sh`; stills in `lanes/walker/stills/`.
- A clip of at most 20 s in a window: walking toward a hill, under trees, sliding down the bluff (`lanes/walker/clip.mp4`).
- Full gate PASS, with test counts not below main's; `perf` run alone (NOT RUN is not a pass).
- A change in public kernel behaviour keeps `engine/kernel/API.md` true; ask before bumping KERNEL_API.

## Scope
`engine/kernel/world/**`, `engine/kernel/runner/**` (camera, walker), `engine/style/**`, `engine/rigs/**`,
new `engine/tools/selftest.d/*-walker-*.sh` files, `docs/shifts/2026-11-19-night/lanes/walker/**`.

---

# Lane rules (pasted verbatim into every lane brief)

## Standups: you report, the Director reads
- Keep `docs/shifts/<shift>/lanes/<lane>/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
  when the lane lands).
- Append one line at each milestone and at least every 60 minutes of work:
  `HH:MM | state: working|blocked|done|cut | did: <one line> | next: <one line> | gates: <last PASS/FAIL line or ->`
- `blocked` names the question in the same line. Then keep working on whatever the block does not touch.
- When you finish, write `REPORT.md` beside it (below) and set the last standup line to `done`.

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
- New selftest cases go in your own `engine/tools/selftest.d/NNN-<name>.sh` file.
- A kernel API addition updates `engine/kernel/API.md`; the Director regenerates docs on main (`tl arch --index`).
- Gates before `done`: `node devx/bin/tl.mjs check --tier fast`; when kernel, kits, rigs, style or seeds changed, also
  `node devx/bin/tl.mjs check --tier full` (perf alone if it says NOT RUN).

## REPORT.md
- Outcome against each acceptance criterion: met / not met, with its evidence.
- Gates with PASS/FAIL lines and counts.
- Changed files; behaviour changes; anything the owner should look at, and how.
- Questions for the Director; the next three things this lane would do.
