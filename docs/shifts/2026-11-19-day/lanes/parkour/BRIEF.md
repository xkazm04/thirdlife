# Lane parkour (day of 19 Nov): a harder, TV-ninja-style obstacle run

Worktree `.claude/worktrees/d19-parkour` (branch `d19-parkour`). Time box: about 08:55 to 16:45. **Route:** Astra alone
designs and builds the course and its look; it won the owner's eye twice. The Opus agent operates the lane: it launches
Codex, passes this brief on verbatim, verifies every gate, takes the stills and the clip, and writes the report. It does
not direct the design.

## The owner's words (19 Nov, 08:20)
"Continue with improvements to create more sophisticated challenges (like TV ninja runs)". The C retry stays for now.

## Goal
Grow course F (`engine/packs/parkour`) into a multi-stage obstacle run in the spirit of TV ninja courses, with obstacles
that demand timing and a chain of moves instead of single jumps. Generic obstacle kinds only, all in the house look:
- stepping pads at angles;
- a swinging or moving element;
- a narrow beam;
- a wall to scale with a run-up;
- a gap that needs a run-jump-slide chain;
- a final tower.

Every one must be possible with the walker's moves (run, jump, run slide, slope slide). Where a new move would be needed
(a wall run, a grab), do not invent it in the pack: list it as a question for the Director.

**Stages:** two or three stages with checkpoints, and a stage timer in the HUD (best per stage). Keep `TLHand`
honesty: difficulty is quoted per hand.

## Laws
- No kernel change. Kit additions only if no existing part fits (say which ones you checked in `engine/kits/KIT.md`).
- Moving elements are pack physics: deterministic, counted in frames, with no wall clock.
- A game in the world plays as it does alone.

## Acceptance
- Stills of every new obstacle, a course overview, and the plot from the village road, with a contact sheet.
- A windowed clip of 20 s or less of one full run (`clip.mp4`; speed-ups named).
- Bots: `bot_course` (perfect hand) finishes. A ladder per hand (newcomer, regular, sharp over 20 seeds) is quoted.
- The impossibility test still fails when a gap is made impossible. Each new obstacle has its own impossibility case
  where it makes sense.
- Gates: lint, every pack test, `--only packs,world` (re-run hockey's frame-time check alone if load trips it), and the
  fast tier.

## Scope
`engine/packs/parkour/**`, `engine/kits/**` (additions only), and `docs/shifts/2026-11-19-day/lanes/parkour/**`.

---

# Lane rules (pasted verbatim into every lane brief)

## Standups: you report, the Director reads
- Keep `docs/shifts/<shift>/lanes/<lane>/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main
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
