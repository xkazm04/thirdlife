# Keep the camera on the same car pad while the visitor walks from the live plot to its distant picture.
if [ -z "$FILTER" ] || [[ "blend.car_origin" == *"$FILTER"* ]]; then
  origin_dir="$(mktemp -d "$OUT/car-origin.XXXXXX")"
  origin_engine="$(cd "$HERE/.." && pwd)"
  origin_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  if command -v cygpath >/dev/null 2>&1; then
    origin_dir="$(cygpath -am "$origin_dir")"
    origin_engine="$(cygpath -am "$origin_engine")"
  fi
  cat >"$origin_dir/car.json" <<'JSON'
{
  "schema":"tl.walk/1", "name":"origin_cut", "visitor":true, "ticks":320, "mode":"bot",
  "plots":[{"id":"car","pack":"ex_car","origin":[85,0.5,57],"radius":40,"seed":1}],
  "landscape":{"seed":7,"pad_h":[0.5],"margin_m":140,"relief":0,"trees":0,"broadleaf":0,"rocks":0,
    "bushes":0,"belt":0,"mesas":0,"soft_patches":0,"plain_clumps":0},
  "player":[[0,[86,0.5,20]],[55,[86,0.5,20]],[140,[-125,0.5,0]],[320,[-125,0.5,0]]],
  "events":[
    {"t":40,"e":"shot","name":"near","cam":"crane","from":[85,75,57.001],"to":[85,0,57]},
    {"t":300,"e":"shot","name":"distant","cam":"crane","from":[85,75,57.001],"to":[85,0,57]}
  ]
}
JSON
  cat >"$origin_dir/measure.gd" <<'GDSCRIPT'
extends SceneTree

func _initialize() -> void:
	var dir := OS.get_cmdline_user_args()[0]
	var near := Image.load_from_file(dir.path_join("01_near.png"))
	var distant := Image.load_from_file(dir.path_join("02_distant.png"))
	if near == null or distant == null or near.get_size() != Vector2i(1920, 1080) or distant.get_size() != near.get_size():
		quit(1)
		return
	# The central patch is well inside the verge. Sample past the cars, cones and their shadows.
	var grass := 0
	var asphalt := 0
	var samples := 0
	for y: int in range(430, 650, 4):
		for x: int in range(760, 1160, 4):
			var live := near.get_pixel(x, y)
			var picture := distant.get_pixel(x, y)
			grass += int(live.g > live.r)
			asphalt += int(picture.r > 1.2 * picture.g)
			samples += 1
	print("ORIGIN live_grass=%.1f%% distant_asphalt=%.1f%% (%d samples per view, minimum 90%% each)" %
		[100.0 * grass / samples, 100.0 * asphalt / samples, samples])
	quit(0 if mini(grass, asphalt) >= 0.9 * samples else 1)
GDSCRIPT
  origin_why=""
  origin_result=""
  # The measure reads green-dominant grass, a property of the classic palette (crisp paints dry olive patches where red
  # leads); the case proves the live-to-picture cut, so it runs under classic since crisp became the default (20 Nov).
  if TL_STYLE=classic bash "$HERE/world.sh" tour "$origin_dir/car.json" --pictures-only --load=block "--out-dir=$origin_dir" >"$origin_dir/window.log" 2>&1; then
    MSYS_NO_PATHCONV=1 "$origin_godot" --headless --path "$origin_engine" --script "$origin_dir/measure.gd" -- "$origin_dir" >"$origin_dir/measure.log" 2>&1
    origin_status=$?
    origin_result="$(grep -a '^ORIGIN ' "$origin_dir/measure.log" | tr -d '\r')"
    if [ "$origin_status" != 0 ] || [ -z "$origin_result" ]; then
      origin_why="${origin_result:-measurement failed in $origin_dir/measure.log}"
    fi
  else
    origin_why="capture failed in $origin_dir/window.log"
  fi
  verdict blend.car_origin "$origin_why" "${origin_result#ORIGIN }"
fi
