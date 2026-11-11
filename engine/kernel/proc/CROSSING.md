# P8: what crosses a process boundary, class by class

For whoever freezes kernel API v1. "S" is the process that simulates a pack (no window), "D" the process that draws
it. Read with `PROCESS.md` (the numbers) and `PATCHES-P8.md` (the exact text of the changes).

How to read a verdict:

- **crosses**: works today with the pack unchanged; D needs only the stream. "(measured)" means the spike did it and
  a capture or a figure shows it; without that word it is a reading of the source.
- **crosses as an event**: S keeps a record of the call, D replays it through the kernel's own preset.
- **crosses as a build record**: the node carries, or could carry, the two values that make it again in another
  process (`tl_kind`, `tl_params`). Needed only when D may not run the pack's code (sharing with strangers).
- **does not cross**: the pack holds a node or a value that exists, or means something, only where there is a window.

## The three rules behind every line

1. **Simulation state crosses for free.** Everything the pack reads back that the simulation owns (bodies, rules,
   contacts, triggers, the random generator, its own nodes' transforms) lives in S and never needs to cross. The
   state hash is equal in S and in one process for all four packs.
2. **A picture crosses as "what to build" plus "where it is now".** Per tick: local transforms that changed,
   visibility, HUD text, bone poses, the camera's lens. Measured: 0.26 to 9.4 kB per tick.
3. **Nothing may be read back from the picture.** A window's size, what a camera sees, whether a sound or an
   effect has ended, a material's parameters: S does not have them. Every API that returns one of these is on the
   "does not cross" list below, and the list is short because the kernel already counts lifetimes in frames.

## Kernel API

| Class | Verdict | Detail |
|---|---|---|
| `TLContext` | crosses, with one field that must change meaning | `rng`, `seed`, `frame`, `max_frames`, `read_json`, `load_script`, `pack_state`, `pick`, `shuffle`, `seconds`, `frames`, `info`, `space_state_of`: S only, nothing to cross. **`headless` does not cross as defined**: in S it is true and tells the pack to "skip purely visual work", so the work is built nowhere unless D runs the pack's code too. For v1 it has to mean "do not spend time on looks here", never "this will not be seen". `pack_dir` is a machine path; a restricted S can still read it. |
| `TLInput` | crosses (measured) | Named actions with a strength per tick are already the wire format. D samples the devices and sends `[action, strength]` each tick; S latches. Cost: one frame (see PROCESS.md). Missing: a door for remote samples that is not the bot's `press()` and a way to tell D the key bindings without running the pack (patch 1). `action_pressed` / `action_released` fire in S: fine. |
| `TLCameras` | pose and lens cross (measured); two calls do not | `add_view`, `chase`, `orbit`, `activate`, `shake`, `set_subject`, `subject_of`, `views`, `has_view`: the cameras are nodes in S, their transform, `fov`, `h_offset`, `v_offset` and "which is active" cross (the drive capture is a chase camera followed across). **`subject_px()` and `frame()` do not cross**: they project through the camera with the viewport's size, and S has no viewport of the player's size; `subject_px` returns a number about a window that does not exist, `frame` places the camera for an aspect ratio S guessed. **`view(name)` hands the pack the raw `Camera3D`**: `unproject_position`, `is_position_in_frustum` and the projection are the same problem. Fix for v1: the viewport's aspect is an input D sends once and on resize; `subject_px` goes (or is defined on a nominal 16:9). |
| `TLChaseCam`, `TLOrbitCam` | cross (measured for chase) | Frame-counted smoothing runs in S. `TLOrbitCam.yaw_basis()` is read back by packs for camera-relative movement: it works because the camera's pose is simulation state in S. Consequence: turning the camera has the same extra frame as every other input. `bind_actions` goes through `TLInput`: crosses. |
| `TLHud` | crosses (measured) | Labels exist in a headless process; sources (`add_score`, `add_clock`, `add_speed`, `add_bound`) are evaluated in S and the text crosses when it changes. `text_of` reads S's own copy. A widget is fully described by id, anchor and text: a build record is trivial. Not synchronised by the spike: the layer's own `visible` (`hide_all`). A pack that adds its own `Control` to the layer by hand has no record. |
| `TLAudio` | crosses as an event (measured: 132 events in the wall run) | Every call is recorded in `ctx.audio_events` even headless; D plays the preset. `count`, `events`: S's own record. Missing in the record: `volume_db` (patch 2). There is no "sound finished" signal in the API: keep it that way. |
| `TLVfx` | `burst`, `attach`: cross as an event (measured: 33 effects in the wall run); `squash`: crosses; `trail`: does not | S makes a `TLVfxNode` without particles and counts its life in frames; D makes the particles from the preset at the node's place. `opts` (direction, scale, colour) are thrown away in S (patch 3). `squash` changes a visual's scale from a frame-counted helper node that also runs headless: it crosses as a transform (read, not measured). `trail` draws nothing and records nothing headless. |
| `TLVfxNode` | crosses | Lifetime in physics frames, freed in S, the removal crosses. |
| `TLBodies` | simulation: S only; picture: build record | `make`, `ground`, `trigger`, `from_part`, `drive`, `push`, `contact`, `is_dynamic_part`. Bodies carry `tl_material` and their collision shape, enough to draw a stand-in, and `from_part` keeps the kit part (which has `tl_kind`, `tl_params`) under the body. |
| `TLBall`, `TLBiped`, `TLVehicle` | cross (measured) | Physics and control in S. The picture is a kit part or a rig plus transforms plus bone poses. `drive_from_input(input, map, view)` takes the camera's basis from S. |
| `TLContact`, `TLDamage`, `TLTrigger`, `TLRules`, `TLSteer`, `TLLaws` | S only | Nothing to draw, nothing to cross. Signals fire in S. |
| `TLFracture` | crosses once the stream can say "moved" (measured) | When a block breaks the kernel REPARENTS its 48 pieces. A stream that knows only "removed" and "added" loses the picture of every piece (the first run drew boxes). The spike's stream now carries `moved: [node, new parent]`; D reparents its own node. `Intact`'s visibility crosses as visibility. |
| `TLSpawner` | does not cross unless what the factory builds has a build record | The factory is pack code that runs in S at a later tick. If D built the scene by running the pack's setup, D never saw the factory run: the spike draws such bodies as boxes and counts them (`bodies_without_picture`). With build records it is an ordinary "added" row. This is the line that separates "D runs the setup once" from "D builds from records". |

## Kit, rigs, style

| Class | Verdict | Detail |
|---|---|---|
| `TLKit.build`, `TLRigs.build` | cross as a build record, today | Both tag what they return with `tl_kind` and `tl_params`. In seed_wall 216 of 266 nodes at the start are a tagged part or inside one. |
| `TLKit.build_layout` (`TLKitLayout`, `TLKitLayoutBuild`) | crosses as a build record after patch 4 | The layout is a data file of the pack; D can build the whole venue from the same JSON with no pack code. The root is tagged with the layout's name only. The dictionary it returns (`nodes`, `cams`) is read by the pack in S: fine, S builds the geometry too (it needs the collision). Parts made only where there is a window (window lights, the light mast's light, the welding flash) are D's alone and need nothing from S. |
| `TLKitArena`, `TLKitHouse`, `TLKitNature`, `TLKitSite`, `TLKitRoad`, `TLKitWall`, `TLKitTerrain`, `TLKitPath`, `TLKitParts`, `TLMesh` | S: fine; picture: only through a tagged part | These return a `TLMesh` or build under a part. A pack that calls a generator directly and wraps the mesh in its own `MeshInstance3D` makes a node with no record: it is drawn only if D runs the pack's code. `TLKit.hash`, `triangles`, `shape_sig` read the generator's arrays and work headless. |
| `TLRigNode`, `TLRigBiped`, `TLRigBot`, `TLRigVehicle` | poses cross (measured); window-only extras do not | `tick` computes the skeleton's pose headless too; the spike sends every bone that changed (10 numbers a bone; six skaters are most of the hockey game's 9.4 kB per tick). `socket()` nodes follow the skeleton in each process. `play`, `set_param`, `set_locomotion`, `metrics`, `clips`, `look_angles`: S only. **Do not cross**: what a rig switches on only where there is a window (the bot's beacon glow and welding flash, the vehicle's nitro light): in S the nodes do not exist, in D nobody ticks the rig. They need to be parameters the rig computes everywhere and D applies. |
| `TLStyle` | data crosses; materials do not | `color`, `num`, `palette`, `has_key`, `index`, `is_toon`: tables, the same in both. `material`, `material_instance`, `flat_material`: in S every one is the same empty stub, so **a parameter a pack sets on a material is written to nothing** and never reaches D. v1 needs a kernel verb for "this node's look parameter is now x" that is kept as node state. `install`, `ground`, `load_style`: the kernel's, D only. |
| `TLStyleFx` | does not cross | `glow`, `sparks`, `smoke`, `dust_burst`, `nitro_trail`, `tyre_dust`, `preset`, `trail` return particle or mesh nodes that are null or empty headless, with no record. Reach them only through `TLVfx` (which records) or give them the same record. `squash`: see `TLVfx`. |

## What a pack does outside the API that stops working

Allowed by the fence today, and wrong in S:

- anything in `_process` meant to smooth the picture: it runs at S's loop rate, not at the display's;
- waiting for something only a window has: a particle system's or an audio player's `finished`, a
  `VisibleOnScreenNotifier3D`, `RenderingServer.frame_post_draw`, the frame rate;
- reading the pointer or a raw key (already outside the contract: input is `TLInput`);
- naming: a node the engine named (`@Node3D@41`) has a different name in each process. The spike matches unnamed
  nodes by class and order, which holds only while both trees come from the same code (patch 5 gives every node of
  a pack a number in the order it entered the tree).

## The stream the spike uses (one message per tick, S to D)

`["t", frame, ids, transforms(12 numbers each), visibility, added[id, key, class, kind, parent, preset], removed,
labels[id, text], bones[id, poses], cameras[id, fov, h_offset, v_offset], sounds[preset, position], active camera,
echo of D's last input number, moved[id, new parent]]`, and D to S `["i", number, actions, strengths]`.
Encoded by the engine (`var_to_bytes`; objects are never decoded), a 4-byte length in front, TCP on 127.0.0.1.
Not a proposal for a format: it is what was enough to draw four games.
