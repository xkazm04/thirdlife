#!/bin/bash
# Our side of the sound comparison (lane K6): the hokej pack played by its scripted hand in a window through Godot's
# movie writer (fixed 60 frames a second; the sound goes into the movie, not to the sound card), then the sound alone
# as a wav. usage: record_ours.sh <out.wav> [frames=4500] [test=tests/bot_match_hand.gd]
# The movie (MJPEG, large) is written beside the wav and deleted.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"; E="$(cd "$HERE/../.." && pwd)"
command -v cygpath >/dev/null 2>&1 && E="$(cygpath -m "$E")"
G="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
out="$1"; n="${2:-4500}"; test="${3:-tests/bot_match_hand.gd}"
[ -n "$out" ] || { echo "usage: record_ours.sh <out.wav> [frames] [test]"; exit 2; }
avi="${out%.wav}.avi"; rm -f "$avi" "$out"
MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' timeout 900 "$G" --position 0,1440 --resolution 480x270 --rendering-driver d3d12 --fixed-fps 60 \
  --write-movie "$avi" --path "$E" --quit-after "$n" res://kernel/host/host.tscn -- worker --mode=bot "--pack=$E/packs/hokej" "--test=$test" \
  "--frames=$n" "--report=${avi%.avi}.report.json" > "${avi%.avi}.log" 2>&1 || true
[ -f "$avi" ] || { echo "FAIL no movie (see ${avi%.avi}.log)"; exit 1; }
ffmpeg -hide_banner -loglevel error -y -i "$avi" -vn -c:a pcm_s16le "$out"
rm -f "$avi"
ls -la "$out"
