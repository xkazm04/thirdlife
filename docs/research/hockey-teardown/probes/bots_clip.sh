#!/bin/bash
# H2: a bots run of the probe pack in a WINDOW (d3d12, 1280x720, movie writer 60 fps), cut to mp4. From N1's clip.sh.
#   clip.sh <level> <hand> <seed> <frames> <out.mp4> [from_s] [len_s]
T=C:/Users/kazda/kiro/third-life/.claude/worktrees/d23-bots
L="$1"; H="$2"; SEED="$3"; NFR="$4"; OUT="$5"; FROM="${6:-0}"; LEN="${7:-20}"
G=C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe
base="$(basename "${OUT%.mp4}")"; avi="$T/.tl/clip/$base.avi"; rm -f "$avi"
PROBE_LEVEL=$L PROBE_HAND=$H MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$G" --position "${GPOS:-0,1440}" --resolution 1280x720 --rendering-driver d3d12 --fixed-fps 60 \
  --write-movie "$avi" --path "$T/engine" --quit-after "$NFR" res://kernel/host/host.tscn -- worker --mode=bot \
  "--pack=$T/.tl/probe/hockey" "--seed=$SEED" --test=tests/bots_probe.gd "--frames=$NFR" "--report=$T/.tl/clip/$base.json" > "$T/.tl/clip/$base.log" 2>&1
[ -s "$avi" ] || { echo "FAIL no movie ($avi)"; exit 1; }
ffmpeg -y -loglevel error -ss "$FROM" -t "$LEN" -i "$avi" -vf scale=960:540 -c:v libx264 -pix_fmt yuv420p -crf 23 -r 30 "$OUT" && ls -la "$OUT"
