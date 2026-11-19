Lane blend, round 2 (day of 19 Nov, about 11:40-14:30)
Worktree .claude/worktrees/d19-blend2, branch d19-blend2 from main a68ef16 (with editor placement and flight).
Nothing committed. Route: Opus directing Astra (gpt-6.2-astra, high), new Codex session
01a1f38e-acbe-7933-ad1d-9379dbfb6586: round 3 = 545,669 tokens; round 4 (resumed by session id) = 606,984 tokens as
printed by codex at the end of that run (a resumed run's figure includes the session's earlier context; the
morning's round 2 was printed the same way). Lane total today as printed: 254,091 + 584,113 + 545,669 + 606,984.

OUTCOME, per item of the Director's round-2 brief
1. Triangle shading of the 3 m heightfield: FIXED, toon look kept.
   Astra traced the light/dark triangles not to the geometry but to the shader's value noise: a shared corner of two
   noise cells was hashed from each cell's own float coordinates and came out different (D3D12 rounding), so the
   painted tone jumped along cell edges. Fix: an integer corner hash in a village-only variant of the toon shader
   (`#define TL_VILLAGE` prepended to the palette shader by village_terrain.gd; a pack drawn alone compiles the
   unchanged shader). Road wear and meadow colour are painted into the terrain's own vertices instead of layered
   strips/patch meshes. Bands, hatching, grass marks and inked crests stay (walker 8/8 incl. style.walker.ink).
   Stills: round2/facets_main_vs_round2.jpg (wall from above, bluff lot from the road), round2/crane_before_after.jpg
   (8 lots, road + above), round2/flight_main_vs_round2.jpg (from 20-25 m in flight).
   Check 512-blend-pigment.sh (windowed capture of level grass, measured headless): 99.9th-percentile tone jump
   17.58/255 on main -> 7.42/255 (limit 12) with the broad tone span kept (53.80 -> 53.64, min 30).
2. A person walks the village (windowed, all 10 lots, take-off with F from the road, fly over at 20-25 m):
   10 scripted visits per version (round2/walks/: one walk per lot from boot/village.json, devices.json, runvisits.sh,
   lotsheet.sh). Sheets: round2/visits_before.jpg (main a68ef16) and round2/visits_after.jpg (final code), one row per
   lot: walk in, at the edge, along the edge, in the air over the road, air approach.
   My judgement, lot by lot (final code):
   - walker, paddle, drive, wall, parkour, kit: no seam, no circle, no floating prop from road, edge or air; the
     ground reads as one painted field; rails and the one sign/pennant at the entrance read fine from the air.
   - car: as on main (plain grass with the car and cones; see the finding below).
   - hockey: transition fine; the arena wall is pack content and dominates from the road.
   - both construction sites: the ground blends, but their own ROUND FENCE still draws a circle from the air
     (site/draw.gd: editor lane, as you assigned).
   What still draws the eye is pack content: kit's three bare strips, walker's long white strip, hockey's closed-looking
   gateway (Astra's list in .tl/codex-3.log; outside this scope).
   Clip: clip-blend2.mp4 (16.5 s, windowed, drive lot: walk off the road, along the edge, take off, fly over the track).
3. ex_car's brown floor slab: the village frames it only where main already draws it. Round 3 at first revealed the
   floor box in the real village too (an 80 m flat dark slab where main shows grass; round2/car_round3_regression_sent_back.jpg).
   I judged that worse than main and sent Astra back (round 4): main's plot cut by origin is restored, and the grass
   verge applies only to the floor in a distant merged picture (the tour layout, plot at 148,64), where the slab now
   has a softened grass edge. The village car lot matches main (round2/car_main_vs_round2.jpg).
   Check 513-blend-car-origin.sh: live view grass 99.8 % (main 99.7, round 3 0.0), distant picture asphalt 100 %.
   Open question for you: should a pack mesh whose origin is outside its plot but whose box reaches in (ex_car's
   asphalt) be drawn in the world at all? Today it is not (main), so ex_car's course is missing in the village.

GATES (final code, this worktree)
  tl check --tier full (13:05-13:37, one run): PASS arch [12/12], assets [4/4], cards [3/3], devx.test [229/229],
    foreman.typecheck, foreman.test [219/219], kit.selftest [92/92], packs [2/2] (44 of 44 verb runs), perf [2/2]
    (mix30, pile600 within tolerance, machine quiet), seeds [39/39], item.selftest [91/91], ui.selftest [160/160],
    world [8/8] (world = alone); FAIL kernel.selftest [293/293]: 286 passed, 7 failed = all 7 cases of
    flight_case.gd (one process; one subcase fails, the six others are reported with it).
    Counts vs main (gate trend): kernel 293 found (main 291, + blend.pigment, blend.car_origin), kit 92 = 92,
    devx 229 = 229, seeds 39, world 8, packs 2.
  THE KERNEL FAIL IS ON MAIN TOO, not this round's: the failing subcase is flight.collide ("trunk=-inf"). It aims at a
    hard-coded tree, kernel/runner/flight_case.gd:246 "the seed-7 tree east of the car plot" at (256.27, 50.86). This
    lane's round 1 (on main since a68ef16) reshaped the slopes, so the seeded scatter puts that tree elsewhere. Flight was
    written before blend landed; the two met on main. The same 7 cases fail identically on an engine archive of
    a68ef16 (the archive also fails pose/wings: it has no assets/, so I used only the 7 shared results). Suggested fix (flight lane's
    file, not in my scope): take the tree from the landscape's probe (`land.get_meta(&"tl_probe")["tree"]` = [x, z,
    radius] of the first tree on gentle ground 10 m from a road), which follows the scatter.
  Focused: selftest blend. 4/4 (footprint, shoulder 0.614 m, pigment 7.42/255, car_origin 99.8 %); walker 8/8
    (Astra; style.walker.ink included); ground 10/10 (Astra).
  world.sh tour tour --out-dir (window): PASS world.tour; world.sh tour tour --headless: PASS world.tour.
  Determinism: all 8 pack hashes of the 16-view crane walk equal main a68ef16's run of the same walk (parkour
    203ed385383ebab6 differs from this morning's b2eff3f37a317b68 on main too: today's parkour commit 01d5871). No
    game hash moved. Seeded scatter counts unchanged (Astra: 384 trees, 46 rocks, 160 bushes both).
  Perf: the gate's perf step PASS (quiet). Interleaved A/B on the same machine, stock tour in a window, main archive vs
    this worktree: frame p50 main 2.235 / 2.481 ms, round 2 2.309 / 2.352 ms; gpu 1.193 / 1.198 vs 1.217 / 1.212 ms
    (+0.02 ms: the village shader variant); landscape build 504 / 598 vs 464 / 518 ms. No measurable frame cost.
  One-off: one windowed car visit (round 3 code) ended with exit 139 at shutdown, after all its output; not reproduced
    in 9 reruns of car on rounds 3-4 nor in about 70 other visits today. Reported, not explained.

CHANGED FILES (uncommitted)
  engine/style/shaders/toon.gdshader             TL_VILLAGE-only: integer noise corners; verge for a floor in a
                                                 distant picture; everything else as main
  engine/kernel/world/terrain/village_terrain.gd village shader variant + material; meadow and entrance wear painted
                                                 into the terrain vertices
  engine/kernel/world/landscape.gd, terrain/village_parts.gd   road/patch strips replaced by painted wear (random draws
                                                 of the removed passes kept); shorter entrance rails + colliders, one
                                                 sign and pennant at the turn
  engine/kernel/world/draw/draw_base.gd          floor-box verge material for a merged distant picture only
  engine/kernel/world/WORLD.md                   how village ground and entrances are drawn
  engine/tools/selftest.d/512-blend-pigment.sh, 513-blend-car-origin.sh   new (windowed capture + headless measure,
                                                 like 430-walker-ink)
  No public API change (tl_style.gd untouched; arch 12/12), no contract, nothing in site.gd / site/ / packs.

QUESTIONS FOR THE DIRECTOR
1. flight.collide on main: hand the probe-based fix to the flight lane (or allow me to touch flight_case.gd)?
2. ex_car's course is not drawn in the village (main's origin cut). Draw reaching floor boxes in the world (as alone),
   or keep them hidden? If drawn, the floor needs the pack's own course look, not a bare slab.
3. The construction sites' round fence (site/draw.gd) is the last circle from the air.

NEXT THREE THINGS THIS LANE WOULD DO
1. With the flight lane: the probe-based tree in flight_case.gd, so world changes cannot break it again.
2. With the editor lane: the site fence follows the footprint.
3. Pack-side asks for the owner's eye (not landscape): kit's strips, hockey's closed-looking gateway, car's course.

LANE FOLDER (round 2): REPORT-round2.txt, STANDUP.md, clip-blend2.mp4, round2/ (visits_before.jpg, visits_after.jpg,
crane_before_after.jpg, facets_main_vs_round2.jpg, flight_main_vs_round2.jpg, car_main_vs_round2.jpg,
car_round3_regression_sent_back.jpg, walks/). Raw captures, Codex logs (codex-3.log, codex-4.log), briefs
(astra-r3.md, astra-r4.md) and the main archive are under .tl/ in the worktree.
