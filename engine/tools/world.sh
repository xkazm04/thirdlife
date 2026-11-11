#!/bin/bash
# N2: several packs alive in one process (kernel/world/). Not a verify verb: no tl.verify/1 report.
#
#   world.sh run --packs=<a>,<b>,... [--frames=N] [--seeds=1,2,..] [--at=x:y:z,..] [--spacing=M] [--every=N,..]
#                [--pause=<i|all>:<from>:<ticks>;..] [--mode=smoke|bot] [--space=own|shared] [--trace=N] [--hold=N]
#                [--state=1] [--out=<file>]
#       one JSON line per pack (its state hash; "kind":"pack") and one for the world ("kind":"world"), tl.world/1.
#       A pack is a directory, or a bare name looked up in seeds/, kernel/examples/, kernel/world/packs/ and packs/.
#       List options take one value per pack or one value for all.
#   world.sh same --packs=<a>,<b>,... [options of run]
#       the acceptance check: every pack alone, then all together, three times; PASS when every pack's hash
#       together equals its hash alone, every time.
#   world.sh bench [--only=<test>] [--quick]
#       the measurements; writes kernel/world/BENCH.md and kernel/world/bench.json.
#   N5a (kernel/world/TIERS.md):
#   world.sh walk <script.json> [--log=<file>] [--cost=model|measured] [--ticks=N] [--mode=smoke|bot] [--save=<world file>]
#       a scheduled world: the player's scripted walk decides each pack's tier (stage, sideline, backdrop, ledger)
#       every world tick. Prints the tier log (one line per event) and one line per pack with its hash.
#       A bare script name is looked up in kernel/world/walks/. TL_JSON=1 prints the tl.world/1 lines instead.
#   world.sh replay <world log> [options]      the same world from a log written by --log: the logged decisions again
#   world.sh proof <script.json> [--tiers-all] the walk, then every pack alone for the same number of its own ticks,
#       then the replay of the walk's log; PASS when all three hashes of every pack are equal
#       (--tiers-all: and every pack was stage, sideline and backdrop).
#   world.sh save <world file> --packs=<a>,<b>,... [--plot-spacing=M] | --walk=<script> | --world=<file> [options of run]
#       runs the world and writes the world file (tl.world/1): temporary file, read back, renamed; rev counted up;
#       the revision before it stays as <world file>.prev. Prints one line per plot.
#   world.sh load <world file> [--frames=N] [--mode=smoke|bot] [--save=<world file>]
#       rebuilds every pack FROM ITS SEED (its live state is not restored; only what the pack saved itself with
#       _pack_save/_pack_load, its tick count and its summary). Prints the same lines as save. A file that is not
#       whole JSON is refused with exit code 2 and left as it is.
#   N7 (kernel/world/WORLD.md):
#   world.sh tour <walk> --out-dir=<abs dir> [--ticks=N] [--landscape=off]
#       one world you can walk through: the walk (a script with "visitor": true) in a 1920x1080 window at 0,1440, the
#       visitor on the world's landscape, each plot drawn by its tier; writes the numbered pictures of the walk's
#       `shot` events into --out-dir, prints the tier log and one line per pack, then the proof: every pack's hash in
#       the tour (drawing on) = the same pack alone for the same number of its own ticks = the replay of the log.
#   world.sh tour <walk> --headless            the same without a window and without pictures (the selftest case)
#   world.sh tour <walk> --out-dir=<abs dir> --pictures-only     the window and the pictures, no proof
#   world.sh visit <walk>                      the same world for a person: WASD, Shift, E enters, Q or Esc leaves;
#       a window on the desktop that stays open until it is closed. NOT run by any test.
#
# Env: TL_GODOT (Godot console exe), TL_ENGINE_DIR (this engine/ directory), TL_RAW=1 (also print the engine's lines),
#      TL_WINDOW_POS (default 0,1440), TL_VIEW_TIMEOUT (seconds, default 600; then this run's own window is stopped).
G="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
E="${TL_ENGINE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
if command -v cygpath >/dev/null 2>&1; then
  E="$(cygpath -m "$E")"
  G="$(cygpath -m "$G")"
fi

resolve_pack() {
  local v="$1"
  case "$v" in res://*) echo "$v"; return;; esac
  if [ ! -d "$v" ]; then
    for base in seeds kernel/examples kernel/world/packs packs; do
      if [ -d "$E/$base/$v" ]; then echo "$E/$base/$v"; return; fi
    done
  fi
  if command -v cygpath >/dev/null 2>&1; then
    case "$v" in /*|[A-Za-z]:*) cygpath -m "$v";; *) cygpath -m "$PWD/$v";; esac
  else
    echo "$v"
  fi
}

fix_arg() {
  local a="$1"
  case "$a" in
    --packs=*)
      local v="${a#*=}" out="" item
      IFS=',' read -ra items <<< "$v"
      for item in "${items[@]}"; do out="${out:+$out,}$(resolve_pack "$item")"; done
      echo "--packs=$out";;
    --out=*|--out-dir=*|--log=*|--replay=*|--world=*|--save=*|--tiers=*|--walk=*)
      local k="${a%%=*}" v="${a#*=}"
      if command -v cygpath >/dev/null 2>&1; then
        case "$v" in /*|[A-Za-z]:*) v="$(cygpath -m "$v")";; *) v="$(cygpath -m "$PWD/$v")";; esac
      fi
      echo "$k=$v";;
    *) echo "$a";;
  esac
}

godot_mode() {   # godot_mode <mode> <args...>: the tl.world/1 lines on stdout; the exit code is the engine's
  local mode="$1"; shift
  local args=()
  for a in "$@"; do args+=("$(fix_arg "$a")"); done
  if [ -n "$TL_RAW" ]; then
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$G" --headless --fixed-fps 60 --path "$E" res://kernel/host/host.tscn -- "$mode" "${args[@]}"
    return $?
  fi
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$G" --headless --fixed-fps 60 --path "$E" res://kernel/host/host.tscn -- "$mode" "${args[@]}" 2>/dev/null \
    | tr -d '\r' | grep -E '^(\{"schema":"tl\.world/1"|\[bench\])'
  return "${PIPESTATUS[0]}"
}

window_mode() {  # window_mode <mode> <args...>: as godot_mode, in a window; a window that died before "[view] start" is started again
  local mode="$1"; shift
  local args=() a attempt code=1 tmp log tag pid waited
  for a in "$@"; do args+=("$(fix_arg "$a")"); done
  tmp="${TMPDIR:-${TEMP:-/tmp}}"; command -v cygpath >/dev/null 2>&1 && tmp="$(cygpath -m "$tmp")"
  for attempt in 1 2 3; do
    tag="tlworld_$$_${RANDOM}"
    log="$tmp/$tag.log"
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$G" --position "${TL_WINDOW_POS:-0,1440}" --resolution 1920x1080 --rendering-driver d3d12 --fixed-fps 60 --log-file "$log" --path "$E" res://kernel/host/host.tscn -- "$mode" "${args[@]}" "--tag=$tag" >/dev/null 2>&1 &
    pid=$!
    waited=0
    while kill -0 $pid 2>/dev/null; do
      sleep 1; waited=$((waited + 1))
      if [ $waited -ge "${TL_VIEW_TIMEOUT:-600}" ]; then
        # only the process this call started: it carries this call's own tag on its command line
        echo "[world] no end after ${waited}s: stopping this run's own window ($tag)" >&2
        powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name like 'Godot%'\" | Where-Object { \$_.CommandLine -like '*$tag*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }" >/dev/null 2>&1
        break
      fi
    done
    wait $pid 2>/dev/null; code=$?
    if grep -q '^\[view\] start' "$log" 2>/dev/null; then break; fi
    echo "[world] the window died before it started (exit $code); attempt $attempt of 3" >&2
  done
  if [ -n "$TL_RAW" ]; then cat "$log"; rm -f "$log"; return $code; fi
  tr -d '\r' < "$log" | grep -E '^(\{"schema":"tl\.(world|view|visitor)/1"|\[view\] [^s]|SCRIPT ERROR|ERROR|WARNING|   at:)'
  rm -f "$log"
  return $code
}

# prove <tl.world/1 lines of the walk> <its world log> <1: every pack must have been stage, sideline and backdrop>
# every pack alone for the same number of its own ticks, and the replay of the log; sets $fail
prove() {
  local out="$1" logf="$2" all="$3" rep line n=0 plot frames h seen solo rline rh rf verdict t
  rep="$(godot_mode world "--replay=$logf")" || { echo "the replay ended with an error"; fail=1; }
  echo "plot | pack | own ticks | tiers seen | hash in the walk | alone, same ticks | replay of the log | verdict"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    n=$((n+1))
    plot="$(echo "$line" | jstr plot)"; frames="$(echo "$line" | jnum frames)"; h="$(echo "$line" | jstr state_hash | cut -c1-16)"
    seen="$(echo "$line" | jarr tiers_seen)"
    rline="$(echo "$rep" | grep '"kind":"pack"' | grep "\"plot\":\"$plot\"")"
    rh="$(echo "$rline" | jstr state_hash | cut -c1-16)"; rf="$(echo "$rline" | jnum frames)"
    if [ "$frames" = "0" ] && [ -z "$h" ]; then
      # N7: in the ledger at the end of the walk, or built again from its seed on its last ticks and not ticked since
      verdict="not in memory (ledger), or not ticked since it was built again: nothing to hash"
      [ "$rf" != "0" ] && { verdict="$verdict, DIFFERENT in the replay ($rf ticks)"; fail=1; }
      echo "$plot | $(echo "$line" | jstr pack) | 0 | $seen | - | - | - | $verdict"
      continue
    fi
    solo="$(godot_mode world "--packs=$(echo "$line" | jstr dir)" "--mode=$(echo "$line" | jstr mode)" "--seeds=$(echo "$line" | jnum seed)" "--frames=$frames" | hashes_of | cut -d' ' -f2)"
    verdict="same"
    [ -z "$h" ] && { verdict="NO HASH"; fail=1; }
    if echo "$line" | grep -q '"restored":true'; then
      verdict="restored from what the pack saved itself: not comparable with a run from the seed"
    elif [ "$h" != "$solo" ]; then verdict="DIFFERENT alone"; fail=1; fi
    if [ "$h" != "$rh" ] || [ "$frames" != "$rf" ]; then verdict="$verdict, DIFFERENT in the replay ($rf ticks)"; fail=1; fi
    if [ "$all" = 1 ]; then
      for t in stage sideline backdrop; do case ",$seen," in *",$t,"*) ;; *) verdict="$verdict, never $t"; fail=1;; esac; done
    fi
    echo "$plot | $(echo "$line" | jstr pack) | $frames | $seen | $h | $solo | $rh | $verdict"
  done <<< "$(echo "$out" | grep '"kind":"pack"')"
  [ $n -eq 0 ] && fail=1
}

walk_file() {   # a walk script: a path, or a bare name in kernel/world/walks/
  local v="$1"
  if [ ! -f "$v" ]; then
    if [ -f "$E/kernel/world/walks/$v" ]; then v="$E/kernel/world/walks/$v";
    elif [ -f "$E/kernel/world/walks/$v.json" ]; then v="$E/kernel/world/walks/$v.json"; fi
  fi
  echo "$v"
}
jnum() { grep -o "\"$1\":[-0-9.e]*" | head -1 | cut -d: -f2; }
jstr() { grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }
jarr() { grep -o "\"$1\":\[[^]]*\]" | head -1 | sed -E 's/^[^[]*\[//; s/\]$//; s/"//g'; }
errors_of() { grep '"kind":"world"' | grep -o '"errors":\[[^]]*\]' | head -1 | sed -E 's/^"errors":\[//; s/\]$//'; }
show_walk() {   # the tl.world/1 lines of a scheduled world, as text
  local out="$1" line wt
  [ -n "$TL_JSON" ] && { echo "$out"; return; }
  echo "$out" | grep '"kind":"event"' | sed -E 's/^\{"schema":"tl.world\/1","kind":"event",//; s/\}$//; s/"//g; s/,/  /g; s/^t:([0-9]+)/tick \1 /'
  wt="$(echo "$out" | grep '"kind":"world"' | jnum world_ticks)"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "pack $(echo "$line" | jstr plot) $(echo "$line" | jstr pack) seed $(echo "$line" | jnum seed): ticks $(echo "$line" | jnum frames) of $wt, hash $(echo "$line" | jstr state_hash | cut -c1-16), tier $(echo "$line" | jstr tier), seen [$(echo "$line" | jarr tiers_seen)], changes $(echo "$line" | jnum tier_changes), longest wait $(echo "$line" | jnum max_gap), speed $(echo "$line" | jnum speed_share)"
  done <<< "$(echo "$out" | grep '"kind":"pack"')"
  line="$(echo "$out" | grep '"kind":"world"')"
  echo "world $(echo "$line" | jstr walk): ticks $wt, cost $(echo "$line" | jstr cost), events $(echo "$line" | jnum events), valve demotions $(echo "$line" | jnum valve_demotions), speed $(echo "$line" | jnum speed_pm) (lowest $(echo "$line" | jnum speed_min_pm)) per mille, slice $(echo "$line" | jnum slice) (highest $(echo "$line" | jnum slice_max_seen)), tick p50 $(echo "$line" | jnum iter_ms_p50) ms mean $(echo "$line" | jnum iter_ms_mean) ms p99 $(echo "$line" | jnum iter_ms_p99) ms, gate leaks $(echo "$line" | jnum gate_leaks), wrong-pack calls $(echo "$line" | jnum wrong_pack_calls), kernel calls p50 $(echo "$line" | jnum kernel_ms_p50) ms, script errors $(echo "$line" | jnum script_errors), engine errors $(echo "$line" | jnum engine_errors)"
  local errs; errs="$(echo "$out" | errors_of)"; [ -n "$errs" ] && echo "errors: $errs"
}
show_plots() {  # one line per plot: what save and load must agree on
  local out="$1" line
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "plot $(echo "$line" | jstr plot): pack $(echo "$line" | jstr pack) seed $(echo "$line" | jnum seed) origin [$(echo "$line" | jarr plot_origin)] ticks $(echo "$line" | jnum ticks)"
  done <<< "$(echo "$out" | grep '"kind":"pack"')"
  local errs; errs="$(echo "$out" | errors_of)"; [ -n "$errs" ] && echo "world.sh: $errs"
}

hashes_of() { grep '"kind":"pack"' | sed -E 's/.*"index":([0-9]+).*"state_hash":"([0-9a-f]{16}).*/\1 \2/'; }

case "$1" in
  run)
    shift; godot_mode world "$@"; exit $?;;
  bench)
    shift; godot_mode world-bench "$@"; exit $?;;
  same)
    shift
    packs=""; rest=()
    for a in "$@"; do case "$a" in --packs=*) packs="${a#*=}";; *) rest+=("$a");; esac; done
    [ -z "$packs" ] && { echo "world.sh same: --packs=<a>,<b>,... is required"; exit 2; }
    IFS=',' read -ra items <<< "$packs"
    fail=0
    solo=()
    for i in "${!items[@]}"; do
      h="$(godot_mode world "--packs=${items[$i]}" "${rest[@]}" | hashes_of | cut -d' ' -f2)"
      solo+=("$h"); echo "alone     ${items[$i]}: ${h:-NO HASH}"
      [ -z "$h" ] && fail=1
    done
    for run in 1 2 3; do
      out="$(godot_mode world "--packs=$packs" "${rest[@]}")"
      while read -r idx h; do
        [ -z "$idx" ] && continue
        verdict="same"; [ "$h" != "${solo[$idx]}" ] && { verdict="DIFFERENT (alone ${solo[$idx]})"; fail=1; }
        echo "together $run ${items[$idx]} [#$idx]: $h $verdict"
      done <<< "$(echo "$out" | hashes_of)"
      [ "$(echo "$out" | hashes_of | wc -l)" -ne "${#items[@]}" ] && { echo "together $run: not every pack reported a hash"; fail=1; }
      echo "$out" | grep '"kind":"world"' | grep -o '"gate_leaks":[0-9]*\|"wrong_pack_calls":[0-9]*\|"script_errors":[0-9]*\|"engine_errors":[0-9]*\|"contact_or_body_limit_warnings":[0-9]*' | tr '\n' ' '; echo
    done
    [ $fail -eq 0 ] && echo "PASS world.same: every pack hashes together as it does alone, three runs" || echo "FAIL world.same"
    exit $fail;;
  walk|replay)
    cmd="$1"; shift
    [ -z "$1" ] && { echo "world.sh $cmd: a file is required"; exit 2; }
    f="$1"; shift
    [ "$cmd" = walk ] && f="$(walk_file "$f")"
    out="$(godot_mode world "--$cmd=$f" "$@")"; code=$?
    show_walk "$out"; exit $code;;
  proof)
    shift
    [ -z "$1" ] && { echo "world.sh proof: a walk script is required"; exit 2; }
    f="$(walk_file "$1")"; shift
    all=0; rest=()
    for a in "$@"; do case "$a" in --tiers-all) all=1;; *) rest+=("$a");; esac; done
    tmp="${TMPDIR:-${TEMP:-/tmp}}/tl_world_proof_$$"; mkdir -p "$tmp"
    out="$(godot_mode world "--walk=$f" "--log=$tmp/log.json" "${rest[@]}")"; code=$?
    show_walk "$out"
    fail=0; [ $code -ne 0 ] && { echo "the walk ended with exit code $code"; fail=1; }
    prove "$out" "$tmp/log.json" "$all"
    rm -rf "$tmp"
    [ $fail -eq 0 ] && echo "PASS world.proof: every pack of the walk hashes as it does alone for the same ticks, and the log replays to the same" || echo "FAIL world.proof"
    exit $fail;;
  tour)
    shift
    [ -z "$1" ] && { echo "world.sh tour: a walk script is required"; exit 2; }
    f="$(walk_file "$1")"; shift
    headless=0; outdir=""; rest=(); proof=1
    for a in "$@"; do case "$a" in --headless) headless=1;; --pictures-only) proof=0;; --out-dir=*) outdir="${a#*=}";; *) rest+=("$a");; esac; done
    tmp="${TMPDIR:-${TEMP:-/tmp}}/tl_world_tour_$$"; mkdir -p "$tmp"
    if [ $headless -eq 1 ]; then
      out="$(godot_mode world "--walk=$f" "--log=$tmp/log.json" "${rest[@]}")"; code=$?
    else
      [ -z "$outdir" ] && { echo "world.sh tour: --out-dir=<abs dir> is required (or --headless)"; exit 2; }
      mkdir -p "$outdir"
      out="$(window_mode world-view "--walk=$f" "--log=$tmp/log.json" "--out-dir=$outdir" "${rest[@]}")"; code=$?
    fi
    show_walk "$out"
    echo "$out" | grep -E '^(\[view\]|SCRIPT ERROR|ERROR|WARNING|   at:)'
    echo "$out" | grep '"kind":"picture"' | sed -E 's/.*"out":"([^"]*)".*"stage":(-?[0-9]+).*"cam":"([^"]*)".*"world_tick":([0-9]+).*"draw_calls":([0-9]+).*"primitives":([0-9]+).*"frame_ms_p50":([0-9.]+).*/picture: \1 (tick \4, stage \2, cam \3, \5 draw calls, \6 primitives, frame \7 ms)/'
    tl="$(echo "$out" | grep '"kind":"tour"')"
    [ -n "$tl" ] && echo "window: $(echo "$tl" | jnum pictures) of $(echo "$tl" | jnum shots_asked) pictures, $(echo "$tl" | jnum stage_changes) stage changes, frame p50 $(echo "$tl" | jnum frame_ms_p50_all) ms (simulation and drawing), render cpu $(echo "$tl" | jnum render_cpu_ms_p50) ms gpu $(echo "$tl" | jnum render_gpu_ms_p50) ms, landscape built in $(echo "$tl" | jnum build_ms) ms (terrain $(echo "$tl" | jnum terrain_ms) ms, colliders $(echo "$tl" | jnum space_ms) ms)"
    echo "$out" | grep -E '"kind":"visitor' | sed -E 's/^\{"schema":"tl.view\/1",/visitor: /; s/,"space":.*$//; s/"//g; s/,/  /g'
    echo "$out" | grep '"kind":"tour"' | grep -o '"landscape":{[^}]*' | sed -E 's/^"landscape":\{/landscape: /; s/"//g; s/,/  /g' | head -1
    fail=0; [ $code -ne 0 ] && { echo "the tour ended with exit code $code"; fail=1; }
    if [ $headless -eq 0 ] && [ -z "$tl" ]; then echo "the window did not report the end of the tour"; fail=1; fi
    [ -f "$tmp/log.json" ] && [ -n "$outdir" ] && cp "$tmp/log.json" "$outdir/world_log.json"
    if [ $proof -eq 0 ]; then
      rm -rf "$tmp"
      [ $fail -eq 0 ] && echo "DONE world.tour: pictures only, nothing was proven" || echo "FAIL world.tour"
      exit $fail
    fi
    prove "$out" "$tmp/log.json" 0
    echo "$out" | grep -q '"e":"tier".*"to":"stage"' || { echo "no game was ever put on stage"; fail=1; }
    rm -rf "$tmp"
    [ $fail -eq 0 ] && echo "PASS world.tour: every pack of the tour hashes as it does alone for the same ticks, and the log replays to the same" || echo "FAIL world.tour"
    exit $fail;;
  visit)
    shift
    [ -z "$1" ] && { echo "world.sh visit: a walk script is required"; exit 2; }
    f="$(walk_file "$1")"; shift
    TL_WINDOW_POS="${TL_WINDOW_POS:-120,80}" TL_VIEW_TIMEOUT="${TL_VIEW_TIMEOUT:-86400}" window_mode world-view "--walk=$f" --live "$@"
    exit $?;;
  save)
    shift
    [ -z "$1" ] && { echo "world.sh save: a world file is required"; exit 2; }
    f="$1"; shift
    out="$(godot_mode world "--save=$f" "$@")"; code=$?
    if [ -n "$TL_JSON" ]; then echo "$out"; else show_plots "$out"; fi
    exit $code;;
  load)
    shift
    [ -z "$1" ] && { echo "world.sh load: a world file is required"; exit 2; }
    f="$1"; shift
    out="$(godot_mode world "--world=$f" "$@")"; code=$?
    if [ -n "$TL_JSON" ]; then echo "$out"; else show_plots "$out"; fi
    exit $code;;
  *)
    sed -n '2,45p' "$0"; exit 2;;
esac
