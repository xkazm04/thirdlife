# Arm C: active ragdoll (your route)

Worktree `.claude/worktrees/n21d-falls-c`. Selftest file `engine/tools/selftest.d/671-falls-c.sh`.

**The idea:** the figure gets physical bones (Godot 4.7 `PhysicalBoneSimulator3D` with `PhysicalBone3D` children on the
rig's `Skeleton3D`), driven toward the animated pose by motors or springs while he stands. A small hit lets the motors
go soft for a moment (the body sways under the blow and is pulled back to the pose: the flinch IS physical). A big hit
lets them go: the figure really falls, under gravity, onto the floor, AWAY from the blow (give the bodies the impulse),
lies there, then recovers: the motors take hold again and pull him up through a get-up pose (or a get-up clip) inside
the rise window. Gang Beasts / TABS: "failure is fun to watch".

**This arm has to prove what the other two get by construction**, and it is only eligible if it holds:
- **Determinism**: the lab twice gives the same state hash (the state holds a digest of the victims' sockets every
  frame: a ragdoll pose that differs between two runs FAILS `falls.lab_invariants`). The physics engine is Jolt
  (`engine/project.godot`), fixed 60 Hz.
- **The simulation is unchanged**: the capsule (`TLBiped`, a `CharacterBody3D`) stays the simulated body; the ragdoll is
  the drawn figure only. Its bones must never push the capsule, another figure, the puck or anything else: give them
  their own collision layer, collide only with static ground (the kit's ground bodies), and exclude the figure's own
  capsule. The hockey pack's `tests/bot_check.gd` state hash must be identical before and after.
- **World = alone**: in a world of several games, each game has its OWN physics space: the world moves every
  `CollisionObject3D` that enters a game's tree into that game's space (`engine/kernel/world/pack.gd`, `adopt`). Physical
  bones made later than the figure (at the first hit, say) must still end up in the right space and find that game's
  ground. The Director runs `node devx/bin/tl.mjs check --tier full --only world,packs` on your tree.
- **Cost**: simulate only while a reaction runs (start the simulator on a hit, stop it when he is back on the pose), so
  a figure nobody hits costs nothing. The hockey game has 10+ bipeds and a 1.0 ms frame p50 budget.
- **Headless**: the runner runs headless (no rendering) for every verification; the ragdoll must behave the same there.
If any of these cannot be made to hold today, say so plainly with the measurement; a ragdoll that breaks the hash law
is NOT eligible, but its clip still goes to the owner, labelled as such. Honest is the deliverable.

**Build:**
1. In the rig (`engine/rigs/biped/`, e.g. a new `ragdoll.gd` helper the biped rig owns): physical bones for the main
   chain (Hips, Spine/Chest, Head, upper/lower arms, upper/lower legs: about 11-13 bodies, capsules sized from the
   rig's bones), joints with sensible limits, built once (lazily at the first hit is fine), off until needed.
2. Driving: per physics tick, pull each body toward its animated bone transform (target velocities or torques from the
   pose error, with a strength you can blend: 1 = holds the pose, 0 = limp). React: strength dips by the hit's
   strength and recovers over 12-24 frames, plus an impulse at the hit height away from the blow. Down: strength to ~0,
   impulse away from the blow, he falls; while lying, low strength; at the rise, blend strength back up and/or blend the
   drawn pose from physics back to a get-up pose then locomotion inside `get_up_frames`.
3. The rig still answers its whole table without physics (the stand-in capsule must keep working; classic style too).
4. The kernel side: `TLHit.react` / `TLHit.down` hand the rig the hit (direction in the rig's space, strength, height,
   down or not) through a duck-typed call (a rig param declared like `lean`, or a rig method found with `has_method`);
   a rig without it falls back to today's behaviour. For `down` with zero `from_dir`, see the shared spec.
5. Where the figure ends up: the capsule does not move with the ragdoll; keep the ragdoll's pelvis near the capsule
   (it falls next to where he stood, and when he rises the figure is back over the capsule): no popping across the rink.

Your own selftest cases (671): the lab twice with equal pose digests; the bones never touch the capsule (the hockey
`bot_check` hash unchanged); the ragdoll is asleep / off 60 frames after the get-up.
