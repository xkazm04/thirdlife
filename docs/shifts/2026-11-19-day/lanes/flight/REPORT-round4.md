Lane flight, round 4 (d19-flight4 from main aeb201e, which has parkour's Skyline), day of 19 Nov 2026, 14:01-14:20 by
the worktree clock. By me; 0 Codex tokens. Nothing copied from other trees; round 3's diff (2cf0196) re-applied to files.

WHAT BROKE PARKOUR (main 011e8e2, reverted aeb201e)
  The soft end of the swing. Measured on this tree, parkour's 17 bots, state hashes against pure main aeb201e:
    - round 3 as merged (cap 85 deg + brake): bot_grips FAILS ("blue held 1 ticks; red held 0 ticks"): Skyline enters
      its grips fast and its timing expects the plain, energy-keeping swing; the brake bled the entry.
    - the cap alone at 95 deg, no brake: all 17 bots pass but 14 of 17 change their state hash (Skyline's swings go past
      95 deg while pumping), so any cap below the 100 deg guard changes the pack.
    - the ledge tolerance (FIT_TOL) and the camera bars alone: all 17 pass, all 17 hashes identical to main.
FIX (kernel only; the parkour pack is untouched)
  engine/kernel/world/terrain/walker_grips.gd `soft_swing` (default false): the soft end (SOFT_AMP 85 deg, BRAKE 6/s)
  applies only with it; engine/kernel/world/terrain/world_space.gd sets it for the village visitor. A pack biped keeps
  the plain swing (dead stop at 100 deg, exactly as before). API.md says so. No new public names.
  Pack bipeds cannot opt in to the soft end yet (TLBiped is at its 600-line budget; an option `moves: [&"soft_swing"]`
  is a one-line addition once there is room, if the parkour lane wants it and re-tunes its bots).
RESULT
  Parkour, all 17 bots: PASS, state hashes identical to pure main aeb201e (bot_course f7abac00, bot_grips dc4d66ed,
  bot_swing_phases 0777fb73, ... full table .tl/hash-pure.txt vs .tl/hash-final.txt in the worktree).
  Round-3 items otherwise as in REPORT-round3.md: ledge at 3.05 m caught (moves.ledge_fit 5/5), cameras ignore marked
  bars (moves.cam_bar, moves.biped_grip), pack grip-pose case (moves.biped_grip), visitor soft swing (moves.swing_soft).
GATES (this tree)
  fast: PASS arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck.
  selftest flight.: 12 passed, 0 failed. moves.: 14 passed, 0 failed.
  full --only packs,world,kit.selftest: PASS packs 2/2 (verb runs 47 of 47, parkour's bots included), PASS world 8/8
  (world = alone), PASS kit.selftest 95/95.
FILES (commit exactly these)
  engine/kernel/world/terrain/walker_grips.gd, engine/kernel/world/terrain/world_space.gd, engine/kernel/api/tl_chase_cam.gd,
  engine/kernel/api/tl_biped.gd, engine/kernel/world/terrain/crown_camera.gd, engine/kernel/world/visitor.gd,
  engine/kernel/API.md, engine/kernel/world/moves_demo.gd, engine/kernel/world/{flight_cam_bar_case,swing_soft_case}.gd(.uid),
  engine/kernel/runner/{biped_grip_case,ledge_fit_case}.gd(.uid), engine/tools/selftest.d/533-536, docs/shifts/2026-11-19-day/
  lanes/flight/{STANDUP.md, REPORT-round3.md, REPORT-round4.txt, clip-cam-bar.mp4, sheet_cam_bar.jpg}.
LESSON
  A kernel change to a move must be gated against every pack that opts in to it; a tree cut before such a pack landed
  cannot see it. Next time: ask for a fresh worktree right before the gate when another lane is landing on the same move.
