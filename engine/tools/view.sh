#!/bin/bash
# N5b: several packs drawn in one landscape (kernel/world/draw/). Not a verify verb.
#
#   view.sh shot --packs=<a>,<b>,... --out=<abs png> [--at=x:y:z,..] [--yaw=deg,..] [--spacing=80] [--stage=0]
#                [--cam=<view of the stage pack>|overview] [--frame=300] [--radius=40,..] [--lift=m,..] [--band=9]
#                [--standins=off|auto|all] [--far=150] [--also=<stage>:<cam>:<abs png>;..] [--settle=frames]
#                [--until=end] [--crane=x:y:z,x:y:z] [--hud=on|off] [--ground=on|off] [--mode=bot|smoke]
#                [--frames=36000] [--seeds=..] [--mech=a|b] [--cull=auto|aabb|margin] [--measure=120]
#       a 1920x1080 window at 0,1440 (Direct3D 12), every pack played by its bot, one picture at world tick --frame.
#       --at is the PLOT of each pack (default: a grid, --spacing metres apart); the packs themselves are simulated
#       at their own origin. --radius cuts each pack to its plot (0 = whole pack); --lift overrides the measured
#       height of the pack's ground at the plot edge. --also takes more pictures in the same process after re-basing
#       the world on another stage pack. --crane places the overview camera (from,to in world coordinates).
#       Prints one tl.view/1 line per picture; with --until=end also the world's tl.world/1 lines (final hashes).
#   view.sh check --packs=<a>,<b>,... [options of shot]
#       item 3: the state hash of every pack with drawing on (windowed, to the end of every bot) against its hash
#       from the headless `world.sh run --mode=bot`. PASS when all are equal.
#
# Env: TL_GODOT, TL_ENGINE_DIR, TL_RAW=1 (print the engine's own lines too), TL_WINDOW_POS (default 0,1440),
#      TL_VIEW_TIMEOUT (seconds, default 420; then this run's own processes are stopped), TL_VIEW_REALTIME=1.
# What it is and what was measured: kernel/world/draw/DRAW.md.
HERE="$(cd "$(dirname "$0")" && pwd)"
G="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
E="${TL_ENGINE_DIR:-$(cd "$HERE/.." && pwd)}"
if command -v cygpath >/dev/null 2>&1; then
  E="$(cygpath -m "$E")"
  G="$(cygpath -m "$G")"
fi

# P11: one test window at a time on this machine. Two windows on the same spot of the screen throttle each other to
# about 270 ms a frame (P5, P6 re-runs), so a windowed run waits for a lock under the system's temporary folder that
# holds the holder's process id; the lock of a holder that is gone is taken over. TL_WINDOW_LOCK=off skips it.
# P14: the one lock of every test window (world.sh, view.sh, tl perf's windowed scenarios: devx/lib/perf/scenarios.mjs
# withWindowLock). Its `pid` holds a Git Bash process id, or `win:<id>` when a node process holds it.
lock_alive() {
  case "$1" in
    win:*) tasklist //FI "PID eq ${1#win:}" //NH 2>/dev/null | grep -q " ${1#win:} ";;
    *) kill -0 "$1" 2>/dev/null;;
  esac
}
win_lock() {
  [ "${TL_WINDOW_LOCK:-on}" = off ] && return 0
  local d="${TEMP:-${TMP:-/tmp}}" waited=0 holder
  command -v cygpath >/dev/null 2>&1 && d="$(cygpath -u "$d")"
  TL_LOCK_DIR="$d/thirdlife_window.lock"
  while ! mkdir "$TL_LOCK_DIR" 2>/dev/null; do
    holder="$(cat "$TL_LOCK_DIR/pid" 2>/dev/null)"
    if [ -n "$holder" ] && ! lock_alive "$holder"; then
      echo "[lock] the holder ($holder) is gone: the window lock is taken over" >&2
      rm -rf "$TL_LOCK_DIR"; continue
    fi
    [ $waited -eq 0 ] && echo "[lock] another test window is open (process ${holder:-?}): waiting for it" >&2
    sleep 2; waited=$((waited + 2))
  done
  echo "$TL_LOCK_PID" > "$TL_LOCK_DIR/pid"; TL_LOCK_HELD=1
  echo "[lock] window lock taken by $TL_LOCK_PID after ${waited}s" >&2
  trap win_unlock EXIT
}
win_unlock() { [ -n "$TL_LOCK_HELD" ] && rm -rf "$TL_LOCK_DIR"; TL_LOCK_HELD=""; return 0; }
TL_LOCK_PID=$$

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

abs_path() {
  local v="$1"
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
    --out=*)
      echo "--out=$(abs_path "${a#*=}")";;
    --also=*)
      local v="${a#*=}" out="" item
      IFS=';' read -ra items <<< "$v"
      for item in "${items[@]}"; do
        local st="${item%%:*}" rest="${item#*:}"
        out="${out:+$out;}$st:${rest%%:*}:$(abs_path "${rest#*:}")"
      done
      echo "--also=$out";;
    *) echo "$a";;
  esac
}

view_run() {   # the tl.view/1 and tl.world/1 lines on stdout; a window that died before "[view] start" is started again
  local args=() attempt code tmp log tag pid waited fixed="--fixed-fps 60"
  # TL_VIEW_REALTIME=1: no fixed frame step, so a slow frame is followed by up to 8 physics ticks (the project's
  # limit) instead of one. `check` uses it: a run to the end of every bot stays bounded when the GPU is busy.
  [ -n "$TL_VIEW_REALTIME" ] && fixed=""
  for a in "$@"; do args+=("$(fix_arg "$a")"); done
  tmp="${TMPDIR:-${TEMP:-/tmp}}"; command -v cygpath >/dev/null 2>&1 && tmp="$(cygpath -m "$tmp")"
  # N7: the viewer is the host mode `world-view` (kernel/host/host.gd), which builds the class cache like every verb
  win_lock          # P11: one test window at a time on this machine; the window is silent (Dummy sound driver)
  for attempt in 1 2 3; do
    tag="tlview_$$_${RANDOM}"
    log="$tmp/$tag.log"
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$G" --position "${TL_WINDOW_POS:-0,1440}" --resolution 1920x1080       --rendering-driver d3d12 --audio-driver Dummy $fixed --log-file "$log" --path "$E" res://kernel/host/host.tscn       -- world-view "${args[@]}" "--tag=$tag" >/dev/null 2>&1 &
    pid=$!
    waited=0
    while kill -0 $pid 2>/dev/null; do
      sleep 1; waited=$((waited + 1))
      if [ $waited -ge "${TL_VIEW_TIMEOUT:-420}" ]; then
        # only the processes this call started: they carry its own tag on their command line
        echo "[view] no end after ${waited}s: stopping this run's own processes ($tag)" >&2
        powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name like 'Godot%'\" | Where-Object { \$_.CommandLine -like '*$tag*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }" >/dev/null 2>&1
        break
      fi
    done
    wait $pid 2>/dev/null; code=$?
    if grep -q '^\[view\] start' "$log" 2>/dev/null; then break; fi
    echo "[view] the window died before it started (exit $code); attempt $attempt of 3" >&2
  done
  if [ -n "$TL_RAW" ]; then cat "$log"; rm -f "$log"; win_unlock; return $code; fi
  [ -n "$TL_VIEW_TAIL" ] && tail -n 20 "$log" 2>/dev/null | tr -d '\r' > "$TL_VIEW_TAIL"   # P14c: check's loud failure
  tr -d '\r' < "$log" | grep -E '^(\{"schema":"tl\.(world|view)/1"|\[view\]|SCRIPT ERROR|ERROR|   at:)' | grep -v '^\[view\] start'
  rm -f "$log"
  win_unlock
  return $code
}

hashes_of() { grep '"kind":"pack"' | sed -E 's/.*"index":([0-9]+).*"frames":([0-9]+).*"state_hash":"([0-9a-f]{16}).*/\1 \3 \2/'; }

case "$1" in
  shot)
    shift; view_run "$@"; exit $?;;
  check)
    shift
    packs=""; rest=(); has_out=0
    for a in "$@"; do case "$a" in --packs=*) packs="${a#*=}";; --out=*) has_out=1; rest+=("$a");; *) rest+=("$a");; esac; done
    [ -z "$packs" ] && { echo "view.sh check: --packs=<a>,<b>,... is required"; exit 2; }
    tmp="${TMPDIR:-${TEMP:-/tmp}}"
    [ $has_out -eq 0 ] && rest+=("--out=$tmp/tl_view_check_$$.png")
    IFS=',' read -ra items <<< "$packs"
    head="$(bash "$HERE/world.sh" run "--packs=$packs" --mode=bot --frames=36000 | hashes_of)"
    tail_f="$tmp/tl_view_check_$$.tail"
    drawn_out="$(TL_VIEW_TAIL="$tail_f" TL_VIEW_REALTIME=1 TL_VIEW_TIMEOUT="${TL_VIEW_TIMEOUT:-900}" view_run "--packs=$packs" "${rest[@]}" --until=end)"
    vcode=$?
    drawn="$(echo "$drawn_out" | hashes_of)"
    if [ -z "$drawn" ]; then   # P14c: a silent windowed half fails loudly with what the window did print
      echo "view.check: the windowed run gave no pack hash (exit $vcode); the last 20 lines of its log:"
      sed 's/^/  | /' "$tail_f" 2>/dev/null; rm -f "$tail_f"; echo "FAIL view.check"; exit 1
    fi
    rm -f "$tail_f"
    echo "$drawn_out" | grep '"schema":"tl.view/1"' | sed -E 's/.*"out":"([^"]*)".*"stage":([0-9]+).*"cam":"([^"]*)".*/picture: \1 (stage \2, cam \3)/'
    fail=0
    for i in "${!items[@]}"; do
      h="$(echo "$head" | awk -v i="$i" '$1==i{print $2" at "$3}')"
      d="$(echo "$drawn" | awk -v i="$i" '$1==i{print $2" at "$3}')"
      verdict="same"
      if [ -z "$h" ] || [ -z "$d" ] || [ "$h" != "$d" ]; then verdict="DIFFERENT"; fail=1; fi
      echo "pack $i ${items[$i]}: headless ${h:-NO HASH}  drawn ${d:-NO HASH}  $verdict"
    done
    echo "$drawn_out" | grep '"kind":"world"' | grep -o '"gate_leaks":[0-9]*\|"wrong_pack_calls":[0-9]*\|"script_errors":[0-9]*\|"engine_errors":[0-9]*' | tr '\n' ' '; echo
    [ $has_out -eq 0 ] && rm -f "$tmp/tl_view_check_$$.png"
    [ $fail -eq 0 ] && echo "PASS view.check: every pack's state hash with drawing on equals its headless hash" || echo "FAIL view.check"
    exit $fail;;
  *)
    sed -n '2,21p' "$0"; exit 2;;
esac
