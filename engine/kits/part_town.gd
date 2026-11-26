extends RefCounted
## 26 Nov 2026 (spark world-sandbox M3; internal to TLKitParts, not API, as part_bodies.gd): the geometry of the town
## parts the Home's pieces needed and the kit lacked, `bench` and `street_lamp`. TLMesh only, the crisp-cel palette.
## Static functions; `mk` is the part's TLMesh.

## `bench` of length `l`: two dark wood end frames (legs, an arm each), a seat of three planks 0.45 m up and, with
## `back`, two back planks to 0.88 m on the -z side. Centred on the origin; a person sits facing +z.
static func add_bench(mk: TLMesh, l: float, back: bool) -> void:
	var hx: float = l * 0.5 - 0.12
	for sx: float in [-hx, hx]:
		mk.box(Vector3(0.08, 0.41, 0.07), "wood_dark", Color.WHITE, 0.0, Vector3(sx, 0.205, 0.16))
		mk.box(Vector3(0.08, 0.41 if not back else 0.86, 0.07), "wood_dark", Color.WHITE, 0.0, Vector3(sx, (0.41 if not back else 0.86) * 0.5, -0.17))
		mk.box(Vector3(0.08, 0.06, 0.46), "wood_dark", Color.WHITE, 0.0, Vector3(sx, 0.40, 0.0))
		mk.box(Vector3(0.07, 0.05, 0.40), "wood_dark", Color.WHITE, 0.0, Vector3(sx, 0.64, 0.0))
		mk.box(Vector3(0.06, 0.22, 0.05), "wood_dark", Color.WHITE, 0.0, Vector3(sx, 0.52, 0.16))
	for i: int in 3:
		mk.box(Vector3(l, 0.045, 0.13), "plank", Color(1.0 - 0.04 * float(i % 2), 1.0, 1.0), 0.012, Vector3(0, 0.4475, -0.15 + 0.15 * float(i)))
	if back:
		for i: int in 2:
			mk.box(Vector3(l, 0.12, 0.035), "plank", Color(0.96 + 0.04 * float(i), 1.0, 1.0), 0.01, Vector3(0, 0.62 + 0.2 * float(i), -0.2))


## `street_lamp` of height `h`: a stone foot, a dark iron post, an arm over +z and a lantern whose panes glow in the
## palette's `window` colour (the light itself is a node of the part, TLKitParts).
static func add_street_lamp(mk: TLMesh, h: float) -> void:
	mk.box(Vector3(0.42, 0.3, 0.42), "stone", Color.WHITE, 0.04, Vector3(0, 0.15, 0))
	mk.box(Vector3(0.26, 0.12, 0.26), "steel_dark", Color.WHITE, 0.02, Vector3(0, 0.36, 0))
	mk.cyl(0.065, h - 0.42, 8, "steel_dark", Color.WHITE, 0.05, Vector3(0, 0.42, 0))
	mk.bar(Vector3(0, h - 0.25, 0), Vector3(0, h - 0.1, 0.42), 0.05, 0.05, "steel_dark", Color.WHITE)
	var top: Vector3 = Vector3(0, h - 0.1, 0.42)
	mk.box(Vector3(0.05, 0.12, 0.05), "steel_dark", Color.WHITE, 0.0, top + Vector3(0, -0.06, 0))
	mk.box(Vector3(0.3, 0.06, 0.3), "steel_dark", Color.WHITE, 0.01, top + Vector3(0, -0.15, 0))
	mk.box(Vector3(0.24, 0.3, 0.24), "window", Color.WHITE, 0.0, top + Vector3(0, -0.33, 0))
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		mk.box(Vector3(0.035, 0.32, 0.035), "steel_dark", Color.WHITE, 0.0, top + Vector3(c.x * 0.125, -0.33, c.y * 0.125))
	mk.hull([top + Vector3(-0.19, -0.48, -0.19), top + Vector3(0.19, -0.48, -0.19), top + Vector3(0.19, -0.48, 0.19), top + Vector3(-0.19, -0.48, 0.19),
		top + Vector3(-0.06, -0.62, -0.06), top + Vector3(0.06, -0.62, -0.06), top + Vector3(0.06, -0.62, 0.06), top + Vector3(-0.06, -0.62, 0.06)], "steel_dark")
