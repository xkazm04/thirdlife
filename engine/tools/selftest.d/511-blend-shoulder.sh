# Measure the built triangle heightfield on seeded rolling land, including its return to the natural slope.
if [ -z "$FILTER" ] || [[ "blend.shoulder" == *"$FILTER"* ]]; then
  blend_dir="$(mktemp -d "$OUT/blend.XXXXXX")"
  blend_case="$blend_dir/shoulder.gd"
  cat >"$blend_case" <<'GDSCRIPT'
extends SceneTree

const Terrain = preload("res://kernel/world/terrain/village_terrain.gd")
const RADIUS := 48.0
const PAD_Y := 10.0
const STEP := 3.0 # one mesh cell

func _initialize() -> void:
	call_deferred("measure")

func measure() -> void:
	var t := Terrain.new(7, Rect2(-180, -180, 360, 360), STEP)
	t.pads = [{"c": Vector2.ZERO, "extent": Vector2.ONE * RADIUS, "axis": Vector2.RIGHT,
		"rp": RADIUS, "h": PAD_Y, "own": true, "yard": false, "approach": Vector2.RIGHT}]
	t.build_grid()
	var axis := flat_reach(t, Vector2.RIGHT)
	var diagonal := flat_reach(t, Vector2.ONE.normalized())
	var worst := 0.0
	for i: int in 72:
		var d := Vector2.from_angle(TAU * i / 72.0)
		var previous := PAD_Y
		var current := PAD_Y
		for m: int in range(int(RADIUS), 145, int(STEP)):
			var next := t.h(d.x * m, d.y * m)
			worst = maxf(worst, absf(next - 2.0 * current + previous))
			previous = current
			current = next
	var ratio := diagonal / axis
	var rims := drive_rims()
	var ok := is_finite(rims.x) and absf(rims.x - rims.y) < 0.01 and ratio >= 1.32 and ratio <= 1.48 and worst < 0.65
	print("SHOULDER %s axis=%.2fm diagonal=%.2fm ratio=%.3f max_second_difference=%.3fm at 3m (72 rays, limit 0.65m) Drive_rim=%.2fm ground_only=%.2fm" %
		["ok" if ok else "failed", axis, diagonal, ratio, worst, rims.x, rims.y])
	quit(0 if ok else 1)

# The dense scenery mesh includes high branches at the same radius as the track's ground.
func drive_rims() -> Vector2:
	const Draw = preload("res://kernel/world/draw/draw_base.gd")
	TLStyle.set_headless(false)
	var holder := Node3D.new()
	root.add_child(holder)
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://seeds/seed_drive/data/track.json"))
	layout.erase("forest")
	layout["terrain"]["far"] = false
	var built := TLKit.build_layout(layout, holder)
	var rims := Vector2(NAN, NAN)
	var ground := holder.find_child("TerrainNear", true, false) as Node3D
	if built.get("ok", false) and ground != null:
		rims = Vector2(Draw.edge_height(holder, 64.0), Draw.edge_height(ground, 64.0))
	holder.free()
	return rims

func flat_reach(t: RefCounted, d: Vector2) -> float:
	for quarter: int in range(1, 440):
		var p := d * (quarter * 0.25)
		if absf(t.h(p.x, p.y) - PAD_Y) > 0.001:
			return (quarter - 1) * 0.25
	return INF
GDSCRIPT
  blend_engine="$(cd "$HERE/.." && pwd)"
  blend_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  if command -v cygpath >/dev/null 2>&1; then
    blend_engine="$(cygpath -am "$blend_engine")"
    blend_case="$(cygpath -am "$blend_case")"
  fi
  blend_why=""
  MSYS_NO_PATHCONV=1 timeout 90 "$blend_godot" --headless --path "$blend_engine" --script "$blend_case" >"$blend_dir/output" 2>&1 || blend_why="Godot failed"
  blend_result="$(grep -a '^SHOULDER ' "$blend_dir/output" | tr -d '\r')"
  [[ "$blend_result" == "SHOULDER ok "* ]] || blend_why="${blend_result:-missing measurements in $blend_dir/output}"
  verdict blend.shoulder "$blend_why" "${blend_result#SHOULDER ok }"
fi
