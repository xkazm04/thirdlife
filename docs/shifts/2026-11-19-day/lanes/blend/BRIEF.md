# Lane blend (day of 19 Nov): constructions that sit in the terrain, not in a circle

Worktree `.claude/worktrees/d19-blend` (branch `d19-blend`). Time box: about 08:55 to 16:45. **Route:** Opus directing
Astra. You own correctness (determinism, world = alone, gates). Astra designs the look: give it the problem and the
constraints, not a picture. Its first idea of how the transition should look is the one to try first. Judge the result
by stills and say honestly whether it is better.

## The owner's words (19 Nov, 08:20)
"All constructions do have circle around incompatible with terrain around, the transition is not seamless".

## What exists
- Every village lot (house games, seeds, examples, construction sites) gets a flat pad. A circular ring fence and a
  rim run around it, and the terrain is cut or filled to the pad. See `engine/kernel/world/landscape.gd`,
  `terrain/village_terrain.gd`, `terrain/village_parts.gd`, `draw/` (`view_seam.gd`, rims, `ground_cover`) and
  `engine/kernel/world/WORLD.md`.
- Look at the night's stills first: `docs/shifts/2026-11-19-night/lanes/editor/stills/lot/` (a lot by the river) and
  the parkour lane's road-edge stills. Then capture today's state yourself, from the road and from above, for at least 4
  lots on different ground (flat, slope, near the river, near the bluff).

## Goal
The ground around every lot transitions into the surrounding terrain without a visible seam or a foreign circle:
- the pad follows the footprint shape, not a disc;
- the grade blends over a natural distance with the terrain's own colours and ink;
- fences and rims follow the footprint and the terrain, or go where the design says.
The lot's reserved area may stay a disc in the data (the scheduler and the editor's ring), so long as it is no longer
**seen** as a circle. Keep:
- **Determinism:** world = alone. A changed terrain may change hashes only of what stands on it; say which, and why
  that is right. No game's state hash may move.
- **Performance:** frame time on the tour; `perf` alone.
- Last night's walker ink and crest work.
- The editor lane works in `site.gd` and `site/`. Your input from it is the lot's footprint and yaw, already in the walk
  data or `job_created.lot`; agree any new field through the Director.

## Acceptance
- Before/after stills of the same 4+ lots, from the road and from above, side by side, with a contact sheet.
- A windowed clip of 20 s or less (`clip-blend.mp4`): walking off the road into a lot and along its edge.
- A permanent measurable check in your own blocks, for example no ring-shaped height step around a lot, or the pad
  outline following the footprint.
- Gates: the full gate (world 8/8, packs; `perf` alone if busy), and the windowed tour. Counts are never below main's.

## Scope
`engine/kernel/world/landscape.gd`, `engine/kernel/world/terrain/village_terrain.gd`,
`engine/kernel/world/terrain/village_parts.gd`, `engine/kernel/world/draw/**`, `engine/style/**`, `engine/kernel/world/WORLD.md`,
new `engine/tools/selftest.d/51x-blend-*.sh`, and `docs/shifts/2026-11-19-day/lanes/blend/**`.

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
