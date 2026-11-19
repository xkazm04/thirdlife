Lane blend (day of 19 Nov): constructions that sit in the terrain, not in a circle
Worktree .claude/worktrees/d19-blend, branch d19-blend from main 1b3e055. Nothing committed (the Director lands).
Route: Opus directing Astra (gpt-6.2-astra, high), one Codex session 01a1f2be-b82b-79a0-8855-095a84d1402f.
Codex tokens: round 1 254,091; round 2 584,113 (resumed by session id); total 838,204.

OUTCOME
The owner's "circle around every construction" is gone from the road and from above on all 8 lots I captured
(6 games, 1 construction-site lot, a lot by the river, a lot at the bluff foot). What made the circle, and what
replaced it:
- the pad was a disc of r + 10.5 m with a linear round bank -> the flat floor follows the plot's footprint and yaw
  (rounded rectangle) and grades into the land over 20 to 66 m by height difference, easing at both ends
  (village_terrain.gd `_grade_pads`); the pad under a game stays flat out to r + 3 + one cell (visitor/floor rule);
- the dirt ring, dry-grass band and stone kerb arc (WorldPlotRings, WorldPadKerbs) -> removed; worn ground is now
  vertex colour on the heightfield along the spur and through a lot's crane yard (wear map);
- the round fence at r + 3.6 -> short rails either side of the entrance only (with matching colliders);
- the pack's own ground, clipped to a disc by the runtime -> keeps its clip, but its outer band takes the village's
  ground colours and grass detail in village coordinates (toon.gdshader branch, only on the village's private rim
  material; a pack drawn alone renders exactly as before), with an irregular worn edge (wall's dirt clearing).
- Bug found and fixed on the way: a pack's rim height was the median of every wide mesh vertex near the rim; for
  seed_drive that included treetops (+7.63 m instead of -1.09 m for its ground), so the track was sunk into a 7 m
  bowl with 60-degree walls. The rim is now the median of terrain-coded vertices when they encircle the plot
  (draw_base.gd `edge_height`); drive's steepest rim face 59.7 -> 13.8 deg. The rim band is 9..16 m by radius
  (rim_width) unless a walk sets rim_band. Rim cache key gets "|soil" (old cached rims are not read); picture-cache
  keys already include rim and band.

ACCEPTANCE
1. Before/after stills of the same 4+ lots, from the road and from above, side by side, contact sheet: MET.
   8 lots x 2 views. contact-before-after.jpg (16 pairs), sheet_before.jpg, sheet_after.jpg, before/*.jpg,
   after/*.jpg. Walk used: blend_views.walk.json (exe village + parkour + a river lot + a bluff lot, crane shots).
   All taken by me in a window (world.sh tour --pictures-only --load=block).
2. Windowed clip <= 20 s, walking off the road into a lot and along its edge: MET. clip-blend.mp4 (15.0 s,
   world.sh visit-test with blend_clip.walk.json + blend_clip.devices.json; off the road into the paddle lot, turn,
   run along its edge).
3. Permanent measurable check in my blocks: MET. engine/tools/selftest.d/
   510-blend-footprint.sh  blend.footprint: a long rotated footprint is flat along its axis and graded across it,
     grade steps < 0.65 m per metre, clip triangles at pad height through road and pond stamps, sink rule, repeatable.
   511-blend-shoulder.sh   blend.shoulder: on seeded rolling land, flat reach on-axis 54.25 m, diagonal 76.25 m,
     ratio 1.406 (footprint, not disc: needs 1.32..1.48); largest second difference of height across the shoulder on
     72 rays 0.614 m (limit 0.65); drive rim -1.09 m = ground-only -1.09 m. Astra showed it fails on the old disc
     grade (ratio 0.965, 2.833 m) and on round 1 (1.255, 0.679 m).
4. Gates: MET, perf by A/B (see below). Counts not below main's.

GATES (worktree, after round 2 and my one fix)
  tl check --tier full (10:04): arch FAIL + devx.test FAIL on a new public TLStyle.terrain_rim_material (API index
    stale). I moved it into village_terrain.gd as a private helper (tl_style.gd is now identical to main), then
    tl check --tier full --only arch,devx.test: PASS arch [12/12], PASS devx.test [226/226].
  Rest of that full run: PASS kernel.selftest [279/279] (main 277: + blend.footprint, blend.shoulder),
    PASS world [8/8] (world = alone), PASS packs [2/2] (35 of 35 verb runs), PASS seeds [39/39], PASS kit.selftest
    [91/91], PASS item.selftest [91/91], PASS ui.selftest [128/128], PASS foreman.test [210/210], PASS
    foreman.typecheck, PASS assets [4/4], PASS cards [3/3]; perf NOT RUN (machine BUSY).
  Focused after the fix: selftest blend. 2/2, ground. 10/10, walker 8/8 (incl. style.walker.ink: last night's
    ink/crest work intact; walker.crown, slide_floor, slide_entry, crown_swing_behind).
  world.sh tour tour --out-dir (window): PASS world.tour (10 of 10 pictures, 4 stage changes, every pack = alone, log
    replays). world.sh tour tour --headless: PASS world.tour.
  Perf: tl perf run (all six) busy, not recorded, all PASS. tl perf run --scenario tour6,walk30 --quiet-only
    (quiet, use 42 %, recorded as ledger line 11): tour6 frame p50 2.440 ms (main's quiet 2.07..2.25), gpu 1.186
    (1.214), first frame 676 (727), six built 2735 ms (2976); walk30 frame p50 2.389 (1.99..2.17), gpu 1.232
    (1.429), first frame 924 (1499), six built 2251 (3249). sim_tick p50 rose by the same ~0.3 ms though simulation
    code is unchanged, so I ran an interleaved A/B on the same machine (main = git archive of 1b3e055 under .tl/main):
      tour window frame p50: main 2.714 / 2.697 ms, blend 2.544 / 2.694 ms; gpu main 1.261 / 1.253, blend 1.193 /
      1.188; landscape build main 861 / 829 ms, blend 507 / 572 ms.
    Verdict: no frame-time cost; GPU and landscape build cheaper. NOTE: the perf run appended a line to the tracked
    perf/ledger.jsonl in this worktree (outside my scope): keep or drop it when landing.

DETERMINISM
  Landscape.build still returns early when headless, so no game simulation sees the landscape. Every pack hash in
  my 16-view captures equals the before capture (e.g. drive 9eed108e41702120, hockey 3b263b64a200cf2f, parkour
  b2eff3f37a317b68); world gate 8/8 world = alone; tour proof PASS. No game's state hash moved.
  What does move, and why it is right: the visitor's path wherever the ground changed (he walks the new
  heightfield), the drawn lift of seed_drive (rim -1.09 instead of +7.63: drawing only), and seeded scenery: the
  scatter rejects places by slope, so trees, rocks and the far mesas draw from the same seeded stream at other
  points (deterministic, same on every run; Astra kept the old random draw counts of removed passes so the stream
  shifts only through slope tests).

BEHAVIOUR CHANGES THE OWNER / DIRECTOR SHOULD KNOW
- The round fence walls are gone from the visitor's collider: he can walk onto a plot from any side, not only at
  the gate. Astra probed 576 crossings at 12 plots: 522 straight, 51 with a detour, 3 hockey approaches blocked
  by rails or pack geometry (he can back out 19 m). No trap found. (.tl/astra-r2/edge-crossings.txt in the worktree)
- Far mesas and some trees stand differently (see determinism).
- seed_drive sits level with the land now instead of in a bowl.
- How to look: tl play / world.sh visit on the exe village, walk off the road to any game; or the stills above.

NOT DONE / STILL VISIBLE
- A live construction site still draws its own round fence (site/draw.gd, the editor lane's scope); the ground
  around it now blends (Astra's still .tl/active-site/02_site_bays.png). That fence is the one circle left.
- ex_car's flat brown floor box (tour layout, plot at 148,64) now reads as a bare square slab on grass; it was
  inside the ring on main too (tour_overview_end_main_vs_blend.jpg). Pack content, not landscape.
- From above the hills still show the old triangle shading of the 3 m heightfield (pre-existing).

CHANGED FILES (all uncommitted in the worktree)
  engine/kernel/world/landscape.gd               footprints/axes into pads, rings/kerbs/fence loop removed, entrance
                                                 rails + colliders, random draws of removed passes kept
  engine/kernel/world/terrain/village_terrain.gd footprint grade `_grade_pads`, wear map, colours on workers,
                                                 village rim material (`_rim_material`, private)
  engine/kernel/world/terrain/village_parts.gd   edge geometry = rails and flags; lots without dirt discs; bank rocks
  engine/kernel/world/draw/draw.gd, draw_base.gd, draw_pictures.gd   dress pack ground sheets with the village rim
                                                 material (restored on unplace), soil-first rim height, rim_width
  engine/kernel/world/draw/view.gd, view_seam.gd footprints to the landscape, one rim band for draw and colliders,
                                                 rim cache key "|soil"
  engine/style/shaders/toon.gdshader             tl_land_* uniforms; branch only when tl_land_index matches
  engine/kernel/world/WORLD.md                   pads, rails, visitor walls, rim rules
  engine/tools/selftest.d/510-blend-footprint.sh, 511-blend-shoulder.sh   new
  perf/ledger.jsonl                              one quiet perf line (by tl perf run; see above)
  No kernel API change (TLStyle unchanged), no contract touched, site.gd and site/ untouched.

QUESTIONS FOR THE DIRECTOR
1. The site's round fence (site/draw.gd): ask the editor lane to let it follow the footprint, or drop it like the
   plots' fences? It is the remaining visible circle.
2. Plots are now open on all sides for the visitor (no fence wall). Keep (the design), or put walls back without
   drawing them?
3. Keep the perf ledger line from this worktree or drop it at landing?

NEXT THREE THINGS THIS LANE WOULD DO
1. With the editor lane: the site fence and ring follow the footprint (and the editor's own ring stays data-only).
2. Walk the exported exe village as a person (cooked package) at visitor height past every lot, and judge it.
3. Soften the 3 m heightfield's triangle shading on the graded shoulders (normals or a finer cell near pads).

Final: tl check --tier fast: PASS arch [12/12], assets [4/4], cards [3/3], devx.test [226/226], foreman.typecheck.

Lane folder: STANDUP.md, REPORT.txt, contact-before-after.jpg, sheet_before.jpg, sheet_after.jpg, before/, after/,
clip-blend.mp4, tour_overview_end_main_vs_blend.jpg, blend_views.walk.json, blend_clip.walk.json,
blend_clip.devices.json. Raw captures, Codex logs and briefs are under .tl/ in the worktree (codex-1.log, codex-2.log,
astra-r1.md, astra-r2.md, before/, r1/, r2/, tour-win/, tour-main/, ab-*/).
