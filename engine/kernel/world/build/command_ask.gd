extends RefCounted
## M4 (spark world-sandbox): the ask of the LLM command bar, `tl.world-edit-ask/1` (contracts/BUILD.md "The LLM
## command bar"; COMMAND.md has every key). What the exe measured round the cursor, so the model builds from facts:
## the sentence, the cursor cell and the facing, a region read (home_build.gd `read_region`, 32 x 24 x 32 cells by
## default), the ground's height per column (the land layer's `height_at` when M2 gives one, else home/hook.gd
## `ground_y`), the columns protection refuses (with the reason), the op kinds the Home applies now, the shape,
## material, paint and part tables, and the caps. Static, no state; reads the Home, never writes it.

const Blocks := preload("res://kernel/world/build/blocks.gd")
const SCHEMA := "tl.world-edit-ask/1"
const SIZE := Vector3i(32, 24, 32)       # cells read round the cursor: x, y, z
const BELOW := 4                         # cells of the region below the cursor's cell
const MAX_OPS := 4000
const SHAPE_NOTES := {
	1: "a full 1 m block",
	2: "the lower half of a block (a step, a ledge, a ridge cap)",
	3: "four steps of 0.25 m rising toward its rot's side; walkers climb it",
	4: "a 45-degree slope rising toward its rot's side; walkers climb it",
	5: "a thin 0.25 m column in the middle of the cell (porch posts, railings' posts)",
	6: "a window: a frame of its material and a glass pane; the pane faces z at rot 0 and 2, x at rot 1 and 3",
	7: "a 45-degree roof slope rising toward its rot's side; neighbouring roofs join into ridges and corners",
	8: "a fence or railing that joins to fences, posts and walls next to it",
}
const MAT_NOTES := {
	1: "light grey stone (walls, foundations, paths)",
	2: "dark grey stone (trims, plinths, bridges)",
	3: "pale planks (walls, floors, decks)",
	4: "dark wood (frames, beams, doors, posts)",
	5: "red-brown roof tiles",
	6: "blue-grey slate (roofs)",
	7: "smooth concrete",
	8: "warm sandstone (walls, steps)",
	9: "white plaster (walls, trims)",
}
const PAINTS := ["grass", "grass_dark", "grass_dry", "dirt", "sand", "stone", "rock_warm", "cliff", "valley"]
const NOT_YET := "not built yet"


## The ask for `sentence` at `cursor` facing `facing` (home_build.gd `rot_facing` of the camera's forward). `build`:
## home_build.gd; `land`: the landscape node (its meta "tl_home": the ground). Returns the ask, or {"error"}.
static func make(build: RefCounted, land: Node, sentence: String, cursor: Vector3i, facing: int, size := SIZE) -> Dictionary:
	var lo := Vector3i(cursor.x - size.x / 2, clampi(cursor.y - BELOW, Blocks.Y_MIN, Blocks.Y_MAX), cursor.z - size.z / 2)
	var hi := Vector3i(lo.x + size.x - 1, mini(lo.y + size.y - 1, Blocks.Y_MAX), lo.z + size.z - 1)
	var read: Dictionary = build.read_region(lo, hi)
	if read.has("error"):
		return read
	var ask := {"schema": SCHEMA, "sentence": sentence.strip_edges(), "cursor": [cursor.x, cursor.y, cursor.z], "facing": facing,
		"region": {"min": [lo.x, lo.y, lo.z], "max": [hi.x, hi.y, hi.z]}, "ops": ops_now(build, cursor)}
	var blocks := []
	for b: Array in read.blocks:
		var c := int(b[3])
		blocks.append([int(b[0]), int(b[1]), int(b[2]), Blocks.shape_of(c), Blocks.mat_of(c), Blocks.rot_of(c), 1 if Blocks.flip_of(c) else 0])
	ask["blocks"] = blocks
	var g := ground(build, land, lo, hi)
	ask["ground"] = {"min": [lo.x, lo.z], "rows": g}
	var refused := refused_columns(build, lo, hi, g)
	if not refused.is_empty():
		ask["refused"] = refused
	ask["shapes"] = table(Blocks.SHAPE_NAMES, SHAPE_NOTES)
	var names := {}
	for id: int in MAT_NOTES:
		names[id] = Blocks.MAT_KEYS[id]
	ask["mats"] = table(names, MAT_NOTES)
	if (ask.ops as Array).has("paint"):
		ask["paints"] = PAINTS.duplicate()
	if (ask.ops as Array).has("put"):
		ask["parts"] = parts()
	var water := water_of(build, lo, hi)
	if not water.is_empty():
		ask["water"] = water
	var layers := {}
	for k: String in read:
		if not (k in ["min", "max", "blocks"]):
			layers[k] = read[k]
	if not layers.is_empty():
		ask["layers"] = layers
	ask["caps"] = {"ops": MAX_OPS, "blocks_left": maxi(0, int(build.blocks.cap_home) - int(build.blocks.total))}
	return ask


## The op kinds the Home applies now: every layer's `offers()` in the layers' order (blocks: place, remove; land: land,
## paint; pieces: put, lift; M5 water: pour, drain; paths: path, unpath; plants: plant), a stub layer offering none.
## The model's boxes (`fill`, `clear`) are the Foreman's (world_edit_check.ts expands them into place and remove).
static func ops_now(build: RefCounted, _at: Vector3i) -> Array:
	var out := []
	for l: RefCounted in build.get("layers"):
		if l.has_method("offers"):
			for o: Variant in l.call("offers"):
				if not out.has(str(o)):
					out.append(str(o))
	return out


## The water in the box (the water layer's `water_runs`: [{"y", "runs": [[z, x0, x1], ...]}]), [] when there is none
## or no water layer measures it. M5's lanes add the river's water here.
static func water_of(build: RefCounted, lo: Vector3i, hi: Vector3i) -> Array:
	var w: RefCounted = build.layer("water")
	return (w.call("water_runs", lo, hi) as Array) if w != null and w.has_method("water_runs") else []


## rows[z - lo.z][x - lo.x]: the y of the cell a block takes standing on the ground at the column (x, z), the cell
## holding the point just above the ground (home_build.gd `cell_at_ray_hit`).
static func ground(build: RefCounted, land: Node, lo: Vector3i, hi: Vector3i) -> Array:
	var land_layer: RefCounted = build.layer("land")
	var by_land := land_layer != null and land_layer.has_method("height_at")
	var home: Object = land.get_meta(&"tl_home") if land != null and land.has_meta(&"tl_home") else null
	var rows := []
	for z in range(lo.z, hi.z + 1):
		var row := []
		for x in range(lo.x, hi.x + 1):
			var h := 0.0
			if by_land:
				h = float(land_layer.call("height_at", x + 0.5, z + 0.5))
			elif home != null:
				h = float(home.call("ground_y", x + 0.5, z + 0.5))
			row.append(clampi(int(floorf(h + 0.01)), Blocks.Y_MIN, Blocks.Y_MAX))
		rows.append(row)
	return rows


## The columns protection refuses at their ground cell, as [{"reason", "runs": [[z, x0, x1], ...]}] (x runs per z row),
## asked with the visitor out of the way (he moves; the exe still refuses a cell he stands in when the answer is kept).
static func refused_columns(build: RefCounted, lo: Vector3i, hi: Vector3i, rows: Array) -> Array:
	var protect: RefCounted = build.protect
	var was: Callable = protect.get("visitor_at")
	protect.set("visitor_at", func() -> Vector3: return Vector3(0, -1e6, 0))
	var by := {}                            # reason -> runs
	var order := []
	for j: int in rows.size():
		var z := lo.z + j
		var run_why := ""
		var x0 := 0
		for i: int in (rows[j] as Array).size() + 1:
			var why := ""
			if i < (rows[j] as Array).size():
				why = str(protect.call("refusal", Vector3i(lo.x + i, int(rows[j][i]), z)))
			if why == run_why:
				continue
			if run_why != "":
				if not by.has(run_why):
					by[run_why] = []
					order.append(run_why)
				(by[run_why] as Array).append([z, lo.x + x0, lo.x + i - 1])
			run_why = why
			x0 = i
	protect.set("visitor_at", was)
	var out := []
	for r: String in order:
		out.append({"reason": r, "runs": by[r]})
	return out


static func table(names: Dictionary, notes: Dictionary) -> Array:
	var out := []
	for id: int in notes:
		out.append({"id": id, "name": str(names[id]), "note": str(notes[id])})
	return out


## The kit parts a put may name (TLKit), each with the first sentence of its doc.
static func parts() -> Array:
	var out := []
	for k: String in TLKit.list():
		var doc := str(TLKit.spec(k).get("doc", k))
		out.append({"kind": k, "note": doc.get_slice(". ", 0).trim_suffix(".")})
	return out
