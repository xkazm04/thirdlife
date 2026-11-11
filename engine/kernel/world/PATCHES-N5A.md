# N5a: patches for files outside the builder's scope

Nothing below is applied in this copy. Entries 1, 2 and 5 are exact changes with their reason; entry 3 is a
measurement with three proposals and no exact patch (the change is a kit author's); 4 and 6 are notes.

## 1. `seeds/seed_paddle/scripts/main.gd`: the `_pack_save` / `_pack_load` example in a seed

The brief asks for both functions in one seed; seeds are outside this builder's file scope, so the working example is
in `kernel/examples/ex_bounce/scripts/main.gd` (same shape) and this is the seed's patch. Insert before
`func _pack_state() -> Dictionary:` (line 164):

```gdscript
## Optional: what a world keeps of this game when it saves or unloads it (plain data only). The world rebuilds the
## pack from its seed, calls `_pack_start`, then `_pack_load` with this. The rally starts again; the score survives.
func _pack_save() -> Dictionary:
	return {"scores": rules.scores.duplicate()}


func _pack_load(saved: Dictionary) -> void:
	var kept: Dictionary = saved.get("scores", {})
	for side: String in kept.keys():
		if rules.scores.has(side):
			rules.scores[side] = int(kept[side])
	for side: String in SIDES:
		hud.set_text(StringName("score_" + side), str(rules.score(side)))
```

Reason: item 5 of the brief. Two functions that no verify verb calls: the seed's hashes do not change (checked for
`ex_bounce`: `tl.sh selftest` passes with the same functions in it). The `hud.set_text` loop is NOT tested: check the
widget id (`score_<side>`, API.md section 13) when applying; drop the loop if the HUD follows `rules.scores` itself.

## 2. `contracts/PACK.md`: two optional entry functions, and the default of `on_leave`

Add to the section "Scripts" (optional functions of the entry script):

```
| `_pack_save() -> Dictionary` | optional | plain data the world keeps of this game in a world file or while the pack is not in memory (ledger) |
| `_pack_load(data: Dictionary) -> void` | optional | called once after `_pack_start` on a pack that was rebuilt from its seed, with what `_pack_save` returned |
```

and to the row `on_leave` of the amendments of 2026-11-11: "default `bot` when the manifest lists a test, else
`pause`" (the scheduler does this; the manifest requires at least one test today, so the default is always `bot`).

and to the section "Composability figures": lint now also reports `kit_parts_used` (kit parts placed by the pack's
`tl.layout/1` files plus `TLKit.build("<kind>"` calls), `kit_kinds_used` (the distinct kinds, sorted),
`kit_build_calls`, `world_coordinates` and `world_coordinates_by` (uses of `global_position`, `global_transform`,
`to_global(`, `look_at(` in the pack's scripts). Figures, never pass/fail.

Reason: `kernel/world/world.gd` calls the two functions (item 5) and `kernel/runner/lint.gd` writes the figures
(item 6); the contract is where a pack author and the Foreman look.

## 3. `kits/tl_kit_layout_build.gd`: terrain and forest are 87 to 95 % of a seed's loading time

Measured (TIERS.md, "Loading"): of 2.1 to 4.3 s per seed pack, `_build_nature` is 0.8 to 2.3 s and `_build_terrain`
0.8 to 1.1 s; all parts, props, walls and actors together are 0.1 to 0.4 s. Nothing is shared between two copies of a
seed. With `forest.scatter` and `terrain.far` off (two switches the layout format already has) the three seeds load
in 0.4 to 0.7 s and end in the same bot hashes.

What this copy does instead (in scope): `ctx.read_json` hands a `tl.layout/1` file out with both switches off when
the world host was started with `--scenery=plot` (`kernel/api/tl_context.gd`). That is a seam, not the fix. The fix
belongs in the kit, in this order:

a. A cache of the scatter prototypes. `_build_nature` calls `TLKitNature.pine(100 + v, ...)`, `broadleaf`, `rock`,
   `bush`, `grass_tuft` with the same arguments in every pack; each builds a `TLMesh` in GDScript, triangle by
   triangle. Proposed, in `kits/tl_kit_layout_build.gd` `_scatter(holder, mk, ...)`: build the `ArrayMesh` of `mk`
   once per (generator, arguments) in a `static var _proto: Dictionary` and give every pack's `MultiMesh` the same
   mesh. Not written as an exact patch: `_scatter` takes a built `TLMesh`, so the cache has to sit one call earlier,
   in the callers, and that is a kit author's change.
b. `terrain.build_grid()` and `build_near()` run for every pack although two packs with the same `terrain` block and
   seed get the same grid. A cache keyed by the terrain block's JSON text would take the terrain's 0.8 to 1.1 s off
   the second copy of a seed (an estimate from the table, not measured). In a world the far terrain and the forest should not be per pack at all: plots
   stand 60 m apart and each seed scatters a forest over 400 x 380 m and mesas 200 m away.
c. Spreading over frames: `TLKitLayoutBuild.run` is one call. The cheap split is to return after the bodies are
   built (everything the simulation needs: 0.1 to 0.4 s) and let the kernel call a second step
   (`build_scenery()`), one piece per frame, for terrain far, nature and waterfalls.

## 4. `tools/tl.sh`: nothing

`world.sh` carries every new command; `tl.sh selftest` already runs `tools/selftest.sh`, which has the four new cases.

## 5. `foreman/fixtures/engine/kernel/runner/verbs.json`

Follows `engine/kernel/runner/verbs.json` (N2's rule): the `world` mode has twelve new options (`walk`, `replay`,
`log`, `tiers`, `cost`, `ticks`, `world`, `save`, `name`, `seed`, `plot-spacing`, `scenery`). Copy the file.

## 6. `kernel/world/draw/**` (the builder who draws the world): what the scheduler offers

Not a patch, a pointer. Every holder (`kernel/world/pack.gd`) carries the meta `tl_plot` =
`{id, origin: Vector3, yaw}` (where the plot is in the world; the pack itself is simulated at its own origin) and
`ctx.on_stage` is true only for the stage pack (set on every `tier` event). The tier of plot `i` is
`world.sched.plots[i].tier`.
