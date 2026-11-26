# PATCHES-WP1: changes outside `kernel/world/build/` that WP1 proposes (the Director decides)

## P1. `home/hook.gd` `grow`: hand the builder what protection needs (for WP2)

`grow` has the valley (its `sites` are game lots) and the visitor's space. After `parent.set_meta(&"tl_home", home)`:

```gdscript
	parent.set_meta(&"tl_valley_sites", valley.sites)     # build/protect.gd from_sites: the Home's game lots
```

WP2 then attaches the builder where it mounts build mode, with `walk` being the boot/village.json document:
`HomeBuild.attach(parent, walk, null)` followed by `b.protect.from_sites(parent.get_meta(&"tl_valley_sites", []))`.
If the attach happens inside `grow` instead, pass `valley` directly: `HomeBuild.attach(parent, walk, valley)`. `grow`
does not get the walk today (only `cfg = walk.landscape`). Plots are `walk.plots`, so whoever attaches needs the walk.

## P2. The visitor cannot step up a vertical riser (`terrain/world_body.gd` `_ground_move`, `world_space.gd` `walk`)

**Evidence** (build_case.gd build.walk, 26 Nov 2026):

| Riser | Walker | Result |
|---|---|---|
| 0.5 m (blocks colliding as drawn) | `walk` 4.5 m/s | stopped at the first riser (feet never above 31.00) |
| | `drive` 4.5 m/s | reached the first step once (31.52), then stopped at the second |
| | `drive` 9 m/s | stopped at the first riser (31.02) |
| 0.125 m | `drive` 4.5 m/s | stalled (highest feet 31.83) |
| 45-degree wedge (what WP1 now uses for stairs) | all three | climbed |

`step_up` is 0.55 m, but it never takes effect against a vertical face. After the lifted sweep, the probe down meets the
step's edge with the capsule's round foot: the centre has moved only one frame (0.075 m at walking speed) past
touching, so the contact normal is steep.
- `walk` refuses the move (`slope_ok` false), so he stays put.
- `_ground_move` sees `landed.y - from.y` > SNAP_DOWN (0.35) and runs `_steep_n`. The centre ray finds the lower floor,
  so it returns ZERO ("the round foot met an edge") and he drops back.

The same holds for a slab (0.5 m), a curb, or any pack biped's step.

**Proposal** (not made; outside WP1's scope, and visit.gd and walker feel are shared): in `_ground_move`, when the
down probe's contact is not walkable, cast a ray straight down at the capsule's centre plus `radius` along the move
direction. If that ray finds a walkable top within `step_up` of the feet, and the capsule fits standing there
(`_standing_floor`'s fit test), put him on it. Selftests that must stay green: 751 home walk, 260-k8. If it lands,
`shapes.gd` can drop the stair's wedge collider (STAIR_RISE / `info.col`) and collide stairs as drawn.

## P3. `kernel/runner/visit.gd`: tell protection where the visitor is (WP2)

`drive` moves no body: the capsule's place is the `pos` that visit.gd keeps. Build mode sets
`build.protect.visitor_at = func() -> Vector3: return <the visitor's feet>`. With it unset, protection reads the
body's transform, which only `place` and `walk` set.
