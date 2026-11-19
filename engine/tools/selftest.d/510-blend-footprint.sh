# The picture tour has square, unturned plots. Exercise a long rotated footprint and a sub-cell rim.
if [ -z "$FILTER" ] || [[ "blend.footprint" == *"$FILTER"* ]]; then
  blend_dir="$(mktemp -d "$OUT/blend.XXXXXX")"
  blend_case="$blend_dir/footprint.gd"
  cat >"$blend_case" <<'GDSCRIPT'
extends SceneTree

const Terrain = preload("res://kernel/world/terrain/village_terrain.gd")

func _initialize() -> void:
	var t := Terrain.new(19, Rect2(-90, -90, 180, 180), 3.0)
	var c := Vector2(0.7, -1.2)
	var axis := Vector2.from_angle(-0.68)
	var pad := {"c": c, "extent": Vector2(40, 12), "axis": axis, "rp": 12.0,
		"h": 6.0, "own": true, "yard": false, "approach": Vector2.RIGHT}
	t.pads = [pad]
	t.relief = 0
	t.build_grid()
	var along := c + axis * 36.0
	var across := c + axis.orthogonal() * 36.0
	var cross_height := t.h(across.x, across.y)
	var ok := absf(t.h(along.x, along.y) - 6.0) < 0.001 and cross_height < 4.0
	# Cross the shoulder outside the clip. A discontinuity that the visitor could hit fails the case.
	var previous := t.h(c.x, c.y)
	for m: int in range(1, 90):
		var p := c + axis.orthogonal() * m
		var y := t.h(p.x, p.y)
		ok = ok and absf(y - previous) < 0.65
		previous = y
	# Road and water stamps cross the interior. All triangles under the rim still share the pad height.
	t.roads = [{"pts": PackedVector2Array([c]), "ys": PackedFloat32Array([-1]), "half": 4.0}]
	t.ponds = [{"c": c, "r": 16.0, "y": -4.0}]
	t.build_grid()
	for i: int in 144:
		var p := c + Vector2.from_angle(i * TAU / 144.0) * 15.0
		ok = ok and absf(t.h(p.x, p.y) - 6.0) < 0.001
	var faces := t.faces_in_disc(c, 11.0)
	ok = ok and not faces.is_empty()
	for p: Vector3 in faces:
		ok = ok and absf(p.y - 6.0) < 0.001
	pad["own"] = false
	t.build_grid()
	ok = ok and absf(t.h(c.x, c.y) - (6.0 - t.SINK)) < 0.001
	var first := t.heights.duplicate()
	t.build_grid()
	ok = ok and first == t.heights
	print("BLEND ", "ok" if ok else "failed", " long axis ", t.h(along.x, along.y), ", cross axis before water ", cross_height)
	quit(0 if ok else 1)
GDSCRIPT
  blend_engine="$(cd "$HERE/.." && pwd)"
  blend_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  if command -v cygpath >/dev/null 2>&1; then
    blend_engine="$(cygpath -am "$blend_engine")"
    blend_case="$(cygpath -am "$blend_case")"
  fi
  blend_why=""
  MSYS_NO_PATHCONV=1 timeout 90 "$blend_godot" --headless --path "$blend_engine" --script "$blend_case" >"$blend_dir/output" 2>&1 || blend_why="Godot failed"
  grep -aq '^BLEND ok' "$blend_dir/output" || blend_why="missing success result in $blend_dir/output"
  verdict blend.footprint "$blend_why" "rotated floor, walkable grade, supported clip and sink"
fi
