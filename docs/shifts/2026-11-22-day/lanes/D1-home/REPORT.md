D1 home | day shift 2026-11-22 | tree .claude/worktrees/d22-home (branch d22-home) | Opus solo

All three rounds are landed on main: rounds 1+2 in merge efbf00f (commit 41d1a37), round 3 in merge 2fdaee0.

OUTCOME AGAINST THE ACCEPTANCE

1. Arm A in the normal World, the far plain gone: MET for the exe / boot.tscn World; see the note on world.sh.
   - What happens: landscape.gd `build` asks home/hook.gd `wanted(cfg)`. When it is on:
     - the far plain (village_parts far_ground) and the mesas and plain clumps are not made;
     - the forest belt keeps only the trees on the village's own ground;
     - after the village terrain and the visitor's space are built, and before the first draw, `Home.grow` draws arm A
       (places.gd `grow`, unchanged art) and hangs its colliders on the visitor's space.
   - The switch:
     - boot/village.json landscape.home = "wren" turns it on: the exe, boot.tscn, and the menu's World.
     - TL_HOME=plain gives the old landscape back.
     - TL_HOME=wren turns it on for any walk. That covers world.sh tour/visit of kernel/world/walks/*.json, which I did
       not edit (outside my claim). Without the variable, world.sh's walks keep the old landscape.
     - `tl play` has no world entry (devx/lib/commands/play.mjs plays packs only), so there is nothing to switch there.
     - Headless runs build no landscape at all (landscape.gd returns early), as before.
   - Stills (1920x1080, from boot.tscn windows, the visitor's own camera), in round-1/:
     - village_edge.jpg, with village_edge_old_landscape.jpg for comparison (same place, TL_HOME=plain);
     - bridge_deck.jpg, mill_green_look_back.jpg, flight_over_wren_water.jpg;
     - sheet.jpg puts four of them together.
   - Window clips in round-2/. Each is 20.0 s of game time at 60 fps (--fixed-fps 60, a scripted W+Shift hold, 960x540
     frames):
     - clip_gate_to_valley_20s.mp4: from (-391, 14), just outside the village's west edge (x -393), past arm A's lane
       gate into the valley toward the ford.
     - clip_across_bridge_20s.mp4: on the mill bridge from (-628, 109) to (-805, 81), over the whole of Wren Water.
     - Not met as asked: one 20 s clip from the gate across the bridge. The gate is about 430 m from the bridge's far
       end, so at run speed (9 m/s) the walk takes about 48 s. I split it into two real-time clips instead of speeding
       it up. Each clip has a contact sheet beside it.

2. Walkable: MET. Selftest block 751 runs kernel/world/home/walk_case.gd: the visitor's own body
   (world_space.gd `drive`), one step per physics frame, in the space landscape.gd builds for boot/village.json.
   - home.walk: from the village road (-200, 3) to Mill Green.
     - 518.4 m outside the village in 3457 frames, with 0 frames off the drawn ground.
     - At his centre he is never more than 0.000 m under the drawn ground, and under his sole he is never more than
       0.002 m above it.
     - "Drawn ground" here means the rendered valley triangles plus the lane and deck quads.
   - home.bridge: 817 frames over Wren Water, all on the deck. His feet stay at 1.30 m (the water is at -4.88 m).
   - home.drops: dropped from 25 m at five far places (Charcoal Green, Kite Down, x -2500, the Sisters, Perry Fair),
     he lands by frame 87 and stands for 120 frames without sinking. The worst is a slope at (1900, -2100): 0.118 m at
     his centre, because the capsule sits on its round bottom.
   - home.trees (round 3): he runs at five valley trunks, and each stops him at its radius + 0.35 m.
   - Controls:
     - TL_HOME=plain: "no Home" FAIL.
     - Trunk shapes left out: he walks into all five trees (closest 0.00 m), FAIL.
   - Two catches found on the way, both fixed:
     a. Ground triangles wound downward report a downward contact, so the body was "in the air" on them. Every face is
        now wound up, and steep faces (lane sides, rails) are added both ways.
     b. The lanes are drawn 0.22 m above the land. As bare sheets he wedged under their edge and stuck at (-475, 53).
        Their sides and ends now ramp down to the ground over 0.7 m (over the chalk verge where one is drawn). The
        deck has rails of 1.6 m instead.
   - How it is built:
     - Collider chunks of 96 m, world-anchored (68 x 68 over +-3264 m), made with N5's land/chunk_collider.gd `build`
       and `drop`.
     - Each chunk is the drawn triangles: the valley ground of ground.gd whose cell centre lies in the chunk, plus the
       lanes and the deck.
     - A 5 x 5 block is kept round the visitor, and chunks beyond 3 are dropped. The stream runs from
       world_space.ensure_land, chained after the village land's own.
     - The chunks are tagged "home ground" and counted under the stat home_faces, so the village's terrain bodies and
       face totals are what they were (land.colliders).
     - Mill check (a probe outside the tree): run at the hall from the west, he stopped at the stone base, 7 m from its
       centre, with last_hit "home solid".
     - Round 3 adds the valley's trees as 4 m trunk cylinders on their chunk's body (1016 made over the selftest
       route), plus the mill's stone base, hall and porch as boxes.

3. World = alone holds: MET.
   - tl check --tier full: world [8/8], hash table identical to main's (drive a2940a17@3441, wall 5896844e@1221,
     paddle dff1a390@4486, walker f1c7b537@371, kit ca698e71@332, car 3a459d0f@1872, hockey ecd7591b@6738,
     parkour f7abac00@988).
   - Arm A touches no pack. Only the visitor's own physics space gets bodies.

4. Frame cost, read honestly: MEASURED on a BUSY machine (CPU 19-100 % around the runs, 0-3 other Godot processes).
   Source: round-3/frame_cost.jsonl.
   - Method: 3 + 3 interleaved windows of boot.tscn at 1920x1080 (Home, then TL_HOME=plain).
     - The visitor starts at (-391, 14) and runs W+Shift for physics frames 300-1500.
     - TL_EXE_FRAMES_TIMES=1 (new, boot/frames.gd) logs each drawn frame with vsync off and no picture, so the
       intervals are what a frame costs. They are draw intervals, not physics frames.
     - Caveat: in the old landscape the same keys walk him onto the far plain, so the walk scenes differ.
   - Medians (ranges):
     - landscape build: Home 1596 ms (1503-1645) vs old 613 ms (493-835): about +0.95 s. Home.grow itself takes
       946-1038 ms.
     - first drawn frame since process start: Home 5069 ms (4093-5458) vs old 3489 ms (2998-7944). This is noisy on a
       busy machine, and the build difference above is the honest part.
     - walking frame p50: Home 1.53 ms (1.51-1.63) vs old 1.11 ms (0.83-1.28).
     - walking frame p99: Home 9.25 ms (6.57-9.32) vs old 7.00 ms (6.01-10.04).
     - GPU p50: Home 1.43 ms vs old 0.51 ms.
   - Collider streaming: 205 chunks made and 180 dropped over the whole selftest route, 26-28 ms in total (headless).
   - Arm A's own night figures (first draw +1.4 s, flight p50 5 ms) were measured in its own tour viewer and are not
     comparable.

5. Gates: see GATES below.

CHUNKS AND tl.land/1 (proposal; contracts not edited): round-3/land_proposal.txt
The Home cannot be written as tl.land/1 records cheaply, for three reasons:
- its lattice origin is world-anchored (-3264, -3264), not the village's low corner (-393, -330);
- it draws 12 m and 48 m cells, not 3 m cells;
- its palette has 3 more surfaces than ids 1-5.
The proposal:
- a list of lands, each with its own base and origin;
- base kind "wren";
- an edited chunk is re-meshed at 3 m with split "fixed" (N5's HeightMapShape3D path), and an unedited chunk stays coarse;
- material ids 6 grass_dark, 7 grass_dry, 8 stone.
Heights (-128 m, 0.01 m) and water groups fit as written. Arm A's own export (valley.gd `chunk`, proposal_version 1)
is unchanged; home.a.chunk still checks it.

GATES
Round 1+2 (tree at 41d1a37, 13:12-14:39, busy):
- fast: arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck: PASS (also after the land fix).
- full, PASS: world [8/8] = alone, kit 120/120, seeds 39/39, item 91/91, ui 201/201, foreman.test 290 (284 pass,
  6 skip), perf 2/2 (quiet).
- full, kernel.selftest: cut at the 1800 s cap (215/216 units, 0 failed), which is a stopped run. The uncapped suite run
  beside it gave 487 PASS, 1 FAIL: land.colliders, caused by my Home chunks being tagged "terrain". After the fix,
  land. 7/7 and home. 8/8 = 488 (main's 480 + 8).
- full, packs: FAIL only on hockey invariants.many_budget, a wall-clock budget: p50 1.004 ms, then 1.152 ms re-run
  alone, busy. The Director accepted it as busy-only.
Round 3 (tree at efbf00f + round 3, 14:53-16:13, busy):
- full, PASS: arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck, foreman.test 307 (301 pass,
  6 skip), kit 120/120, seeds 39/39, item 91/91, ui 201/201, world [8/8] = alone (same hash table).
- kernel.selftest: cut at the cap (101/102 units, 0 failed). Uncapped: 489 passed, 0 failed (.tl/d1/selftest-r3.log),
  including home.walk, home.bridge, home.trees and home.drops, and land. 7/7.
- packs: FAIL only on hockey many_budget, p50 1.117 ms (busy).
- perf: NOT RUN (machine busy, 68 %).
- The full tier is therefore not green as the gate prints it. Every red line is a wall-clock check on a busy machine
  or the cap, and the uncapped suite is complete.

CHANGED FILES
Round 1+2 (landed, 41d1a37):
- engine/kernel/world/home/: arm A's files, plus hook.gd and walk_case.gd.
- engine/kernel/world/landscape.gd: +5 lines, 592 in total.
- engine/kernel/world/land/chunk_collider.gd: optional tag and stat arguments; the defaults are unchanged.
- engine/kernel/world/home/places.gd: lane, deck and rail faces for the visitor.
- engine/boot/village.json: landscape.home "wren".
- engine/boot/boot.gd: TL_EXE_START=x,z,x2,z2, a test instrument for the start position and facing; 595 lines.
- engine/tools/selftest.d/750-home-a.sh (arm A) and 751-home-walk.sh.
Round 3 (landed, merge 2fdaee0):
- home/places.gd and home/landmarks.gd: trunks and solids recorded.
- home/hook.gd: trunks on their chunk body, mill boxes.
- home/walk_case.gd and selftest.d/751-home-walk.sh: home.trees.
- boot/frames.gd: TL_EXE_FRAMES_TIMES.

BEHAVIOUR CHANGES
- The World shows Wren Valley instead of the far plain and mesas, and the visitor can walk and fly out over it.
- The belt trees beyond the village ground are gone; the valley's own woods replace them.
- First load is about 1 s longer.
- Expectations that moved: none. The uncapped kernel suite rose from 480 to 488 (750: 5, 751: 3), and to 489 with
  home.trees.

FOR THE OWNER TO LOOK AT, AND HOW
- Start the World one of two ways:
  - the exported game: ThirdLife.exe (after `bash engine/tools/export.sh`), then choose World in the menu;
  - from the repository: the Godot console exe with `--path engine res://boot/boot.tscn`, then choose World.
  `tl play` has no World entry: it plays a single pack.
- Where to go:
  - You start on the village road facing east into the village. Turn round to face west, and walk or run (Shift) along the road past the
    parkour course and over the village's small bridge.
  - The village ends at about x -393. Arm A's lane gate is just beyond, at x -404.
  - The lane runs to the ford, then over the long mill bridge (about 250 m further) to Mill Green and the waterwheel.
  - F flies (Space up, C down) to see the whole valley, the ridge (Bell Scar) and the far peaks.
  - Trees and the mill now stop you. The other valley buildings and fences do not yet.
- To compare with the old landscape, start the same way with the environment variable TL_HOME=plain: the far plain
  and its mesas come back.
- What to judge: the look at walking height, the first load (about 1 s longer: outcome 4 above), and whether the valley reads as
  Home.

PRE-EXISTING FINDING (on main too, out of scope)
- A pink patch at the village's west road end (about x -295, z 9). It is seen in a TL_HOME=plain run of the same code
  main runs, and one corner still shows beside arm A's lane.
- Stills: findings/pink_patch_x-295_old_landscape.jpg and findings/pink_patch_x-295_home.jpg.

NOT DONE / KNOWN
- The visitor still passes through the valley's other kit parts (houses at Perry Fair, the watch tower, portals, fences,
  stalls, flags). Only trees and the mill have colliders.
- The packs step failed twice on hockey invariants.many_budget, a wall-clock check on a busy machine (p50 1.004 and
  1.152 ms against 1.0). The Director accepted it as busy-only, and it will be re-read on a quiet machine.
- Exit leak warnings in window runs (17 boot.tscn windows):
  - "5 ObjectDB instances were leaked at exit" in s1 (Home);
  - "2 ObjectDB instances" in m/home-1 and m/home-2 (Home);
  - in s2p (TL_HOME=plain, the old landscape) RID leaks after a segfault at teardown (rc 139), after its picture was
    written, while the fast gate ran beside it.
  16 of the 17 runs exited 0.
  - A --verbose Home run after the round-3 gates (leak2, a walk into the valley) leaked nothing, so the leak is intermittent. Its
    source is untraced (one candidate: the hook's closure on world_space.ensure_land outliving the space at exit).
  - Logs: .tl/d1/*/window.log.

QUESTIONS FOR THE DIRECTOR
1. Contract question, tl.land/1 for the Home (contracts/LAND.md is yours): decide items 1-4 of
   round-3/land_proposal.txt (summarised under CHUNKS AND tl.land/1 above).
2. Should world.sh's walks (kernel/world/walks/compact_village.json, tour.json) get landscape.home "wren" too? They
   are outside my claim.
3. The lanes float 0.22 m because of arm A's art. Would you rather lower them to about 0.05 m? That would need no
   ramps, but it is a visible change.

NEXT THREE THINGS THIS LANE WOULD DO
1. Colliders for the rest of arm A's kit parts (houses, tower, portals, stalls), the way they were done for the mill.
2. Cut the first-load cost: build the far half of the valley ground (48 m cells) on a worker after the first draw, as
   landscape.gd already does for the edges.
3. Answer tl.land/1 once decided: make valley.gd `chunk` emit tl.land/1, and round-trip it in home.a.chunk.
