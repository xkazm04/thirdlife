# Day shift of 19 Nov 2026: plan

Agreed with the owner at 08:20 and 08:40. The owner's words: "Continue with all tracks during this day as I will not be
available for large part of the day now, add one track to allow character fly as fast cool way of transport, this
ability would give character mechanical wings, vertical movement and 500% faster movement forward than usual run".
"All tracks" means the morning's three (E2 contracts, E1 editor placement, P1 parkour challenges) plus the flight track.
The owner is away, so the Director takes the design decisions, records them in each brief, and lists them on the
verdict page for the owner to overturn.

- **Before launch (Director, done 08:45):** E2 contract text: CARDS.md `interview` and `footprint`; JOB.md
  `job_created.answers` and `lot`, `change_requested.decision`, and the foreman flags (`cf73f58`).
- **Start:** about 08:55. **Land-by:** 18:00 (land and push, as last night). **Standups:** hourly at :37.
  **Verdict:** 17:15, as a page with clips.
- **Rules from last night:** report as `REPORT.txt` plus the final message; each lane owns a selftest block range;
  raw captures stay under `.tl/`, and only clips of 20 s or less, sheets and notes go in the lane folder.

| Lane | Route | Claims (write scope) | Selftest blocks |
|---|---|---|---|
| editor | Opus directing Astra | `engine/ui/**`, `engine/tools/ui.sh`, `foreman/**`, `engine/cards/**`, `devx/lib/commands/cards*`, `devx/lib/cards/**`, `devx/test/cards*`, `engine/kernel/world/site.gd`, `engine/kernel/world/site/**` | 500-509 |
| blend | Opus directing Astra (Astra designs the look) | `engine/kernel/world/landscape.gd`, `engine/kernel/world/terrain/village_terrain.gd`, `engine/kernel/world/terrain/village_parts.gd`, `engine/kernel/world/draw/**`, `engine/style/**` | 510-519 |
| parkour | Astra alone for the look and the course; an Opus operator verifies | `engine/packs/parkour/**`, `engine/kits/**` (additions) | pack tests only |
| flight | Opus directing Astra; wings modelled by Opus in Blender or built from rig parts | `engine/kernel/api/tl_biped.gd`, `engine/kernel/api/tl_chase_cam.gd`, `engine/kernel/world/visitor.gd`, `engine/kernel/world/terrain/world_body.gd`, `engine/kernel/world/terrain/walker_space.gd`, `engine/kernel/world/terrain/crown_camera.gd`, `engine/kernel/runner/**`, `engine/rigs/**`, `engine/kernel/API.md`, `engine/kernel/runner/manifest.gd`, `assets/**` | 520-539 |

Four lanes at once: 40 GB RAM free at 08:15, and two of the lanes are mostly non-Godot. Estimated Astra spend is 2-3 M
tokens. Not offered: hockey and win measurement (deferred).

## Launch record (08:35-08:42)
Worktrees `d19-{editor,blend,parkour,flight}` were cut from `1b3e055`, each with foreman deps, the site jobs and the class
cache. Scopes are claimed in `.claude/sessions.json`; the selftest blocks are assigned per lane in the briefs, not claimed,
because `tl arch` reads overlapping globs as a collision.

| Lane | Agent (SendMessage id) | Started |
|---|---|---|
| editor | ab4f290a059951785 | 08:40 |
| blend | a30fec00b00f954ea | 08:40 |
| parkour | a3c7abec1e09a7c6a | 08:40 |
| flight | ab4454967cfe24cf9 | 08:40 |

Timers: standups hourly at :37 (09:37-16:37), verdict at 17:13.
| parkour round 2 | `.claude/worktrees/d19-parkour2` (from `ebeeb2b`) | same agent | 10:36 |
| flight round 2 | `.claude/worktrees/d19-flight2` (from `ebeeb2b`) | same agent | 10:36 |
| editor round 2 | `.claude/worktrees/d19-editor2` | same agent | 11:45 |
| blend round 2 | `.claude/worktrees/d19-blend2` | same agent | 11:45 |
| editor round 3 | `.claude/worktrees/d19-editor3` | same agent | 13:05 |
