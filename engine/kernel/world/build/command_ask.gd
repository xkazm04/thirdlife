extends RefCounted
## M4 (spark world-sandbox): the ask of the LLM command bar, `tl.world-edit-ask/1` (contracts/BUILD.md "The LLM
## command bar"; COMMAND.md has every key). What the exe measured round the cursor, so the model builds from facts:
## the sentence, the cursor cell and the facing, a region read (home_build.gd `read_region`, 32 x 24 x 32 cells by
## default), the ground's height per column (the land layer's `height_at` when M2 gives one, else home/hook.gd
## `ground_y`), the columns protection refuses (with the reason), the op kinds the Home applies now, the shape,
## material, paint and part tables, and the caps. Static, no state; reads the Home, never writes it.
## M5 (lane C): `water`, the measured water (the valley's river and ponds, home/valley.gd `water`, merged with the water
## layer's `water_runs`; in a water column `ground` is the bed), and tables of what play has unlocked only (unlocks.gd:
## materials 11 brick and 12 plaster once granted, the kit parts without the locked kinds).

const Blocks := preload("res://kernel/world/build/blocks.gd")
const Unlocks := preload("res://kernel/world/build/unlocks.gd")
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
	9: "white trim (edges, small surfaces; a large white wall reads as blank)",
	11: "red brick (walls, chimneys)",
	12: "warm plaster (house walls)",
}
const PAINTS := ["grass", "grass_dark", "grass_dry", "dirt", "sand", "stone", "rock_warm", "cliff", "valley"]
const NOT_YET := "not built yet"


## The ask for `sentence` at `cursor` facing `facing` (home_build.gd `rot_facing` of the camera's forward). `build`:
## home_build.gd; `land`: the landscape node (its meta "tl_home": the ground); `unlocks`: unlocks.gd of the Home (null:
## nothing earned yet, every rule unmet). Returns the ask, or {"error"}.
static func make(build: RefCounted, land: Node, sentence: String, cursor: Vector3i, facing: int, size := SIZE, unlocks: RefCounted = null) -> Dictionary:
	if unlocks == null:
		unlocks = Unlocks.new("")
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
	var hs := heights(build, land, lo, hi)
	var g := cells_of(hs)
	ask["ground"] = {"min": [lo.x, lo.z], "rows": g}
	var refused := refused_columns(build, lo, hi, g)
	if not refused.is_empty():
		ask["refused"] = refused
	ask["shapes"] = table(Blocks.SHAPE_NAMES, SHAPE_NOTES)
	ask["mats"] = mats(unlocks)
	if (ask.ops as Array).has("paint"):
		ask["paints"] = PAINTS.duplicate()
	if (ask.ops as Array).has("put"):
		ask["parts"] = parts(unlocks)
	var water := water_of(build, lo, hi, hs)
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


## The water in the box as the ask's `water` key: [{"y": <cell y of the surface>, "runs": [[z, x0, x1], ...]}, ...],
## sorted by y, runs by z then x; [] when there is none. Two sources merged per column (the water layer's wins): the
## valley's own water (home/valley.gd `water(x, z)`: the river and the village ponds, a level in m) where it stands
## above the ground there (the bed: `heights`, given as `hs` or measured here), and the water layer's
## `water_runs(lo, hi)`. A surface outside the box's y range is left out. A Home without a valley has only the layer's.
static func water_of(build: RefCounted, lo: Vector3i, hi: Vector3i, hs: Array = []) -> Array:
	var col := {}                            # Vector2i(x, z) -> surface cell y
	var v: Object = valley_of(build)
	if v != null and v.has_method("water"):
		if hs.is_empty():
			hs = heights(build, null, lo, hi)
		for z in range(lo.z, hi.z + 1):
			for x in range(lo.x, hi.x + 1):
				var lv: Variant = v.call("water", x + 0.5, z + 0.5)
				if lv == null or float(lv) <= float(hs[z - lo.z][x - lo.x]) + 0.01:
					continue
				var y := floori(float(lv))
				if y >= lo.y and y <= hi.y:
					col[Vector2i(x, z)] = y
	var w: RefCounted = build.layer("water")
	if w != null and w.has_method("water_runs"):
		for e: Dictionary in w.call("water_runs", lo, hi):
			for r: Array in e.runs:
				for x in range(int(r[1]), int(r[2]) + 1):
					col[Vector2i(x, int(r[0]))] = int(e.y)
	return runs_of(col)


## {Vector2i(x, z): y} as [{"y", "runs": [[z, x0, x1], ...]}], sorted by y, runs by z then x.
static func runs_of(col: Dictionary) -> Array:
	var by := {}                             # y -> {z: [x, ...]}
	for c: Vector2i in col:
		var y: int = col[c]
		if not by.has(y):
			by[y] = {}
		if not (by[y] as Dictionary).has(c.y):
			by[y][c.y] = []
		(by[y][c.y] as Array).append(c.x)
	var ys := by.keys()
	ys.sort()
	var out := []
	for y: int in ys:
		var runs := []
		var zs := (by[y] as Dictionary).keys()
		zs.sort()
		for z: int in zs:
			var xs: Array = by[y][z]
			xs.sort()
			var x0: int = xs[0]
			for i: int in range(1, xs.size() + 1):
				if i == xs.size() or int(xs[i]) != int(xs[i - 1]) + 1:
					runs.append([z, x0, int(xs[i - 1])])
					if i < xs.size():
						x0 = xs[i]
		out.append({"y": y, "runs": runs})
	return out


## The valley (home/valley.gd) under the Home: the land layer's ground (land_ground.gd `valley`); null on flat ground.
static func valley_of(build: RefCounted) -> Object:
	var l: RefCounted = build.layer("land")
	if l != null and l.has_method("ground"):
		var g: Variant = l.call("ground")
		if g is Object and g != null and (g as Object).get("valley") != null:
			return (g as Object).get("valley")
	return null


## rows[z - lo.z][x - lo.x]: the y of the cell a block takes standing on the ground at the column (x, z), the cell
## holding the point just above the ground (home_build.gd `cell_at_ray_hit`).
static func ground(build: RefCounted, land: Node, lo: Vector3i, hi: Vector3i) -> Array:
	return cells_of(heights(build, land, lo, hi))


## rows[z - lo.z][x - lo.x]: the ground's height in m at the column's centre (the land layer's `height_at` when M2
## gives one, else home/hook.gd `ground_y`, else 0). Under water it is the bed.
static func heights(build: RefCounted, land: Node, lo: Vector3i, hi: Vector3i) -> Array:
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
			row.append(h)
		rows.append(row)
	return rows


## Heights in m as the cells a block takes standing there.
static func cells_of(hs: Array) -> Array:
	var rows := []
	for r: Array in hs:
		var row := []
		for h: float in r:
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


## The block materials a place may name: M1's 1-9 and each later one play has unlocked (`unlocks`: unlocks.gd).
static func mats(unlocks: RefCounted) -> Array:
	var names := {}
	var notes := {}
	for id: int in MAT_NOTES:
		if str(unlocks.call("locked", "mats", id)) == "":
			names[id] = Blocks.MAT_KEYS[id]
			notes[id] = MAT_NOTES[id]
	return table(names, notes)


## The kit parts a put may name (TLKit) that play has unlocked (`unlocks`; null: every part), each with the first
## sentence of its doc.
static func parts(unlocks: RefCounted = null) -> Array:
	var out := []
	for k: String in TLKit.list():
		if unlocks != null and str(unlocks.call("locked", "parts", k)) != "":
			continue
		var doc := str(TLKit.spec(k).get("doc", k))
		out.append({"kind": k, "note": doc.get_slice(". ", 0).trim_suffix(".")})
	return out
