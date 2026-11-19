# A top-down view of level village grass isolates pigment from mesh normals and shadows.
# Measure long straight jumps in the rendered tone while requiring the broad painted tones to survive.
if [ -z "$FILTER" ] || [[ "blend.pigment" == *"$FILTER"* ]]; then
  pigment_dir="$(mktemp -d "$OUT/pigment.XXXXXX")"
  pigment_engine="$(cd "$HERE/.." && pwd)"
  pigment_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  if command -v cygpath >/dev/null 2>&1; then
    pigment_dir="$(cygpath -am "$pigment_dir")"
    pigment_engine="$(cygpath -am "$pigment_engine")"
  fi
  cat >"$pigment_dir/field.json" <<'JSON'
{
  "schema":"tl.walk/1", "name":"blend_pigment", "visitor":true, "ticks":40, "mode":"bot",
  "plots":[{"id":"walker","pack":"ex_walker","origin":[0,6,0],"radius":24,"seed":1}],
  "landscape":{"seed":7,"margin_m":230,"relief":0,"trees":0,"broadleaf":0,"rocks":0,"bushes":0,
    "belt":0,"mesas":0,"soft_patches":0,"plain_clumps":0},
  "player":[[0,[0,6,0]],[40,[0,6,0]]],
  "events":[{"t":20,"e":"shot","name":"grass","cam":"crane","from":[-105,90,50.001],"to":[-105,0,50]}]
}
JSON
  cat >"$pigment_dir/measure.gd" <<'GDSCRIPT'
extends SceneTree

func _initialize() -> void:
	var img := Image.load_from_file(OS.get_cmdline_user_args()[0])
	if img == null or img.get_size() != Vector2i(1920, 1080):
		quit(1)
		return
	var jumps := PackedFloat32Array()
	var tones := PackedFloat32Array()
	# Average out the paper grain and pebbles in 3 x 96 pixel strips. Subtract the local
	# gradient so a smooth colour wash contributes very little even where it changes quickly.
	for y: int in range(96, img.get_height() - 96, 96):
		var row := PackedFloat32Array()
		for x: int in range(48, img.get_width() - 48, 3):
			var sum := 0.0
			for dx: int in 3:
				for dy: int in 96:
					var c := img.get_pixel(x + dx, y + dy)
					sum += (c.r8 + c.g8) * 0.5
			row.append(sum / 288.0)
		tones.append_array(row)
		for k: int in range(1, row.size() - 2):
			var step_ := row[k + 1] - row[k]
			var sides := (row[k] - row[k - 1] + row[k + 2] - row[k + 1]) * 0.5
			jumps.append(absf(step_ - sides))
	jumps.sort()
	tones.sort()
	var jump := jumps[floori(0.999 * (jumps.size() - 1))]
	var span := tones[floori(0.95 * tones.size())] - tones[floori(0.05 * tones.size())]
	var ok := jump < 12.0 and span > 30.0
	print("PIGMENT %s pairs=%d edge_p99.9=%.2f/255 (limit 12) tone_span_5_95=%.2f/255 (min 30)" %
		["ok" if ok else "failed", jumps.size(), jump, span])
	quit(0 if ok else 1)
GDSCRIPT
  pigment_why=""
  if ! bash "$HERE/world.sh" tour "$pigment_dir/field.json" "--out-dir=$pigment_dir" --pictures-only --load=block >"$pigment_dir/window.log" 2>&1; then
    pigment_why="capture failed in $pigment_dir/window.log"
  else
    MSYS_NO_PATHCONV=1 "$pigment_godot" --headless --path "$pigment_engine" --script "$pigment_dir/measure.gd" -- "$pigment_dir/01_grass.png" >"$pigment_dir/measure.log" 2>&1 || pigment_why="measurement failed"
    pigment_result="$(grep -a '^PIGMENT ' "$pigment_dir/measure.log" | tr -d '\r')"
    [[ "$pigment_result" == "PIGMENT ok "* ]] || pigment_why="${pigment_result:-missing measurements in $pigment_dir/measure.log}"
  fi
  verdict blend.pigment "$pigment_why" "${pigment_result#PIGMENT ok }"
fi
