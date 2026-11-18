# Check API compatibility and deterministic input recording and replay.
# Exercise pointer input, keyboard focus and the script fence.

# ---------------------------------------------------------------- P7: the simulation contract
# (kernel API version, the input record tl.input/1, replay, the pointer through ctx.input, keys and the panel, the fence)
SEEDS_DIR="$HERE/../seeds"
OUTW="$OUT"; command -v cygpath >/dev/null 2>&1 && OUTW="$(cygpath -m "$OUT")"
p7_on() { [ -z "$FILTER" ] || [[ "$1" == *"$FILTER"* ]] || [[ "p7" == "$FILTER" ]]; }
# p7_pack <name> [sed expression for pack.json]: a copy of pack_min under $OUT
p7_pack() { rm -rf "$OUT/$1"; cp -r "$EX/pack_min" "$OUT/$1"; [ -n "$2" ] && sed -i -E 's/"kernelApi": "[0-9.]+"/"kernelApi": "0.1"/' "$OUT/$1/pack.json" && sed -i "$2" "$OUT/$1/pack.json"; return 0; }
# p7_play <name> <pack dir> <frames> <devices json text> [record file]: a scripted interactive session without a window
p7_play() {
  echo "$4" > "$OUT/$1.devices.json"; rm -f "$OUT/$1.result.json"
  bash "$TL" play "--pack=$2" --headless "--frames=$3" "--devices=$OUTW/$1.devices.json" "--result=$OUTW/$1.result.json" ${5:+"--record=$5"} >/dev/null 2>&1
}
p7_res() { grep -o "\"$2\":\"\\?[^,\"}]*" "$OUT/$1.result.json" 2>/dev/null | head -1 | sed -E 's/^"[a-z_]+":"?//'; }

# API version: a pack runs when its major equals the kernel's and its minor is not greater; "0.1" is the old name of 1.0.
# P14: the kernel's version is read from the manifest code (kernel/runner/manifest.gd KERNEL_API), not held as text here.
KAPI="$(grep -oE 'KERNEL_API: String = "[0-9]+\.[0-9]+"' "$HERE/../kernel/runner/manifest.gd" | grep -oE '[0-9]+\.[0-9]+')"
KMAJ="${KAPI%%.*}"; KMIN="${KAPI#*.}"; KNEXT="$KMAJ.$((KMIN + 1))"
if p7_on p7.api; then
  p7_pack p7_api01 "s/x/x/"; p7_pack p7_api10 's#"kernelApi": "0.1"#"kernelApi": "1.0"#'; p7_pack p7_api20 's#"kernelApi": "0.1"#"kernelApi": "2.0"#'; p7_pack p7_apinext "s#\"kernelApi\": \"0.1\"#\"kernelApi\": \"$KNEXT\"#"
  check p7.api_1_0_lint 0 lint "--pack=$OUT/p7_api10" -- "\"kernelApi\":\"$KAPI\"" '"id":"lint.schema","ok":true'
  check p7.api_1_0_runs 0 smoke "--pack=$OUT/p7_api10" --frames=120 -- '"id":"smoke.loads","ok":true'
  check p7.api_0_1_is_1_0 0 smoke "--pack=$OUT/p7_api01" --frames=120 -- "\"kernelApi\":\"$KAPI\"" '"id":"smoke.loads","ok":true'
  check p7.api_2_0_refused 1 lint "--pack=$OUT/p7_api20" -- "kernelApi '2.0' cannot run on this kernel, which offers API $KAPI: the pack was built for major version 2 and this kernel is major version $KMAJ"
  check p7.api_2_0_not_run 2 smoke "--pack=$OUT/p7_api20" --frames=120 -- 'the manifest is not valid'
  check p7.api_next_refused 1 lint "--pack=$OUT/p7_apinext" -- "kernelApi '$KNEXT' cannot run on this kernel, which offers API $KAPI: the pack needs minor version $((KMIN + 1)) and this kernel has $KMIN"
fi

# a bot's run saved as a record replays to the bot's hash, and the replay's own record is the same file
if p7_on p7.record; then
  REC="$OUTW/p7_paddle.input.json"; REC2="$OUTW/p7_paddle.again.json"; rm -f "$REC" "$REC2"
  check p7.record_bot 0 bot "--pack=$SEEDS_DIR/seed_paddle" "--record=$REC" -- '"id":"record.written","ok":true' '"id":"bot.ok","ok":true'
  check p7.record_replay 0 replay "--pack=$SEEDS_DIR/seed_paddle" "--input=$REC" "--record=$REC2" -- '"verb":"replay","level":"V2"' '"id":"replay.complete","ok":true' '"id":"record.written","ok":true'
  why=""; hb="$(field p7.record_bot state_hash)"; hr="$(field p7.record_replay state_hash)"
  [ -n "$hb" ] && [ "$hb" = "$hr" ] || why="the bot's hash ($hb) is not the replay's ($hr)"
  cmp -s "$REC" "$REC2" || why="${why:+$why; }the replay's own record differs from the record it was fed"
  grep -q '^{"schema":"tl.input/1","pack":"seed.paddle","seed":1,"mode":"bot","max_frames":36000,"length":[0-9]*,"end":"tick","frames":\[' "$REC" || why="${why:+$why; }the record's head is not tl.input/1"
  verdict p7.record_same_hash "$why" "seed_paddle: bot ${hb:0:16} = replay ${hr:0:16}; $(grep -c '^\[' "$REC") frames with input of $(number p7.record_replay frames)"
  check p7.record_wrong_pack 2 replay "--pack=$EX/pack_min" "--input=$REC" -- "the input record is of pack 'seed.paddle', this pack is 'example.pack_min'"
  echo '{"schema":"tl.input/1","pack":"example.pack_min","seed":1,"mode":"bot","max_frames":600,"length":10,"end":"step","frames":[],"note":"x"}' > "$OUT/p7_bad.input.json"
  check p7.record_unknown_key 2 replay "--pack=$EX/pack_min" "--input=$OUTW/p7_bad.input.json" -- "unknown key 'note'"
  check p7.record_needs_input 2 replay "--pack=$EX/pack_min" -- '--input=<file> is required'
fi

# the mouse is input like any other: a session with a right-button drag and the wheel on the wall seed (whose walker
# moves relative to the orbit camera) is recorded, replays to its own hash, and differs from the same keys without the mouse
if p7_on p7.mouse; then
  drag=""; for f in $(seq 40 69); do drag="$drag[$f,\"drag\",6,1.5],"; done
  keys_a='[20,"key","W",1],'; keys_b='[120,"key","Space",1],[124,"key","Space",0],[200,"key","D",1],[260,"key","D",0],[300,"key","W",0]'
  MREC="$OUTW/p7_mouse.input.json"; rm -f "$MREC"
  p7_play p7_mouse "$SEEDS_DIR/seed_wall" 600 "[$keys_a$drag[90,\"wheel\",1,0],[91,\"wheel\",1,0],$keys_b]" "$MREC"
  p7_play p7_nomouse "$SEEDS_DIR/seed_wall" 600 "[$keys_a$keys_b]"
  check p7.mouse_replay 0 replay "--pack=$SEEDS_DIR/seed_wall" "--input=$MREC" -- '"id":"replay.complete","ok":true'
  why=""; hm="$(p7_res p7_mouse state_hash)"; hn="$(p7_res p7_nomouse state_hash)"; hr="$(field p7.mouse_replay state_hash)"
  [ -n "$hm" ] && [ "$hm" = "$hr" ] || why="the session's hash ($hm) is not its replay's ($hr)"
  [ -n "$hn" ] && [ "$hm" != "$hn" ] || why="${why:+$why; }the mouse changed nothing ($hm with, $hn without)"
  [ "$(grep -c '"tl.look_x",6\]' "$MREC")" = 30 ] && grep -q '\[90,"tl.zoom",1\]' "$MREC" || why="${why:+$why; }the record lacks the 30 drag frames or the wheel"
  verdict p7.mouse_same_hash "$why" "seed_wall, 600 frames: session ${hm:0:16} = replay ${hr:0:16}; without the mouse ${hn:0:16}"
fi

# engine/ui/PATCHES.md entry 1: a text field that has focus takes the keyboard (Space is down from frame 10 to 79, the
# field has focus from 30 to 59); entry 2: Esc does not end the game while the designer panel is open
if p7_on p7.keys; then
  KREC="$OUTW/p7_keys.input.json"; rm -f "$KREC"
  p7_play p7_keys "$EX/pack_min" 120 '[[10,"key","Space",1],[30,"field",1],[60,"field",0],[80,"key","Space",0]]' "$KREC"
  got="$(grep -o '\[[0-9]*,"nudge",1\]' "$KREC" 2>/dev/null | grep -o '^\[[0-9]*' | tr -d '[' | tr '\n' ' ')"
  want="$( (seq 10 29; seq 60 79) | tr '\n' ' ')"
  why=""; [ "$got" = "$want" ] || why="the game saw the key in frames [$got], expected 10..29 and 60..79"
  verdict p7.keys_field_takes_keyboard "$why" "pack_min: Space held 70 frames, 30 of them typed into a field: the game got 40"
  p7_play p7_esc "$EX/pack_min" 200 '[[10,"panel",1],[20,"key","Escape",1],[25,"key","Escape",0],[40,"panel",0],[50,"key","Escape",1]]'
  ran="$(p7_res p7_esc frames_run)"
  why=""; [ "$ran" = 51 ] || why="the run ended after ${ran:-no} frames, expected 51 (Esc at 20 with the panel open is not for the game; Esc at 50 ends it)"
  verdict p7.keys_esc_panel_open "$why" "pack_min: Esc with the panel open at frame 20 went on, Esc at frame 50 ended the run"
  # a session that ends because the window is closed still writes its record
  CREC="$OUTW/p7_close.input.json"; rm -f "$CREC"
  p7_play p7_close "$EX/pack_min" 200 '[[10,"key","Space",1],[30,"close",0,0]]' "$CREC"
  why=""; grep -q '"length":30,"end":"step","frames":\[' "$CREC" 2>/dev/null || why="no record of 30 frames after the window was closed at frame 30 ($(head -c 120 "$CREC" 2>/dev/null))"
  [ "$(grep -o '"nudge",1\]' "$CREC" 2>/dev/null | wc -l | tr -d ' ')" = 20 ] || why="${why:+$why; }the record does not hold the 20 frames of the key"
  verdict p7.keys_window_closed_keeps_record "$why" "pack_min: closed at frame 30, the record has 30 frames and the key's 20"
fi

# the fence follows the seam: device reads past ctx.input, clocks that are not the tick count, another pack's nodes
if p7_on p7.fence; then
  p7_pack p7_fence
  printf '%s\n' 'extends Node' 'var t = Timer.new()' 'func _process(_d: float) -> void:' '	pass' 'func _unhandled_key_input(_e) -> void:' '	pass' \
    'func f(ctx, n: Node3D) -> void:' '	var a = InputEventKey.new()' '	set_process_input(true)' '	var m = n.get_global_mouse_position()' '	var b = Button.new()' \
    '	ctx.input.accept_devices = true' '	var dt = get_process_delta_time()' '	var tw = create_tween()' '	var w = n.get_world_3d()' '	var h = ctx.holder' \
    '	ctx.input._feed([])' '	var c = TLContext.current' '	var g = n.get_nodes_in_group("x")' '	var ok = ball.holder()' > "$OUT/p7_fence/scripts/seam.gd"
  check p7.fence_seam 1 lint "--pack=$OUT/p7_fence" -- '"id":"lint.fence","ok":false' \
    '"file":"scripts/seam.gd","line":2,"message":".Timer. is outside the fence' '"line":3,"message":"._process. is outside the fence' '"line":5,"message":"._gui_input handler. is outside' \
    '"line":8,"message":".InputEvent\*. is outside' '"line":9,"message":".set_process_input. is outside' '"line":10,"message":".mouse position. is outside' '"line":11,"message":".a control that takes clicks or keys. is outside' \
    '"line":12,"message":".accept_devices. is outside' '"line":13,"message":".get_process_delta_time. is outside' '"line":14,"message":".Tween/AnimationPlayer. is outside' '"line":15,"message":".get_world_3d\(\). is outside' \
    '"line":16,"message":"..holder. is outside' '"line":17,"message":".a private member of the kernel. is outside' '"line":18,"message":".TLContext.current. is outside' '"line":19,"message":".get_nodes_in_group. is outside'
  if p7_on p7.fence_holder_call; then
    why=""; grep -q '"line":20,' "$(report_of p7.fence_seam)" && why="ball.holder() (a TLBall method) was taken for ctx.holder"
    verdict p7.fence_holder_call "$why" "a call of TLBall.holder() is not the kernel's holder node"
  fi
  # a pack script's own event handler is switched off by the kernel: it sees no device event (lint counts it as a bypass)
  p7_pack p7_handler
  # P11: the handler is a fence error now and `play` refuses the pack, so the net behind the fence is proven in a
  # smoke run (no lint): the pack itself sends a device event at its tick 10 and says at 20 whether its handler is on
  printf '%s\n' '' 'var _p11_n: int = 0' 'func _unhandled_input(_event) -> void:' '	push_error("a pack handler saw a device event")' \
    'func _physics_process(_d: float) -> void:' '	_p11_n += 1' '	if _p11_n == 10:' '		var ev = InputEventMouseMotion.new()' '		ev.relative = Vector2(5, 5)' \
    '		Input.parse_input_event(ev)' '	if _p11_n == 20 and is_processing_unhandled_input():' '		push_error("the handler is still switched on")' >> "$OUT/p7_handler/scripts/main.gd"
  check p7.fence_handler_switched_off 0 smoke "--pack=$OUT/p7_handler" --frames=60 -- '"id":"smoke.no_script_errors","ok":true'
fi

