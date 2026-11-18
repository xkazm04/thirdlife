# Lane parkour: polish the landed course to the winning look (night of 19 Nov)

Shift `2026-11-19-night`, lane `parkour`. Worktree `.claude/worktrees/n19-parkour` (branch `n19-parkour`). Time box 00:00-06:30.
Route: **Astra alone** for the look (it won the owner's eye in the trial: course D). The Opus agent that runs this lane
launches Codex with this brief verbatim, does NOT direct the art, then verifies the gates, captures the clip and writes
REPORT.md. It may resume Astra by session id with the gate failures it found, and nothing else.

## The owner's words
"Parkour winners - D, with F as close second place, E as close third" ... "Land F, polish later". F's code is on main
(`engine/packs/parkour`). D's and E's code no longer exists; their stills and reports do (`ref/` beside this brief).

## Goal
Course F plays as it does, but LOOKS like D: read `ref/b-*.jpg` (D's course, jump, bar, chute, from the village road) and
`ref/D-report.md`, compare with F's look in the game, and bring F to D's look with house kit parts and the house toon
style (no hand-made materials, lights or environments). Then E's retry room: E moved the bar 3.5 -> 5.5 m into its deck
because "a regular-hand retry had no run-up" (`ref/E-report.md` line 66, `ref/E-bar_slide.jpg`). Give F's bar the same
run-up, so a failed slide can be retried from the checkpoint without walking back.

## Acceptance
- Stills of F after the pass, from the same five views as D's (course, jump, bar, chute, village road), side by side with
  D's in `lanes/parkour/stills/`, plus a contact sheet.
- The bar has a run-up after its checkpoint; a regular-hand bot retry at the bar finishes (`tl ladder` or the pack's bot
  tests; quote the hand and the seed count).
- Every parkour bot test and the impossibility test still pass; `node devx/bin/tl.mjs check --tier full --only packs,world` PASS.
- A clip of at most 20 s of one full run in a window (`engine/tools/look.sh clip`, or Godot `--write-movie` at 1280x720
  then mp4) at `lanes/parkour/clip.mp4`.
- No kernel change. Kit additions only if no existing part fits (say which ones you looked at in `engine/kits/KIT.md`).

## Scope
`engine/packs/parkour/**`, `engine/kits/**` (additions only), `docs/shifts/2026-11-19-night/lanes/parkour/**`.

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
