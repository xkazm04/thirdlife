#!/bin/bash
# P8 spike: one pack simulated in a second process and drawn by the first (kernel/proc/PROCESS.md). A measurement,
# not a verify verb and not on the path a game runs on.
#
#   proc.sh run     --pack=<dir> [--test=tests/x.gd] [--seed=1] [--frames=36000] [--out=<png>] [--shot=600] [--fast]
#                   [--stall-at=<f> --stall-ms=<ms>] [--die-at=<f>] [--port=<n>] [--res=1280x720]
#       1. the pack played by its bot in ONE headless process (tl.sh bot): its state hash and frame time;
#       2. the same run in TWO processes: S (headless: the simulation and the bot) and D (a window at 0,1440: the
#          picture, built by the pack's own setup and then only following S). Prints S's and D's figures (one
#          JSON line each), the two hashes side by side, and where D's capture is. Real time by default (the
#          window shows the game at its own speed); --fast lets S run as fast as it can (figures of cost per tick).
#       --stall-at / --die-at: S sleeps, or ends without a word, at that frame: D must go on (it reports it).
#   proc.sh latency --pack=<dir> [--n=10] [--key=right,left] [--watch=Paddle_player] [--port=<n>]
#       the delay from a key to the picture, in drawn frames and ms: one process first, then two.
#   proc.sh solo    --pack=<dir> [--test=..] [--seed=1] [--frames=..]
#       the pack played by its bot in one WINDOWED process in real time (the comparison for D's and S's processor time).
#   proc.sh chan    the round trip of one message through each channel the engine offers a script (TCP and UDP
#                   on 127.0.0.1, a named pipe), both ends in one headless process
#   proc.sh left    how many processes of this tool are still running (it must say 0)
#
# Exit code: 0 the run ended and (for `run` without --die-at) both hashes are equal, 1 they are not, 2 could not run.
# Env: TL_GODOT, TL_ENGINE_DIR, TL_WINDOW_POS (default 0,1440), TL_PROC_TIMEOUT (seconds, default 600), TL_RAW=1.
# The channel is a TCP connection on 127.0.0.1 (loopback only); every process started here carries a tag on its
# command line and only tagged processes are ever stopped.
HERE="$(cd "$(dirname "$0")" && pwd)"
G="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
E="${TL_ENGINE_DIR:-$(cd "$HERE/.." && pwd)}"
if command -v cygpath >/dev/null 2>&1; then
  E="$(cygpath -m "$E")"
  G="$(cygpath -m "$G")"
fi
TMP="${TMPDIR:-${TEMP:-/tmp}}"; command -v cygpath >/dev/null 2>&1 && TMP="$(cygpath -m "$TMP")"
POS="${TL_WINDOW_POS:-0,1440}"
LIMIT="${TL_PROC_TIMEOUT:-600}"

abs_path() {
  local v="$1"
  if command -v cygpath >/dev/null 2>&1; then
    case "$v" in /*|[A-Za-z]:*) cygpath -m "$v";; *) cygpath -m "$PWD/$v";; esac
  else
    echo "$v"
  fi
}

resolve_pack() {
  local v="$1"
  if [ ! -d "$v" ]; then
    for base in seeds kernel/examples packs; do
      if [ -d "$E/$base/$v" ]; then echo "$E/$base/$v"; return; fi
    done
  fi
  abs_path "$v"
}

godot() { MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$G" "$@"; }

count_tagged() {   # how many engine processes carry this tag on their command line
  powershell -NoProfile -Command "@(Get-CimInstance Win32_Process -Filter \"Name like 'Godot%'\" | Where-Object { \$_.CommandLine -like '*$1*' }).Count" 2>/dev/null | tr -d '\r'
}

stop_tagged() {
  powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name like 'Godot%'\" | Where-Object { \$_.CommandLine -like '*$1*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }" >/dev/null 2>&1
}

wait_pids() {   # wait for this run's processes; past the limit, stop only the tagged ones
  local tag="$1" waited=0; shift
  while :; do
    local alive=0 p
    for p in "$@"; do kill -0 "$p" 2>/dev/null && alive=1; done
    [ $alive -eq 0 ] && break
    sleep 1; waited=$((waited + 1))
    if [ $waited -ge "$LIMIT" ]; then
      echo "[proc] no end after ${waited}s: stopping this run's own processes ($tag)" >&2
      stop_tagged "$tag"; break
    fi
  done
  for p in "$@"; do wait "$p" 2>/dev/null; done
}

lines_of() { tr -d '\r' < "$1" | grep -E '^(\{"proc":1,|\[proc\]|SCRIPT ERROR|ERROR|   at:)'; }
field() { grep -o "\"$2\":\"[^\"]*\"" <<< "$1" | head -1 | sed -E 's/.*:"(.*)"/\1/'; }

cmd="$1"; shift
pack=""; test=""; seed="1"; frames=""; out=""; shot="600"; fast=0; port=$((47000 + $$ % 2000)); res="1280x720"
stall_at=""; stall_ms="1000"; die_at=""; n="10"; key="right,left"; watch="Paddle_player"
for a in "$@"; do
  case "$a" in
    --pack=*) pack="$(resolve_pack "${a#*=}")";;
    --test=*) test="${a#*=}";;
    --seed=*) seed="${a#*=}";;
    --frames=*) frames="${a#*=}";;
    --out=*) out="$(abs_path "${a#*=}")";;
    --shot=*) shot="${a#*=}";;
    --fast) fast=1;;
    --port=*) port="${a#*=}";;
    --res=*) res="${a#*=}";;
    --stall-at=*) stall_at="${a#*=}";;
    --stall-ms=*) stall_ms="${a#*=}";;
    --die-at=*) die_at="${a#*=}";;
    --n=*) n="${a#*=}";;
    --key=*) key="${a#*=}";;
    --watch=*) watch="${a#*=}";;
    *) echo "proc.sh: unknown option $a"; exit 2;;
  esac
done

need_pack() {
  if [ -z "$pack" ] || [ ! -f "$pack/pack.json" ]; then echo "proc.sh $cmd: --pack=<dir> is required (no pack.json in '$pack')"; exit 2; fi
  [ -z "$test" ] && test="$(grep -o '"tests/[^"]*"' "$pack/pack.json" | head -1 | tr -d '"')"
}

tag="tlproc_$$_${RANDOM}"

case "$cmd" in
  run)
    need_pack
    [ -z "$frames" ] && frames=36000
    [ -z "$out" ] && out="$TMP/$tag.png"
    echo "[proc] 1/2 one process: tl.sh bot --pack=$pack --test=$test --seed=$seed --frames=$frames"
    solo="$(TL_QUIET=1 bash "$HERE/tl.sh" bot "--pack=$pack" "--test=$test" "--seed=$seed" "--frames=$frames")"
    solo_hash="$(field "$solo" state_hash)"
    solo_frames="$(grep -o '"frames":[0-9]*' <<< "$solo" | head -1 | cut -d: -f2)"
    solo_p50="$(grep -o '"frame_ms_p50":[0-9.]*' <<< "$solo" | head -1 | cut -d: -f2)"
    echo "[proc] one process: outcome $(field "$solo" outcome), bot frames $solo_frames, frame_ms_p50 $solo_p50, state_hash $solo_hash"
    pace="--max-fps 60"; [ $fast -eq 1 ] && pace="--fixed-fps 60"
    sargs=(sim --mode=bot "--pack=$pack" "--test=$test" "--seed=$seed" "--frames=$frames" "--port=$port" "--result=$TMP/$tag.result.json" "--tag=$tag")
    [ -n "$stall_at" ] && sargs+=("--stall-at=$stall_at" "--stall-ms=$stall_ms")
    [ -n "$die_at" ] && sargs+=("--die-at=$die_at")
    echo "[proc] 2/2 two processes on 127.0.0.1:$port: S headless ($pace), D a ${res} window at $POS"
    godot --headless $pace --path "$E" res://kernel/proc/proc.tscn -- "${sargs[@]}" > "$TMP/$tag.s.log" 2>&1 &
    spid=$!
    godot --position "$POS" --resolution "$res" --rendering-driver d3d12 --max-fps 60 --path "$E" res://kernel/proc/proc.tscn \
      -- draw "--pack=$pack" "--seed=$seed" "--port=$port" "--out=$out" "--shot=$shot" "--tag=$tag" > "$TMP/$tag.d.log" 2>&1 &
    dpid=$!
    wait_pids "$tag" $spid $dpid
    [ -n "$TL_RAW" ] && { echo "---- S"; cat "$TMP/$tag.s.log"; echo "---- D"; cat "$TMP/$tag.d.log"; }
    s_lines="$(lines_of "$TMP/$tag.s.log")"; d_lines="$(lines_of "$TMP/$tag.d.log")"
    echo "$s_lines" | sed 's/^/S: /'; echo "$d_lines" | sed 's/^/D: /'
    s_fig="$(echo "$s_lines" | grep '"role":"sim"' | tail -1)"
    s_hash="$(field "$s_fig" state_hash)"
    s_frames="$(grep -o '"frames":[0-9]*' <<< "$s_fig" | head -1 | cut -d: -f2)"
    rm -f "$TMP/$tag.s.log" "$TMP/$tag.d.log" "$TMP/$tag.result.json"
    echo "[proc] state hash, one process : ${solo_hash:-NONE} (frames $solo_frames)"
    echo "[proc] state hash, process S   : ${s_hash:-NONE} (frames ${s_frames:-?})"
    [ -f "$out" ] && echo "[proc] capture of D's window : $out"
    [ -f "${out%.png}.lost.png" ] && echo "[proc] capture after S was lost: ${out%.png}.lost.png"
    echo "[proc] processes of this run still alive: $(count_tagged "$tag")"
    if [ -n "$die_at" ]; then
      echo "$d_lines" | grep -q '"s_lost":true' && { echo "PASS proc.run: S ended without a word and D went on drawing"; exit 0; }
      echo "FAIL proc.run: D did not report the loss of S"; exit 1
    fi
    if [ -n "$solo_hash" ] && [ "$solo_hash" = "$s_hash" ]; then
      echo "PASS proc.run: the pack's state hash in process S equals its hash in one process"; exit 0
    fi
    echo "FAIL proc.run: the hashes differ or one is missing"; exit 1;;
  latency)
    need_pack
    echo "[proc] 1/2 one windowed process, $n presses of $key, watching $watch"
    godot --position "$POS" --resolution "$res" --rendering-driver d3d12 --max-fps 60 --path "$E" res://kernel/proc/proc.tscn \
      -- solo --mode=smoke "--pack=$pack" "--seed=$seed" --frames=36000 "--latency=$n" "--key=$key" "--watch=$watch" "--tag=$tag" > "$TMP/$tag.o.log" 2>&1 &
    wait_pids "$tag" $!
    lines_of "$TMP/$tag.o.log" | sed 's/^/one: /'
    echo "[proc] 2/2 two processes on 127.0.0.1:$port"
    godot --headless --max-fps 60 --path "$E" res://kernel/proc/proc.tscn -- sim --mode=smoke "--pack=$pack" "--seed=$seed" --frames=36000 \
      "--port=$port" "--tag=$tag" > "$TMP/$tag.s.log" 2>&1 &
    spid=$!
    godot --position "$POS" --resolution "$res" --rendering-driver d3d12 --max-fps 60 --path "$E" res://kernel/proc/proc.tscn \
      -- draw "--pack=$pack" "--seed=$seed" "--port=$port" "--latency=$n" "--key=$key" "--watch=$watch" "--tag=$tag" > "$TMP/$tag.d.log" 2>&1 &
    dpid=$!
    wait_pids "$tag" $spid $dpid
    [ -n "$TL_RAW" ] && { cat "$TMP/$tag.o.log" "$TMP/$tag.s.log" "$TMP/$tag.d.log"; }
    lines_of "$TMP/$tag.s.log" | sed 's/^/S: /'; lines_of "$TMP/$tag.d.log" | sed 's/^/D: /'
    rm -f "$TMP/$tag.o.log" "$TMP/$tag.s.log" "$TMP/$tag.d.log"
    echo "[proc] processes of this run still alive: $(count_tagged "$tag")"
    exit 0;;
  solo)
    need_pack
    [ -z "$frames" ] && frames=36000
    godot --position "$POS" --resolution "$res" --rendering-driver d3d12 --max-fps 60 --path "$E" res://kernel/proc/proc.tscn \
      -- solo --mode=bot "--pack=$pack" "--test=$test" "--seed=$seed" "--frames=$frames" "--tag=$tag" > "$TMP/$tag.o.log" 2>&1 &
    wait_pids "$tag" $!
    [ -n "$TL_RAW" ] && cat "$TMP/$tag.o.log"
    lines_of "$TMP/$tag.o.log" | sed 's/^/one: /'
    rm -f "$TMP/$tag.o.log"
    echo "[proc] processes of this run still alive: $(count_tagged "$tag")"
    exit 0;;
  chan)
    godot --headless --path "$E" --script res://kernel/proc/proc_chan.gd -- "--tag=$tag" > "$TMP/$tag.c.log" 2>&1 &
    wait_pids "$tag" $!
    tr -d '\r' < "$TMP/$tag.c.log" | grep -E '^(tcp|udp|pipe|SCRIPT ERROR|ERROR)'
    rm -f "$TMP/$tag.c.log"
    echo "[proc] processes of this run still alive: $(count_tagged "$tag")"
    exit 0;;
  left)
    echo "[proc] processes of this tool still running: $(count_tagged "tlproc_")"; exit 0;;
  *)
    sed -n '2,24p' "$0"; exit 2;;
esac
