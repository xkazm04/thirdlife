# Compare world and solo runs and exercise input handlers under the fence.
# needs: OUTW from 110-p7.sh.

# --- P11 ---
# The world joins the contract: a pack in a world hashes as the runner hashes it alone; a pack script's event handler
# is off in a world too; an _input handler is a fence error; the visitor's walk is an input record that replays.
p11_on() { [ -z "$FILTER" ] || [[ "$1" == *"$FILTER"* ]] || [[ "p11" == "$FILTER" ]]; }
if p11_on p11.world_alone; then
  out="$(bash "$HERE/world.sh" alone --packs=seed_paddle,ex_kit,ex_walker --mode=bot --frames=6000 2>&1)"
  why=""; echo "$out" | grep -q '^PASS world.alone' || why="$(echo "$out" | grep -E 'DIFFERENT|FAIL|exit' | head -3 | tr '\n' ' ')"
  [ -z "$why" ] && ! echo "$out" | grep -q '^PASS world.alone' && why="no PASS world.alone line: the run stopped before its verdict"
  verdict p11.world_alone "$why" "$(echo "$out" | grep ' | bot | ' | cut -d'|' -f1,3,4 | tr -s ' ' | tr '\n' ';')"
fi
if p11_on p11.world_handler_off; then
  rm -rf "$OUT/p11_wh"; cp -r "$EX/pack_min" "$OUT/p11_wh"
  # the handler would push an error for every device event; the pack itself sends one at its tick 10 and reports at 20
  # whether the kernel left the handler on. (A fixture: this pack would fail lint; a world does not lint.)
  printf '%s\n' '' 'var _p11_n: int = 0' 'func _unhandled_input(_event) -> void:' '	push_error("a pack handler saw a device event")' \
    'func _physics_process(_d: float) -> void:' '	_p11_n += 1' '	if _p11_n == 10:' '		var ev = InputEventMouseMotion.new()' '		ev.relative = Vector2(5, 5)' \
    '		Input.parse_input_event(ev)' '	if _p11_n == 20 and is_processing_unhandled_input():' '		push_error("the handler is still switched on")' >> "$OUT/p11_wh/scripts/main.gd"
  # the engine's own lines (TL_RAW): the world's error count does not attribute every error (two packs: 0 although both fired)
  out="$(TL_RAW=1 bash "$HERE/world.sh" run "--packs=$OUTW/p11_wh,seed_wall" --frames=60 2>&1)"
  why=""; echo "$out" | grep -q '"kind":"world"' || why="the world did not finish"
  echo "$out" | grep -q 'world done: packs=2 ticks=60' || why="${why:+$why; }the world did not run 60 ticks"
  echo "$out" | grep -qE 'a pack handler saw a device event|the handler is still switched on' && why="${why:+$why; }the pack's handler was on or ran in a world: $(echo "$out" | grep -oE 'a pack handler saw a device event|the handler is still switched on' | sort -u | tr '\n' ';')"
  verdict p11.world_handler_off "$why" "a pack's _unhandled_input in a world: switched off at ready, got no device event"
fi
if p11_on p11.input_handler_fence; then
  rm -rf "$OUT/p11_bb"; cp -r "$EX/bad_bypass" "$OUT/p11_bb"
  printf '%s\n' '' '' 'func _input(_event: InputEvent) -> void:' '	score += 1' >> "$OUT/p11_bb/scripts/main.gd"
  n="$(wc -l < "$OUT/p11_bb/scripts/main.gd" | tr -d ' ')"; n=$((n - 1))
  check p11.input_handler_fence 1 lint "--pack=$OUT/p11_bb" -- '"id":"lint.fence","ok":false' "\"file\":\"scripts/main.gd\",\"line\":$n,\"message\":\"._input handler. is outside"
fi

