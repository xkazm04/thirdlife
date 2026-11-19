Lane editor, round 3 (day of 19 Nov 2026): report (done at about 14:30)
Worktree .claude/worktrees/d19-editor3 (branch d19-editor3, from main 858712d). Nothing is committed.
Astra (codex gpt-6.2-astra, high), one session 01a1f3ac-f3e8-78b0-b86e-4a6888f3fafe, built:
- the yaw layout of the construction;
- the design for turning the arrived game;
- the pad of a lot with no h.
I did the visits, the fixes they found, and the polish of task 3, and re-ran every gate myself.

WHERE TO LOOK
1. clip-visit.mp4 (28.5 s, recorded at 1.5x). A person's visit in a window, input events only, recorded
   (world.sh visit-test):
   - he runs the road to the workbench game on its moved lot by the river and turns to it;
   - he walks in through the arch and presses E: the game is on stage;
   - Q leaves; F flies up 30 m;
   - he backs off north, turns and looks down at the lot from about 30 m;
   - he flies 500 m east to a second, fresh workbench game (made today with the Find a place placement ranked 2nd)
     and lands beside it.
   The walk and the device script are in the lane folder: visit_round3.walk.json and visit_round3.devices.json.
   The walk names job dirs under this worktree's .tl/.
2. stills/round3/:
   - the gate from the road: before the title fix (visit2_...) and after (visit3_01);
   - walking in, the game on stage, the lot from the air, the fresh game from the air;
   - a top view of the moved lot;
   - yaw30_building_above.jpg and yaw30_building_road.jpg: the construction turned 30 degrees while the sign and rails
     face the road;
   - shots_p-6b-ranked-bigger.jpg: the editor's three places measured again after the rink grew.

TASK 1: THE VILLAGE WALKED AS A PERSON (window, walk, E, Q, F)
Read wrong, and fixed inside my scope:
1. The arch and the sign said "Ice hockey, three against three by the river. Decided".
   - Cause: Foreman's title rule takes the words before a colon, and the workbench sends "<idea>. Decided: <answers>.".
   - Now the title is the idea's first sentence (foreman/src/cli.ts). The new foreman test covers it, together with
     the plain and colon cases.
   - New jobs say "Ice hockey, three against three by the river" (stills visit3_01, visit3_02).
   - Old jobs keep their logged title.
2. A walk lot with no h that does not move stood its game at y 0, while the landscape puts such a pad at the land's
   height. Now every lot with no h takes the land's height at its centre (Astra, site.gd). The new case is
   site.auto_pad (block 503): stationary auto, old reservation and moved lot all at 5.56 m; an explicit 13.375 m
   stays exactly.
3. Seen in the workbench polish: a measured reason said "next to walker" twice, because "walker" matched "walk".
   Fixed, with a selftest case.
Seen and fine:
- the pad sits on the land, with no step;
- no circle round the lot; short rails at the entrance;
- the sign reads from the road;
- E enters the game and Q leaves at the gate;
- flight over the lots; landing beside the fresh game on the ground.
The rest, outside my scope or not wrong enough to change today:
- The plain lots (no job) still draw a crane and a scaffold ("the next game is being built here", landscape
  Parts.lots). From the air a crane on an empty lot reads as a construction that is not there (blend / landscape).
- The arch's floating title repeats the big sign's first line right beside it. A person reads the same words twice
  at the gate. Proposal: the arch keeps the name and the sign keeps only the state ("Ready. Walk in and press E to
  play.").
- After Q the visitor stands at the gate facing out, which is good. With W held at once he walks into the next plot
  across the road (parkour) and that plot's gate stops flight (visit_fly_gate). That surprised me in the script, and
  it would surprise a person.
- An arrived game sits square, not at the player's turn (task 2).
- Correction to my 13:24 standup: an arrived game does NOT turn to its gate. My top-view camera looked straight down,
  and its roll made the court look turned.

TASK 2: TURNING THE ARRIVED GAME
Built inside my scope (Astra, verified):
- site.gd reads yaw_deg from job_created.lot (or the draft's lot) and keeps it; the [site] report carries it when it
  is not 0.
- site/draw.gd lays the construction out along the footprint turned by the yaw: crane, bays, house, scaffold, stores,
  the plan board, and their colliders.
- What belongs to the entrance stays at the gate facing the road: the rails, the gate path, the sign, the arrival arch
  and masts.
- Yaw 0 gives the old build exactly: the mesh, label and collider digest
  (a3151ac71892db831b139eba3e5181051a9e680c8570a84886355e0f09a10b0d) equals the build before the change.
- New case site.editor_yaw (block 502): four box transforms checked against independent positions, the entrance
  geometry, job and draft give the same placement, and a repeat build.
- I found that case failing under load. The worker meshes outran its 1200-frame cap (it passes alone). I raised the
  cap to 12000; the proof ends itself.
Not built (world_space and runner belong to the flight lane until it lands): the arrived game itself. The ready patch
description follows at the end of this report.

TASK 3: THE MAP FOLLOWS THE REQUIREMENTS (polish)
- The editor's own three places (Find a place with no place words) did not follow an answer. A bigger rink kept
  places measured for the smaller ring.
- Now any answer that changes the ring measures them again. It is free: no model call.
- The Designer's places stay as it chose them and are judged again, as before.
- Drive `ui.sh place --measured` checks this: "ring 32 -> 43 m: the three measured places follow (best 69.0)".
- Also: drive flag --take=N (take the N-th ranked place), used to make the second fresh game.
- I found nothing else that fails to redraw. Checked: footprint, stands, spectators, path, gate, clearance, Why here,
  scale strip, request and blocker.

GATES (this tree)
- selftest site.: 18/18 (16 on main; + site.editor_yaw, site.auto_pad). world.: 16/16. blend.: 2/2 (Astra's run).
- --only world,packs: PASS world 8/8 (world = alone), packs 2/2 (44 of 44 verb runs).
- fast tier: PASS 5/5 (arch 12/12, devx.test 229/229).
- foreman: typecheck clean; tests 223 (217 pass, 0 fail, 6 skipped; +1 title test).
- ui.sh selftest: 166 passed, 0 failed (main 165).
- Drives (fake adapter): place, place --measured, editor, home all ok. Also place --build twice, to make the two
  promoted workbench games for the visit.
- Full gate: exit 1. PASS: arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck, foreman.test 223 (217 pass, 0 fail, 6 skipped), kit 95/95, packs 2/2 (44/44 verb runs), perf 2/2 (machine quiet, use 29 %), seeds 39/39, item 91/91, ui.selftest 166/166, world 8/8. FAIL: kernel.selftest, 297/305. All 8 failures are the flight lane's known one: 7 flight.* cases from one run whose 'FLIGHT collide ... trunk=-inf' fails (on main, as reported in round 2), plus moves.flight_unchanged, which re-runs that flight suite. I re-ran the whole selftest to name all 8. Every block of mine passes (500-503).

CHANGED FILES
- engine/kernel/world/site.gd: yaw read and kept; ground height for lots with no h.
- engine/kernel/world/site/draw.gd: construction along the turned axis; entrance pieces on the road frame.
- engine/kernel/world/site/fixtures/editor_yaw.gd and its .uid (new).
- engine/tools/selftest.d/502-editor-yaw.sh and 503-site-auto-pad.sh (new).
- foreman/src/cli.ts (title = the first sentence); foreman/src/test/place_calls.test.ts (+1 test).
- engine/ui/editor/place_panel.gd: measured places follow the ring; walk fact match.
- engine/ui/editor/drive_editor.gd: --measured re-measure check; --take=N.
- engine/ui/editor/selftest_place.gd.
- Lane folder: STANDUP.md, REPORT-round3.txt, clip-visit.mp4, visit_round3.walk.json, visit_round3.devices.json,
  stills/round3/ (10 JPGs).

BEHAVIOUR CHANGES
- A new job's title is the idea's first sentence (before the first ". " or ":"). Old jobs keep their logged title.
- A site lot with no h stands its pad, site node and game at the land's height, not at 0. A lot with h is unchanged.
- A turned workbench game's construction is laid out turned; yaw 0 is byte-identical to before.
- The editor's own places are measured again when the ring changes.

QUESTIONS FOR THE DIRECTOR
1. Should the arch and the sign stop saying the same words? A proposal is under task 1.
2. The plain lots' crane on an empty lot (blend lane / landscape): keep it as "a game could go here", or drop it?

NEXT THREE THINGS
1. Land the arrived-game turn after flight lands (the patch below, in its 5 steps, each with its case).
2. Arch and sign wording (if approved), then walk the exported exe village as a person, cooked package.
3. A recorded person-visit as a gate check (world.sh visit-proof style) over a workbench lot: E, Q, F, replayed to the
   same hashes.

CODEX (Astra) TOKENS (one session; codex prints the running total)
- Brief A (yaw layout, block 502, stills, design): 201,993.
- Brief B (pad for a lot with no h, block 503): 41,510 (running total 243,503).
- Round 3 total: 243,503. No real Designer calls this round.

=====================================================================================================================
READY PATCH DESCRIPTION: TURNING THE ARRIVED GAME (Astra's design, read and checked against the files by the lane lead)
=====================================================================================================================
# Turning the arrived game

The next shift can turn the reserved site's existing plot. Give it a world `yaw` as soon as the site reserves the plot, before the viewer builds the landscape or the first promotion releases the holder. Arrival, reload and stage changes can then use the same transform. This round only implements the construction frame.

## Coordinate convention

The workbench draws a footprint point with `at + p.rotated(model.yaw)` in village X/Z metres (`engine/ui/editor/map_base.gd:89`). At editor +30°, a marker 10 m along local +X belongs at offset (+8.660254, +5) in X/Z. Godot's positive rotation about +Y takes +X toward −Z. The reserved plot therefore needs **world yaw in degrees equal to minus the editor yaw in degrees**. For the probe's −15° job, the saved world plot should carry +15°. Use this signed conversion once, at reservation. Preserve the sign of existing authored world yaws.

## Patch order and acceptance cases

Paths in this section start at `engine/kernel/` unless another root is given. Case names beginning with `site.arrived_yaw_` are proposed selftests.

1. **Reserve and persist the placement.** In `world/site.gd:44` (`setup`, reserved branch near line 89, new plot line 103), add `yaw = -s.yaw_deg` to the appended plot only for a nonzero turn. The walk lot schema stays as defined. On replay, the reserved plot in the recorded walk supplies the orientation, including the zero default for old logs. Derive the construction view's editor angle from that record so that a later draft edit cannot change the replay heading. Keep the recorded scheduler footprint when restoring the held plot. `world/world.gd:222` reads the recorded walk, line 279 copies yaw to `plot_defs`, and `_spawn_plot` at lines 189–196 gives it to the holder as metadata. `world/pack.gd:490` writes `plot_yaw` in `plot_record`, and `world/world.gd:329` restores it. Keep the established world-file representation. Set the yaw before building the view, since changing only the holder at `site.gd:490` (`_arrive`) would leave the prebuilt pad and drawing transform at their old heading.

   **Proof — `site.arrived_yaw_record`.** Start with job +30°, draft −15° and a legacy site. Inspect the expanded walk for −30°, +15° and an absent key respectively. Save and reload, run a second promotion and replay after changing only the draft yaw. Check the same reserved indices, headings, centres and first arrival tick. Extend block 500's job-over-draft case and block 501's existing moved-pad assertion to inspect these fields.

2. **Make footprint queries agree with the plot.** `world/world.gd:294` passes world degrees directly into the scheduler. `world/tiers.gd:163` currently passes that number to `Vector2.rotated`, which takes radians. Use `rotated(deg_to_rad(float(p.yaw)))` for the world-to-local X/Z offset. Its sign is positive because this is the inverse projection into the plot. At `tiers.gd:152`, `_gap` assumes two axis-aligned footprints. Keep its existing formula for unturned pairs. For a turned pair, form the oriented rectangle corners, return zero on overlap or containment and otherwise take the minimum corner-to-opposite-edge distance. Build adjacency at setup with the actual footprint sizes, before the held sentinel is applied. `tiers.gd:279` uses the distance for tiers and `_decide_visits` at line 359 uses it for entry. `site.gd:520` restores a square of side `2 * sched_r` at arrival. Preserve that definition and the held sentinel for this change. The visible rink can be rectangular inside its reserved lot.

   **Proof — `site.arrived_yaw_entry`.** Use a 40 × 12 m authored plot, a neighbouring plot and an independent X/Z projection. Check a point just inside the long edge, one outside the short edge and an adjacency threshold crossed by the rotated corner. Include negative yaw, zero yaw and an unenterable held site. Request entry after promotion and check the accepted plot ID and tick. Arbitrary-axis checks on a circle would miss the unit error.

3. **Use the same basis for the floor, rim and visitor's solids.** `world/draw/view.gd:167` already constructs `Transform3D(Basis(UP, deg_to_rad(world_yaw)), origin)`. Lines 179–189 apply the vertical rim lift. `world/landscape.gd:91` projects basis X into village X/Z and uses both axes for terrain bounds. Lines 183–184 give the grade its extent, axis, radius and road approach. `world/terrain/village_terrain.gd:187` grades those axes with a circular support region under the clip. Reserved site plots enter the plot loop. The 0.72r × 0.62r half-extents and fixed RIGHT axis at `landscape.gd:104` belong to the remaining plain lots. `site.gd:148` already projects the same axis in the moved-pad height calculation. Keep both bounds calculations in agreement. Keep the spur and rails on the road bearing computed at `landscape.gd:161` and the construction node in the road frame at line 324.

   Initial collider copies go through `landscape.gd:517` → `terrain/world_space.gd:249` (`add_pack`, recursive copy at line 345). Queued arrival goes through `draw/view.gd:358` → `world_space.gd:257` (`begin_pack`) and line 276 (`step_pack`). Both paths strip the holder transform, bend in pack-local space, then apply the full plot transform to vertices or to the primitive shape frame. Supply the same plot to both. `draw/view_seam.gd:61` removes the temporary pad when copying finishes. Yaw is constant throughout this job, including rebuilds. A future feature for moving an already-built site would need to replace its tagged solids and pending copies because `view.gd:358` copies only on the first arrival.

   **Proof — `site.arrived_yaw_solids`.** Put an off-centre, asymmetric static box and a concave floor near the rim of a test pack. Build once through each copy path. Raycast in the visitor's space at the rotated and former positions, check the box normal and the bent floor height. Query the pack's own space at its original marker. Extend block 501 with a yawed bounds/height reference and retain `blend.footprint`, `ground.shut_pad_solid` and `ground.ledger_shapes`.

4. **Stage, controls and road return.** `world/draw/draw.gd:109` (`set_stage`) calculates `stage_plot.affine_inverse() * other_plot`. For full-detail packs, `_adopt` at line 211 sets the shader transform and `_mirror` at line 237 handles other visuals. `draw/draw_base.gd:179` updates culling bounds. `draw/view.gd:392` (`_set_stage`) applies the inverse to the landscape, snaps interpolation and activates the pack camera. `runner/visit.gd:249` hands off input. On leaving, lines 343–369 use the plot centre, radius and nearest road direction for the visitor's position and facing. Keep those world-space gate calculations. Applying plot yaw to the camera or gate a second time would visibly swing the road or put the visitor on the wrong side.

   **Proof — `site.arrived_yaw_stage`.** Use an asymmetric visible marker and two plots. As a visitor, assert the marker equals `plot * local`. Enter, check the stage marker and camera against their pack-local transforms and the other plot against the relative transform. Leave, check visitor feet outside the road-facing rail opening, bearing toward the road, and the restored marker. Record and replay the same device ticks. Take a road still and an on-stage still.

5. **Reuse the local picture caches.** `world/draw/draw_pictures.gd:270` collects stand-in meshes relative to the holder. `_append` at line 345 bakes the radial bend in that space. `_cache_key` at line 170 hashes pack contents, radius, rim, picture rules and band. `_cache_load` at line 226 calls `_place_standin` at line 260, which applies the current relative transform, clipping and transformed AABB. `draw/draw_base.gd:110` supplies the world origin and basis X to the ground material for both live and cached meshes. The shader uses those for its village coordinates (`engine/style/shaders/toon.gdshader:260`). Rim height (`draw/view_seam.gd:18`) and measured radius (`site.gd:266`, `site.gd:426`) are pack-local measurements. Reuse all three cache keys across placements.

   **Proof — `site.arrived_yaw_picture`.** Use a shared temporary cache and the same asymmetric pack, seed, radius, rim and settings at zero and +30° editor yaw. Cold-build and warm-load the far mesh. Check the same cache path and local mesh vertices, an actual cache hit, distinct transformed marker positions, rotated AABBs and matching near/far rim samples. Re-enter after switching stage to catch a stale `rel`. Compare screenshots at fixed camera and event frames.

## Determinism and the world log

`world/world.gd:195` gives a scheduled pack simulation origin zero and its own physics space by default. `world/pack.gd:164` sets the holder to `ctx.origin`, creates a PhysicsServer space and stores its RID on the context. `adopt` at line 228 moves body and area RIDs into it. `api/tl_context.gd:89` resolves queries to that space. Queue attachment calls `world._rebuild` (`world/jobs.gd:227`), which spawns through the same code. `runner/pack_life.gd:314` hashes the bodies, canonical pack state, RNG and input. `host/statehash.gd:29` includes body orientation and velocities and subtracts the simulation origin from positions. Rotating the simulation holder would therefore change the hash. Applying the transform only at the village boundary preserves it.

**Proof — `site.arrived_yaw_hash`.** Extend `site.arrival` in block 120 with a turned promoted pack. Hold the input stream, seed and positive count of pack physics ticks fixed. Compare the full `state_hash` in the zero-yaw world, turned world, solo run and recorded replay, and assert each run reached its end marker. Keep `world.same`, `world.walk_proof`, `world.file`, and the full world/packs gate. No pack hash golden needs regeneration.

The recorded walk in `tl.worldlog/1` acquires the signed plot yaw (`world/world.gd:641–646`). A boundary-crossing route may also produce different tier, entry or build events and pack tick totals. The tour proof at `engine/tools/world.sh:189` compares each run with solo at that pack's own tick count and with replay at the recorded count. A different end-of-walk tick allocation can yield a different final hash while the equal-tick hashes still agree. Update expectations for those specific events and yawed screenshots. PNG hashes reflect the changed pixels. The promoted pack directory hash and local stand-in, rim and extent cache keys retain their values for the same pack and geometry settings.
