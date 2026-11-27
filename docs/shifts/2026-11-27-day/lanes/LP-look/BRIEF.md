# Lane LP: the Home sandbox look, polished (day of 27 Nov)

Worktree `C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-look`, branch `d27-look`, from main 8be26d61. Opus, solo.
Time box: about 5 hours of work; land in rounds (send "landable" after each round; no edits after a landable message until the Director says it landed).
Selftest block range: `engine/tools/selftest.d/768-772`. Absolute paths only; never `cd` inside a backgrounded command.

## The owner's words (27 Nov, leaving for 24 h)
"use this time to master the sandbox engine ... Think about what is our engine unique and where can outshine those two [Minecraft, Roblox] ... combining with our graphics and LLM builder which are superior game design aspects".
Our graphics are one of the two things the owner calls superior. M5 (water, paths, plants, land look) landed on main yesterday and its own lanes judged several looks short of the bar. This lane brings them to the bar, judged by eye in the exe.

## Read first
- `CLAUDE.md`, `contracts/BUILD.md` (M5 section), `engine/kernel/world/build/BUILD.md`, `LAND.md`, `PATCHES-L.md`, `PATCHES-P.md`, `PATCHES-W.md`, `PATCHES-C.md`.
- The M5 captures and the lanes' own judgements: `C:/Users/kazda/kiro/third-life/.spark/Spark/captures/world-sandbox/` (l-*, p-*, w-*, c-*), and `.spark/Spark/ideas/world-sandbox.md` (sections "Design decisions, wave 5" and the lane review lines).
- Lane L's exe tools for captures: `engine/kernel/world/build/land_drive.gd`, `land_shots.gd`. The style: `engine/style/STYLE.md`, `engine/style/shaders/toon_cel.gdshader`, `water_cel.gdshader`, `style_crisp.json` (the crisp cel look the owner chose on 20 Nov).

## Goal: five looks, each judged in the exe against the valley's own ground in the same frame
1. **Terrace face.** A flattened terrace on a slope today shows its steep side as a flat pink painted shape. It must read as a rock face (the valley's own rock and strata where it is steep), with a clean top edge.
2. **Growth.** Flowers are near invisible past ~10 m, meadow barely differs from plain grass, tall grass reads like a shadow. Each of the three must be recognisable at 10, 25 and 50 m: meadow a lusher, varied grass; flowers clearly dotted colour; tall grass lighter, taller-looking tufts that catch light (not darker than the ground). Stay shader-only (no instances, no draw calls) unless you measure that it cannot reach the bar, then report before building instances.
3. **Stone path.** Today a flat paved mat with square ends and world-axis bricks. It must read as a laid stone path: rounded or tapered ends, the joint pattern following the path direction, an edge that sits into the grass (the dirt path is the round's best result: match its edge quality).
4. **Pond shore.** Crisp but polygonal (3 m land triangles). Make the shoreline read as a smooth curve from a walking eye height. Measure the options before choosing (finer water/shore mesh, a smoother land surface near water, a shader shore term), and keep the land's collision and every land/water test as they are, or name why a test expectation moves.
5. **LLM bridge.** The real Opus bridge built a deck 0.2 m over the water. Fix the prompt (`foreman/prompts/world_edit.md`; the ask's water facts) so a bridge deck clears the water by at least 1 m and its approach steps start on dry ground; prove with ONE real Opus call in the exe at the stream near the spawn ("a small stone bridge with railings across the stream here"), report duration, tokens, ops, refused, and capture it beside `c-bridge.jpg`.

## Acceptance
- Before/after captures from the same camera for 1-4 (`lp-terrace-before/after.jpg`, `lp-growth-10m/25m/50m.jpg` after and before, `lp-stone-path-before/after.jpg`, `lp-shore-before/after.jpg`) and `lp-bridge.jpg`, in `docs/shifts/2026-11-27-day/lanes/LP-look/` (JPG, under 400 KB each). Judge each honestly: met / not met.
- Headless numbers in `768-home-look2.sh` (and more blocks in range if needed): e.g. the terrace side vertices carry rock, growth density reaches the shader, a stone path's end vertices taper, the shore's max segment length; an unedited ground draws byte-identically (celsurf/n3 stay green).
- Frame cost near each before/after (p50/p99) and the land chunk mesh time before/after.
- The fast gate; because this lane changes engine/style and the draw layer, the uncapped kernel suite `bash engine/tools/selftest.sh` (main had 712 passed, 3 failed: base.lines_undeclared, base.lines_own_6001, feel.pushbox_invariants many_budget) and `node devx/bin/tl.mjs check --tier full --only world,packs` (world 9/9 hashes equal main's).

## Files
Yours: the land look (`land_mesh.gd`, `land_brush.gd`, `land_ghost.gd`, `plants_layer.gd`), paths drawing (`path_mesh.gd`, `path_shape.gd`), water drawing (`water_mesh.gd`), `engine/style/shaders/toon_cel.gdshader` and `water_cel.gdshader` (only behind checks that unedited ground and the river draw as today), `foreman/prompts/world_edit.md`, `command_ask.gd` (water facts only), new files `engine/kernel/world/build/look_*.gd`. Not yours: contracts (ask the Director), the walker, the command bar's UI, tl.build file format (no new keys).

## Lane rules (verbatim from .claude/skills/shift/lane-rules.md)

### Standups: you report, the Director reads
- Keep `docs/shifts/2026-11-27-day/lanes/LP-look/STANDUP.md` in YOUR worktree (the Director reads it there and copies it to main when the lane lands).
- Append one line at each milestone and at least every 60 minutes of work:
  `HH:MM | state: working|blocked|done|cut | did: <one line> | next: <one line> | gates: <last PASS/FAIL line or ->`
- `blocked` names the question in the same line. Then keep working on whatever the block does not touch.
- When you finish, write `REPORT.txt` beside it (the harness refuses agent writes to files named REPORT.md), return the full report as your final message too, and set the last standup line to `done`.

### Honesty
- Evidence or it is not done: a gate line, a test count, a still, a video, a repro before and after.
- A stopped run is never a pass. NOT RUN is not PASS. Fewer tests completed than on main is a stopped run.
- Unmeasured is not zero. Never fake a frame, a figure or a hash.
- A behaviour change that moves a test expectation is named, with why. Never loosen a test to make it pass.
- What the player sees or feels is judged as a person meets it (a window, the exported game), not only headless.

### Laws (CLAUDE.md)
- Work only in your worktree. No git that writes (read-only `git diff`/`git status` are fine). The Director lands.
- Never kill a process you did not start. Prefer `--headless`. Build the class cache once: `"$G" --headless --path engine --import`.
- Time is physics frames; determinism (same pack + seed + frames = same state_hash); unknown keys are errors; packs use only the TL* API and never declare class_name; kit, rigs, style reference nothing outside themselves.
- Contracts (`contracts/*`) are Director-only: put the question in your report.
- New selftest cases go in your own `engine/tools/selftest.d/NNN-<name>.sh` files, numbered inside the block range your brief assigns.
- Raw captures stay under `.tl/` in your worktree. The lane folder gets only sheets, notes, JPG stills and mp4 clips of 30 s or less.
- A kernel API addition updates `engine/kernel/API.md`; the Director regenerates docs on main (`tl arch --index`).
- Gates before `done`: `node devx/bin/tl.mjs check --tier fast`; when kernel, kits, rigs, style or seeds changed, also the full gate (perf alone if it says NOT RUN).

### REPORT
- Outcome against each acceptance criterion: met / not met, with its evidence.
- Gates with PASS/FAIL lines and counts.
- Changed files; behaviour changes; anything the owner should look at, and how.
- Questions for the Director; the next three things this lane would do.
- Your measurement outranks this brief: if a premise here is wrong, say so with the evidence.
