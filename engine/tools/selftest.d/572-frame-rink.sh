# The west scoreboard must not project a panel onto the left goal mouth.
if [ -z "$FILTER" ] || [[ "style.frame.rink" == *"$FILTER"* ]]; then
  frame_engine="$(cd "$HERE/.." && pwd)"
  frame_reader="$OUT/frame_572.gd"
  frame_image="$OUT/frame_572.png"
  frame_log="$OUT/frame_572.log"
  cat > "$frame_reader" <<'GDSCRIPT'
extends SceneTree

func mean_color(im: Image, region: Rect2i) -> Vector3:
	var sum := Vector3.ZERO
	for y in range(region.position.y, region.end.y, 2):
		for x in range(region.position.x, region.end.x, 2):
			var c := im.get_pixel(x,y)
			sum += Vector3(c.r8,c.g8,c.b8)
	return sum/(ceili(region.size.x/2.0)*ceili(region.size.y/2.0))

func median_color(im: Image, region: Rect2i) -> Vector3:
	# The median ignores a skater standing in the patch (22 Nov: the bots moved; a red skater sat in the east patch).
	var r: Array[float] = []
	var g: Array[float] = []
	var b: Array[float] = []
	for y in range(region.position.y, region.end.y, 2):
		for x in range(region.position.x, region.end.x, 2):
			var c := im.get_pixel(x,y)
			r.append(c.r8); g.append(c.g8); b.append(c.b8)
	r.sort(); g.sort(); b.sort()
	var m := r.size() / 2
	return Vector3(r[m], g[m], b[m])

func _initialize() -> void:
	var im := Image.load_from_file(OS.get_cmdline_user_args()[0])
	if im == null or im.get_size() != Vector2i(960,540):
		quit(1)
		return
	# Symmetric open ice on each side of centre, between the faceoff rings.
	var west := median_color(im, Rect2i(218,210,109,107))
	var east := median_color(im, Rect2i(633,210,109,107))
	var delta := (west-east).abs()
	# The blue line between the samples also has to remain visible on the ice.
	var blue := mean_color(im, Rect2i(368,102,4,64))
	var ok := maxf(delta.x,maxf(delta.y,delta.z)) < 14.0 and east.x-blue.x > 24.0
	print("FRAME572 ", "ok" if ok else "FAIL", " west=",west.snappedf(0.1)," east=",east.snappedf(0.1)," blue=",blue.snappedf(0.1))
	quit(0 if ok else 1)
GDSCRIPT
  if command -v cygpath >/dev/null 2>&1; then
    frame_engine="$(cygpath -m "$frame_engine")"
    frame_reader="$(cygpath -m "$frame_reader")"
    frame_image="$(cygpath -m "$frame_image")"
  fi
  frame_error=""
  if TL_STYLE=diorama bash "$TL" capture "--pack=$frame_engine/packs/hockey" --seed=1 \
      --test=tests/bot_hockey.gd --cam=arena --frame=1500 --res=960x540 --hud=on \
      "--out=$frame_image" "--report=$OUT/frame_572.json" > "$frame_log" 2>&1; then
    MSYS_NO_PATHCONV=1 "${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}" \
      --headless --path "$frame_engine" --script "$frame_reader" -- "$frame_image" >> "$frame_log" 2>&1 || frame_error="ice comparison failed"
  else
    frame_error="arena capture failed"
  fi
  frame_line="$(grep -a '^FRAME572 ok ' "$frame_log" | tr -d '\r')"
  if [ -z "$frame_line" ] || grep -aEq 'SCRIPT ERROR|SHADER ERROR|^ERROR:' "$frame_log"; then
    frame_error="${frame_error:-missing clean comparison}; see $frame_log"
  fi
  verdict style.frame.rink "$frame_error" "${frame_line#FRAME572 ok }"
fi
