# Lane hunt2: bug hunt round 2 on the fixed tree (queued; starts when the first lane lands)

Shift `2026-11-19-night`, lane `hunt2`. Worktree `.claude/worktrees/n19-hunt2` (branch `n19-hunt2`, cut from main AFTER the
night's first landing). Time box: until 07:00.
Route: **Opus directing Astra** (the trial's bug-hunt winner: 59 vs 23 vs 14). You are the Opus director; Astra hunts and
fixes through `codex exec` (`.claude/skills/shift/SKILL.md` § 3); you re-run every repro and every gate yourself.

## Goal
1. Hunt for defects in what changed since 17 Nov: walker, camera, terrain, parkour, Pip, the site, selftest.d, and today's
   37 fixes. Did each fix hold? Did one break something else? Each finding needs file:line, a runnable repro and a
   severity. OpenAI's cybersecurity filter may stop a hunting run: resume it by id with a reworded brief.
2. Fix the proven high and medium findings that are in your scope, each with a permanent check in your own
   `engine/tools/selftest.d/NNN-*.sh`. List the lows for the backlog.

## Acceptance
- `lanes/hunt2/findings.md` (every finding, its verdict, its repro path) and `lanes/hunt2/repro/`.
- Each fix: repro before -> after. Full gate PASS, with counts not below main's.
- Do not touch files another live lane claims (`.claude/sessions.json`); list those findings for the Director.

## Scope
Assigned at launch: the paths no live lane claims. Findings may come from anywhere.

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
