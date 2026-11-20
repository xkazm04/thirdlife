# L5 hockey-fun: what this lane needs from files outside its column

## 1. Kernel: `TLVfx.burst` draws a one-shot burst at the parent's origin in a window (engine/kernel/api/tl_vfx.gd)

Seen in a window on 21 Nov (clip `hit_v2.mp4`, before the pack's workaround). A body check at (-10.9, 2.5) put its ice
spray on the centre spot (0, 0), the pack's origin. The bursts the hockey pack already had (shot spray, goal flash,
confetti) did the same. Headless runs cannot see it.

Cause (read in the code): `burst()` adds the effect node under `parent` and only then sets `fx.global_position`. With
physics interpolation on, the node's first drawn transform is interpolated from where it entered the tree. A one-shot
CPUParticles3D (explosiveness 0.92, `local_coords = false`) emits almost all its particles in that first frame, so they
come out at the parent's origin. Calling `reset_physics_interpolation()` on the returned node did not cure it (clip
`hit_v2.mp4`).

The pack's workaround (`scripts/fun/fun.gd` and `scripts/fx/fx.gd`, `burst` / `_burst`) puts each burst under a plain
Node3D. That node is positioned before it enters the tree, and the pack frees it 200 frames later.

Proposed kernel fix, one line, for any pack: in `TLVfx.burst`, set the position before adding the node:

```gdscript
var fx: TLVfxNode = _make(preset, opts, true)
fx.position = parent.global_transform.affine_inverse() * position if parent is Node3D else position
parent.add_child(fx)
fx.global_position = position
```

`TLVfx.attach` is not affected: it attaches to a moving target and emits continuously.
