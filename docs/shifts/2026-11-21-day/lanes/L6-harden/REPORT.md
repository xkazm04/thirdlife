L6 crisp-harden: REPORT (day of 21 Nov 2026)
Worktree .claude/worktrees/n21d-harden, branch n21d-harden, base main df58f0b. Nothing committed (the Director lands).
Owner's words: "Crisp looks well, continue with open items during this day to harden."

SUMMARY
The five open items are done. Each fix has a case in a new selftest block, 700-harden-day.sh, with 6 cases. Each case
fails on the base.
1. Road edges. Scatter objects are kept off the road and off crisp's rails by an exact distance. Roadside bushes that
   leaned onto the road are moved behind the rails. Grass on the road is left out.
2. A kit-wide check: every part's collider top must match its mesh top, straight and turned. barricade, cabin, house,
   timber_frame and marshal_post now have bodies built from their pieces.
3. The site fixtures have an owner table (fixtures/README.md) and a guard case. None was unused, so none was removed.
4. Block 502's flake is found and fixed. The fixture counted frames while the site's worker thread built meshes. It
   now waits for the meshes themselves.
5. I walked the village as a person. Two new defects turned up and are fixed: plain-lot props you could walk through
   or were held off, and rock bodies that were 1.4 m pillars.
The world hashes the same as each game alone (8/8) under crisp and classic (gate lines below). One pack hash moves:
seed.wall, because its balls meet the new barricade and cabin bodies. Five kit hashes move; the manifest is
re-scanned in this tree.

ACCEPTANCE
1. Every fix has a case in block 700 that fails on the base. MET.
   Base = a clean `git archive df58f0b` export with only the case scripts added. Where the fix is the colliders, the
   base's colliders are put back into the branch (named below). Base results:
   - harden.road_edge: FAIL. 46 findings in the exe's village under crisp (meshes and bodies on a road or across its
     rails), 36 in wf_feel, 19 under classic.
     Example: "WorldRoadBushes at (266.1, 7.7) 2.10 m onto the main road (0.65 m onto it)".
     wf_feel: "WorldBushes at (-215.5, 1.0) 3.23 m". This is the bush the night's L1 made walk-through; it was still
     drawn on the road.
   - harden.kit_tops: FAIL on house (its mesh over its body in 75% of columns), timber_frame (88%), barricade
     (phantom 8%), cabin (phantom 78%, 3.37 m over the step), marshal_post (phantom 29%).
   - harden.site_waits: FAIL. editor_yaw and no_ring did not finish in 120 frames.
   - harden.site_fixtures: FAIL, 11 of 11 ("no row in fixtures/README.md").
   - harden.lot_props: FAIL, 73 of 82 walks in wf_feel and 70 of 79 in tour. Base colliders with the new meta: the
     crane's 4 m box inside its 5.2 m base; no body for pallets, barricades, cones or the second timber stack; the
     scaffold box 0.65 m off.
   - harden.rock_tops: FAIL, 44 of 60 rocks of the exe's village, e.g. "body's top 1.15 m, the rock's 0.26 m".
   Branch: block 700 6/6 PASS. Block 620 (last night's) 9/9 PASS. selftest `harden.` 15/15.
2. world 8/8 = alone under crisp AND classic. See GATES.
3. The kit selftest is green; the kernel blocks I touch are green. See GATES.
4. A clip of the walk, 20 s or less. MET.
   clip-harden-day.mp4 is 18.5 s, 1280x720, with clip-harden-day-strip.jpg. It was made in a window, crisp, the
   wf_feel village, with scripted keys (clip.sh plus the road_clip / lot_clip walk and devices files).
   (a) 5.5 s: he walks west along the road's south edge to where a bush stood 1.8 m onto the road (base). He turns
       into the rails: the rails stop him, and the bush now stands behind them.
   (b) 13 s:
       - he walks into the plain lot's barricade and is held at its boards;
       - he slides off its end and passes the cones;
       - he runs past the scaffold and into the pallets of concrete blocks, which hold him.
5. Kit hashes moved, with the expected manifest rows. MET. assets/manifest.json is re-scanned in this tree only
   (`tl assets scan`). Exactly these 5 rows change; the other 31 equal the base:
     kit.barricade     a2e8dd0f218c31c3356a126458252a1b32deeb9a -> 4f35749c7c076c70e8abb13950aa9f4381320741
     kit.cabin         718f2fe413268d5eaeccb5ce8c7363814c025f73 -> 1672a2180e121b100c8cc1c32a62773d6bda62dc
     kit.house         9d373d9755273f06e0af4e2602bc4adc5b8d31e8 -> bd358b6c7a0f5a2467f22d8c02ab255f4fee8dad
     kit.marshal_post  ea1c6f2b30fe9cbb43ba03629ed9540af11b3f26 -> e3bfef3151ff41adef5df0dafde6a1f4317bf7c3
     kit.timber_frame  ddfeedefde89d0c720c2dc9ad3c8808c0478fe7b -> 59e56aebee119c38e45e5261912eba0c80a20ca7
   If main's manifest moved since df58f0b, re-scan on the merged tree (these five move by this lane).

THE ITEMS, ONE BY ONE
1. Road edges (kernel/world/terrain/road_clear.gd, new; landscape.gd)
   - The cause: the scatter measures road clearance with terrain `road_dist`. That is the nearest 3 m grid vertex's
     distance to the nearest 2 m sample, so it can be up to about 2 m wrong.
   - Measured on the base, by mesh foot. Trees, rocks and pad rocks never reached a road in the exe's or the wf_feel
     village; the brief's premise holds only for bushes and grass. Roadside bushes: 4 on the road and 14 across the
     verge or rails (exe), 2 and 8 (wf_feel). Tufts on the road: 15 (exe) and 18 (wf_feel). One scatter bush stood
     1.8 m onto the road (wf_feel).
   - The fix: `keep_off` runs after each kind is placed (pines, broadleaf, rocks, bushes, pad rocks, roadside trees
     and bushes, tufts). It takes the exact distance to each road's line (main road and spurs, each by its own half
     width) against the instance's foot. The foot is the mesh's widest point under 1.2 m, or the collider's radius
     when that is wider.
     - A solid thing must stay off the road. Under a look with rails it must also stay off the main road's verge and
       rails (rails + 0.15 m). If it does not, it is moved straight out, at most 3.5 m, on the land as it stood.
     - Grass on the road is left out.
     - It draws no random numbers, so every other object stands where it stood. Verified by dumping every instance
       position, base against branch:
       - crisp, exe's village: 18 roadside bushes moved, 15 tufts gone;
       - crisp, wf_feel: 10 roadside bushes and 1 bush moved, 18 tufts gone;
       - classic, exe's village: 4 roadside bushes moved, 15 tufts gone;
       - nothing else changed.
   - Walked in a window: clip part (a).
2. Kit collider top = mesh top (kernel/world/terrain/kit_tops_case.gd, new; kits/part_bodies.gd, new;
   kits/tl_kit_parts.gd)
   - The case covers every part from TLKit.list() plus 3 larger variants, straight and turned 30 degrees.
     - Rays go straight down on a grid. Each column compares the drawn mesh with the static bodies.
     - A difference counts only where every column within 0.125 m also differs: what a 0.25 m foot, or a thing
       stacked on the part, would meet. This is the "stacked" meaning. Cracks between planks do not count.
     - Tolerance 0.12 m; a part may differ in at most 3% of its columns.
     - Allowed by name, with why: arch_rib, crane, tree and light_mast (out-of-reach pieces are not solid); entrance
       (the lintel over its walkable opening); goal (see QUESTIONS).
   - New bodies, numbers taken from their generators:
     - barricade: boards plus a hull for each A-frame. A ball rolls under the boards between the legs.
     - cabin: skids, box to the roof at 2.89 m, roof unit and step. The old box stood over the step up to 3.37 m.
     - house: footing, walls, the gable roof as one hull, ridge, chimney, and the porch slab, step, posts and roof.
       The old body was a box to mid-roof.
     - timber_frame: footing, floor, 8 posts and the top beams. The old body was four posts: he walked into the 0.7 m
       footing.
     - marshal_post: the roof is a sloped hull, as drawn.
   - part_bodies.gd is internal and not API: TLKitParts reads it through a private const. A first version as
     tl_kit_bodies.gd tripped arch api-v1 ("new class ... needs KERNEL_API 1.13"), so it was renamed.
   - kit selftest (k.sh) 95/95.
3. Site fixtures without an owner (kernel/world/site/fixtures/README.md, new)
   - Every one of the 11 top-level fixtures is run by something; evidence is in the table's "Run by" column.
   - `unmade/` looked unused to a path grep. It is block 120's site.unmade (`$FX/unmade`) and the input to the log
     schema check. It is the only fixture with change_requested, reopened and replan events. Kept.
   - The README states the rule: a change to the code a fixture guards updates the fixture in the same change.
   - harden.site_fixtures guards the table:
     - every entry has a row;
     - every "Run by" file exists and names the entry;
     - a README row for a fixture that is gone fails.
4. Block 502 flaky under load (kernel/world/site/draw.gd `wait_meshes`; fixtures editor_yaw.gd, no_ring.gd;
   harden_case.gd)
   - Found: editor_yaw.gd waited for the site's worker meshes by awaiting physics frames under --quit-after 12000.
     With --fixed-fps the headless main loop spins about 100 k frames a second.
     - Measured, counting frames in a copy: the 7 builds used 3 k to 10 k frames on this machine. Under my own 16 CPU
       hogs one run used 10,125.
     - The base fixture with --quit-after 3000 ends exactly as the busy gate did: no "OK", no error, exit 0. With
       12000 it passes. That is a frame budget racing a wall-clock worker.
     - no_ring.gd (block 501) has the same pattern with 1200 frames. On the base it passed at 120 frames once and
       failed at 120 under load.
   - Fixed: draw.gd `wait_meshes()` waits for every worker mesh and takes it, as `_collect` does when one is done.
     editor_yaw waits for the meshes instead of counting frames. no_ring waits for them and keeps its frames for the
     rebuilds. harden_case.gd's two site cases do the same.
   - The test was not loosened. 502 keeps its 12000 and now needs only a few frames. harden.site_waits demands that
     both fixtures finish in 120 frames.
   - Blocks 501 and 502 and all `site.*` cases: 25/25 PASS.
5. The village walked as a person (village_parts.gd `lots`/`_prop`, landscape.gd rocks)
   - Plain lots: harden.lot_props walks into every prop from 8 sides. He must stop at what is drawn: never into it,
     never more than 0.45 m before it. Lots under 20 m are left out (see open items). On the base:
     - the crane: its 4 m box sat inside its turned 5.2 m concrete base, so he walked into the base;
     - the scaffold: its box stood 0.65 m off its bays;
     - timber: one stack had an unturned box 0.3 m over it, the other had no body;
     - pallets of concrete blocks (0.94 and 1.34 m), barricades and cones: no body, he walked through them.
     Now each prop is solid as drawn and turned as drawn. Each lot prop is listed in the landscape's meta
     `tl_lot_props`.
   - The window walk found a hold: walking diagonally along a lot barricade he stuck for 10 s in the corner between
     its splayed foot and its boards. In the visitor's space the lot barricade is now a slab under the boards; its
     7 cm feet are not solid, and he slides off its end (clip part (b)). The kit barricade (packs) keeps its leg
     hulls, as drawn.
   - Rocks: every scatter rock with a body was a 1.4 m cylinder, a pillar over knee-high stones, and lower than
     boulders over 1.6 m. Pad rocks were the same. Now each body stands to its own rock's top (mesh aabb x scale,
     0.1 m steps). The visitor probe's "auto" rock is taken only from rocks over 0.8 m, so it still stops him.
     Case harden.rock_tops.
   - Not changed, with reasons:
     - tree trunks: the body is 0.42 x scale, twice the drawn trunk. The lowest crown tier is at head height, so
       holding him off is right;
     - bush tops: within about 0.2 m, foliage;
     - the site's own crane box (block 502 pins it).

GATES (final tree)
- tl check --tier fast: PASS (arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck clean).
- block 700: 6/6 PASS; block 620: 9/9 PASS; site.*: 25/25 PASS; kit selftest 95/95.
- world,packs, crisp (tl check --tier full --only world,packs):
  - world: PASS [8/8], world = alone. Hashes: seed.drive a2940a17@3441, seed.wall 5896844e@1221,
    seed.paddle dff1a390@4486, example.walker f1c7b537@371, example.kit ca698e71@332, example.car 3a459d0f@1872,
    game.ice_hockey_three_against 3b372f91@6751, game.parkour f7...
  - packs: FAIL [1/2], verb runs 60 of 61. The one red is hockey invariants.many_budget, frame p50 1.114 ms against a
    1.0 ms budget. That is wall clock on a machine loaded by every other lane; the hockey pack and the kit parts it
    uses (rink, goal) are unchanged in this tree. Last night's L1 measured the base failing it the same way
    (1.216 ms). Busy: not evidence either way. Not A/B'd today.
- world,packs, TL_STYLE=classic:
  - world: PASS [8/8], the same hashes as crisp;
  - packs: FAIL [1/2], the same hockey many_budget, p50 1.109 ms (busy).
- kit selftest (k.sh): 95 passed, 0 failed.
- Kernel selftest, final tree, 383 cases found = last night's 377 + this lane's 6. The machine was loaded by every
  other lane, so it ran in chunks with L1's block filter (selftest.sh with a block regex, blocks unchanged):
  - 010-399: 254 PASS, 1 FAIL (from one full run, stopped by me once it reached block 400);
  - 400-499: 22/22 PASS;
  - 500-709: 106/106 PASS.
  - The one FAIL: world.compact. In that run example.walker's alone run printed no hash (an empty column, so
    "DIFFERENT"). Re-run alone twice, both PASS:
    - world.sh proof compact_village: 6 of 6 the same;
    - selftest.sh world.compact: 1/1.
    The compact village's packs use no changed part, and the visitor's space is in no pack's space. I read it as a
    stopped sub-run under load, but it was red once in the long run: please re-run it on the merged tree.

CHANGED FILES
- engine/kernel/world/terrain/road_clear.gd (+ .uid), new: the exact road clearance.
- engine/kernel/world/landscape.gd: RoadClear on every scatter kind; rock and pad-rock bodies to their tops. +8 lines,
  587 of 600, CRLF kept.
- engine/kernel/world/terrain/village_parts.gd: `lots` props solid, `_prop`, meta tl_lot_props.
- engine/kernel/world/site/draw.gd: `wait_meshes()`.
- engine/kernel/world/site/fixtures/editor_yaw.gd, no_ring.gd: wait for the meshes. README.md, new.
- engine/kernel/world/terrain/harden_case.gd: its two site waits use wait_meshes.
- engine/kernel/world/terrain/harden_day_case.gd (+ .uid), kit_tops_case.gd (+ .uid), new: the cases.
- engine/tools/selftest.d/700-harden-day.sh, new: road_edge, lot_props, rock_tops, kit_tops, site_waits,
  site_fixtures (6 cases).
- engine/kits/part_bodies.gd (+ .uid), new; engine/kits/tl_kit_parts.gd: the five bodies.
- engine/kits/KIT.md: "Collider top = mesh top" section. k.sh docs regenerated it; the generated table is unchanged.
- engine/kernel/world/WORLD.md: lot props, road edges, rocks.
- assets/manifest.json: re-scanned in this tree (5 rows).
- Lane folder: STANDUP.md, REPORT.txt, clip-harden-day.mp4 (18.5 s), clip-harden-day-strip.jpg, clip.sh, and the
  lot_clip / road_clip walk and devices files.
Nothing outside the column but the manifest (as the brief asked) and my own selftest block, so there is no
PATCHES.md. engine/kernel/API.md is untouched: no API change.

BEHAVIOUR CHANGES (named)
- Crisp roadside: bushes that leaned onto the road or across the rails stand behind the rails now, and are solid
  there. Grass tufts on a road are gone.
- Classic: 4 roadside bushes on the road's surface moved and 15 tufts went. Nothing else moved.
- Plain lots: every prop stops the visitor as drawn.
- Rocks: he steps onto low ones and can jump onto waist-high ones; a big boulder is as tall as drawn.
- Kit parts barricade, cabin, house, timber_frame and marshal_post: new bodies (hashes above).
  - Pack hashes, bot 1220 frames, base export against branch:
    - seed.wall: 636b30026a88c5ae -> 21e736f35005a670. Both changed parts matter: with only the barricade put back to
      auto_box it gives 7afd5a41b9564155, neither the base nor the branch.
    - seed.drive 25e55145, seed.paddle 7afbc19c and parkour f7abac00: unchanged.
- The visitor's space is in no pack's space, so road, lot and rock changes move no pack hash.

FOR THE OWNER'S EYE
- clip-harden-day.mp4: the road edge with the bush now behind the rails, then the lot's barricade, cones and pallets.
- To walk it yourself: `bash engine/tools/world.sh visit wf_feel` (crisp).
  - Walk west on the road to x -215 and turn into the rails.
  - Then go to the plain lot at (194, 61): its gate is to the south.

QUESTIONS FOR THE DIRECTOR
1. The kit `goal` net's top is one flat box at 0.85 of the crossbar, but the drawn net slopes down to 0.62. A puck
   landing on the net would rest in the air. Changing it moves every hockey hash during L4/L5's day, so it is in
   kit_tops ALLOW with that reason. Should L4 take it, or I after hockey lands?
2. The kit barricade keeps splayed leg hulls (faithful, and a ball rolls under its boards). A visitor walking
   diagonally along a pack's barricade (seed.wall, parkour yards) can stick in the foot/board corner, as he did on
   the lot before the slab. A slab for packs too would move seed.wall again. Your call.
3. Landing: the manifest is re-scanned in this tree. If main's manifest moved, please re-scan on the merged tree.

NEXT THREE THINGS THIS LANE WOULD DO
1. The tour's 8 m lot (205, -34): Parts.lots draws a 5.2 m crane base, a 7.2 m scaffold and pallets into each other
   there (a heap; harden.lot_props leaves lots under 20 m out). Scale or skip props by lot radius.
2. A spawn/gate check across every walk script (L1's third item), plus the site in the exe's construction lot seen
   in the exported game.
3. The goal net body (question 1) and a kit-wide rule for a part's walk-past feel (the corner question 2) once the
   hockey lanes land.
