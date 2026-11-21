# N6 arms: what every arm does (the Director's brief; the direction is in your own ARM brief)

You are one of three arms of lane N6 (world-directions) of the Third Life night shift `2026-11-22-night`. Three arms
grow the same village into a Home in three directions, for the owner to see side by side and pick one. You work ALONE on
the look: nobody art-directs you. What is fixed below is the process, the files, the proofs and the evidence.

## Read first (absolute paths are given in your ARM brief; read them in your own tree)
- `CLAUDE.md` ("Laws that bite").
- `docs/shifts/2026-11-22-night/COMMON.md` (the shift's laws; you are not a Director, ignore "Calling Codex").
- `docs/TWO-WORLDS.md` in full: The Home, chunked streaming terrain, build layers, order of work item 5.
- `engine/kernel/world/WORLD.md` (Relief, the visitor's body, the pictures), `engine/kernel/world/landscape.gd`,
  `engine/kernel/world/terrain/village_terrain.gd`, `village_parts.gd` (`far_ground`, `mesas`, `plain_clumps`),
  `engine/kernel/world/draw/view.gd` (how the world, the landscape and the pictures are made), `engine/tools/world.sh`
  (`tour`, `window_mode`, the window lock, `prove`), `engine/boot/village.json` (the exe's village: 8 games).
- `engine/kits/KIT.md`, `engine/style/STYLE.md` (crisp cel is the house look; `TL_STYLE=crisp`).
- `docs/research/WHAT-MADE-GAMES-POPULAR.md` anti-pattern 3 ("10,000 bowls of oatmeal").
- The Director's rubric: `docs/shifts/2026-11-22-night/lanes/N6-world/RUBRIC.md` in the DIRECTOR's tree (path in your
  ARM brief). Score every round against it, honestly; the Director scores the same sheets independently.

## What you build
A **procedural Home-growth generator**: TWO-WORLDS order item 5, "a procedural base outward from the village".
- **Files:** only NEW files under `engine/kernel/world/home/**` (code, data, walks, tour/runner scenes, a `home.sh`
  tool), your selftest file(s) `engine/tools/selftest.d/75N-home-*.sh` (numbers 750-759 only), and your evidence under
  `docs/shifts/2026-11-22-night/lanes/N6-world/arm-<x>/**`. Raw frames, logs and big files go under `.tl/` of your tree.
  **No tracked file may change** (landscape.gd, terrain/**, WORLD.md and land/** belong to lane N5 tonight; the rest to
  others). If you need a hook in a tracked file, do not make it: work around it from inside `home/` and write the hook
  you wanted into `docs/shifts/2026-11-22-night/lanes/N6-world/arm-<x>/PATCHES.md`.
- **No `class_name`** in your files (preload by path). Three arms build in one class cache family; a name collides.
- **Data first, then drawing.** The generator is deterministic from the world seed (its own `RandomNumberGenerator` /
  `FastNoiseLite` instances with fixed seeds, never the village's stream, never the clock). It produces:
  - a pure sampler: height, ground material (a palette key) and water at any (x, z) of the Home;
  - a list of regions (name, kind, bounds, what makes it itself), paths (splines with widths and what they connect),
    water bodies, venue sites (empty game plots: centre, footprint, pad height, yaw) and dungeon-portal markers;
  - a per-chunk export in the shape TWO-WORLDS proposes for `tl.land/1` (a 96 x 96 m chunk: 32 x 32 cells of 3 m,
    heights quantised to u16 with a stated scale and offset, a material id per cell, the water level), so lane N5's
    chunks can adopt your land later. You need not write 4,600 files: export on demand, and write the few chunks your
    selftest checks plus a region summary JSON.
- **Extent:** at least x -1240..1300 and z -940..890 (3x the village box on each axis), the village box (x -392..452,
  z -330..280) left exactly as landscape.gd builds it today. The growth meets the village heightfield at its border
  without a step or a crack, and takes over from the flat far plain (`far_ground`); the old far-plain props (the mesas,
  the plain clumps, belt trees outside the village box) must stand on your land or be removed by your code, never
  float or sink. Coarser cells than 3 m are fine away from the village; say what you chose.
- **Venues:** 4-8 empty venue plots and 2-4 dungeon-portal markers, placed where a player would want to go in YOUR
  landscape, each reachable by a road or path from the village. A plot is a graded flat pad with a marker; a portal is a
  marker you can see from a distance. They hold no game tonight.
- **Use what exists:** the terrain builder's ideas (`village_terrain.gd`), the kit (`TLKit.build`, `TLKitNature`,
  `TLKitRoad`, `TLKitPath`, `TLMesh`), the style (`TLStyle.material`, palette keys), MultiMesh scatter as in
  `village_parts.gd multi`. No hand-made materials, lights or environments.
- **Optional, only if the rest is done:** the visitor can walk out onto the growth (its faces in the world's space).

## How the growth gets into a world without a tracked file changing (your problem to solve; ideas)
`world.sh tour` and the host (`kernel/host/host.gd`, mode `world-view`, `kernel/world/draw/view.gd`) cannot be told
about your files. You may write your own runner scene under `home/` that starts the same world view the host starts
(the same walk, the same 8 games, the same tiers and log), waits for the landscape, then grows the Home on it; and your
own `home.sh` that opens it in a window with the SAME machine-wide window lock as world.sh (copy `lock_alive`,
`win_lock`, `win_unlock` and its 1920x1080 / `--position 0,1440` / `--fixed-fps 60` / `--audio-driver Dummy` line),
and that can run the proof: each pack's hash in your Home world = the same pack alone for the same number of its own
ticks (reuse what `world.sh` does in `prove` and `alone`). How you do it is yours; that the 8 games hash as alone is
not negotiable.

## The grind loop: at least 5 rounds, each one the same
1. **Build** (or refine) the growth.
2. **Capture, in a window, under crisp (`TL_STYLE=crisp`):**
   - a **flyover clip**, 20 s or less (for example 1200 world ticks, every second frame at 30 fps), counted in frames,
     never the clock; frames as PNG/JPG under `.tl/`, then `ffmpeg` (`/c/ffmpeg/bin/ffmpeg`, H.264 mp4, 1280x720 or
     1920x1080, a few MB) into `arm-<x>/round-<n>/flyover.mp4`;
   - the **6 fixed stills** of the rubric (`overview_sw`, `village_edge_out`, `far_look_back`, `venue_approach`,
     `region_seam`, `map`) as JPG into `arm-<x>/round-<n>/`, and ONE sheet `arm-<x>/round-<n>/sheet.jpg` (3 x 2,
     each still labelled with its name and the round). Coordinates of stills 2-5 are chosen in round 1 and kept.
   - **figures** from the same window: the growth's build time (ms, by phase), the world's load time with and without
     the growth (A/B in the same session; label it busy if other Godot windows or builds run), flyover frame p50 / p99
     / max (ms), draw calls and primitives at each still. Write them to `arm-<x>/round-<n>/figures.json`.
   The window lock is shared by every lane on this machine: take it for one capture run, release it, never hold it
   while you think or edit. If you wait on it, that is normal (other lanes capture too).
3. **Score** the round against RUBRIC.md: each of the 7 items 0-4 with the evidence named, the hard gates pass/fail,
   into `arm-<x>/round-<n>/SCORES.md`. LOOK at the stills and the clip's frames yourself (open the images) before you
   score; a score without a look is not a score.
4. **Refine:** pick the 1-3 changes that raise the weakest items, write them in one line at the end of SCORES.md as
   "next", then go to 1.
Keep every round's sheet and stills: the owner wants to see the evolution. After each round append one line to
`arm-<x>/LOG.md`: `HH:MM | round N | total X/28 (S V R P C L F) | gates | what changed | next`.

## Proofs you run (the Director re-runs every one; your report is a claim)
- Your selftest block, headless (`bash engine/tools/selftest.sh home.<x>`, a filter that matches your cases):
  determinism (same seed twice = same data hash), the extent, every venue and portal reachable by a path from the
  village, the chunk export (a chunk's u16 heights and its neighbour's agree on their shared edge), the village box
  heights untouched where the growth meets it. Headless, frames not clock.
- The Home world proof in a window: 8/8 games hash as alone (see above), at least once on your final round.
- `node devx/bin/tl.mjs check --tier fast` after every round (it catches file sizes and lint).
- `node devx/bin/tl.mjs check --tier full --only world` once at the end.

## Laws
- Read-only git is fine (`git status`, `git diff`, `git log`); do not commit, stash, reset, checkout, or add.
- ABSOLUTE PATHS ONLY in every command; never `cd` inside a backgrounded command.
- Never kill a process you did not start (other lanes' Godot windows and gates run on this machine). Prefer
  `--headless` for everything but the captures.
- Time is physics frames (60 Hz). A stopped run is never a pass; unmeasured is not zero; never fake a frame, a figure or
  a hash.
- Godot: `C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe` (the class cache of your
  tree is built; after adding scripts run `"$G" --headless --path <your tree>/engine --import` once).
- When you are done (or at about 06:00 at the latest), write `arm-<x>/REPORT.txt`: what you built (files), the rounds
  with their totals, the final figures, the proofs with their PASS/FAIL lines, what you would do next, and the hooks
  you wanted (PATCHES.md). Then stop.
