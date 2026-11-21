# Site fixtures: who runs them, what they guard

The construction site's test inputs (`kernel/world/site/`: `site.gd` reads a Foreman job's `job.jsonl`, `log.gd` folds
it, `draw.gd` draws the site). They belong to the `kernel` context (`context-map.json`), like the code they guard.

The rule (day of 21 Nov 2026, lane L6): a change to the code a fixture guards updates that fixture in the same change,
and names the moved count in the fixture (the night of 21 Nov moved the body counts of `no_ring.gd` and
`editor_yaw.gd` with `draw.gd`). A fixture nothing runs is removed. Every top-level entry here has a row, and every
"Run by" file names it: the selftest case `harden.site_fixtures` (`tools/selftest.d/700-harden-day.sh`) fails
otherwise. A fixture waits for the site's worker meshes with `draw.gd wait_meshes`, never by counting frames.

| Fixture | What it is | Run by | Guards |
|---|---|---|---|
| `arrive/` | the job log of a game that was built and promoted (21 events), with the promoted pack `example.bounce@0.1.0` | `tools/selftest.d/460-walker-world.sh`, `tools/selftest.d/480-editor-lot.sh`, `tools/selftest.d/500-editor-joblot.sh`, `tools/selftest.d/501-editor-site.sh`, `tools/selftest.d/502-editor-yaw.sh`, `tools/selftest.d/503-site-auto-pad.sh`, `tools/selftest.d/120-p5.sh`, `kernel/world/walks/walker_world_case.gd`, `kernel/world/site/fixtures/arrived_yaw_world.cjs`, `kernel/world/site/fixtures/site_arrive.json`, `kernel/world/site/fixtures/site_solid.json` | `site.gd`, `log.gd`, `draw.gd`, the arrival of a promoted game |
| `failed/` | the job log of a job whose package failed after the round limit (11 events) | `kernel/world/site/fixtures/site_arrive.json`, `kernel/world/walks/site.json`, `kernel/world/walks/walker_world_case.gd` | a failed and a blocked package shown on the site (`site.failed`) |
| `unmade/` | the job log of a change that was NOT made (33 events: the only fixture with `change_requested`, `reopened` and `replan`) | `tools/selftest.d/120-p5.sh`, `kernel/world/walks/walker_world_case.gd` (its log schema check reads every directory here) | the restore after a change not made (`site.unmade`), `log.gd` on a reopened and replanned job |
| `site_arrive.json` | a walk: the `arrive/` and `failed/` jobs on two lots | `tools/selftest.d/120-p5.sh`, `tools/selftest.d/440-walker-replay.sh`, `kernel/world/site/fixtures/arrived_yaw_world.cjs` | `site.replay_same`, `site.failed`, the replay |
| `site_solid.json` | a walk: the `arrive/` job on a lot, for the scaffold's solid bays | `tools/selftest.d/120-p5.sh` | `site.solid` (bays solid, cleared on arrival) |
| `no_ring.gd` | the site's entrance rails, sign posts and site fence, building and arrived, by its worker mesh and its bodies | `tools/selftest.d/501-editor-site.sh`, `tools/selftest.d/700-harden-day.sh` | `draw.gd` (`site.no_ring`) |
| `editor_yaw.gd` | the site placed by the editor's yaw: meshes and bodies, job and draft, repeat build | `tools/selftest.d/502-editor-yaw.sh`, `tools/selftest.d/700-harden-day.sh` | `draw.gd`, `site.gd` (`site.editor_yaw`) |
| `arrived_yaw_entry.gd` | the arrived game's turned plot: its gaps and held or released entry | `tools/selftest.d/504-editor-arrived-yaw.sh` | `site.gd`, `tiers.gd` (`site.arrived_yaw_entry`) |
| `arrived_yaw_solids.gd` | the arrived game's turned walls and floor in the visitor's space, whole and sliced | `tools/selftest.d/504-editor-arrived-yaw.sh` | `pack.gd`, `terrain/world_space.gd` (`site.arrived_yaw_solids`) |
| `arrived_yaw_stage.gd` | the arrived game's turned stage drawn in a world | `kernel/world/site/fixtures/arrived_yaw_world.cjs` | `world.gd`, `draw/draw.gd` |
| `arrived_yaw_world.cjs` | the world, world-file and replay entry points with real promoted jobs | `tools/selftest.d/504-editor-arrived-yaw.sh` | the arrival through `host.tscn -- world` |
