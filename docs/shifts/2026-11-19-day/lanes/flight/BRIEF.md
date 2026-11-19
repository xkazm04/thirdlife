# Lane flight (day of 19 Nov): mechanical wings, a fast and cool way to travel

Worktree `.claude/worktrees/d19-flight` (branch `d19-flight`). Time box: about 08:55 to 16:45. **Route:** Opus directing
Astra for the mechanics (you scout, brief Astra, verify every claim and re-run the gates). Build the wings yourself:
model them in Blender like Pip (`docs/art/bosses/pip/` and the TLKitAsset path in API 1.7), or from rig parts if that
reads better in the toon style. Your call; say why.

## The owner's words, verbatim (19 Nov, 08:40)
"add one track to allow character fly as fast cool way of transport, this ability would give character mechanical
wings, vertical movement and 500% faster movement forward than usual run"

## The Director's design decisions
The owner is away, so these stand until the owner overturns them on the verdict page.
- **Input:** flight toggles with **F** in the village walker. If F is taken there, use another free key and say which.
  - **On take-off:** the mechanical wings unfold (an animated unfold of about 0.5 s, not a pop).
  - **Space:** climbs; **C** descends (C is the slide key on the ground, unused in the air).
  - **W/A/S/D:** as on the ground; A/D keep "face" (the owner's W1).
  - Landing gently on ground folds the wings and returns to walking.
- **Speed:** forward cruise is **5 x the run speed**, with smooth acceleration of about 1 s, no instant jump to top
  speed. Vertical speed is moderate (about the run speed). Turning is banked and smooth.
- **The world:** flight respects collision. You cannot fly into hills, trees, buildings or other games' bodies; you
  slide off them, as the walker does. There is a ceiling (about 120 m above the ground). Entering a game's plot from the
  air lands you at its gate, so stage entry keeps working.
- **Camera:** it pulls back and lowers its pitch with speed for a sense of speed, keeps the crown and terrain rules
  (crowns, never inside a hill), and has no motion sickness from sudden swings.
- **Feel and look:** the wings have a slow idle flap or glide pose and a small wind trail at top speed, made from house
  style parts only (no hand-made materials or lights). The figure leans into the flight.
- **API:** a kernel API addition is allowed (TLBiped fly mode and speed scale), opt-in and safe for every pack, with
  KERNEL_API 1.9 and `engine/kernel/API.md`. Packs that do not opt in behave exactly as today. Hashes of every game stay
  as they are (world = alone).

## Acceptance
- A windowed clip of 30 s or less (`clip.mp4`): take off on the road, climb, cruise at 5 x over the village and the
  bluff, bank round a tree, descend and land by the parkour plot.
- Stills of the wings folded, unfolding and cruising, with a contact sheet.
- Measured: cruise speed / run speed = 5.0 ± 0.1, acceleration time, ceiling, and zero frames inside a hill or crown
  over a scripted flight sweep. Each is a permanent case in your blocks.
- Gates: the full gate, counts never below main's (`perf` alone if busy), and the windowed tour.
  `node devx/bin/tl.mjs arch --index` is run by the Director on main.

## Scope
`engine/kernel/api/tl_biped.gd`, `engine/kernel/api/tl_chase_cam.gd`, `engine/kernel/world/visitor.gd`,
`engine/kernel/world/terrain/world_body.gd`, `engine/kernel/world/terrain/walker_space.gd`,
`engine/kernel/world/terrain/crown_camera.gd`, `engine/kernel/runner/**`, `engine/rigs/**`, `engine/kernel/API.md`,
`engine/kernel/runner/manifest.gd`, `assets/**` (the wings asset and its manifest entry), new
`engine/tools/selftest.d/52x-flight-*.sh` and `53x-flight-*.sh`, and `docs/shifts/2026-11-19-day/lanes/flight/**`.

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
