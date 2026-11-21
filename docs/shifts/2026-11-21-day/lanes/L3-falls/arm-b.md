# Arm B: authored clips plus a physical blend on the hit bone (your route)

Worktree `.claude/worktrees/n21d-falls-b`. Selftest file `engine/tools/selftest.d/671-falls-b.sh`.

**The idea:** authored directional clips carry the big motion (as in arm A, which is built separately in another
worktree: you build your own clips here), and on top of them the bone that was HIT, and the bones below it in the
chain, take a short physical wobble driven by the impulse: the way Unreal's "physical animation" hit reactions blend
physics in at the hit bone 0 -> 1 -> 0 over about 12 frames. The experiment is the wobble: that it makes a hit feel
like it landed on a body, at a cost the hockey game can afford, and deterministically.

**Build:**
1. Directional clips, as simple as will read well: flinches `hit_front`, `hit_back`, `hit_left`, `hit_right`
   (upper-body); falls `fall_back` (front hit), `fall_front` (hit from behind), `fall_side` (mirrored by a param or two
   clips); get-ups `get_up_back`, `get_up_front`, time-scaled into the rise window (`get_up_frames`, 24). Falls hold
   their last pose while he lies; harder hits fall faster. The whole figure goes down (`_hips` to the floor), nothing
   sinks into the floor. If time is short, keep the clips plain and spend it on the wobble.
2. The physical layer, in the rig (`engine/rigs/biped/`): pick the hit bone from the hit height and direction (a
   chest-high blow: `Chest`/`UpperChest` with `Neck`/`Head` and the arms following; a low one: `Hips`/`Spine`). Give it
   an angular impulse away from the blow, scaled by strength, and integrate a damped spring per bone (a second-order
   system per axis, frame-stepped at 1/60 s, child bones lagging the parent so the motion travels outward), added on top
   of the clip's pose after the clip is evaluated. Blend weight 0 -> 1 -> 0 over about 12 frames (a quick rise, a
   longer settle). Deterministic by construction: no physics engine, fixed step, no clock, no random.
   - Alternative if you can make it deterministic and cheap: Godot `PhysicalBone3D` / `PhysicalBoneSimulator3D` on just
     the hit chain with `influence` blended 0 -> 1 -> 0. If you try it, prove determinism (the lab's invariants) and
     measure the cost; the spring is the default.
3. Also on falls: the hit bone wobbles at the start of the fall and the arms/head lag and bounce when the body lands
   (a landing impulse at the frame the clip hits the floor).
4. The kernel side: `TLHit.react` / `TLHit.down` choose the clip by `from_dir` in the victim's frame and hand the rig
   the impulse (direction in the rig's space, strength, height) through a duck-typed call (a rig param declared like
   `lean`, or a rig method found with `has_method`); a rig without it falls back to today's behaviour. For `down` with
   zero `from_dir`, see the shared spec.
5. Cost: measure the rig's extra time per tick (frames, not wall clock, are the law; but report the cost of the spring
   for 12 bipeds). The hockey game has 10+ bipeds: the spring must be idle (zero work) when no wobble is running.

Your own selftest cases (671): the wobble twice gives the same pose; the wobble is zero 30 frames after the hit; a
front hit's first wobble frames bend the chest away from the blow.
