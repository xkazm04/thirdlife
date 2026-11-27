# PATCHES-K: lane K's edits outside its own files, and what it asks of others (M5, 27 Nov 2026)

Lane K owns the walker files in `kernel/world/terrain/`, `kernel/dungeon/**`, `boot/hub.gd`, `boot/menu.gd`, the API
files and `block_mesh.gd`'s stair collider (LANES.md). LANES.md asks that each edit of a walker file be listed here.

## Made (in lane K's scope)

### K1. `terrain/world_body.gd` (584 -> 586 lines): `step_risers`, visitor only
- Header: a `riser` line in the list of modes.
- `var step_risers := false` and `const Riser = preload("res://kernel/world/terrain/walker_riser.gd")`.
- `_ground_move`: after the probe down, `edge` = the body the foot met (read only when `step_risers`). In the branch
  where the round foot met an EDGE (`_steep_n` returned ZERO: "walked off an edge, falls"), with `step_risers`:
  - up (the contact is not under his feet): when `Riser.top_ahead` finds a walkable top of a Home block within
    `step_up` ahead (a ray down at the centre plus radius + 2 cm along the move), he stands where the foot met the edge
    (`landed`, a sweep's end, so the capsule fits) with `ground_n` UP and goes on rolling over it;
  - down: when the edge is a Home block's and `Riser.floor_under` finds a walkable tread within `step_up` under the
    centre, the same, so a stair is walked down, not fallen down a step at a time.
  Everything else (and everything with the flag off) is the seam's code path.
- Not taken from PATCHES-WP1.md P2 as written ("stand him on it", the top's height): measured, it dips. Put at the
  top's height while his centre is still up to 0.335 m in front of the edge, his round foot floats over the edge; the
  next tick's probe lands it on the edge 0.05-0.15 m lower (a pop down, then up). Standing where the sweep met the edge
  keeps the feet monotone (largest dip 0.2 mm, the flat floor's own sawtooth).

### K2. `terrain/world_space.gd` (468 -> 476 lines)
- `var step_risers := true` (this file is the visitor's space; packs use `walker_space.gd`), copied onto the mover in
  `ensure_mover`.
- `walk` (the scripted walk): the same two cases where it refused "too steep" (`slope_ok`), with `edge` the drop's body.

### K3. New `terrain/walker_riser.gd` (helpers: `top_ahead`, `floor_under`, `steps_on`; TAGS = ["home blocks"])
Only block_mesh.gd's bodies are stepped so. Measured why: with every body steppable, `harden.bush_block` failed (a
0.6 m bush on a bank stood within `step_up` over his feet; he walked onto it, 0.01 m from its middle). The village's
bushes, trunks, rocks, rails, walls, a game's copied colliders, the Home's pieces and the land keep the seam's
behaviour, byte for byte (766 `bush`: the visitor's per-frame path on a non-Home 0.25 m box equals the seam's SHA).

### K4. `build/block_mesh.gd`: the stair collides as drawn
`var stair_steps := true`: a stair cell's collider is its drawn triangles wound back (`_drawn_col`, cached per entry
and side; `_wound`), also for a partly hidden face, instead of shapes.gd's wedge (`e.cv`). The mesh and its hash are
unchanged (the hash reads only the drawn arrays). 752 `build.walk` on the real steps, against the wedge (BUILD.md):

| Walker | On the platform at frame (wedge) | Stopped at frame (wedge) | From the wall (wedge) |
|---|---|---|---|
| `walk`, 4.5 m/s | 73 (73) | 125 (122) | 0.378 m (0.378) |
| `drive`, 4.5 m/s | 76 (76) | 126 (126) | 0.350 m (0.350) |
| `drive`, 9 m/s | 44 (44) | 69 (69) | 0.350 m (0.350) |

`build_case.gd` needs no change: its rows pass as they are.

## Asked (the Director makes them)

### K5. `build/shapes.gd` (frozen): drop the wedge
With K4 the wedge (`STAIR_RISE`, `info.col` for STAIR, `_wedge(col, form, STAIR_RISE)` at :139-153) is built and never
used. Cleaner than K4: in `_info`, no `col` for a stair (then `has_col` is false and every stair polygon carries its
collider triangles, as every other shape), and remove `stair_steps`, `_ccw`, `_drawn_col`, `_wound` from block_mesh.gd.
Replace the comment at :29-34 with: "A stair collides as drawn, four 0.25 m risers: the visitor steps up the risers of
the Home's blocks (terrain/walker_riser.gd; selftest 766)."

### K6. `build/BUILD.md` (frozen), "Colliders"
"The **stair** is the exception: it collides as the ramp of its own form, because the visitor's walkers stop at any
vertical riser" -> "A stair collides as drawn, its four 0.25 m steps: the visitor steps up any riser of the Home's
blocks up to `step_up` (0.55 m: a step, a slab, a slab onto a cube), not a full block (terrain/walker_riser.gd)." The
walker table: the figures of K4.

### K7. `contracts/BUILD.md:44-46` (a contract; the Director's call)
"... and collides as its 45-degree ramp, because the visitor's walkers do not climb a vertical riser
(...PATCHES-WP1.md P2). When the walker steps up risers, stairs collide as drawn." -> "A stair is drawn as 4 steps of
0.25 m and collides as drawn: the visitor steps up a riser of the Home's blocks up to 0.55 m (selftest 766)."

### K8. Lane C: the shape note and the prompt rule (exact wording)
- `command_ask.gd:16-17` SHAPE_NOTES:
  - 2: `"the lower half of a block (a step, a ledge, a ridge cap); walkers step up onto it"`
  - 3: `"four steps of 0.25 m rising toward its rot's side; walkers walk up and down it"`
- `foreman/prompts/world_edit.md:21-22`, replace the "Walking:" sentences with:
  "Walking: a walker climbs stairs (four 0.25 m steps per block) and ramps, and steps up a single riser of half a block
  (a slab on the ground, a cube behind a slab), but not a full block. Every way up a full block must be stairs, ramps
  or a half-block step."
