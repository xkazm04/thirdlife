# N2: patches to files outside my scope

None of these files was edited in the copy `site/_work/n2/engine`: every N2 test ran without them. They matter the
first time a world of several packs gets a window and a player.

## 1. `kernel/api/tl_orbit_cam.gd`, line 61 (`_unhandled_input`)

```gdscript
-	var ctx: TLContext = TLContext.current
+	var ctx: TLContext = TLContext.of(self)
```

Reason: `TLContext.current` is now "the pack the kernel is calling right now". `_unhandled_input` is called by the
engine, not by the kernel, so in a world `current` is null there (in a single-pack run it still is the pack, so
`tl.sh play` works unchanged). `TLContext.of(node)` finds the camera's own pack through its holder. Without the
patch the mouse does not orbit or zoom the camera of a pack inside a world.

## 2. `kernel/api/tl_cameras.gd`, line 77 (`activate`)

```gdscript
-	cam.current = true
+	var pack: TLContext = TLContext.of(self)
+	if pack == null or pack.on_stage:
+		cam.current = true
```

and in `kernel/api/tl_context.gd` (mine; not added yet, so that it does not sit there unused):

```gdscript
var on_stage: bool = true              ## false while another pack owns the window's camera (set by the world host)
```

Reason: a viewport has one current camera. In a world every pack that calls `ctx.cameras.activate(view)` takes it,
and the last caller wins. Only the pack the player is in may take the window's camera; the world host would set
`on_stage` when the player enters or leaves a plot. Not needed headless (nothing is drawn), so not measured.

## 3. `kernel/runner/lint.gd`: a new note, not a failure (proposal, no exact patch)

List every `global_position`, `global_transform`, `global_basis`, `to_global(` and `look_at(` in `scripts/` and
`tests/` under a new composability key, for example `world_coordinates: [{file, line, pattern}]`.

Reason: measured in `BENCH.md`, test 5. All three seeds and `pack_min` read world coordinates in `_pack_state()`
or in their bot. Standing 64 m from the origin their bots stop winning (seed_drive and seed_paddle never finish),
which is a game bug, not rounding. As long as a pack is simulated at its own origin (way b) this does not matter;
it matters the day a pack's nodes stand at a world offset (way a), and for anything that hands a position from one
pack to another.

## 4. Seeds, kits, rigs, style: no patch

`TLStyle`, `TLStyleFx` (materials, the palette texture, 14 global shader parameters) and `TLKitLayout._schema` are
statics shared by every pack. They are the shared look and a read-only schema. What a pack adds to them while it
runs are cache entries whose content does not depend on the pack (`TLStyle._flat`: a material per colour;
`TLStyleFx._puffs`, `_discs`: a mesh per key), so a second pack reads the same value the first one would have
made. They were left alone on purpose.

## 5. `kernel/runner/lint.gd`: fence `get_tree()` group calls (proposal, no exact patch)

Add `get_tree().get_nodes_in_group`, `get_first_node_in_group` and `call_group` to the fence (advice: "keep your
own list, or ask a TLTrigger").

Reason: scene-tree groups are tree-wide. The kernel's own group (`tl_ball`) is now per pack, and the group names a
pack passes to `TLBodies.make`, `TLBall.create` and so on are only ever tested on one body (`is_in_group`), which
is safe. But a pack that asks the tree for a group by name would get the nodes of every pack in the world that
uses the same name. No seed, example, kit or rig does this today (grep), and lint does not stop it.
