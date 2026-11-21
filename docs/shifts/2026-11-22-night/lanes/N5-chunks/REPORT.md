N5 world-chunks: REPORT (shift 2026-11-22-night, worktree .claude/worktrees/n22-chunks, branch n22-chunks, uncommitted)

WHAT WAS BUILT (TWO-WORLDS order of work, item 3)
The village's land is cut into 96 x 96 m chunks (32 x 32 cells of 3 m), each with a tl.land/1 record. A record is a sparse
delta over the procedural base: u16 heights, a material id per cell and water levels. The base is today's VillageTerrain
after build_grid. Chunk meshes and colliders are built per chunk. The ring code (near / mid / far) and the per-frame build
budget are present and tested. Ledger is on. Today's two villages are the base plus nothing. Each has fewer than 100
chunks, so it is "everything near": every chunk is built at load, as before, and nothing streams during a run.
Route: Opus director, Astra built 2 rounds (r1 210,355 tokens, r2 180,251 tokens = 390,606 of the 0.8 M budget).

ACCEPTANCE
1. world 8/8 = alone, every hash equal to main: MET. tl check --tier full --only world, before and after:
   PASS [8/8]. The pack | ticks | hash table is identical line for line (seed.drive a2940a17@3441 ... game.parkour
   f7abac00@988).
2. Tours headless and in a window PASS, pictures compared to main: MET.
   - Window: world.sh tour tour --load=block, before x2, after x4: PASS every time. All 6 packs: tour = alone = replay,
     with the same hashes as before (drive 6a39e6ce, wall 3d576663, ...). The visitor's path is the same: blocked 0,
     end [126.0, 6.48, -36.0].
   - Headless: world.sh tour tour --headless PASS. Its table is identical to the pristine engine's.
   - Pictures (10 tour + 3 tour_views): within the noise floor by count. Worst px>8: 0.18 % (01) and 0.28 % (08). The
     floor of two runs of the same engine is up to 0.26 % / 0.31 %. Stage-camera shot 05 is bit-identical.
   - A small deterministic residual remains on the visitor-camera shots (07: 0.044 % px>8; bit-identical within each
     side). Traced:
     - It is not drift: the pristine engine re-run at 21:00 reproduces its own 19:15 pictures bit for bit.
     - It is not shadow-cascade fitting: a run with every chunk given the whole land's AABB is unchanged.
     - It is not the cel distant AA: a run of a style without it is unchanged.
     - It is not the drawing: one mesh drawn through the new path is unchanged.
     - It IS the visitor's body. On 56 chunk collider shapes his scripted walk differs from one trimesh of the same
       triangles from tick 0, by at most 1.43 mm. Jolt compresses a mesh shape's vertices against its bounds: rays meet
       the chunks within 0.048 mm of the drawn ground, the old single shape within 0.288 mm. So the chase camera moves
       by a hair.
   - Sheet: docs/shifts/2026-11-22-night/lanes/N5-chunks/before-after-sheet.jpg (before | after | diff > 2 levels).
3. Block 740 (engine/tools/selftest.d/740-land.sh, runner land/land_case.gd): MET, 7/7. Deliberate breaks: Astra reported
   each of the first six FAILing on one (then undone); I broke land.ledger myself (backdrop_m 0: FAIL), restored: PASS.
   - land.same_mesh: both villages' chunk meshes equal the single mesh in every vertex channel and triangle; the
     tree-shade map is the same bytes.
   - land.seams: no cracks; shared border positions and normals are exactly equal; a mid-LOD chunk's skirt reaches below
     its near neighbour's border.
   - land.colliders: 119 terrain bodies, one per near chunk. Face totals are equal, and 2,000 seeded rays per village hit
     where the old trimesh hit, at gy within 1 mm, and miss where it missed. The reference's plot-hole rule is now
     written independently in the test (it was circular in r1).
   - land.heightmap: fixed-split land with Jolt HeightMapShape3D; rays within 1 mm; a NaN hole misses.
   - land.record: byte round trip, sparse edits, paint, water, seam disagreement refused; unknown key, null, bad q,
     schema and base each refused.
   - land.rings: 20 x 20 chunks, budget 2, nearest first, hysteresis, the forced 3 x 3 under the focus, an identical
     replay; an all-near land never changes.
   - land.ledger: tiers.json as shipped (no override). The game is unloaded beyond backdrop_m + 40. Its record is
     unchanged while it is away. It is rebuilt with the same ticks (119) and score ({"bin":4}). Its round's clock starts
     again from the seed, as TIERS.md documents for a world file.
4. Load time and frame cost compared to main: MET.
   - Headless landscape build, pristine engine vs this one, 5 interleaved runs each, busy machine, medians:
     exe village 940 -> 622 ms, tour 750 -> 548 ms. Faster in all 10 pairs.
   - Round 1 was slower (1081 -> 1356); round 2 fixed it:
     - one worker group prepares the chunks' mesh arrays and collider faces;
     - rows are copied as slices;
     - the scatter's terrain queries are typed calls (same functions, same values).
   - Window: 34 to 52 more draw calls per picture (181 -> 233 at the first). 27 to 38 % fewer primitives: chunks
     outside the camera and the shadow cascades are culled. Frame p50 3.2-3.6 ms after vs 2.6-3.0 ms before, measured
     at different hours of a busy machine: not evidence. tl perf was NOT RUN (busy).
5. WORLD.md "Chunks" section: MET (engine/kernel/world/WORLD.md, before "The visitor's body").

DECISION THE DIRECTOR SHOULD KNOW: village colliders are exact faces, not HeightMapShape3D
Godot's Jolt height field splits every quad on the anti-diagonal (x+1, z)-(x, z+1). The village mesh alternates its
diagonals. Measured on the exe village, a height field would sit more than 10 cm off the drawn ground on 3,407 walkable
cells (max 1.1 m). So each chunk is one ConcavePolygonShape3D of exactly the drawn triangles. The HeightMapShape3D path
is built and tested for land drawn with split "fixed" (the Home growing outward, item 5). Switching the village to it
means re-triangulating the drawn ground: a visible change, the owner's call.

GATES (all run by me, after round 2)
- tl check --tier full (21:39-22:38, busy):
  - PASS: world [8/8], kit 115/115, seeds 39/39, item 91/91, ui 201/201, foreman 261/261, assets, cards, typecheck.
  - kernel.selftest was killed at the 1800 s cap after 121/122 blocks, 0 failed. The uncapped suite then gave
    421 passed, 0 failed (35 min; 7 of them block 740).
  - packs 1/2: hockey invariants.many_budget, a frame-time budget (p50 1.189 ms vs 1.0). Re-run alone: PASS [2/2],
    74/74 verb runs.
  - perf NOT RUN (machine busy).
  - arch FAIL and devx.test 227/229: both only schema-versions for tl.land/1 (below).
- Subsets after round 2: land 7/7, site 25/25, harden 15/15, walk 24/24, ground 10/10.
- tl check --tier fast: arch FAIL (schema-versions: tl.land/1 declared in no contracts/ doc) and devx.test 227/229 (the
  two tests that run arch on the real tree). Everything else PASS. Checked in-process: with the PATCHES.md section 1
  text as a virtual contracts/LAND.md the finding goes, and only the six grandfathered world schemas remain
  (.tl/archcheck.mjs).

CHANGED FILES
- new engine/kernel/world/land/:
  - land.gd: chunk table, records, rings, stream, ensure_safe.
  - land_record.gd: the tl.land/1 codec.
  - chunk_mesh.gd, chunk_collider.gd.
  - land_case.gd, synthetic_cases.gd, reference_mesh.gd: the test oracle.
  - ledger_walk.json, fixtures/edit.json, and .uid files.
- new engine/tools/selftest.d/740-land.sh
- engine/kernel/world/landscape.gd: records after build_grid, chunk meshes, chunk colliders, stats["land"], arrive
  steps the stream (587 lines).
- engine/kernel/world/terrain/:
  - village_terrain.gd: the mesh code moved to land/; the diagonal rule knows fixed chunks.
  - tree_shade.gd: works with the chunked node.
  - world_space.gd: _static returns the body; ensure_land hook, used only by a streaming land.
  - harden_walks.gd: _build_village returns stats; plot-ground option for the test.
- engine/kernel/world/tiers.json: backdrop_m 0 -> 960, and its note.
- engine/kernel/world/tiers.gd: +3 lines. Outside my column but needed by item 3; see PATCHES 3.
- engine/kernel/world/WORLD.md: the Chunks section.
- docs/shifts/2026-11-22-night/lanes/N5-chunks/: STANDUP.md, PATCHES.md, REPORT.txt, before-after-sheet.jpg.

BEHAVIOUR CHANGES
- Ledger is on at 960 m. No walk of today reaches it: the farthest plot edge is heavy.json's 880 m, proof.json's 580 m.
  So nothing changed in any tour, proof or gate.
- A held construction-site plot is capped at backdrop. That is exactly what it got before; without the cap,
  site.arrived_yaw_entry went red with ledger on.
- The visitor's contact with the land is now 6x more precise (0.05 vs 0.29 mm max ray error). His feet move by at most
  1.4 mm against before.
- Nothing a pack sees changed: no hash moved anywhere.

QUESTIONS FOR THE DIRECTOR
1. Land the tl.land/1 contract (PATCHES.md section 1, proposed as contracts/LAND.md); the fast gate needs it.
   Alternatively grandfather it with the other world schemas, but devx.test then wants it documented.
2. Is 960 m the ledger distance the owner wants? Nothing reaches it today. The mid ring (about 600 m) is the other
   natural choice once the Home has more venues than a 1/16 slice carries.
3. TIERS.md still says backdrop_m 0 (PATCHES.md section 4 has the line).

HOW THE OWNER SEES IT
Nothing should look different; that is the point. Use world.sh tour tour --out-dir=<dir> (or the exe's village) and
compare with the sheet. The proof that it is chunked is in the scene: TLLandscape/WorldTerrain holds the
WorldTerrain_<cx>_<cz> meshes.

NEXT THREE THINGS THIS LANE WOULD DO
1. The exe saves the land (item 4 prerequisite): Land.records() written next to the world file, loaded through
   landscape.land.records; plus a sculpt / paint brush in the Designer that writes a delta record.
2. The Home grows (item 5): a "plain" base beyond the village, drawn with split "fixed" so HeightMapShape3D colliders
   apply. Let the 100-chunk all-near threshold fall away so the near/mid rings stream for real. Then a far impostor
   (not built tonight).
3. Measure the windowed stream: walk a 20 x 20-chunk land in a window with budget 2, and report hitches, the forced
   count and frame p99 under a quiet `tl perf run --quiet-only`.
