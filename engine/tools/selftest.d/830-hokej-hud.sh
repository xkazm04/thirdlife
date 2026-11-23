# Hokej's screen (lane K5 of the hockey port): thirdjam's HUD and match flow, HEAD 8dc713c6.
#   hokej.hud_rules   thirdjam's own assertions on the pure HUD rules, then a recorded match (its human played by thirdjam's
#                     playerbot) fed frame by frame to the pack's HUD: MATCH card, markers under cards, YOU tag, faceoff dial,
#                     panel, take, possession. More than 100,000 checks and none failed; a stopped run is a FAIL.
#   hokej.hud_layer   the kernel's TLHudLayer: TLHud.add_layer gives one layer per id, in layout units of 1080 a screen.
check hokej.hud_rules 0 bot "--pack=$HERE/../packs/hokej" --test=tests/bot_hud_rules.gd -- '"id":"bot.completed","ok":true' '"id":"bot.ok","ok":true' '[0-9]{6} checks, 0 failed'
if [ -z "$FILTER" ] || [[ "hokej.hud_layer" == *"$FILTER"* ]]; then
  why=""
  grep -q '^func add_layer(id: StringName, unit_h: float = 1080.0) -> TLHudLayer:' "$HERE/../kernel/api/tl_hud.gd" || why="TLHud.add_layer is missing"
  grep -q '^class_name TLHudLayer' "$HERE/../kernel/api/tl_hud_layer.gd" || why="${why:+$why; }TLHudLayer is missing"
  grep -q 'TLHudLayer' "$HERE/../kernel/API.md" || why="${why:+$why; }API.md does not document TLHudLayer"
  verdict hokej.hud_layer "$why"
fi
# K5 round 3 (kernel 1.24): the dungeon frame's pause with a pack that owns its card (ctx.own_pause, TLHud.on_paused,
# ctx.input.menu_keys, ctx.resume, ctx.leave_game) and with a pack that does not (the frame's own card, unchanged).
if [ -z "$FILTER" ] || [[ "hokej.pause_own" == *"$FILTER"* ]] || [[ "hokej.pause_frame" == *"$FILTER"* ]]; then
  hp_g="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  hp_e="$(cd "$HERE/.." && pwd)"
  hp_o="$OUT/hokej_pause"
  rm -rf "$hp_o"; mkdir -p "$hp_o/own/scripts" "$hp_o/own/tests"
  if command -v cygpath >/dev/null 2>&1; then hp_e="$(cygpath -m "$hp_e")"; hp_o="$(cygpath -m "$hp_o")"; hp_g="$(cygpath -m "$hp_g")"; fi
  cat > "$hp_o/own/pack.json" <<'JSON'
{"id": "selftest.own_pause", "version": "0.1.0", "kernelApi": "1.22", "title": "Own pause card", "capabilities": ["ui", "input"], "entry": "scripts/main.gd", "assets": [], "tests": ["tests/bot_idle.gd"], "cameras": []}
JSON
  cat > "$hp_o/own/scripts/main.gd" <<'GDSCRIPT'
extends Node
var ctx
var got: Array = []

func _pack_setup(c) -> void:
	ctx = c
	ctx.own_pause()
	var hud := TLHud.create()
	ctx.root.add_child(hud)
	hud.on_paused(_paused)

func _paused(_f: int) -> void:
	for k: String in ctx.input.menu_keys():
		got.append(k)
		ctx.root.set_meta(&"got", got)
		if k == "esc":
			ctx.resume()
		elif k == "enter":
			ctx.leave_game()

func _pack_start() -> void:
	pass

func _pack_tick(_frame: int) -> void:
	pass

func _pack_teardown() -> void:
	pass

func _pack_state() -> Dictionary:
	return {}
GDSCRIPT
  cat > "$hp_o/own/tests/bot_idle.gd" <<'GDSCRIPT'
extends Node
func _bot_setup(_c) -> void:
	pass
func _bot_tick(_f: int) -> void:
	pass
func _bot_done() -> bool:
	return true
func _bot_result() -> Dictionary:
	return {"ok": true, "summary": "idle"}
GDSCRIPT
  cat > "$hp_o/probe.gd" <<'GDSCRIPT'
extends SceneTree
var lines: PackedStringArray = []

func _initialize() -> void:
	run.call_deferred()

func key(d, code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	d._input(e)

func frames(n: int) -> void:
	for i: int in n:
		await process_frame

func one(dir: String, tag: String) -> void:
	var d = load("res://kernel/dungeon/dungeon.gd").new()
	root.add_child(d)
	var why: Array = [""]
	d.left.connect(func(w: String) -> void: why[0] = w)
	var ok: bool = await d.open(dir, {"seed": 1, "watch": false})
	await frames(5)
	var f0: int = d.frame
	key(d, KEY_ESCAPE)
	await frames(5)
	var frozen: bool = d.frame == f0 or d.frame == f0 + 1
	var a: String = "open=%s paused=%s ctx_paused=%s frame_card=%s frozen=%s" % [str(ok), str(d.paused), str(d.ctx.paused), str(d._pause != null), str(frozen)]
	key(d, KEY_DOWN)
	key(d, KEY_ESCAPE)
	await frames(5)
	a += " after_esc_paused=%s" % str(d.paused)
	if tag == "own":
		a += " got=%s" % str(d.ctx.root.get_meta(&"got", []))
		key(d, KEY_ESCAPE)
		await frames(3)
		key(d, KEY_ENTER)
		await frames(5)
		a += " left=%s" % why[0]
	else:
		d.close("leave")
		await frames(2)
	lines.append(tag + " " + a + (" problem=" + d.problem if d.problem != "" else ""))
	if is_instance_valid(d):
		d.queue_free()
	await frames(2)

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	await one(args[0], "own")
	await one(args[1], "frame")
	for l: String in lines:
		print("HPAUSE " + l)
	quit(0)
GDSCRIPT
  hp_out="$(MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' timeout 300 "$hp_g" --headless --fixed-fps 60 --path "$hp_e" --script "$hp_o/probe.gd" -- "$hp_o/own" "$hp_e/seeds/seed_paddle" 2>&1 | tr -d '\015')"
  hp_own="$(echo "$hp_out" | grep -m1 '^HPAUSE own')"; hp_frame="$(echo "$hp_out" | grep -m1 '^HPAUSE frame')"
  why=""
  [[ "$hp_own" == *"open=true paused=true ctx_paused=true frame_card=false frozen=true after_esc_paused=false"* ]] || why="the own card's pause: ${hp_own:-no line}"
  [[ "$hp_own" == *'got=["down", "esc"]'* ]] || why="${why:+$why; }the menu keys: ${hp_own:-no line}"
  [[ "$hp_own" == *"left=leave"* ]] || why="${why:+$why; }ctx.leave_game: ${hp_own:-no line}"
  verdict hokej.pause_own "$why" "$hp_own"
  why=""
  [[ "$hp_frame" == *"open=true paused=true ctx_paused=true frame_card=true frozen=true"* ]] || why="the frame's own card: ${hp_frame:-no line}"
  verdict hokej.pause_frame "$why" "$hp_frame"
fi
# K5 round 4: the level chosen on HOME is an input. hokej.level_record: a session started at ROOKIE (tests/bot_level_record.gd
# taps the key-less action level_rookie for frame 0, as HOME's PLAY NOW does) is recorded; replayed from the record alone it
# hashes the same; replayed with the level's row taken out of the record it hashes differently (the level comes from the record).
if [ -z "$FILTER" ] || [[ "hokej.level_record" == *"$FILTER"* ]]; then
  hl_o="$OUT/hokej_level"; rm -rf "$hl_o"; mkdir -p "$hl_o"
  hl_p="$HERE/../packs/hokej"
  if command -v cygpath >/dev/null 2>&1; then hl_o="$(cygpath -m "$hl_o")"; fi
  why=""
  TL_QUIET=1 timeout 600 bash "$TL" bot "--pack=$hl_p" --test=tests/bot_level_record.gd "--record=$hl_o/rookie.json" > "$hl_o/bot.json" 2>/dev/null
  hl_a="$(grep -o '"state_hash":"[0-9a-f]*"' "$hl_o/bot.json" | head -1 | sed 's/.*:"//; s/"//')"
  grep -q '"id":"bot.ok","ok":true' "$hl_o/bot.json" || why="the recorded run did not start at ROOKIE"
  node -e 'const fs=require("fs");const r=JSON.parse(fs.readFileSync(process.argv[1]));r.frames=r.frames.filter(f=>!String(f[1]).startsWith("level_"));fs.writeFileSync(process.argv[2],JSON.stringify(r));' "$hl_o/rookie.json" "$hl_o/nolevel.json"
  TL_QUIET=1 timeout 600 bash "$TL" replay "--pack=$hl_p" "--input=$hl_o/rookie.json" > "$hl_o/replay.json" 2>/dev/null
  TL_QUIET=1 timeout 600 bash "$TL" replay "--pack=$hl_p" "--input=$hl_o/nolevel.json" > "$hl_o/replay_nolevel.json" 2>/dev/null
  hl_b="$(grep -o '"state_hash":"[0-9a-f]*"' "$hl_o/replay.json" | head -1 | sed 's/.*:"//; s/"//')"
  hl_c="$(grep -o '"state_hash":"[0-9a-f]*"' "$hl_o/replay_nolevel.json" | head -1 | sed 's/.*:"//; s/"//')"
  [ -n "$hl_a" ] && [ "$hl_a" = "$hl_b" ] || why="${why:+$why; }replay ${hl_b:0:16} is not the recorded ${hl_a:0:16}"
  [ -n "$hl_c" ] && [ "$hl_c" != "$hl_a" ] || why="${why:+$why; }without the level's row the replay hashes ${hl_c:0:16} (should differ from ${hl_a:0:16})"
  verdict hokej.level_record "$why" "recorded ${hl_a:0:16}, replayed ${hl_b:0:16}, without the level ${hl_c:0:16}"
fi
