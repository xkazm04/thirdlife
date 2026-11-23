# H3 gate: the editor always stops for a person after its first (greybox) phase

Shift 2026-11-23-day. Worktree `C:/Users/kazda/kiro/third-life/.claude/worktrees/n23-method` (branch `n23-method`, at
main c4b0b83). Route: Opus solo. Started 09:30. Landable by 11:30.

## The owner's decision (23 Nov), verbatim
Asked "Person gate: should the editor always stop after its first greybox phase for you, even when a job runs straight
through? (recommended: yes)", he answered: "Person gate - yes". And: "Design lines - keep as lebelled" (so FANTASY /
WORLD / TEARDOWN / 30 SECONDS / KILL IF stay labelled lines in the brief; no contract keys; nothing to build for that).

## Goal
`docs/design/METHOD.md` says only a person's hand can pass a game as fun, and the first phase of a job is a greybox with
a playtest card. Today a job started with run-through passes every phase itself (`foreman/src/phases.ts`, `h.s.runThrough`),
so the greybox is never held for a hand. Make the first phase a person gate that run-through cannot pass.

## Acceptance
- A job with run-through pauses after its first phase (`job_state paused`, reason "phase") and waits for the person's
  pass or hold exactly as a job without run-through does; later phases still run through.
- The pause says why in the person's words (status / explain / the Create panel's text if it shows the reason): the
  greybox waits for your hand, with the playtest card.
- No way around it by flag or by the designer's answers; the fake adapter and tests can still drive a job to the end by
  giving the pass explicitly (as a person would).
- Tests: new ones for the gate (run-through job pauses at phase 1, continues after a pass, runs through phases 2+);
  every existing test that relied on run-through passing phase 1 is updated and named in the report with why.
  `npm test` in `foreman/`: 0 fail, count not lower than main's 322.
- If the Create panel (`engine/ui/`) shows or drives run-through, it reads right with the gate (ui selftest stays green:
  `bash engine/tools/ui.sh selftest` or what `engine/tools/` names for it).
- `contracts/JOB.md` is Director-only: if the gate needs words there (an event reason, a rule line), put the exact text
  you propose in the report; do not edit it.
- `docs/design/METHOD.md` gets the one line that says the gate is now enforced, where it describes the greybox stage.
- `node devx/bin/tl.mjs check --tier fast` passes.

## Scope
Write: `foreman/src/**`, `foreman/prompts/**` (only if a prompt mentions run-through), `engine/ui/**` (only text for
the gate), `docs/design/METHOD.md`, `docs/shifts/2026-11-23-day/lanes/H3-gate/`. Selftest block range if needed: 790-799.
No Foreman build job is started (fake adapter only). Absolute paths only; never `cd` in a backgrounded line. When
landable, say so in STANDUP.md, make no further edits, and return the report as your final message.


---

# Lane rules (pasted verbatim into every lane brief)

## Standups: you report, the Director reads
- Keep `docs/shifts/2026-11-23-day/lanes/H3-gate/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
