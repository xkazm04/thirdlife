# Exercise the diorama and classic material paths in one process. The dummy renderer
# can construct real ShaderMaterials; these checks supplement the windowed pixel/boil runs.
if [ -z "$FILTER" ] || [[ "surfaces.handmade" == *"$FILTER"* ]]; then
  sa_dir="$(mktemp -d "$OUT/surfaces-XXXXXX")"
  sa_engine="$(cd "$HERE/.." && pwd)"
  sa_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  if command -v cygpath >/dev/null 2>&1; then
    sa_engine="$(cygpath -am "$sa_engine")"
    sa_dir="$(cygpath -am "$sa_dir")"
  fi
  cat > "$sa_dir/handmade.gd" <<'GDSCRIPT'
extends SceneTree
const Parts := preload("res://kernel/world/terrain/village_parts.gd")
const Scatter := preload("res://kernel/world/draw/stone_scatter.gd")
var problems := PackedStringArray()

class RiverSection:
	extends RefCounted
	var river: Dictionary = {}

	func gy(x: float, _z: float) -> float:
		return 0.5 * (absf(x) - 4.0)

func _initialize() -> void:
	TLStyle.set_headless(false)
	var classic := TLStyle.DEFAULT_PATH
	var toy := "res://style/style_diorama.json"
	_check(TLStyle.load_style(classic).is_empty(), "classic loads")
	var columns := TLStyle.palette()
	var single := TLStyle.material(&"wood")
	var water := TLStyle.material(&"water") as ShaderMaterial
	_check(water.shader.resource_path.ends_with("/water.gdshader"), "classic water")
	_check(TLStyle.load_style(toy).is_empty(), "diorama loads")
	for i in columns.size():
		_check(TLStyle.index(columns[i]) == i + 1, "column " + columns[i])
	_check(TLStyle.num("detail", "handmade") > 0.5, "handmade enabled")
	var groups := {"felt": ["pine", "leaf"], "painted_wood": ["curb_white", "curb_red"], "ground": ["terrain", "grass"], "wood": ["plank", "trunk"]}
	for family: String in groups:
		for key: String in groups[family]:
			_check(TLStyle.data.mat[key].get("class") == family, key + " is " + family)
	_check(TLStyle.material(&"pine") == single and TLStyle.material(&"curb_white") == single, "batched palette")
	_check(water == TLStyle.material(&"water") and water.shader.resource_path.ends_with("/water_resin.gdshader"), "resin reload")
	var source := TLKitNature.pine(100)
	var original := source.content_hash()
	var felt := Parts._felt_foliage(source)
	_check(felt.tri_count > source.tri_count and source.content_hash() == original, "display crown keeps camera recipe")
	var far := Parts._felt_foliage(source, true)
	_check(far.tri_count < felt.tri_count and far.tri_count > source.tri_count, "distant crown budget")
	_check(is_equal_approx(felt.aabb().end.y, source.aabb().end.y) and is_equal_approx(far.aabb().end.y, source.aabb().end.y), "same treetop height")
	_check(felt.content_hash() == Parts._felt_foliage(source).content_hash(), "repeatable felt recipe")
	var stones := _check_waterline()
	_check(TLStyle.load_style(classic).is_empty() and TLStyle.num("detail", "handmade") == 0, "classic reload")
	_check(water.shader.resource_path.ends_with("/water.gdshader"), "classic water restored")
	if problems.is_empty():
		print("SURFACES_OK columns=%d classic/resin/classic crown=%d->%d far=%d bank_stones=%d" % [columns.size(), source.tri_count, felt.tri_count, far.tri_count, stones])
	else:
		print("SURFACES_FAIL ", ", ".join(problems))
	quit(0 if problems.is_empty() else 1)

func _check_waterline() -> int:
	var bank := RiverSection.new()
	var free := func(_p, _r, _road, _water): return true
	_check(Scatter.waterline(bank, 17, free).is_empty(), "dry village")
	var pts := PackedVector2Array()
	var levels := PackedFloat32Array()
	for i in 24:
		pts.append(Vector2(0.0, float(i) * 3.0))
		levels.append(0.0)
	bank.river = {"pts": pts, "ys": levels, "half": 6.0}
	var stones := Scatter.waterline(bank, 17, free)
	_check(not stones.is_empty() and stones == Scatter.waterline(bank, 17, free), "repeatable bank scatter")
	for stone: Transform3D in stones:
		var x := absf(stone.origin.x)
		_check(x >= 2.0 and x <= 4.5, "stone stays on cast edge")
	var closed := func(_p, _r, _road, _water): return false
	_check(Scatter.waterline(bank, 17, closed).is_empty(), "reserved plots exclude bank stones")
	return stones.size()

func _check(ok: bool, label: String) -> void:
	if not ok:
		problems.append(label)
GDSCRIPT
  sa_reason=""
  MSYS_NO_PATHCONV=1 "$sa_godot" --headless --path "$sa_engine" --script "$sa_dir/handmade.gd" > "$sa_dir/log" 2>&1 || sa_reason="Godot exited $?"
  sa_line="$(tr -d '\r' < "$sa_dir/log" | grep -a '^SURFACES_OK' | head -1)"
  [ -n "$sa_line" ] || sa_reason="missing verdict ($sa_dir/log)"
  if grep -aqE 'SCRIPT ERROR|SHADER ERROR|^ERROR:' "$sa_dir/log"; then sa_reason="engine error ($sa_dir/log)"; fi
  verdict surfaces.handmade "$sa_reason" "$sa_line"
fi
