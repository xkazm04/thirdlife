# WP2 kit, rigs and style: builder report and Director verification

Brief `briefs/BRIEF-WP2-KIT.md`. Builder wall time 18:53 to 19:45 CEST on 2026-11-10 (52 min; harness: 483,638 subagent tokens, 120 tool uses).

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

# WP2 report: kit, rigs and style

## Status
All five priorities are built and verified. Work ran 18:53:35 to 19:45:18 CEST by `date` (52 minutes); I stopped because the list was done. No Godot process of mine is alive, no git command was run, nothing was written outside `kitlab/`, and `engine/` and `foreman/` were not read.

Everything below is under `C:\Users\kazda\kiro\third-life\kitlab\`.

## What exists, against the priority list

1. **Style** (`style/tl_style.gd`): static `TLStyle`, no autoload and no project setting.
   - One palette material plus `glass`, `water`, `holo`, `fx_add`, `fx_mix`; both style files; clamp ranges.
   - `load_style` returns errors (file not applied) and `clamped: ` notes (file applied).
   - Headless: no shader, texture or global parameter is touched; `material()` returns a shaderless stub.
   - A run-time swap in one process works (`k.sh swaptest`).
   - I changed two fog values in `style_overcast.json` to their clamped values (0.0042 to 0.004, 0.02 to 0.008) so the file loads without notes. The look is the same as lane B, which clamped them at load.
2. **Kit** (`kits/tl_kit.gd`, `tl_kit_parts.gd`): `TLKit.list/spec/validate/build/hash`, 36 parts.
   - The 29 required parts plus `timber_frame`, `bush`, `barricade`, `cabin`, `marshal_post`, `entrance`, `stones`.
   - Every body is tagged `tl_material`; `barrier_wall` and `crate` have `Intact` / `Pieces`.
3. **Rigs** (`rigs/`): `TLRigs.build/spec/validate` for `biped`, `vehicle`, `bot`.
   - Clips are pose functions driven by `tick(frame)`, with quaternion blending.
   - Biped: 29 bones, 11 clips, `skate` locomotion mode, stick, skate blades, six sockets plus `stick_blade`, face, `look_at`, `lean`, `colors`.
   - `shoot` and `pass` are upper-body clips: the legs keep striding while the rig moves.
4. **Layout** (`kits/tl_kit_layout.gd`, `tl_kit_layout_build.gd`, `kits/LAYOUT.md`): `tl.layout/1`.
   - Lists everywhere, unknown keys are errors, `_` keys are comments.
   - Every prop is a kit part and every actor is a rig, validated through `TLKit.validate` / `TLRigs.validate`.
   - The four lane-B layouts are ported by `tools/convert_laneb.py` to `lab/layouts/{main,alt,c,d}.json`.
   - `two_rinks.json` has two rinks of different size side by side and three houses.
   - `broken_c.json` carries 12 planted faults.
5. **Tools** (`tools/k.sh`): `validate`, `selftest`, `sheet`, `cap`, `stats`, `owed`, `docs`, `swaptest`.

Documentation: `kits/KIT.md`, `kits/LAYOUT.md`, `rigs/RIGS.md`, `style/STYLE.md`. The part and rig tables are generated from the specs by `k.sh docs`.

**Not built**
- No IK: the left hand is posed near the stick butt by angles.
- No helmet or goalie.
- The rig `seed` param has no effect.
- The lane-B sim (cars driving, crane slewing, `site_advance`, crumble) is not ported; layouts place and pose only.
- The lane-B holo tablet on the avatar is dropped.

## Test output
- `bash tools/k.sh selftest`: exit 0, `[selftest] 86 passed, 0 failed: RESULT PASS`, about 25 s.
  - Cases: 5 style, 37 part (36 parts plus validation), 34 rig, 7 layout, 1 refs.
  - It prints one `WARNING:` line on purpose (the unknown-clip case).
  - Random params are one seeded set per part, not a sweep.
- `bash tools/k.sh validate`: exit 0, `7 files, 0 failed` (2 styles, 5 layouts).
- `bash tools/k.sh validate lab/layouts/broken_c.json`: exit 1, 14 readable errors covering all 12 faults. Examples: `unknown key 'sead' (allowed: ...)`, `props[1].kind 'gazebo' is not a kit part`, `flag.color = flag_z is not a palette key`, `arenas[0].ribs.built = 5.0 is more than ribs.count = 2.0`, `cams.hero: missing required key 'fov'`.

## Part table
Triangles are from defaults; **F** = fracturable.

| Kind | Params | Triangles | | Kind | Params | Triangles |
|---|---|---|---|---|---|---|
| ground_patch | 4 | 12 | | scoreboard | 0 | 300 |
| road_spline | 5 | 3,360 | | tyre_stack | 1 | 480 |
| kerb | 3 | 176 | | watch_tower | 1 | 848 |
| barrier_wall **F** | 6 | 1,614 | | pond | 3 | 22 |
| rink | 9 | 3,192 | | bridge | 4 | 1,904 |
| stands | 5 | 19,688 | | lumber | 4 | 1,080 |
| arch_rib | 6 | 404 | | pallet | 2 | 572 |
| scaffold | 6 | 944 | | cone | 0 | 100 |
| crane | 6 | 3,168 | | barricade | 1 | 576 |
| house | 5 | 2,236 | | cabin | 0 | 620 |
| timber_frame | 4 | 1,316 | | marshal_post | 0 | 280 |
| tree | 3 | 80 | | entrance | 0 | 324 |
| rock | 3 | 160 | | stones | 1 | 176 |
| bush | 2 | 160 | | goal | 3 | 492 |
| fence | 2 | 308 | | puck | 2 | 52 |
| light_mast | 2 | 1,384 | | ball | 2 | 320 |
| sign | 1 | 128 | | paddle | 4 | 312 |
| flag | 2 | 72 | | crate **F** | 3 | 320 |

## Clip table
Judged from `biped_clips.png` (side view), `biped_skate_chase.png` and `biped_params.png`.

| Clip | Judgement |
|---|---|
| idle | Fine; subtle breathing. |
| walk | Reads as a walk; ported from lane B with the torso now leaning forward. |
| run | Reads clearly: forward lean, high knees. |
| skate | Reads as hockey skating from behind (alternating side pushes) and from the side (crouch, lean, stick on the ice). The blade dips slightly into the ice at two phases. |
| skate_stop | Body turns sideways and leans away. Reads as a stop, but less crisp than the shot; there is no spray. |
| shoot | The strongest clip: stick back at shoulder height, swing, high follow-through with the back leg lifting. The left hand leaves the stick during the wind-up. |
| pass | A short low sweep, clearly different from the shot. Subtle from the chase camera. |
| cheer | Arms in a V with hops. Clear from behind, weak from the side because the arms barely clear the large head. |
| fall | Clear: stumble, knees, flat on the front. A held stick will clip the ice. |
| carry | Arms held forward over a walk; there is no carried object in the sheet. |
| work | Hammering lean; readable. |

Bot clips (idle, walk, work, carry, weld) all read in `bot_sheet.png`. Work and carry look alike at a glance.

## Budgets
| Rig | Triangles | Bones | Limit |
|---|---|---|---|
| biped (with stick and skates) | 9,652 | 29 | 12,000 / 30 |
| bot | 1,908 | 11 | 3,000 |
| vehicle | 1,740 | none | 8,000 |

Largest layouts at 2560x1440 (limit 600,000 triangles and 400 draw calls):
- `two_rinks`: 492,403 triangles, 222 draw calls.
- `main`: 488,092 triangles, 245 draw calls.

These were measured while other sessions may have been using the GPU; I took no timings.

## Things the Director should know
- **Skeleton3D trap.** A skeleton posed outside the scene tree stops updating for good, including later in-tree poses. `TLRigNode` works around it, and the selftest runs every clip both in and out of the tree. A kernel stand-in rig would hit the same trap.
- **Bot size.** Lane B showed its 0.8 m bot at 1.45 scale. The bot rig bakes that in, so `scale: 1` is about 1.5 m with hat and beacon.
- **Rink markings.** The toon shader now draws them in the rink's own space from the sheet's UV; the three global rink uniforms are gone. This is what makes two rinks possible.
- **Ported clips.** In the lane-B pose convention, positive x tips an upright bone back, so lane B's run leaned backwards. The ported walk and run lean forward.
- **Layout hash.** It covers the node tree, transforms, collision, tags and the merged static mesh (as source-mesh hashes plus transforms).

## Unverified
- Open circuits (`closed: false`) build without error but I never looked at one.
- Only the main layout was viewed in overcast.
- The two fracturable parts were checked visually (`fracture_sheet.png`), not physically; there is no kernel to fracture them.
- Collision was checked by drawing shapes over 12 parts (`collision_sheet.png`), not by a physics test.

## What `tl.layout/1` still cannot express
The full list is at the end of `kits/LAYOUT.md`. The main gaps:
- Anything that moves or reacts; an actor is one pose.
- Road banking, a custom height profile, junctions or a pit lane.
- A rink that is not a rounded rectangle, or stands at the short ends.
- Holograms of anything but roof ribs.
- A real lake, or snow and ice as terrain.
- Parts parented to other parts.
- Triggers, checkpoints and spawn lists.
- Any kit part that does not exist yet (adding one is a spec row plus a builder branch, and it is then a valid `kind`).

## What a pack author will find awkward
- Euler-degree poses with the "positive x tips back" rule; it is documented in `RIGS.md` but easy to get wrong.
- The stick is fixed in `hand_r` with no IK, so two-handed poses are tuned by eye.
- Dynamic props return no body, only tags on the root.
- `props[].p` as `[x, y, z]` is not snapped, so arena-local heights (ice at `c.y + 0.05`) must be computed by hand.
- Bots are arena-local while actors are world-space.
- Kerbs are part of the road body and tagged `asphalt`.
- The big-headed biped is 2.0 m tall, so arms barely clear the head.
- `TLKit.hash` shadows GDScript's global `hash()` inside `tl_kit.gd`.
- Param types `key`, `points`, `ints`, `dict` and `floats` go beyond the contract's spec shape.

## Questions
1. **Dynamic props.** `puck`, `ball` and `paddle` return no body. The root carries `tl_dynamic`, `tl_shape`, `tl_shape_offset`, `tl_material` and `tl_mass_hint`. Proposed wording: "A part the game moves returns zero bodies and carries `tl_dynamic: true`, `tl_shape`, `tl_shape_offset`, `tl_material`, `tl_mass_hint` on its root; the kernel creates the body."
2. **`load_style` return value.** It mixes hard errors and `clamped: ` notes in one array. Is that acceptable, or should notes go elsewhere?
3. **Particles and shader time.** `TLStyleFx` particles (chimney smoke, weld sparks in layouts) and the shader `TIME` (ice shine, grass sway) run on the engine clock. They are visual only and skipped headless. Is that acceptable, or should every effect go through the kernel's `vfx`?
4. **Extra sockets.** Should `stick_blade` (biped) and `carry` (bot) be added to the contract's socket list?

## Captures
All in `captures\`:
- Owed: `parts_sheet.png`, `biped_clips.png`, `biped_skate_chase.png`, `vehicle_sheet.png`, `bot_sheet.png`, `layout_two_rinks.png`, `port_main_vs_laneb.png` (port on the left), `style_swap.png`.
- Extra: `rig_turntables.png`, `layout_two_rinks_site.png`, `layout_two_rinks_rink_a.png`, `port_c_d_alt_vs_laneb.png`, `style_swap_runtime.png`, `fracture_sheet.png`, `collision_sheet.png`, `biped_params.png`.

I looked at all of them as half-size sheets. The ported main, c, d and alt heroes match the lane-B originals closely. `JOURNAL.md` is current.

---

## Director verification

Done 19:47 to 19:55 CEST on 2026-11-10, after the builder had stopped. The kernel builder was still running Godot in
`engine/` at the time (a separate project), so timings are indicative.

### What was re-run, and the result

| Check | Result |
|---|---|
| `bash tools/k.sh selftest` | exit 0, `86 passed, 0 failed: RESULT PASS` |
| `bash tools/k.sh validate` | exit 0, 7 files (2 styles, 5 layouts), 0 failed |
| `bash tools/k.sh validate lab/layouts/broken_c.json` | exit 1, 14 readable errors |
| Self-containment (Director's own grep) | no `res://` reference outside `kits/`, `rigs/`, `style/` |
| Global random or wall clock (Director's own grep) | none; every `randf` is on a seeded generator instance |
| Global class names | 21, all with the prefixes allotted to WP2 (`TLKit*`, `TLRig*`, `TLStyle*`, `TLMesh`) |
| Size | 5,726 lines in `kits/`, `rigs/`, `style/` |

### What the Director saw in the images

- `captures/layout_two_rinks.png`: two rinks of different size side by side (one roofed with holograms, one open), each
  with its own markings and stands, a house, a crane. This is the layout the lane-B schema could not express, and it
  holds the lane-B look.
- `captures/biped_clips.png`: eleven clips, six frames each, side view. Walk, run, skate, shoot, fall and work read
  clearly. `cheer` is weak from the side, as the builder says. The `skate_stop` label is cut off at the sheet edge.
- `captures/biped_skate_chase.png`: from the chase angle, `skate` reads as skating, `shoot` has a clear wind-up and
  follow-through, `pass` is subtle, `skate_stop` turns the body. Good enough to start hockey on.
- The other sheets were not opened by the Director: `parts_sheet.png`, `vehicle_sheet.png`, `bot_sheet.png`,
  `port_main_vs_laneb.png`, `style_swap.png`, and the extras. The builder says it looked at all of them.

### What is not verified

- **Nothing has met the kernel.** Fracturable parts were never fractured, tagged bodies never got physics properties,
  rigs were never driven by a controller. The move into `engine/` and that first contact are WP4's first step.
- Triangle and draw-call figures are the builder's (`two_rinks` 492,403 triangles and 222 draw calls); the selftest
  re-confirmed the triangle count only.
- Open circuits were built but never looked at.

### Director's decisions on the builder's questions (contract amended on 2026-11-10)

1. **Dynamic props**: accepted as proposed. A part the game moves returns no body and carries `tl_dynamic: true`,
   `tl_shape`, `tl_shape_offset`, `tl_material`, `tl_mass_hint` on its root; the kernel creates the body.
2. **`load_style` return**: accepted. Entries starting with `clamped: ` are notes and the file is applied; any other
   entry is an error and the file is not applied.
3. **Particles and shader time on the engine clock**: accepted for visual-only effects that are skipped headless and
   never enter `state_hash`. Consequence recorded: a `capture` at an exact physics frame is not pixel-identical between
   runs. Effects that carry game meaning must go through the kernel.
4. **Extra sockets**: `stick_blade` (biped) and `carry` (bot) are added to the contract.

Known trap to carry into WP4: a `Skeleton3D` posed outside the scene tree stops updating; the kernel's stand-in rig and
any pack that builds a rig before adding it to the tree must go through `TLRigNode`'s workaround.

### Size

5,726 lines, 36 kit parts, 3 rig families, 52 minutes of builder time, 483,638 tokens.
