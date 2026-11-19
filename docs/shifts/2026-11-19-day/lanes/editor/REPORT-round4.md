Lane editor, round 4 (last, day of 19 Nov 2026): the arrived game turns with the player's yaw. Done at about 16:08.
Worktree .claude/worktrees/d19-editor4 (branch d19-editor4, from main a6f8941). Nothing is committed.
Astra (codex gpt-6.2-astra, high) built steps 1-5 in one session (220,627 tokens). I re-ran every gate myself and made one
fix (the site.gd size ratchet, below).

VERDICT: landable (gate lines below).

WHAT A PERSON SEES (stills/round4/)
- yaw30_01_building_above: a workbench job turned +30 degrees. The construction is laid out on the diagonal.
- yaw30_02_arrived_above: the arrived game stands on the same diagonal. Before this round it stood square.
- yaw30_03_arrived_road: the gate, the rails and the sign still face the road.
- stage_01..03: the visitor before entering, on stage, and back on the road side 5 m outside the plot, facing the road.

THE STEPS (each with its case in engine/tools/selftest.d/504-editor-arrived-yaw.sh; all PASS in my run)
1. tiers.gd. `distance` passed degrees to Vector2.rotated, which takes radians; it now uses deg_to_rad. `_gap` handles
   turned pairs as oriented rectangles: corners, containment and crossing edges. Unturned pairs keep the old formula.
   Case site.arrived_yaw_entry: 40 x 12 m at +30, -30 and 0 degrees, oriented gaps, held and released entry.
2. site.gd. The reserved plot carries the yaw, world yaw = minus the editor yaw: job +30 -> plot yaw -30, draft -15 ->
   +15. A yaw of 0 or a legacy job leaves the key absent. Replay and save/load keep the yaw.
   Case site.arrived_yaw_record: arrival tick 38, reload 42, enter 50; save/load and a changed-draft replay.
3. Floor, rim and the visitor's solids. Both collider-copy paths in world_space.gd already applied the full plot
   transform, so no edit was needed there.
   Case site.arrived_yaw_solids: the initial and the sliced copies, the turned wall is hit, the old position is clear,
   the rim is bent, and pack-local rays are unchanged.
4. No state hash moves.
   Case site.arrived_yaw_hash: example.bounce, seed 1, 241 bot frames, in four runs (world at yaw 0, world at editor
   +30, replay, and tl.sh bot alone). All four give
   545cd7c35ab2a3611fe216bd9e48335399463b31117faaaa8caee8f24963fb1b.
5. Stage and leave (design step 4).
   Case site.arrived_yaw_stage: the visitor marker is turned, the stage camera is pack-local, the second plot sits at
   its relative transform, and the visitor returns facing the road 5 m outside. The recorded visit and its replay
   give the same hashes (walker bf12ae2d03897bfe @194, arrived game f9f7c0d39844fc03 @242).
NOT DONE: the picture-cache proof (design step 5). Caches are keyed by pack-local geometry, so a turned placement
should reuse them. That is not measured. I name it, and I do not claim it.

THE 8 WORLD HASHES (`tl check --only world`, before on a6f8941 and after on this tree): IDENTICAL
  seed.drive a2940a1735bc2b72 @3441 | seed.wall d5aea03b46c33ee6 @1220 | seed.paddle dff1a390470352e7 @4486 |
  example.walker f1c7b53757c34040 @371 | example.kit ca698e71d34d1021 @332 | example.car 3a459d0fe25e7853 @1872 |
  game.ice_hockey_three_against a29dcdf02a16dd1c @4186 | game.parkour f7abac006a45bd43 @988
  (Each comes from the gate's world = alone table: the hash in the world equals the runner alone at the same ticks.)

GATES (this tree, my runs)
- --only world,packs (after the ground.gd move): PASS world 8/8 (world = alone), packs 2/2 (48 of 48 verb runs); the 8
  world hashes are identical to main a6f8941 (diffed table: .tl/world-hashes-before.txt vs .tl/world-hashes-after2.txt).
- selftest site.: 23/23 (main 18: + the five arrived_yaw cases). world.: 16/16.
- fast tier: PASS 5/5 (arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck).
- ui.sh selftest: 166 passed, 0 failed.
- My first fast run failed arch and devx.test: site.gd had grown to 609 lines, over its 600-line ratchet. I moved the
  terrain-box helper into a new engine/kernel/world/site/ground.gd; site.gd keeps a 2-line forwarder and is now 559
  lines. After that, fast tier PASS 5/5 and site. 23/23. world,packs and world. were re-run after this move (lines
  above).

CHANGED FILES
- engine/kernel/world/tiers.gd: deg_to_rad, oriented `_gap`, `_corners`.
- engine/kernel/world/site.gd: the reserved plot's yaw; the terrain helper moved to site/ground.gd.
- engine/kernel/world/site/ground.gd and its .uid (new).
- engine/kernel/world/site/fixtures/: arrived_yaw_entry.gd, arrived_yaw_solids.gd, arrived_yaw_stage.gd (each with its
  .uid), arrived_yaw_world.cjs (all new).
- engine/tools/selftest.d/504-editor-arrived-yaw.sh (new).
- engine/ui/editor/editor_model.gd and selftest_place.gd: the turn line's words (expectation moved, because the world
  now turns the game).
- No change to world_space.gd or runner/**: both already used the full plot transform.

BEHAVIOUR CHANGES
- A workbench game turned in the editor now stands turned in the village. Its gate, rails, sign and the spur still
  face the road. Games with yaw 0, and every existing walk, are unchanged (the yaw key stays absent).
- tiers.gd's footprint distance is now right for a turned plot. Until today every plot had yaw 0, so no tier changed.

FOR THE NEXT SHIFT
1. The picture-cache proof (design step 5): cold and warm cache for one pack at 0 and +30 degrees.
2. (Done in this round: the workbench's turn line now says "the game stands turned on its lot; its gate still faces
   the road", because the world builds it; editor_model.yaw_note, with its selftest expectation moved.)
3. A recorded person-visit over a turned lot as a gate check.

CODEX TOKENS: round 4, one session, 220,627.
