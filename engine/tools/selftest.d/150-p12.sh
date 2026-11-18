# Check preparation under capped rendering and when a plot needs its pack immediately.
# Reload a changed script and compare the resulting pack hashes.

# --- P12 ---
P12G="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
P12E="$(cd "$HERE/.." && pwd)"
command -v cygpath >/dev/null 2>&1 && { P12E="$(cygpath -m "$P12E")"; P12G="$(cygpath -m "$P12G")"; }
# A pack's preparation on the build queue's worker does not hang on the frame rate: seed_wall prepared while the
# main thread holds 250 ms frames (a throttled window) takes about as long as with free frames (before P12: 20
# frames, 5 s, because TLMesh.merge asked the renderer for its arrays and each ask waited for the next frame).
if [ -z "$FILTER" ] || [[ "world.prepare_capped" == *"$FILTER"* ]]; then
  p12probe() { MSYS_NO_PATHCONV=1 "$P12G" --headless --path "$P12E" -s res://kernel/world/jobs_probe.gd -- "$P12E/seeds/seed_wall" "$1" 2>/dev/null | tr -d '\r' | grep '^PROBE'; }
  free="$(p12probe 0)"; capped="$(p12probe 250)"
  fms="$(echo "$free" | sed -nE 's/.*prepare_ms=([0-9.]+).*/\1/p' | cut -d. -f1)"; cms="$(echo "$capped" | sed -nE 's/.*prepare_ms=([0-9.]+).*/\1/p' | cut -d. -f1)"
  cfr="$(echo "$capped" | sed -nE 's/.*frames=([0-9]+).*/\1/p')"
  why=""
  [ -z "$fms" ] || [ -z "$cms" ] && why="no probe line: '$free' '$capped'"
  [ -z "$why" ] && [ "$cfr" -gt 8 ] && why="the capped preparation took $cfr frames of 250 ms ($cms ms; free frames: $fms ms)"
  verdict world.prepare_capped "$why" "seed_wall prepared in $fms ms with free frames, $cms ms ($cfr frames) with 250 ms frames"
fi
# A game that is needed is there: in queue mode (a window's mode) the plot on stage at tick 0 cannot be prepared
# yet; it jumps the queue and is built at once (counted in `forced`), and on the walk's last tick every game still
# wanted is built. The walk, each pack alone and the replay of the log hash the same.
if [ -z "$FILTER" ] || [[ "world.needed_now" == *"$FILTER"* ]]; then
  WN="$OUT/world_needed"; rm -rf "$WN"; mkdir -p "$WN"
  command -v cygpath >/dev/null 2>&1 && WN="$(cygpath -m "$WN")"
  sed 's/"mode": "wait"/"mode": "queue"/' "$HERE/../kernel/world/walks/queue.json" > "$WN/needed.json"
  out="$(bash "$HERE/world.sh" proof "$WN/needed.json" 2>&1)"
  js="$(TL_JSON=1 bash "$HERE/world.sh" walk "$WN/needed.json" 2>&1 | grep '"kind":"world"')"
  why=""; echo "$out" | grep -q '^PASS world.proof' || why="$(echo "$out" | grep -E 'DIFFERENT|NO HASH|FAIL|rror' | head -3 | tr '\n' ' ')"
  echo "$js" | grep -q '"forced_list":\[\["a",0,' || why="${why:+$why; }plot a (on stage at tick 0) was not built at once: $(echo "$js" | grep -oE '"forced_list":[^}]*' | head -c 200)"
  echo "$js" | grep -q '"never_built":0' || why="${why:+$why; }a wanted game was never built"
  verdict world.needed_now "$why" "forced $(echo "$js" | grep -oE '"forced_list":\[[^}]*\]\]' | head -c 160); walk = alone = replay"
fi
# A changed script is seen by a reload (PATCHES-P5 2b): ex_slide's main.gd is replaced at tick 299 by one that
# starts the blocks 1.5 times faster, and the pack is reloaded at tick 300. Its hash at the end is the changed
# pack alone, not the old one; the other games are as in the undisturbed run.
if [ -z "$FILTER" ] || [[ "world.reload_script" == *"$FILTER"* ]]; then
  WS="$OUT/world_reload_script"; rm -rf "$WS"; mkdir -p "$WS"
  command -v cygpath >/dev/null 2>&1 && WS="$(cygpath -m "$WS")"
  cp -r "$EX/ex_slide" "$WS/slide"
  sed 's/start_speed = float(data\["start_speed"\])/start_speed = float(data["start_speed"]) * 1.5/' "$EX/ex_slide/scripts/main.gd" > "$WS/main_changed.gd"
  wsw() { printf '{"schema":"tl.walk/1","name":"reload_script","ticks":600,"mode":"smoke","plots":[{"id":"a","pack":"%s","origin":[0,0,0],"seed":1},{"id":"b","pack":"pack_min","origin":[60,0,0],"seed":1}],"player":[[0,[0,0,0]]]%s}\n' "$WS/slide" "$2" > "$1"; }
  wsw "$WS/quiet.json" ""
  wsw "$WS/reload.json" ",\"events\":[{\"t\":300,\"e\":\"reload\",\"plot\":\"a\"}],\"edits\":[[299,\"$WS/slide/scripts/main.gd\",\"$WS/main_changed.gd\"]]"
  hp2() { grep '"kind":"pack"' | grep "\"plot\":\"$1\"" | sed -E 's/.*"frames":([0-9]+).*"state_hash":"([0-9a-f]{16}).*/\1 \2/'; }
  q="$(TL_JSON=1 bash "$HERE/world.sh" walk "$WS/quiet.json" 2>&1)"
  r="$(TL_JSON=1 bash "$HERE/world.sh" walk "$WS/reload.json" 2>&1)"
  af="$(echo "$r" | hp2 a | cut -d' ' -f1)"; ah="$(echo "$r" | hp2 a | cut -d' ' -f2)"
  hx2() { grep '"kind":"pack"' | sed -E 's/.*"state_hash":"([0-9a-f]{16}).*/\1/' | tr -d '\n'; }
  changed="$(bash "$HERE/world.sh" run "--packs=$WS/slide" --frames="${af:-0}" | hx2)"
  plain="$(bash "$HERE/world.sh" run "--packs=$EX/ex_slide" --frames="${af:-0}" | hx2)"
  why=""
  grep -q '\* 1.5' "$WS/main_changed.gd" || why="the changed script was not made (sed found nothing)"
  grep -q '\* 1.5' "$WS/slide/scripts/main.gd" || why="${why:+$why; }main.gd was not replaced at tick 299"
  echo "$r" | grep -q '"t":300,"e":"built","plot":"a"' || why="${why:+$why; }the reloaded pack did not arrive at tick 300"
  [ -n "$ah" ] && [ "$ah" = "$changed" ] || why="${why:+$why; }the reloaded game [$af ticks $ah] is not the changed pack alone [$changed] (old script: $plain)"
  [ "$changed" != "$plain" ] || why="${why:+$why; }the changed script has no effect on the hash: the case proves nothing"
  [ -n "$(echo "$q" | hp2 b)" ] && [ "$(echo "$q" | hp2 b)" = "$(echo "$r" | hp2 b)" ] || why="${why:+$why; }pack_min differs from the undisturbed run"
  verdict world.reload_script "$why" "ex_slide's main.gd changed at tick 299, reloaded at 300: $af ticks, $ah = the changed pack alone, not $plain"
fi

