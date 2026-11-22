#!/bin/bash
# N3: a hockey bot test played in a WINDOW (d3d12, 1280x720, the engine's movie writer at 60 fps), cut to an mp4.
#   clip.sh <tree> <test.gd> <seed> <frames> <out.mp4> [from_s] [len_s]
# The raw avi stays under <tree>/.tl/clips; the mp4 (cut from from_s for len_s, 960x540) goes where <out> says.
T="$1"; TEST="$2"; SEED="$3"; NFR="$4"; OUT="$5"; FROM="${6:-0}"; LEN="${7:-20}"
G="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
mkdir -p "$T/.tl/clips"
base="$(basename "${OUT%.mp4}")"; avi="$T/.tl/clips/$base.avi"; rm -f "$avi"
MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$G" --position "${GPOS:-0,1440}" --resolution 1280x720 --rendering-driver d3d12 --fixed-fps 60 \
  --write-movie "$avi" --path "$T/engine" --quit-after "$NFR" res://kernel/host/host.tscn -- worker --mode=bot \
  "--pack=$T/engine/packs/hockey" "--test=$TEST" "--seed=$SEED" "--frames=$NFR" "--report=$T/.tl/clips/$base.json" > "$T/.tl/clips/$base.log" 2>&1
[ -s "$avi" ] || { echo "FAIL no movie ($avi)"; exit 1; }
ffmpeg -y -loglevel error -ss "$FROM" -t "$LEN" -i "$avi" -vf scale=960:540 -c:v libx264 -pix_fmt yuv420p -crf 23 -r 60 "$OUT" && ls -la "$OUT"
